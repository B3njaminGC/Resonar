import 'package:flutter_test/flutter_test.dart';
import 'package:play_music_app/core/queue_store.dart';

void main() {
  group('SavedQueue', () {
    test('ida y vuelta con lo que se guarda en disco', () {
      const queue = SavedQueue(
        id: 'q1',
        name: 'Gym',
        paths: ['/m/a.mp3', '/m/b.mp3', '/m/c.mp3'],
        index: 2,
        positionMs: 61500,
        shuffle: true,
        orderBeforeShuffle: ['/m/c.mp3', '/m/a.mp3', '/m/b.mp3'],
        loop: 'all',
      );
      final back = SavedQueue.fromMap(queue.toMap())!;
      expect(back.id, equals('q1'));
      expect(back.name, equals('Gym'));
      expect(back.paths, equals(queue.paths));
      expect(back.index, equals(2));
      expect(back.positionMs, equals(61500));
      expect(back.shuffle, isTrue);
      expect(back.orderBeforeShuffle, equals(queue.orderBeforeShuffle));
      expect(back.loop, equals('all'));
    });

    test('lo que falta o viene con otro tipo queda en un valor neutro', () {
      final queue = SavedQueue.fromMap({
        'id': 'q9',
        'paths': ['/m/a.mp3', 7, null],
        'index': 'tres',
        'shuffle': 'si',
        'loop': 3,
      })!;
      expect(queue.name, equals('Cola'));
      expect(queue.paths, equals(['/m/a.mp3']));
      expect(queue.index, equals(0));
      expect(queue.positionMs, equals(0));
      expect(queue.shuffle, isFalse);
      expect(queue.loop, equals('off'));
    });

    test('sin identificador, o sin ser un mapa, se descarta', () {
      expect(SavedQueue.fromMap(null), isNull);
      expect(SavedQueue.fromMap('cola'), isNull);
      expect(SavedQueue.fromMap({'name': 'Sin id'}), isNull);
      expect(SavedQueue.fromMap({'id': ''}), isNull);
    });

    test('copyWith cambia solo lo que se pide', () {
      const queue = SavedQueue(id: 'q1', name: 'A', paths: ['/m/a.mp3']);
      final moved = queue.copyWith(index: 1, positionMs: 500);
      expect(moved.id, equals('q1'));
      expect(moved.name, equals('A'));
      expect(moved.paths, equals(['/m/a.mp3']));
      expect(moved.index, equals(1));
      expect(moved.positionMs, equals(500));
    });
  });

  group('nombres e identificadores', () {
    test('la primera cola es "Cola 1"', () {
      expect(nextQueueName(const []), equals('Cola 1'));
    });

    test('toma el número más chico libre, también tras borrar una', () {
      expect(nextQueueName(['Cola 1', 'Cola 2']), equals('Cola 3'));
      expect(nextQueueName(['Cola 1', 'Cola 3']), equals('Cola 2'));
      expect(nextQueueName(['Gym', 'Cola 2']), equals('Cola 1'));
    });

    test('un identificador nuevo nunca repite uno existente', () {
      final first = newQueueId(const [], seed: 100);
      expect(first, equals('q100'));
      final second = newQueueId([first], seed: 100);
      expect(second, isNot(equals(first)));
      expect(newQueueId([first, second], seed: 100), isNot(anyOf(first, second)));
    });
  });

  group('origen de una cola', () {
    test('la huella es la misma para la misma lista, en el mismo orden', () {
      final a = fingerprintOf(['/m/a.mp3', '/m/b.mp3', '/m/c.mp3']);
      expect(fingerprintOf(['/m/a.mp3', '/m/b.mp3', '/m/c.mp3']), equals(a));
    });

    test('cambia si cambia el orden, una canción o la cantidad', () {
      final base = fingerprintOf(['/m/a.mp3', '/m/b.mp3']);
      expect(fingerprintOf(['/m/b.mp3', '/m/a.mp3']), isNot(equals(base)));
      expect(fingerprintOf(['/m/a.mp3', '/m/c.mp3']), isNot(equals(base)));
      expect(fingerprintOf(['/m/a.mp3']), isNot(equals(base)));
      expect(fingerprintOf(const []), isNot(equals(base)));
    });

    test('dos listas con las mismas letras cortadas distinto no se confunden', () {
      expect(
        fingerprintOf(['ab', 'c']),
        isNot(equals(fingerprintOf(['a', 'bc']))),
      );
    });

    test('el valor no cambia entre versiones: se guarda en disco', () {
      // Si este valor cambiara, todas las colas guardadas dejarían de
      // reconocerse como "la misma lista" y se duplicarían al actualizar.
      expect(fingerprintOf(['/m/a.mp3']), equals('1:947ceb03'));
    });

    test('origen y última vez usada hacen ida y vuelta', () {
      const queue = SavedQueue(
        id: 'q1',
        name: 'Biblioteca',
        source: '120:abc',
        updatedMs: 1700000000000,
      );
      final back = SavedQueue.fromMap(queue.toMap())!;
      expect(back.source, equals('120:abc'));
      expect(back.updatedMs, equals(1700000000000));
    });

    test('una cola vieja, sin esos campos, se lee igual', () {
      final queue = SavedQueue.fromMap({'id': 'q1', 'name': 'Vieja'})!;
      expect(queue.source, isEmpty);
      expect(queue.updatedMs, equals(0));
    });
  });

  group('nombres de colas automáticas', () {
    test('un nombre libre se deja tal cual', () {
      expect(uniqueQueueName('Biblioteca', ['Favoritas']), equals('Biblioteca'));
    });

    test('uno repetido lleva número', () {
      expect(
        uniqueQueueName('Selección', ['Selección']),
        equals('Selección 2'),
      );
      expect(
        uniqueQueueName('Selección', ['Selección', 'Selección 2']),
        equals('Selección 3'),
      );
    });

    test('sin nombre cae en "Cola N"', () {
      expect(uniqueQueueName(null, ['Cola 1']), equals('Cola 2'));
      expect(uniqueQueueName('  ', const []), equals('Cola 1'));
    });

    test('reconoce los nombres automáticos y no los elegidos', () {
      expect(isDefaultQueueName('Cola 4'), isTrue);
      expect(isDefaultQueueName('Cola'), isFalse);
      expect(isDefaultQueueName('Gym'), isFalse);
      expect(isDefaultQueueName('Cola 4 de gym'), isFalse);
    });
  });

  group('fijadas y tocadas a mano', () {
    test('hacen ida y vuelta', () {
      const queue = SavedQueue(id: 'q1', name: 'Gym', pinned: true, edited: true);
      final back = SavedQueue.fromMap(queue.toMap())!;
      expect(back.pinned, isTrue);
      expect(back.edited, isTrue);
    });

    test('una cola vieja no viene ni fijada ni tocada', () {
      final queue = SavedQueue.fromMap({'id': 'q1'})!;
      expect(queue.pinned, isFalse);
      expect(queue.edited, isFalse);
    });
  });

  group('queueToEvict', () {
    SavedQueue q(
      String id,
      int ms, {
      bool pinned = false,
      bool edited = false,
    }) => SavedQueue(
      id: id,
      name: id,
      updatedMs: ms,
      pinned: pinned,
      edited: edited,
    );

    test('saca la que hace más que no se usa', () {
      expect(queueToEvict([q('a', 30), q('b', 10), q('c', 20)], 'a'), 'b');
    });

    test('nunca saca la activa, aunque sea la más vieja', () {
      expect(queueToEvict([q('a', 1), q('b', 10), q('c', 20)], 'a'), 'b');
    });

    test('nunca saca una fijada, aunque sea la más vieja', () {
      expect(
        queueToEvict([q('a', 30), q('b', 1, pinned: true), q('c', 20)], 'a'),
        'c',
      );
    });

    test('las tocadas a mano se dejan para el final', () {
      // La más vieja fue editada: se saca la siguiente, que está sin tocar.
      expect(
        queueToEvict([q('a', 30), q('b', 1, edited: true), q('c', 20)], 'a'),
        'c',
      );
    });

    test('si todas las demás fueron tocadas, se saca la más vieja de ellas', () {
      expect(
        queueToEvict(
          [q('a', 30), q('b', 5, edited: true), q('c', 2, edited: true)],
          'a',
        ),
        'c',
      );
    });

    test('si todas las demás están fijadas, no se saca ninguna', () {
      expect(
        queueToEvict([q('a', 30), q('b', 1, pinned: true)], 'a'),
        isNull,
      );
    });

    test('si no hay otra, no saca nada', () {
      expect(queueToEvict([q('a', 1)], 'a'), isNull);
      expect(queueToEvict(const [], 'a'), isNull);
    });
  });

  group('selección dentro de un mismo origen', () {
    test('la huella no depende de qué canciones se marcaron', () {
      expect(selectionSourceOf('Mi lista'), selectionSourceOf('Mi lista'));
      expect(selectionSourceOf(' Mi lista '), selectionSourceOf('Mi lista'));
    });

    test('otro origen es otra cola', () {
      expect(
        selectionSourceOf('Mi lista'),
        isNot(selectionSourceOf('Otra lista')),
      );
    });

    test('no se confunde con la huella de una lista entera', () {
      expect(
        selectionSourceOf('Mi lista'),
        isNot(fingerprintOf(['/m/a.mp3', '/m/b.mp3'])),
      );
    });

    test('el nombre dice de dónde salió, o queda "Selección"', () {
      expect(selectionLabelOf('Mi lista'), 'Selección de Mi lista');
      expect(selectionLabelOf(null), 'Selección');
      expect(selectionLabelOf('  '), 'Selección');
    });
  });
}
