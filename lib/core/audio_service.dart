import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:audio_service/audio_service.dart' as media;
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../library/track_index.dart';
import '../theme/app_theme.dart';
import 'app_settings.dart';
import 'audio_log.dart';
import 'artwork_cache.dart';
import 'equalizer.dart';
import 'player_handler.dart';
import 'queue_store.dart';

/// Canal con el código nativo de Android para las cosas de audio que Flutter
/// no puede hacer solo: subir el volumen, abrir el ecualizador del sistema y
/// preguntar si hay una llamada en curso.
const MethodChannel _audioChannel = MethodChannel('resonar/audio');

/// Si esta lectura parece un reproductor trabado al final de la pista.
///
/// Existe porque hay archivos (sobre todo bajados) que se clavan en el último
/// segundo en vez de terminar, y la cola se quedaba muda. Pero saltar de más
/// es peor que no saltar: cortaría una canción que estaba sonando bien. Por
/// eso pide que se cumpla todo a la vez, y aun así el vigilante espera dos
/// lecturas seguidas antes de hacer nada.
///
/// En particular, si el reproductor está cargando ([ProcessingState.buffering]
/// y compañía) que la posición no avance es normal y no cuenta como trabado.
bool looksStuckAtEnd({
  required bool playing,
  required ProcessingState state,
  required Duration? duration,
  required Duration position,
  required Duration lastPosition,
}) {
  if (!playing || state != ProcessingState.ready) return false;
  if (duration == null || duration <= Duration.zero) return false;
  final moved =
      (position - lastPosition).abs() > const Duration(milliseconds: 400);
  if (moved) return false;
  return duration - position <= const Duration(seconds: 2);
}

/// Volumen (0 a 1) mientras suena una notificación, a partir del porcentaje
/// que se baja según Ajustes: 40 % de bajada son 0,6 de volumen.
double duckFactorFor(int percent) => 1.0 - percent.clamp(0, 100) / 100;

/// Convierte el modo de bucle guardado en Ajustes al del reproductor.
///
/// Se guarda con `LoopMode.name`, así que los nombres tienen que coincidir:
/// un cambio en el paquete dejaría el bucle siempre apagado sin avisar.
LoopMode loopModeFromName(String? name) => switch (name) {
  'all' => LoopMode.all,
  'one' => LoopMode.one,
  _ => LoopMode.off,
};

/// Reproductor de música local (solo archivos del dispositivo).
///
/// Es un singleton: todas las pantallas comparten cola, estado y notifiers.
class AudioService {
  static final AudioService _instance = AudioService._internal();

  factory AudioService() => _instance;

  AudioService._internal() {
    _player.currentIndexStream.listen(_onIndexChanged);
    _player.playbackEventStream.listen((event) {
      if (event.processingState == ProcessingState.ready) {
        _consecutiveErrors = 0;
      }
    }, onError: (Object error, StackTrace _) => _onPlayerError(error));
    _player.playingStream.listen((playing) {
      if (!playing) _persistPosition();
    });
    // Mientras suena, la posición se guarda cada tanto para retomarla al reabrir.
    Timer.periodic(const Duration(seconds: 5), (_) {
      if (_player.playing) _persistPosition();
    });
    unawaited(_configureAudioSession());
  }

  static const int _artworkWindowBefore = 2;
  static const int _artworkWindowAfter = 12;
  static const int _maxConsecutiveErrors = 3;

  // El ecualizador se engancha al crear el reproductor: no se puede añadir
  // después.
  // `handleInterruptions: false`: las interrupciones las maneja
  // `_onInterruption` y no just_audio, que para un sonido corto no hace nada y
  // deja que el volumen lo decida el sistema. Activar la sesión de audio
  // (pedir el foco al reproducir) lo sigue haciendo just_audio, que es otra
  // opción distinta y queda encendida.
  final AudioPlayer _player = AudioPlayer(
    handleInterruptions: false,
    audioPipeline: EqualizerController.instance.buildPipeline(),
  );
  final List<File> _queue = [];
  ConcatenatingAudioSource? _source;
  int _currentIndex = 0;
  int _queueId = 0;
  int _consecutiveErrors = 0;

  // Los vigilantes se arrancan una sola vez: engancharlos dos veces dejaría
  // dos temporizadores y dos oyentes compitiendo sobre el mismo reproductor.
  bool _watchdogStarted = false;
  bool _volumeWatchStarted = false;
  bool _pauseWhenHeadphonesDisconnected = true;
  StreamSubscription<void>? _becomingNoisySubscription;
  Timer? _sleepTimer;
  PlayerHandler? _handler;

  AudioPlayer get player => _player;
  int get currentIndex => _currentIndex;
  List<File> get playlistFiles => List.unmodifiable(_queue);

  File? get currentFile =>
      _currentIndex >= 0 && _currentIndex < _queue.length
      ? _queue[_currentIndex]
      : null;

  /// Cola actual (para la pantalla "Cola").
  final ValueNotifier<List<File>> queueNotifier = ValueNotifier<List<File>>(
    <File>[],
  );
  /// Ruta del archivo que suena (distingue pistas con el mismo título).
  final ValueNotifier<String?> currentPathNotifier = ValueNotifier<String?>(
    null,
  );
  final ValueNotifier<String?> titleNotifier = ValueNotifier<String?>(null);
  final ValueNotifier<String?> artistNotifier = ValueNotifier<String?>(null);
  final ValueNotifier<String?> albumNotifier = ValueNotifier<String?>(null);
  final ValueNotifier<Uint8List?> artworkBytesNotifier =
      ValueNotifier<Uint8List?>(null);
  final ValueNotifier<String?> playbackErrorNotifier = ValueNotifier<String?>(
    null,
  );
  final ValueNotifier<bool> shuffleNotifier = ValueNotifier<bool>(false);

  /// Orden de la cola antes de mezclar, para poder volver a él.
  List<File>? _orderBeforeShuffle;

