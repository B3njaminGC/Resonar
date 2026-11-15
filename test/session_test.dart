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
}
