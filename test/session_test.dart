import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:play_music_app/core/audio_service.dart';

void main() {
  group('loopModeFromName', () {
    test('ida y vuelta con lo que se guarda en Ajustes', () {
      // El bucle se guarda con `LoopMode.name`. Si los nombres dejaran de
      // coincidir, el bucle volvería siempre apagado y nadie se enteraría.
      for (final mode in LoopMode.values) {
        expect(loopModeFromName(mode.name), equals(mode));
      }
    });

    test('un valor desconocido o ausente queda apagado', () {
      expect(loopModeFromName(null), equals(LoopMode.off));
      expect(loopModeFromName(''), equals(LoopMode.off));
      expect(loopModeFromName('bucle'), equals(LoopMode.off));
    });
  });

  group('duckFactorFor', () {
    test('el porcentaje que se baja da el volumen que queda', () {
      expect(duckFactorFor(0), equals(1.0));
      expect(duckFactorFor(20), closeTo(0.8, 0.0001));
      expect(duckFactorFor(40), closeTo(0.6, 0.0001));
      expect(duckFactorFor(100), equals(0.0));
    });

    test('nunca se va del rango audible', () {
      expect(duckFactorFor(-20), equals(1.0));
      expect(duckFactorFor(500), equals(0.0));
      for (final percent in [0, 10, 33, 40, 75, 100]) {
        final factor = duckFactorFor(percent);
        expect(factor, inInclusiveRange(0.0, 1.0));
      }
    });
  });

  group('endedBeforeDucking', () {
    test('un sonido corto que no llegó a bajar nada no devuelve nada', () {
      expect(
        endedBeforeDucking(
          delayPending: true,
          duckFactor: 1.0,
          ramping: false,
        ),
        isTrue,
      );
    });

    test('si el volumen ya estaba abajo hay que devolverlo', () {
      // Una app de video pide el audio dos veces seguidas: la segunda termina
      // enseguida, pero la música ya venía agachada por la primera.
      expect(
        endedBeforeDucking(
          delayPending: true,
          duckFactor: 0.15,
          ramping: false,
        ),
        isFalse,
      );
    });

    test('si estaba bajando también hay que devolverlo', () {
      expect(
        endedBeforeDucking(
          delayPending: true,
          duckFactor: 1.0,
          ramping: true,
        ),
        isFalse,
      );
    });

    test('sin espera pendiente, la interrupción terminó normalmente', () {
      expect(
        endedBeforeDucking(
          delayPending: false,
          duckFactor: 1.0,
          ramping: false,
        ),
        isFalse,
      );
    });
  });

  group('shouldResumeAfterInterruption', () {
    test('una interrupción corta retoma sola', () {
      expect(shouldResumeAfterInterruption(const Duration(seconds: 20)), isTrue);
      expect(shouldResumeAfterInterruption(const Duration(minutes: 2)), isTrue);
    });

    test('una larga deja la música en pausa', () {
      expect(
        shouldResumeAfterInterruption(const Duration(minutes: 2, seconds: 1)),
        isFalse,
      );
      expect(shouldResumeAfterInterruption(const Duration(minutes: 30)), isFalse);
    });

    test('si no se sabe cuánto duró, retoma', () {
      expect(shouldResumeAfterInterruption(null), isTrue);
    });
  });

  group('playNextSlot', () {
    test('la primera va justo después de la actual', () {
      final slot = playNextSlot(current: 3, anchor: -1, ahead: 0, length: 10);
      expect(slot.index, equals(4));
      expect(slot.ahead, equals(1));
    });

    test('varias seguidas quedan en el orden en que se eligieron', () {
      // Se simula elegir tres canciones "a continuación" con la 3 sonando.
      final queue = ['a', 'b', 'c', 'D', 'e', 'f'];
      const current = 3;
      var anchor = -1;
      var ahead = 0;
      for (final song in ['X', 'Y', 'Z']) {
        final slot = playNextSlot(
          current: current,
          anchor: anchor,
          ahead: ahead,
          length: queue.length,
        );
        queue.insert(slot.index, song);
        anchor = current;
        ahead = slot.ahead;
      }
      expect(queue, equals(['a', 'b', 'c', 'D', 'X', 'Y', 'Z', 'e', 'f']));
    });

    test('si ya empezó a sonar una de las puestas, las demás siguen detrás', () {
      // Se puso X, Y, Z con la 3 sonando; pasó a X (índice 4). Una nueva va
      // después de Z y no entre X y Y.
      final slot = playNextSlot(current: 4, anchor: 3, ahead: 3, length: 9);
      expect(slot.index, equals(7));
    });

    test('si se pasó de largo o se reordenó, se empieza de cero', () {
      final far = playNextSlot(current: 9, anchor: 3, ahead: 3, length: 12);
      expect(far.index, equals(10));
      final back = playNextSlot(current: 1, anchor: 3, ahead: 3, length: 12);
      expect(back.index, equals(2));
    });

    test('nunca se pasa del final de la cola', () {
      final slot = playNextSlot(current: 5, anchor: 5, ahead: 4, length: 7);
      expect(slot.index, equals(7));
    });
  });
}