  /// Deja guardado el aleatorio y el orden original, para que al volver a
  /// entrar quede como estaba.
  Future<void> _persistShuffle() async {
    final settings = AppSettings.instance;
    await settings.setShuffleOn(shuffleNotifier.value);
    await settings.setQueueBeforeShuffle([
      for (final file in _orderBeforeShuffle ?? const <File>[]) file.path,
    ]);
  }
  final ValueNotifier<LoopMode> loopNotifier = ValueNotifier<LoopMode>(
    LoopMode.off,
  );
  final ValueNotifier<double> speedNotifier = ValueNotifier<double>(1.0);

  /// Hora a la que el temporizador de apagado pausará la música (`null` = off).
  final ValueNotifier<DateTime?> sleepEndsAtNotifier =
      ValueNotifier<DateTime?>(null);

  bool get pauseWhenHeadphonesDisconnected => _pauseWhenHeadphonesDisconnected;

  Future<void> setPauseWhenHeadphonesDisconnected(bool enabled) async {
    _pauseWhenHeadphonesDisconnected = enabled;
  }

  /// Activa la notificación de reproducción y los controles del sistema
  /// (panel de medios, pantalla de bloqueo). Llamar una vez al iniciar.
  Future<void> initNotification() async {
    final handler = await media.AudioService.init<PlayerHandler>(
      builder: () => PlayerHandler(
        player: _player,
        onNext: playNext,
        onPrevious: playPrevious,
        // El ■ cierra la app, pero no se olvida de dónde quedó.
        onStop: () => clearQueue(forgetSession: false),
        onPlay: resume,
        currentPath: () => currentFile?.path,
      ),
      config: media.AudioServiceConfig(
        // Canal nuevo: no hereda ajustes viejos (silenciado, etc.).
        androidNotificationChannelId: 'resonar.reproduccion',
        androidNotificationChannelName: 'Reproducción de música',
        androidNotificationChannelDescription:
            'Controles de la canción que está sonando',
        androidNotificationIcon: 'drawable/ic_notification',
        // La notificación queda aunque pauses; se cierra con la ✕.
        androidNotificationOngoing: false,
        androidStopForegroundOnPause: false,
        notificationColor: AppTheme.primaryOrange,
        artDownscaleWidth: 256,
        artDownscaleHeight: 256,
      ),
    );
    _handler = handler;
    final file = currentFile;
    if (file != null) handler.setItem(_itemFor(file));
  }

  StreamSubscription<AudioInterruptionEvent>? _interruptionSubscription;

  /// Cuánto se agacha el volumen mientras otra app hace un sonido corto.
  double _duckFactor = 1.0;

  /// Último volumen que se le pasó al reproductor.
  double _lastVolume = 1.0;

  /// `true` si la pausa actual la pidió una interrupción y no la persona.
  bool _pausedByInterruption = false;

  Timer? _duckTimer;
  Timer? _duckRamp;
  Timer? _duckDelay;

  /// Cuándo empezó la interrupción en curso, para medir cuánto duró.
  DateTime? _interruptionStarted;

  /// Lo que se espera antes de bajar el volumen.
  ///
  /// Un sonido de sistema corto (el tic de enviar un mensaje) pide el audio y
  /// lo devuelve en un instante. Bajar y subir por eso se oye peor que no
  /// hacer nada, porque el tropezón llega cuando el sonido ya terminó. Con
  /// esta espera, cualquier cosa más corta que esto pasa sin que la música se
  /// mueva; una notificación de verdad dura bastante más.
  static const Duration _duckAfter = Duration(milliseconds: 400);

  /// El volumen al que queda la música mientras suena una notificación.
  ///
  /// Fijo y no configurable a propósito: es un detalle que tiene una sola
  /// respuesta razonable, y nadie quiere entrar a Ajustes a elegir un
  /// porcentaje. Lo justo para que la notificación se destaque sin que la
  /// canción desaparezca.
  static final double _duckedFactor = duckFactorFor(15);

  /// Pregunta cada tanto si apareció una llamada mientras hay una
  /// interrupción en curso.
  Timer? _callWatch;

  /// Cuándo pausó la persona por última vez, y cuándo arrancó solo el
  /// reproductor al conectarse una salida.
  DateTime _lastManualPause = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastAutoPlay = DateTime.fromMillisecondsSinceEpoch(0);

  /// Lo máximo que la música puede quedar baja por una notificación.
  ///
  /// Red de seguridad, no el mecanismo normal: el volumen vuelve cuando
  /// Android avisa que terminó la interrupción. Pero si ese aviso no llega
  /// —y hay teléfonos en los que no llega— la música quedaba baja para
  /// siempre, sin forma de recuperarla salvo reiniciando la app. Una
  /// notificación nunca dura tanto, así que a los seis segundos se vuelve
  /// igual.
  static const Duration _maxDuckDuration = Duration(seconds: 6);

  /// Baja o sube el volumen de a poco en vez de un salto.
  ///
  /// Lo que molesta de una notificación no es cuánto baja sino **el escalón**:
  /// un corte seco se oye como un pozo en la ruta, y la misma bajada hecha en
  /// un cuarto de segundo casi no se nota. Vuelve más lento de lo que baja,
  /// que es como suena natural.
  void _rampDuckTo(double target) {
    _duckRamp?.cancel();
    const step = Duration(milliseconds: 25);
    final over = target < _duckFactor
        ? const Duration(milliseconds: 250) // bajar
        : const Duration(milliseconds: 450); // volver
    final steps = (over.inMilliseconds / step.inMilliseconds).round();
    final from = _duckFactor;
    var done = 0;
    _duckRamp = Timer.periodic(step, (timer) {
      done++;
      final progress = (done / steps).clamp(0.0, 1.0);
      _duckFactor = from + (target - from) * progress;
      unawaited(_applyVolume(force: true));
      if (progress >= 1.0) {
        timer.cancel();
        _duckRamp = null;
      }
    });
  }

