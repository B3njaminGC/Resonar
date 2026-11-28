import 'package:flutter_test/flutter_test.dart';
import 'package:play_music_app/update/update_installer.dart';

void main() {
  group('problemForNativeResult', () {
    test('si el instalador se abrió, no hay problema', () {
      expect(UpdateInstaller.problemForNativeResult('ok'), isNull);
    });

    test('sin permiso de instalar, explica qué activar', () {
      final message = UpdateInstaller.problemForNativeResult('permission');
      expect(message, contains('Instalar apps desconocidas'));
    });

    test('sin archivo, dice que no sirve', () {
      expect(
        UpdateInstaller.problemForNativeResult('missing'),
        contains('no sirve'),
      );
    });

    test('una respuesta rara o vacía nunca pasa por éxito', () {
      expect(UpdateInstaller.problemForNativeResult(null), isNotNull);
      expect(UpdateInstaller.problemForNativeResult('quién sabe'), isNotNull);
    });
  });
}
