import 'package:flutter_test/flutter_test.dart';
import 'package:play_music_app/core/header_visibility.dart';

void main() {
  group('headerVisibilityFor', () {
    test('al bajar por una lista larga se esconde', () {
      expect(
        headerVisibilityFor(pixels: 300, maxScrollExtent: 5000, delta: 12),
        isFalse,
      );
    });

    test('al subir vuelve', () {
      expect(
        headerVisibilityFor(pixels: 300, maxScrollExtent: 5000, delta: -12),
        isTrue,
      );
    });

    test('arriba de todo siempre se ve', () {
      expect(
        headerVisibilityFor(pixels: 0, maxScrollExtent: 5000, delta: 12),
        isTrue,
      );
      expect(
        headerVisibilityFor(pixels: -20, maxScrollExtent: 5000, delta: 12),
        isTrue,
      );
    });

    test('una lista corta no la esconde, para no parpadear', () {
      expect(
        headerVisibilityFor(pixels: 100, maxScrollExtent: 150, delta: 12),
        isNull,
      );
    });

    test('el rebote del final y los temblores no cambian nada', () {
      expect(
        headerVisibilityFor(pixels: 5000, maxScrollExtent: 5000, delta: -8),
        isNull,
      );
      expect(
        headerVisibilityFor(pixels: 300, maxScrollExtent: 5000, delta: 1),
        isNull,
      );
    });

    test('en Sonando siempre se ve', () {
      expect(
        headerVisibilityFor(
          pixels: 300,
          maxScrollExtent: 5000,
          delta: 12,
          alwaysVisible: true,
        ),
        isTrue,
      );
    });
  });
}