  /// Pone el volumen del reproductor.
  ///
  /// Lo único que lo mueve es el agachado por notificaciones. Antes también
  /// entraba el fundido entre canciones, que se recalculaba cada 120 ms a
  /// partir de la posición; se quitó porque si ese cálculo quedaba clavado en
  /// un valor bajo la música seguía corriendo sin que se oyera nada.
  Future<void> _applyVolume({bool force = false}) async {
    final target = _duckFactor.clamp(0.0, 1.0);
    // Volver exactamente a 1.0 importa: con el umbral solo, quedaría en 0,99.
    final snapBack = target == 1.0 && _lastVolume != 1.0;
    // Durante una rampa los pasos son chicos a propósito y el umbral los
    // comería, así que ahí se aplica siempre.
    if (!force && !snapBack && (target - _lastVolume).abs() <= 0.02) return;
    final before = _lastVolume;
    _lastVolume = target;
    try {
      await _player.setVolume(target);
      if ((target - before).abs() > 0.05) {
        AudioLog.add(
          'volumen ${(before * 100).round()}% → ${(target * 100).round()}%',
        );
      }
    } catch (error) {
      debugPrint('No se pudo ajustar el volumen: $error');
    }
  }

  /// Empieza a sonar al conectar unos auriculares o un parlante.
  ///
  /// Si no hay nada en la cola intenta retomar la última sesión, porque el
  /// caso típico es salir de casa: te ponés los auriculares y querés que suene
  /// lo último que escuchabas, sin tener que abrir la app y elegir.
  Future<void> onOutputConnected() async {
    if (!AppSettings.instance.playOnHeadphoneConnect) return;
    if (_player.playing) return;
    final now = DateTime.now();
    // Si acabás de pausar a mano, mandás vos. La lista de salidas se relee en
    // cada botón y al volver a la app, así que un parpadeo del bluetooth
    // podría leerse como "se conectó algo" justo después de que pausaste: sin
    // esto, la música te arrancaría sola y parecería que la app hace lo que
    // quiere.
    if (now.difference(_lastManualPause) < const Duration(seconds: 60)) return;
    // Y no dos veces seguidas por el mismo parpadeo.
    if (now.difference(_lastAutoPlay) < const Duration(seconds: 30)) return;
    _lastAutoPlay = now;
    if (_queue.isEmpty) {
      await restoreLastSession();
      if (_queue.isEmpty) return; // no hay nada que retomar
    }
    await _startPlayback();
  }

  /// Qué hacer cuando otra app pide el audio.
  ///
  /// La teoría dice que Android avisa distinto según el caso: `duck` para un
  /// sonido corto (una notificación) y `pause` para una interrupción de verdad
  /// (una llamada). En la práctica no: hay teléfonos que mandan `pause`
  /// también para las notificaciones, y se comprobó con el registro de
  /// *Diagnóstico de audio* (una notificación llegó como `pause` y duró 3,3
  /// segundos). Confiar en el tipo de evento dejaba la música muda en cada
  /// notificación, y además volvía inútil el ajuste de cuánto bajar, porque
  /// ese camino nunca se usaba.
  ///
  /// Así que el tipo de evento ya no decide si se pausa. Siempre se empieza
  /// bajando el volumen, y se pausa solo si [_isCallActive] confirma que hay
  /// una llamada, cosa que se sigue preguntando mientras la interrupción dure
  /// (podés atender dos segundos más tarde). Una notificación entonces es un
  /// bajón de volumen; una llamada, una pausa.
  ///
  /// `unknown` es la excepción: en Android es la pérdida definitiva del foco
  /// (otra app se queda con el audio) y ahí se pausa sin vueltas.
  void _onInterruption(AudioInterruptionEvent event) {
    if (!event.begin) {
      final lasted = _interruptionStarted == null
          ? null
          : DateTime.now().difference(_interruptionStarted!);
      _interruptionStarted = null;
      AudioLog.add(
        'interrupción TERMINA · tipo ${event.type.name}'
        '${lasted == null ? '' : ' · duró ${lasted.inMilliseconds} ms'}',
      );
      final wasIgnored = _duckDelay?.isActive ?? false;
      _duckDelay?.cancel();
      _duckDelay = null;
      _duckTimer?.cancel();
      _callWatch?.cancel();
      _callWatch = null;
      if (wasIgnored) {
        // Terminó antes de que hubiéramos tocado el volumen: no se tocó nada
        // y no hay nada que devolver.
        AudioLog.add('sonido corto: no se bajó el volumen');
        return;
      }
      _rampDuckTo(1.0);
      if (_pausedByInterruption) {
        _pausedByInterruption = false;
        AudioLog.add('sigue la música: terminó la interrupción');
        unawaited(_startPlayback());
      }
      return;
    }

    _interruptionStarted = DateTime.now();
    AudioLog.add('interrupción EMPIEZA · tipo ${event.type.name}');

    if (event.type == AudioInterruptionType.unknown) {
      if (_player.playing) {
        _pausedByInterruption = false; // pérdida definitiva: no se reanuda
        AudioLog.add('pausa: otra app se quedó con el audio');
        unawaited(_player.pause());
      }
      return;
    }

    // Todavía no se toca el volumen. Los sonidos muy cortos —el tic de enviar
    // un mensaje, por ejemplo— empiezan y terminan en menos de lo que tarda
    // una bajada, así que bajar y subir enseguida se oye como un tropezón por
    // algo que ya pasó. Si la interrupción no sigue viva cuando venza esta
    // espera, no se bajó nada y no hubo nada que notar.
    _duckDelay?.cancel();
    _duckDelay = Timer(_duckAfter, () {
      _duckDelay = null;
      _rampDuckTo(_duckedFactor);
      _duckTimer?.cancel();
      _duckTimer = Timer(_maxDuckDuration, () {
        AudioLog.add('no llegó el fin de la interrupción: vuelve el volumen');
        _rampDuckTo(1.0);
      });
    });

    // La llamada no espera: se pregunta desde el primer momento.
    _watchForCall();
  }

