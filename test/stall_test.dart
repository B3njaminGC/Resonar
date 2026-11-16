import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:play_music_app/core/audio_service.dart';

/// Lectura típica: sonando, listo, clavado a un segundo del final.
bool check({
  bool playing = true,
  ProcessingState state = ProcessingState.ready,
  Duration? duration = const Duration(minutes: 3),
  Duration position = const Duration(minutes: 2, seconds: 59),
  Duration? lastPosition,
}) => looksStuckAtEnd(
  playing: playing,
  state: state,
  duration: duration,
  position: position,
  lastPosition: lastPosition ?? position,
);

void main() {
  group('looksStuckAtEnd', () {
    test('clavado al final y sin avanzar: trabado', () {
      expect(check(), isTrue);
    });

    test('si la posición avanza, no está trabado', () {
      expect(
        check(lastPosition: const Duration(minutes: 2, seconds: 57)),
        isFalse,
      );
    });

    test('en pausa nunca está trabado', () {
      expect(check(playing: false), isFalse);
    });

    test('mientras carga no cuenta como trabado', () {
      // El caso que importa: la posición no avanza porque está leyendo el
      // archivo, no porque se haya colgado. Saltar acá cortaría la canción.
      for (final state in [
        ProcessingState.buffering,
        ProcessingState.loading,
        ProcessingState.idle,
        ProcessingState.completed,
      ]) {
        expect(check(state: state), isFalse, reason: '$state');
      }
    });

    test('lejos del final no está trabado, aunque no avance', () {
      // Puede ser el usuario arrastrando la barra de progreso.
      expect(check(position: const Duration(minutes: 1)), isFalse);
    });

    test('sin duración conocida no se decide nada', () {
      expect(check(duration: null), isFalse);
      expect(check(duration: Duration.zero), isFalse);
    });

    test('el borde de los dos segundos', () {
      expect(
        check(position: const Duration(minutes: 2, seconds: 58)),
        isTrue,
        reason: 'exactamente 2 s restantes',
      );
      expect(
        check(
          position: const Duration(minutes: 2, seconds: 57, milliseconds: 900),
        ),
        isFalse,
        reason: '2,1 s restantes',
      );
    });
  });
}
