import 'package:flutter/foundation.dart';

import 'app_settings.dart';

/// Una cola de reproducción guardada: sus canciones y por dónde iba.
///
/// La app siempre tuvo una sola cola. Esto permite tener varias, cada una
/// independiente, como si cada lista que reproducís fuera una cola aparte: con
/// su canción y su segundo, su orden mezclado y su bucle. Cambiar de cola deja
/// la anterior tal cual estaba y retoma la otra donde la dejaste.
@immutable
class SavedQueue {
  const SavedQueue({
    required this.id,
    required this.name,
    this.paths = const [],
    this.index = 0,
    this.positionMs = 0,
    this.shuffle = false,
    this.orderBeforeShuffle = const [],
    this.loop = 'off',
  });

  final String id;
  final String name;

  /// Rutas de las canciones, en el orden en que suenan.
  final List<String> paths;

  /// Canción en la que iba.
  final int index;
  final int positionMs;

  /// Si estaba mezclada, y el orden de antes de mezclar para poder volver.
  final bool shuffle;
  final List<String> orderBeforeShuffle;

  /// 'off' | 'all' | 'one': el bucle es de cada cola, no global.
  final String loop;

  SavedQueue copyWith({
    String? name,
    List<String>? paths,
    int? index,
    int? positionMs,
    bool? shuffle,
    List<String>? orderBeforeShuffle,
    String? loop,
  }) => SavedQueue(
    id: id,
    name: name ?? this.name,
    paths: paths ?? this.paths,
    index: index ?? this.index,
    positionMs: positionMs ?? this.positionMs,
    shuffle: shuffle ?? this.shuffle,
    orderBeforeShuffle: orderBeforeShuffle ?? this.orderBeforeShuffle,
    loop: loop ?? this.loop,
  );

  Map<String, Object> toMap() => {
    'id': id,
    'name': name,
    'paths': paths,
    'index': index,
    'positionMs': positionMs,
    'shuffle': shuffle,
    'orderBeforeShuffle': orderBeforeShuffle,
    'loop': loop,
  };

  /// Lee una cola guardada. Es tolerante a propósito: si falta un campo o
  /// tiene un tipo raro (versión vieja, disco dañado) se usa un valor neutro,
  /// y solo se descarta lo que no tiene ni identificador.
  static SavedQueue? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    if (id is! String || id.isEmpty) return null;
    List<String> strings(Object? value) =>
        value is List ? value.whereType<String>().toList() : const [];
    final name = raw['name'];
    return SavedQueue(
      id: id,
      name: name is String && name.trim().isNotEmpty ? name : 'Cola',
      paths: strings(raw['paths']),
      index: (raw['index'] as num?)?.toInt() ?? 0,
      positionMs: (raw['positionMs'] as num?)?.toInt() ?? 0,
      shuffle: raw['shuffle'] == true,
      orderBeforeShuffle: strings(raw['orderBeforeShuffle']),
      loop: raw['loop'] is String ? raw['loop'] as String : 'off',
    );
  }
}

/// "Cola 1", "Cola 2"...: el número más chico que todavía no se usa, para que
/// al borrar una no queden nombres repetidos ni saltos raros.
String nextQueueName(Iterable<String> existing) {
  final taken = existing.toSet();
  var number = 1;
  while (taken.contains('Cola $number')) {
    number++;
  }
  return 'Cola $number';
}

/// Un identificador que no esté en [existing].
String newQueueId(Iterable<String> existing, {int? seed}) {
  final taken = existing.toSet();
  var stamp = seed ?? DateTime.now().millisecondsSinceEpoch;
  while (taken.contains('q$stamp')) {
    stamp++;
  }
  return 'q$stamp';
}

/// Las colas guardadas, en el orden en que se crearon.
///
/// Una de ellas es la **activa**: la que está cargada en el reproductor. Lo
/// que ahí figura es solo la última foto; el contenido real y vivo lo tiene
/// el reproductor, y se vuelca acá al cambiar de cola. Si la app se cierra
/// con una cola sonando, esa cola se retoma por la sesión de siempre
/// (`AppSettings.saveSession`), igual que antes de que hubiera varias.
class QueueStore {
  QueueStore._() {
    _load();
  }

  static final QueueStore instance = QueueStore._();

  /// Lo más que se guarda. Al pasarse no se borra nada solo: se avisa en la
  /// pantalla y es la persona quien decide cuál sacar.
  static const int maxQueues = 12;

  final ValueNotifier<List<SavedQueue>> queues = ValueNotifier(const []);
  final ValueNotifier<String> activeId = ValueNotifier('');

  SavedQueue? byId(String id) {
    for (final queue in queues.value) {
      if (queue.id == id) return queue;
    }
    return null;
  }

  bool get isFull => queues.value.length >= maxQueues;

  void _load() {
    final settings = AppSettings.instance;
    final loaded = <SavedQueue>[];
    final seen = <String>{};
    for (final raw in settings.savedQueues) {
      final queue = SavedQueue.fromMap(raw);
      if (queue != null && seen.add(queue.id)) loaded.add(queue);
    }
    queues.value = loaded;
    activeId.value = settings.activeQueueId;
    ensureDefault();
  }

  /// Asegura que haya una cola activa. En la primera vez se crea "Cola 1", que
  /// es la sesión de siempre.
  void ensureDefault() {
    final list = queues.value;
    if (list.isEmpty) {
      final first = SavedQueue(
        id: newQueueId(const []),
        name: nextQueueName(const []),
      );
      queues.value = [first];
      activeId.value = first.id;
      _save();
      return;
    }
    if (byId(activeId.value) == null) {
      activeId.value = list.first.id;
      _save();
    }
  }

  SavedQueue add({String? name}) {
    final names = [for (final queue in queues.value) queue.name];
    final queue = SavedQueue(
      id: newQueueId([for (final queue in queues.value) queue.id]),
      name: (name == null || name.trim().isEmpty)
          ? nextQueueName(names)
          : name.trim(),
    );
    queues.value = [...queues.value, queue];
    _save();
    return queue;
  }

  void update(SavedQueue queue) {
    queues.value = [
      for (final existing in queues.value)
        existing.id == queue.id ? queue : existing,
    ];
    _save();
  }

  void rename(String id, String name) {
    final queue = byId(id);
    final clean = name.trim();
    if (queue == null || clean.isEmpty) return;
    update(queue.copyWith(name: clean));
  }

  void remove(String id) {
    queues.value = [
      for (final queue in queues.value)
        if (queue.id != id) queue,
    ];
    _save();
  }

  void setActive(String id) {
    if (byId(id) == null) return;
    activeId.value = id;
    _save();
  }

  void _save() {
    final settings = AppSettings.instance;
    settings.setSavedQueues([for (final queue in queues.value) queue.toMap()]);
    settings.setActiveQueueId(activeId.value);
  }
}
