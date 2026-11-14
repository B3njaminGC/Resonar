import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_music_app/library/library_watcher.dart';

void main() {
  group('lifecycleDecision', () {
    test('irse a segundo plano no revisa, solo lo deja anotado', () {
      final result = lifecycleDecision(
        AppLifecycleState.paused,
        wasInBackground: false,
      );
      expect(result.check, isFalse);
      expect(result.wasInBackground, isTrue);
    });

    test('volver después de estar en segundo plano revisa una vez', () {
      final result = lifecycleDecision(
        AppLifecycleState.resumed,
        wasInBackground: true,
      );
      expect(result.check, isTrue);
      // Queda en falso para que el próximo parpadeo de foco no vuelva a
      // revisar.
      expect(result.wasInBackground, isFalse);
    });

    test('perder el foco sin irse (teclado, notificación) no revisa', () {
      final lost = lifecycleDecision(
        AppLifecycleState.inactive,
        wasInBackground: false,
      );
      expect(lost.check, isFalse);
      expect(lost.wasInBackground, isFalse);

      final back = lifecycleDecision(
        AppLifecycleState.resumed,
        wasInBackground: lost.wasInBackground,
      );
      expect(back.check, isFalse);
    });

    test('la secuencia completa de volver de otra app revisa una sola vez', () {
      var flag = false;
      var checks = 0;
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.paused,
        AppLifecycleState.resumed,
        // Abrir el teclado al volver no tiene que disparar otra revisión.
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        final result = lifecycleDecision(state, wasInBackground: flag);
        flag = result.wasInBackground;
        if (result.check) checks++;
      }
      expect(checks, equals(1));
    });

    test('cerrar la app cuenta como segundo plano', () {
      final result = lifecycleDecision(
        AppLifecycleState.detached,
        wasInBackground: false,
      );
      expect(result.wasInBackground, isTrue);
    });
  });
}
