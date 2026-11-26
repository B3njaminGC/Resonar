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
}
