import 'package:flutter_test/flutter_test.dart';
import 'package:play_music_app/library/track_index.dart';

void main() {
  group('searchTextOf', () {
    test('junta todos los campos en minúsculas', () {
      final text = searchTextOf(
        title: 'Mi Canción',
        fileName: '01 - Mi Cancion (Remix)',
        artist: 'Un Artista',
        album: 'El Álbum',
        genre: 'Cumbia',
      );
      expect(text.contains('mi canción'), isTrue);
      expect(text.contains('un artista'), isTrue);
      expect(text.contains('el álbum'), isTrue);
      expect(text.contains('cumbia'), isTrue);
      expect(text.contains('remix'), isTrue);
      expect(text, equals(text.toLowerCase()));
    });

    test('los campos vacíos no agregan texto', () {
      final text = searchTextOf(title: 'Tema', fileName: 'tema');
      expect(text.replaceAll(searchFieldSeparator, ''), equals('tematema'));
    });
  });

  group('matchesSearch', () {
    final text = searchTextOf(
      title: 'Nada Que Perder',
      fileName: 'nada_que_perder',
      artist: 'Bersuit',
      album: 'Libertinaje',
      genre: 'Rock',
    );

    test('una consulta vacía coincide con todo', () {
      expect(matchesSearch(text, ''), isTrue);
      expect(matchesSearch(text, '   '), isTrue);
    });

    test('coincide por título, artista, álbum y género', () {
      expect(matchesSearch(text, 'perder'), isTrue);
      expect(matchesSearch(text, 'bersuit'), isTrue);
      expect(matchesSearch(text, 'libertinaje'), isTrue);
      expect(matchesSearch(text, 'rock'), isTrue);
    });

    test('no distingue mayúsculas ni espacios de más', () {
      expect(matchesSearch(text, '  BERSUIT '), isTrue);
    });

    test('no coincide con algo que no está', () {
      expect(matchesSearch(text, 'charly'), isFalse);
    });

    test('no coincide a caballo de dos campos', () {
      // "perder" termina el título y "bersuit" abre el artista: pegados no
      // deben formar una coincidencia.
      expect(matchesSearch(text, 'perderbersuit'), isFalse);
    });
  });
}
