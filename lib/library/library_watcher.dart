import 'dart:async';

import 'package:flutter/widgets.dart';

import '../core/app_settings.dart';
import 'library_repository.dart';

/// Qué hacer ante un cambio de estado de la app.
///
/// Android avisa de dos cosas distintas con la misma familia de eventos: que
/// la app se fue a segundo plano (`paused`) y que perdió el foco sin irse
/// (`inactive`), que es lo que pasa cuando se abre el teclado o aparece una
/// notificación arriba. Solo lo primero significa "volvió a la app" y amerita
/// revisar si hay canciones nuevas.
///
/// Devuelve el nuevo valor de [wasInBackground] y si corresponde revisar.
({bool wasInBackground, bool check}) lifecycleDecision(
  AppLifecycleState state, {
  required bool wasInBackground,
}) {
  if (state == AppLifecycleState.paused ||
      state == AppLifecycleState.detached) {
    return (wasInBackground: true, check: false);
  }
  if (state != AppLifecycleState.resumed || !wasInBackground) {
    return (wasInBackground: wasInBackground, check: false);
  }
  return (wasInBackground: false, check: true);
}

/// Busca canciones nuevas sin que haya que pedirlo.
///
/// Revisa al volver a la app (el caso típico: descargaste algo en otra app y
/// volvés) y cada tanto mientras está abierta. Si no hay nada nuevo no se
/// nota: solo avisa cuando aparecieron canciones.
class LibraryWatcher with WidgetsBindingObserver {
  LibraryWatcher._();

  static final LibraryWatcher instance = LibraryWatcher._();

  /// Cuántas canciones nuevas trajo la última revisión (0 = nada que contar).
  final ValueNotifier<int> foundSongs = ValueNotifier<int>(0);

  Timer? _timer;
  bool _running = false;
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

  /// `true` si la app estuvo de verdad en segundo plano desde la última
  /// revisión.
  bool _wasInBackground = false;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _timer ??= Timer.periodic(
      const Duration(minutes: 2),
      (_) => unawaited(check()),
    );
    // Apenas abre: lo que bajaste mientras la app estaba cerrada ya tiene
    // que estar ahí, sin esperar al primer repaso.
    unawaited(check(force: true));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final decision = lifecycleDecision(
      state,
      wasInBackground: _wasInBackground,
    );
    _wasInBackground = decision.wasInBackground;
    if (decision.check) unawaited(check());
  }

  /// Revisa las carpetas. [force] saltea la espera mínima entre revisiones.
  Future<void> check({bool force = false}) async {
    if (_running) return;
    if (!force &&
        DateTime.now().difference(_last) < const Duration(seconds: 8)) {
      return;
    }
    if (AppSettings.instance.includedFolders.isEmpty) return;
    _running = true;
    final repository = LibraryRepository.instance;
    final before = repository.paths.value.toSet();
    try {
      await repository.rescan();
      final added = repository.paths.value
          .where((path) => !before.contains(path))
          .length;
      if (added > 0) foundSongs.value = added;
    } catch (error) {
      // Sin permiso o carpeta que ya no existe: se reintenta más tarde.
      debugPrint('No se pudo revisar la biblioteca: $error');
    } finally {
      _last = DateTime.now();
      _running = false;
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _timer = null;
  }
}