  /// Pregunta si hay una llamada, ahora y durante los próximos segundos.
  ///
  /// Se pregunta varias veces porque el modo del teléfono no cambia en el
  /// mismo instante en que se pierde el foco: entre que el evento llega y que
  /// Android se pone en modo llamada pasan unas décimas, y si atendés más
  /// tarde, más todavía.
  void _watchForCall() {
    _callWatch?.cancel();
    var checks = 0;
    Future<void> check() async {
      if (!await _isCallActive()) return;
      _callWatch?.cancel();
      _callWatch = null;
      _duckDelay?.cancel();
      _duckDelay = null;
      if (!_player.playing) return;
      _pausedByInterruption = true;
      AudioLog.add('pausa: hay una llamada');
      await _player.pause();
    }

    unawaited(check());
    _callWatch = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (++checks > 20) {
        // Diez segundos sin llamada: era un sonido corto raro y largo. Queda
        // con el volumen bajo hasta que la interrupción termine.
        timer.cancel();
        _callWatch = null;
        return;
      }
      unawaited(check());
    });
  }

  /// Si el teléfono está en modo llamada (sonando, hablando o en una
  /// videollamada).
  Future<bool> _isCallActive() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _audioChannel.invokeMethod<bool>('isCallActive') ?? false;
    } catch (error) {
      debugPrint('No se pudo consultar el modo de audio: $error');
      return false;
    }
  }


  Duration _lastWatchPosition = Duration.zero;
  int _stuckTicks = 0;

  /// Vigila el final de cada canción. Si el reproductor se queda clavado en el
  /// último segundo (pasa con archivos cuya duración está mal escrita, típico
  /// de descargas) pasa solo a la siguiente en vez de quedarse mudo.
  void startEndWatchdog() {
    if (_watchdogStarted) return;
    _watchdogStarted = true;
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) unawaited(_onQueueFinished());
    });
    Timer.periodic(const Duration(seconds: 2), (_) {
      final position = _player.position;
      final previous = _lastWatchPosition;
      _lastWatchPosition = position;
      if (!looksStuckAtEnd(
        playing: _player.playing,
        state: _player.processingState,
        duration: _player.duration,
        position: position,
        lastPosition: previous,
      )) {
        _stuckTicks = 0;
        return;
      }
      _stuckTicks++;
      if (_stuckTicks < 2) return; // ~4 s sin avanzar al final
      _stuckTicks = 0;
      AudioLog.add('se salta: la pista parece trabada al final');
      debugPrint('El reproductor se trabó al final: paso a la siguiente.');
      unawaited(_recoverFromStall());
    });
  }

  Future<void> _recoverFromStall() async {
    if (_player.hasNext) {
      try {
        await _player.seekToNext();
        await _startPlayback();
        return;
      } catch (error) {
        debugPrint('No se pudo saltar tras trabarse: $error');
      }
    }
    await _onQueueFinished();
  }

  /// Se terminó la cola. Con aleatorio puesto la baraja de nuevo y sigue;
  /// si no, vuelve al principio y queda en pausa (y no clavado en el final).
  Future<void> _onQueueFinished() async {
    try {
      if (shuffleNotifier.value && _queue.length > 1) {
        // Vuelta completa: recién acá se baraja de nuevo.
        await setPlaylistAndPlay(
          List<File>.of(_queue)..shuffle(math.Random()),
          0,
        );
        return;
      }
      await _player.pause();
      await _player.seek(Duration.zero, index: 0);
    } catch (error) {
      debugPrint('No se pudo cerrar la cola: $error');
    }
  }

  Future<void> _configureAudioSession() async {
    try {
      final session = await AudioSession.instance;
      // Lo que importa acá es `androidWillPauseWhenDucked`, y va en **true**
      // por un motivo que no es obvio. Según la documentación de Android, en
      // false el sistema baja el volumen por su cuenta y *no le avisa a la
      // app*: el descuento lo elige el teléfono y puede dejar la música
      // inaudible, sin que haya nada que podamos hacer. En true se desactiva
      // ese automatismo y Android nos avisa, así que el volumen durante una
      // notificación lo decidimos nosotros (ver `_duckedFactor`).
      //
      // El precio es que hay que manejar las interrupciones a mano, incluidas
      // las de verdad (una llamada): eso lo hace `_onInterruption`.
      await session.configure(
        const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionMode: AVAudioSessionMode.defaultMode,
          avAudioSessionRouteSharingPolicy:
              AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.music,
            flags: AndroidAudioFlags.none,
            usage: AndroidAudioUsage.media,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
          androidWillPauseWhenDucked: true,
        ),
      );
      await _interruptionSubscription?.cancel();
      _interruptionSubscription = session.interruptionEventStream.listen(
        _onInterruption,
      );
      await _becomingNoisySubscription?.cancel();
      _becomingNoisySubscription = session.becomingNoisyEventStream.listen((_) {
        AudioLog.add('se desconectó la salida de audio');
        if (_pauseWhenHeadphonesDisconnected && _player.playing) {
          AudioLog.add('pausa por desconexión');
          unawaited(_player.pause());
        }
      });
    } catch (error) {
      debugPrint('No se pudo configurar la sesión de audio: $error');
      playbackErrorNotifier.value =
          'No se pudo configurar la sesión de audio: $error';
    }
  }

  // ---------------------------------------------------------------- pista

  media.MediaItem _itemFor(File file) {
    final info = TrackIndex.instance.infoFor(file.path);
    return media.MediaItem(
      id: file.path,
      title: info?.title ?? titleFromPath(file.path),
      artist: info?.artistLabel ?? unknownArtistLabel,
      album: info?.album,
      artUri: ArtworkCache.uriFor(file.path),
    );
  }

  AudioSource _sourceFor(File file) =>
      AudioSource.uri(file.uri, tag: _itemFor(file));

  void _onIndexChanged(int? index) {
    if (index == null || index < 0 || index >= _queue.length) return;
    _currentIndex = index;
    _publishCurrent();
    final settings = AppSettings.instance;
    if (index != settings.lastIndex) {
      unawaited(settings.saveSession(index: index, positionMs: 0));
    }
  }

  // ------------------------------------------------------------ sesión

  void _persistPosition() {
    if (_queue.isEmpty) return;
    unawaited(
      AppSettings.instance.saveSession(
        positionMs: _player.position.inMilliseconds,
      ),
    );
  }

  void _persistQueue({bool resetPosition = false}) {
    unawaited(
      AppSettings.instance.saveSession(
        queue: [for (final file in _queue) file.path],
        index: _currentIndex,
        positionMs: resetPosition ? 0 : null,
      ),
    );
  }

  /// Retoma la última cola, canción y posición, en pausa (no empieza a sonar).
  Future<void> restoreLastSession() async {
    if (_queue.isNotEmpty) return;
    try {
      final settings = AppSettings.instance;
      // El aleatorio y el bucle se restauran primero y pase lo que pase: son
      // preferencias y no dependen de que haya una cola para retomar. Antes
      // estaban después del `return` de abajo, así que una cola vacía los
      // dejaba apagados.
      shuffleNotifier.value = settings.shuffleOn;
      _orderBeforeShuffle = settings.shuffleOn
          ? [for (final path in settings.queueBeforeShuffle) File(path)]
          : null;
      final loop = loopModeFromName(settings.loopMode);
      loopNotifier.value = loop;
      await _player.setLoopMode(loop);

      final paths = settings.lastQueue;
      if (paths.isEmpty) return;
      final files = [
        for (final path in paths)
          if (File(path).existsSync()) File(path),
      ];
      if (files.isEmpty) return;

      final savedIndex = settings.lastIndex;
      final savedPath = savedIndex >= 0 && savedIndex < paths.length
          ? paths[savedIndex]
          : null;
      var index = savedPath == null
          ? 0
          : files.indexWhere((file) => file.path == savedPath);
      final sameTrack = index >= 0;
      if (!sameTrack) index = 0;
      await setPlaylistAndPlay(
        files,
        index,
        position: sameTrack
            ? Duration(milliseconds: settings.lastPositionMs)
            : Duration.zero,
        autoplay: false,
      );
      await _player.setLoopMode(loop);
    } catch (error) {
      debugPrint('No se pudo retomar la última sesión: $error');
    }
  }

  void _publishCurrent() {
    final file = currentFile;
    if (file == null) return;
    final info =
        TrackIndex.instance.infoFor(file.path) ?? TrackInfo.fromFile(file);
    currentPathNotifier.value = file.path;
    titleNotifier.value = info.title;
    artistNotifier.value = info.artistLabel;
    albumNotifier.value = info.album;
    artworkBytesNotifier.value = null;
    _handler?.setItem(_itemFor(file));
    unawaited(_loadArtwork(file));
  }

  Future<void> _loadArtwork(File file) async {
    final bytes = await ArtworkCache.bytesFor(file.path);
    // Si mientras tanto cambió la pista, esta carátula ya no corresponde.
    if (currentFile?.path != file.path) return;
    artworkBytesNotifier.value = bytes;
    // La carátula recién extraída también va a la notificación.
    if (bytes != null) _handler?.setItem(_itemFor(file));
  }

  // ----------------------------------------------------------------- cola

  /// Reemplaza la cola por [files] y empieza a reproducir `files[initialIndex]`.
  ///
  /// Con [autoplay] en `false` solo la deja cargada (pausada) en [position].
  Future<void> setPlaylistAndPlay(
    List<File> files,
    int initialIndex, {
    Duration? position,
    bool autoplay = true,
  }) async {
    RangeError.checkValidIndex(initialIndex, files, 'initialIndex');
    final queueId = ++_queueId;
    _consecutiveErrors = 0;
    playbackErrorNotifier.value = null;

    try {
      // Carátulas de las pistas cercanas a la inicial (rápido). El resto de la
      // cola se prepara después, en segundo plano.
      final from = math.max(0, initialIndex - _artworkWindowBefore);
      final to = math.min(files.length, initialIndex + _artworkWindowAfter);
      await ArtworkCache.ensure([
        for (var i = from; i < to; i++) files[i].path,
      ]);
      if (queueId != _queueId) return; // otra reproducción tomó el control

      _queue
        ..clear()
        ..addAll(files);
      queueNotifier.value = List<File>.unmodifiable(_queue);
      _currentIndex = initialIndex;
      final source = ConcatenatingAudioSource(
        children: [for (final file in files) _sourceFor(file)],
      );
      _source = source;
      await _player.setAudioSource(
        source,
        initialIndex: initialIndex,
        initialPosition: position,
      );
      if (queueId != _queueId) return;

      _publishCurrent();
      _persistQueue(resetPosition: autoplay);
      // Las bandas recién existen cuando hay audio cargado.
      unawaited(EqualizerController.instance.load());
      // No usar `await _player.play()`: ese Future solo termina al pausar o
      // acabar la reproducción.
      if (autoplay) unawaited(_startPlayback());
      unawaited(
        ArtworkCache.warm([
          for (final file in files) file.path,
        ], shouldContinue: () => queueId == _queueId),
      );
    } catch (error) {
      if (queueId != _queueId) return;
      debugPrint('No se pudo reproducir: $error');
      playbackErrorNotifier.value = 'No se pudo reproducir: $error';
    }
  }

  /// Reproduce [files] en orden aleatorio. La cola se baraja una sola vez y
  /// después queda fija: lo que ves en la cola es lo que va a sonar.
  Future<void> playShuffled(List<File> files) async {
    if (files.isEmpty) return;
    await _player.setShuffleModeEnabled(false);
    shuffleNotifier.value = true;
    _orderBeforeShuffle = List<File>.of(files);
    await setPlaylistAndPlay(List<File>.of(files)..shuffle(math.Random()), 0);
    await _persistShuffle();
  }

  /// Pone [file] justo después de la pista actual.
  Future<void> playNextInQueue(File file) => _insert(file, atEnd: false);

  /// Añade [file] al final de la cola. Si no hay nada sonando, la reproduce.
  Future<void> addToQueue(File file) => _insert(file, atEnd: true);

  Future<void> _insert(File file, {required bool atEnd}) async {
    final source = _source;
    if (source == null || _queue.isEmpty) {
      await setPlaylistAndPlay([file], 0);
      return;
    }
    final queueId = _queueId;
    await ArtworkCache.ensure([file.path]);
    if (queueId != _queueId) return;

    final index = atEnd
        ? _queue.length
        : math.min(_currentIndex + 1, _queue.length);
    _queue.insert(index, file);
    queueNotifier.value = List<File>.unmodifiable(_queue);
    _persistQueue();
    try {
      await source.insert(index, _sourceFor(file));
    } catch (error) {
      if (queueId == _queueId) {
        _queue.removeAt(index);
        queueNotifier.value = List<File>.unmodifiable(_queue);
      }
      playbackErrorNotifier.value = 'No se pudo añadir a la cola: $error';
    }
  }

  /// Quita una pista de la cola. Si era la última, se detiene la reproducción.
  Future<void> removeFromQueue(int index) async {
    final source = _source;
    if (source == null || index < 0 || index >= _queue.length) return;
    if (_queue.length == 1) {
      await clearQueue();
      return;
    }
    // La lista visible se actualiza antes del primer `await` para que
    // `Dismissible` no se quede con un elemento fantasma.
    _queue.removeAt(index);
    queueNotifier.value = List<File>.unmodifiable(_queue);
    _persistQueue();
    try {
      await source.removeAt(index);
    } catch (error) {
      debugPrint('No se pudo quitar de la cola: $error');
    }
  }

  /// Vacía la cola.
  ///
  /// [forgetSession] borra además la sesión guardada en disco. El botón ■ de
  /// la notificación pasa `false`: cierra la app, pero la próxima vez tiene
  /// que retomar donde quedó. Borrarla ahí era lo que hacía que al volver a
  /// entrar la app apareciera como recién instalada, sin canción, sin
  /// aleatorio y sin bucle.
  Future<void> clearQueue({bool forgetSession = true}) async {
    if (!forgetSession && _queue.isNotEmpty) {
      // Antes de vaciar: dejar anotado en qué canción y en qué segundo quedó.
      await AppSettings.instance.saveSession(
        queue: [for (final file in _queue) file.path],
        index: _currentIndex,
        positionMs: _player.position.inMilliseconds,
      );
    }
    _queueId++;
    _queue.clear();
    _source = null;
    queueNotifier.value = const <File>[];
    currentPathNotifier.value = null;
    titleNotifier.value = null;
    artistNotifier.value = null;
    albumNotifier.value = null;
    artworkBytesNotifier.value = null;
    _handler?.clearItem();
    if (forgetSession) {
      unawaited(
        AppSettings.instance.saveSession(
          queue: <String>[],
          index: 0,
          positionMs: 0,
        ),
      );
    }
    await _player.stop();
  }

  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    final source = _source;
    if (source == null ||
        oldIndex < 0 ||
        oldIndex >= _queue.length ||
        newIndex < 0 ||
        newIndex >= _queue.length ||
        oldIndex == newIndex) {
      return;
    }
    final file = _queue.removeAt(oldIndex);
    _queue.insert(newIndex, file);
    queueNotifier.value = List<File>.unmodifiable(_queue);
    _persistQueue();
    await source.move(oldIndex, newIndex);
  }

  Future<void> seekToQueueIndex(int index) async {
    final length = _player.sequence?.length ?? 0;
    if (index < 0 || index >= length) {
      throw RangeError.range(index, 0, length - 1, 'index');
    }
    await _player.seek(Duration.zero, index: index);
    unawaited(_startPlayback());
  }

  // -------------------------------------------------------- varias colas

  /// Foto de la cola que está cargada ahora, sobre [base] (nombre e id).
  SavedQueue _snapshotActive(SavedQueue base) => base.copyWith(
    paths: [for (final file in _queue) file.path],
    index: _currentIndex,
    positionMs: _player.position.inMilliseconds,
    shuffle: shuffleNotifier.value,
    orderBeforeShuffle: [
      for (final file in _orderBeforeShuffle ?? const <File>[]) file.path,
    ],
    loop: loopNotifier.value.name,
  );

  /// Vuelca la cola viva a su lugar en [QueueStore], antes de cambiar a otra.
  void _parkActive() {
    final store = QueueStore.instance;
    final current = store.byId(store.activeId.value);
    if (current == null) return;
    store.update(_snapshotActive(current));
  }

  /// Pasa a la cola [id]: la actual queda guardada tal cual (canción, segundo,
  /// mezcla y bucle) y la otra se retoma donde estaba. Si estaba sonando, la
  /// otra también suena; si estaba en pausa, queda cargada en pausa.
  Future<void> switchToQueue(String id) async {
    final store = QueueStore.instance;
    if (id == store.activeId.value) return;
    final target = store.byId(id);
    if (target == null) return;
    final wasPlaying = _player.playing;
    _parkActive();
    store.setActive(id);
    AudioLog.add('cola: pasa a "${target.name}"');
    await _loadSaved(target, autoplay: wasPlaying);
  }

  Future<void> _loadSaved(SavedQueue saved, {required bool autoplay}) async {
    // El aleatorio y el bucle son de cada cola: se ponen los de esta antes de
    // cargarla, y se dejan guardados como los de la sesión actual.
    final loop = loopModeFromName(saved.loop);
    shuffleNotifier.value = saved.shuffle;
    _orderBeforeShuffle = saved.shuffle && saved.orderBeforeShuffle.isNotEmpty
        ? [for (final path in saved.orderBeforeShuffle) File(path)]
        : null;
    loopNotifier.value = loop;
    await _persistShuffle();
    await AppSettings.instance.setLoopMode(loop.name);

    final files = [
      for (final path in saved.paths)
        if (File(path).existsSync()) File(path),
    ];
    if (files.isEmpty) {
      await clearQueue();
      await _player.setLoopMode(loop);
      return;
    }
    final savedPath = saved.index >= 0 && saved.index < saved.paths.length
        ? saved.paths[saved.index]
        : null;
    var index = savedPath == null
        ? 0
        : files.indexWhere((file) => file.path == savedPath);
    final sameTrack = index >= 0;
    if (!sameTrack) index = 0;
    final position = sameTrack
        ? Duration(milliseconds: saved.positionMs)
        : Duration.zero;
    await setPlaylistAndPlay(
      files,
      index,
      position: position,
      autoplay: autoplay,
    );
    await _player.setLoopMode(loop);
    // `setPlaylistAndPlay` deja la posición en 0 al arrancar y la sesión
    // guardada todavía tiene la de la otra cola: se corrige acá.
    await AppSettings.instance.saveSession(
      queue: [for (final file in files) file.path],
      index: index,
      positionMs: position.inMilliseconds,
    );
  }

  /// Arranca una cola nueva sin tocar las que ya hay: la actual queda guardada
  /// y la nueva empieza con [files] (o vacía), sin mezcla y sin bucle.
  ///
  /// Devuelve `null` si no hizo falta crear nada (la cola actual estaba vacía,
  /// así que se usa esa) o si ya se llegó al máximo de colas.
  Future<SavedQueue?> startNewQueue({List<File> files = const []}) async {
    final store = QueueStore.instance;
    if (_queue.isEmpty) {
      if (files.isNotEmpty) await setPlaylistAndPlay(files, 0);
      return null;
    }
    if (store.isFull) return null;
    _parkActive();
    final queue = store.add();
    store.setActive(queue.id);
    AudioLog.add('cola: nueva "${queue.name}"');
    shuffleNotifier.value = false;
    _orderBeforeShuffle = null;
    loopNotifier.value = LoopMode.off;
    await _persistShuffle();
    await AppSettings.instance.setLoopMode(LoopMode.off.name);
    await _player.setLoopMode(LoopMode.off);
    if (files.isEmpty) {
      await clearQueue();
    } else {
      await setPlaylistAndPlay(files, 0);
    }
    return queue;
  }

  /// Borra la cola [id]. Si era la que suena, pasa a la vecina; si era la
  /// única, no se borra: queda vacía.
  Future<void> deleteQueue(String id) async {
    final store = QueueStore.instance;
    if (store.byId(id) == null) return;
    if (id != store.activeId.value) {
      store.remove(id);
      return;
    }
    final all = store.queues.value;
    if (all.length == 1) {
      await clearQueue();
      _parkActive();
      return;
    }
    final at = all.indexWhere((queue) => queue.id == id);
    final neighbour = all[at == 0 ? 1 : at - 1];
    await switchToQueue(neighbour.id);
    store.remove(id);
  }

  // ------------------------------------------------------------- control

  /// Si el volumen del teléfono está en cero, lo sube una rayita: si no,
  /// parece que la app no anda y los botones de volumen terminan cambiando
  /// el de las llamadas en vez del de la música.
  Future<void> _raiseVolumeIfMuted() async {
    if (!Platform.isAndroid || !AppSettings.instance.raiseVolumeOnPlay) return;
    try {
      await _audioChannel.invokeMethod<bool>('raiseVolumeIfMuted');
    } catch (error) {
      debugPrint('No se pudo revisar el volumen: $error');
    }
  }

  /// Escucha el aviso de Android de que el volumen quedó en cero y pausa.
  void startVolumeWatch() {
    if (_volumeWatchStarted || !Platform.isAndroid) return;
    _volumeWatchStarted = true;
    _audioChannel.setMethodCallHandler((call) async {
      if (call.method != 'musicVolumeZero') return null;
      AudioLog.add('el volumen del sistema quedó en cero');
      if (AppSettings.instance.pauseOnZeroVolume && _player.playing) {
        AudioLog.add('pausa por volumen en cero');
        await _player.pause();
      }
      return null;
    });
  }

  Future<void> _startPlayback() async {
    // Darle a play devuelve el volumen a donde corresponde, sin depender de
    // que haya llegado ningún aviso: si algo quedó a medias, esto lo salva.
    _duckTimer?.cancel();
    _duckRamp?.cancel();
    _duckDelay?.cancel();
    _duckDelay = null;
    _duckFactor = 1.0;
    unawaited(_applyVolume(force: true));
    unawaited(_raiseVolumeIfMuted());
    try {
      await _player.play();
    } catch (error) {
      playbackErrorNotifier.value =
          'No se pudo iniciar la reproducción: $error';
    }
  }

  /// Un archivo ilegible (borrado, dañado, formato no soportado) no debe cortar
  /// la cola: se avisa y se salta a la siguiente (máx. 3 fallos seguidos, para
  /// no entrar en bucle con `LoopMode.all`).
  void _onPlayerError(Object error) {
    debugPrint('Error de reproducción: $error');
    playbackErrorNotifier.value = null;
    playbackErrorNotifier.value = 'No se pudo reproducir la pista: $error';
    if (_queue.length < 2 ||
        _consecutiveErrors >= _maxConsecutiveErrors ||
        !_player.hasNext) {
      return;
    }
    _consecutiveErrors++;
    unawaited(
      _player
          .seekToNext()
          .then((_) => _startPlayback())
          .catchError((Object e) => debugPrint('No se pudo saltar: $e')),
    );
  }

  Future<void> playPause() async {
    // Si la persona toca play o pausa durante una llamada, manda ella: al
    // colgar no se reanuda nada por las nuestras.
    _pausedByInterruption = false;
    if (_player.playing) {
      _lastManualPause = DateTime.now();
      await _player.pause();
      return;
    }
    await resume();
  }

  Future<void> playNext() async {
    final length = _player.sequence?.length ?? 0;
    if (length > 1) {
      await _player.seekToNext();
    } else if (length == 1) {
      await _player.seek(Duration.zero);
    }
  }

  /// Pasados los primeros segundos, "anterior" reinicia la canción; dentro
  /// de ese rato, recién ahí salta a la pista de antes.
  static const Duration _restartWindow = Duration(seconds: 5);

  Future<void> playPrevious() async {
    final length = _player.sequence?.length ?? 0;
    if (length == 0) return;
    if (length == 1 || _player.position > _restartWindow) {
      await _player.seek(Duration.zero);
      return;
    }
    await _player.seekToPrevious();
  }

  /// Mezcla (o desmezcla) la cola una sola vez. No se usa el modo aleatorio
  /// del reproductor, que elegía una pista al azar en cada salto y por eso
  /// había canciones que no sonaban nunca.
  Future<void> toggleShuffle() async {
    final enabled = !shuffleNotifier.value;
    shuffleNotifier.value = enabled;
    await _player.setShuffleModeEnabled(false);
    if (_queue.length < 2) {
      if (!enabled) _orderBeforeShuffle = null;
      await _persistShuffle();
      return;
    }
    final current = _currentIndex >= 0 && _currentIndex < _queue.length
        ? _queue[_currentIndex]
        : null;
    final List<File> next;
    if (enabled) {
      _orderBeforeShuffle = List<File>.of(_queue);
      next = List<File>.of(_queue)..shuffle(math.Random());
      if (current != null) {
        // La que está sonando queda primera para no cortarla.
        next.removeWhere((file) => file.path == current.path);
        next.insert(0, current);
      }
    } else {
      final previous = _orderBeforeShuffle;
      _orderBeforeShuffle = null;
      if (previous == null) {
        next = List<File>.of(_queue);
      } else {
        final paths = {for (final file in _queue) file.path};
        final known = {for (final file in previous) file.path};
        next = [
          for (final file in previous)
            if (paths.contains(file.path)) file,
          // Lo que se agregó mientras estaba el aleatorio va al final.
          for (final file in _queue)
            if (!known.contains(file.path)) file,
        ];
      }
    }
    final found = current == null
        ? 0
        : next.indexWhere((file) => file.path == current.path);
    final index = found < 0 ? 0 : found;
    if (!await _reorderInPlace(next, index)) {
      // Sin nada cargado no hay nada que conservar: se arma de cero.
      await setPlaylistAndPlay(
        next,
        index,
        position: _player.position,
        autoplay: _player.playing,
      );
    }
    await _persistShuffle();
  }

  /// Reordena la cola **sin cortar lo que está sonando**.
  ///
  /// Rearmar la fuente con `setAudioSource` obliga al reproductor a recargar
  /// la pista actual, y eso es el segundo de silencio que se oía al tocar el
  /// aleatorio. En vez de eso se saca todo lo que está antes y después de la
  /// pista actual y se vuelve a insertar en el orden nuevo: la que suena nunca
  /// se toca, así que no se entera. Son cuatro operaciones, no importa si la
  /// cola tiene diez canciones o dos mil.
  ///
  /// Devuelve `false` si no había nada cargado y hay que armar la cola de
  /// cero.
  Future<bool> _reorderInPlace(List<File> next, int index) async {
    final source = _source;
    final playing = _player.currentIndex;
    if (source == null || playing == null || _queue.isEmpty) return false;
    final queueId = _queueId;
    try {
      // 1) Dejar en la fuente solo la pista que suena.
      if (playing + 1 < source.length) {
        await source.removeRange(playing + 1, source.length);
      }
      if (playing > 0) await source.removeRange(0, playing);
      if (queueId != _queueId) return true;
      // 2) Rodearla con el orden nuevo.
      if (index > 0) {
        await source.insertAll(0, [
          for (final file in next.take(index)) _sourceFor(file),
        ]);
      }
      if (index + 1 < next.length) {
        await source.addAll([
          for (final file in next.skip(index + 1)) _sourceFor(file),
        ]);
      }
      if (queueId != _queueId) return true;
      _queue
        ..clear()
        ..addAll(next);
      _currentIndex = index;
      queueNotifier.value = List<File>.unmodifiable(_queue);
      _publishCurrent();
      _persistQueue();
      return true;
    } catch (error) {
      debugPrint('No se pudo reordenar la cola en el lugar: $error');
      return false;
    }
  }

  Future<void> toggleLoop() async {
    final nextMode = switch (loopNotifier.value) {
      LoopMode.off => LoopMode.all,
      LoopMode.all => LoopMode.one,
      LoopMode.one => LoopMode.off,
    };
    await _player.setLoopMode(nextMode);
    loopNotifier.value = nextMode;
    await AppSettings.instance.setLoopMode(nextMode.name);
  }

  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed);
    speedNotifier.value = speed;
  }

  /// Pausa la música dentro de [duration]; `null` cancela el temporizador.
  void setSleepTimer(Duration? duration) {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    if (duration == null) {
      sleepEndsAtNotifier.value = null;
      return;
    }
    sleepEndsAtNotifier.value = DateTime.now().add(duration);
    _sleepTimer = Timer(duration, () {
      _sleepTimer = null;
      sleepEndsAtNotifier.value = null;
      unawaited(_player.pause());
    });
  }

  Future<void> pause() {
    _pausedByInterruption = false;
    _lastManualPause = DateTime.now();
    return _player.pause();
  }

  /// Darle play desde cualquier lado: la notificación, el botón del auricular,
  /// el widget o la pantalla.
  ///
  /// Si la cola está vacía se retoma la última sesión antes de reproducir.
  /// Importa cuando el sistema resucitó la app (un botón del auricular con la
  /// app cerrada): `main` también retoma la sesión, pero lo hace sin esperar,
  /// así que el play puede llegar antes y encontrarse con la nada.
  Future<void> resume() async {
    _pausedByInterruption = false;
    if (_queue.isEmpty) await restoreLastSession();
    await _startPlayback();
  }

  Future<void> stop() => _player.stop();
  Future<void> seek(Duration position) => _player.seek(position);
}
