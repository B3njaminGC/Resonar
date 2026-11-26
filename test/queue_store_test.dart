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
}
