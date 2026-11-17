import 'package:flutter/foundation.dart';

/// Registro de lo que le pasa al audio, para mirarlo desde el teléfono.
///
/// Existe por un problema concreto: cuando entra una notificación la música
/// se baja, y desde afuera no hay forma de saber si eso lo hace la app o el
/// sistema. La diferencia importa, porque si Android no nos avisa de la
/// interrupción no hay ajuste de la app que pueda cambiar nada.
///
/// `debugPrint` no sirve para eso: leerlo necesita una computadora con adb.
/// Esto guarda los últimos eventos en memoria para poder verlos en
/// *Ajustes → Configuración avanzada → Diagnóstico de audio* y mandar una
/// captura.
///
/// Es a propósito un registro corto y en memoria: no se guarda en disco, no
/// se manda a ningún lado y se vacía al cerrar la app.
class AudioLog {
  AudioLog._();

  static const int _limit = 60;

  /// Los eventos, del más nuevo al más viejo.
  static final ValueNotifier<List<String>> entries = ValueNotifier(const []);

  static void add(String message) {
    final now = DateTime.now();
    final stamp =
        '${_two(now.hour)}:${_two(now.minute)}:${_two(now.second)}'
        '.${now.millisecond.toString().padLeft(3, '0')}';
    final line = '$stamp  $message';
    entries.value = [line, ...entries.value].take(_limit).toList();
    debugPrint('AudioLog: $line');
  }

  static void clear() => entries.value = const [];

  static String _two(int value) => value.toString().padLeft(2, '0');
}
