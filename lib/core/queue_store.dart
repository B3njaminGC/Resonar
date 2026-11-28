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
    this.source = '',
    this.updatedMs = 0,
    this.pinned = false,
    this.edited = false,
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

  /// Huella de la lista con que se armó (ver [fingerprintOf]). Sirve para
  /// reconocer "esta es la misma lista de antes" y volver a su cola en vez de
  /// armar otra. Vacía si la cola no nació de una lista.
  final String source;

  /// Cuándo se usó por última vez, para saber cuál sacar si hay demasiadas.
  final int updatedMs;

  /// Fijada por la persona: nunca se saca sola.
  final bool pinned;

  /// Tocada a mano (se reordenó, se le quitó o agregó algo, se renombró):
  /// es trabajo de la persona, así que se saca recién cuando no queda otra, y
  /// no se pisa al volver a reproducir la lista de la que salió.
  final bool edited;

  SavedQueue copyWith({
    String? name,
    List<String>? paths,
    int? index,
    int? positionMs,
    bool? shuffle,
    List<String>? orderBeforeShuffle,
    String? loop,
    String? source,
    int? updatedMs,
    bool? pinned,
    bool? edited,
  }) => SavedQueue(
    id: id,
    name: name ?? this.name,
    paths: paths ?? this.paths,
    index: index ?? this.index,
    positionMs: positionMs ?? this.positionMs,
    shuffle: shuffle ?? this.shuffle,
    orderBeforeShuffle: orderBeforeShuffle ?? this.orderBeforeShuffle,
    loop: loop ?? this.loop,
    source: source ?? this.source,
    updatedMs: updatedMs ?? this.updatedMs,
    pinned: pinned ?? this.pinned,
    edited: edited ?? this.edited,
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
    'source': source,
    'updatedMs': updatedMs,
    'pinned': pinned,
    'edited': edited,
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
    // `as num?` fallaría con un texto; esto lo deja en 0.
    int number(Object? value) => value is num ? value.toInt() : 0;
    final name = raw['name'];
    return SavedQueue(
      id: id,
      name: name is String && name.trim().isNotEmpty ? name : 'Cola',
      paths: strings(raw['paths']),
      index: number(raw['index']),
      positionMs: number(raw['positionMs']),
      shuffle: raw['shuffle'] == true,
      orderBeforeShuffle: strings(raw['orderBeforeShuffle']),
      loop: raw['loop'] is String ? raw['loop'] as String : 'off',
      source: raw['source'] is String ? raw['source'] as String : '',
      updatedMs: number(raw['updatedMs']),
      pinned: raw['pinned'] == true,
      edited: raw['edited'] == true,
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

/// Si [name] es uno de los automáticos ("Cola 3"), o sea que nadie lo eligió.
bool isDefaultQueueName(String name) => RegExp(r'^Cola \d+$').hasMatch(name);

/// [base] si está libre; si no, "base 2", "base 3"... Así dos selecciones
/// distintas no quedan con el mismo nombre. Sin [base] cae en "Cola N".
String uniqueQueueName(String? base, Iterable<String> existing) {
  final clean = base?.trim() ?? '';
  if (clean.isEmpty) return nextQueueName(existing);
  final taken = existing.toSet();
  if (!taken.contains(clean)) return clean;
  var number = 2;
  while (taken.contains('$clean $number')) {
    number++;
  }
  return '$clean $number';
}

/// Huella de una lista de canciones: cantidad y un hash de las rutas, en
/// orden. Es FNV-1a escrito a mano y no `hashCode` porque tiene que dar lo
/// mismo en cada arranque y en cada versión de Dart: se guarda en disco.
String fingerprintOf(Iterable<String> paths) {
  var hash = 0x811c9dc5;
  var count = 0;
  for (final path in paths) {
    for (final unit in path.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    // Separador: ["ab", "c"] y ["a", "bc"] no son la misma lista.
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
    count++;
  }
  return '$count:${hash.toRadixString(16)}';
}

/// La cola que menos se usó, para sacarla cuando ya hay demasiadas.
///
/// Nunca la activa ni las fijadas. Las que la persona tocó a mano se dejan
/// para el final: solo se sacan si no queda ninguna sin tocar. `null` si no
/// hay nada que se pueda sacar.
String? queueToEvict(Iterable<SavedQueue> queues, String activeId) {
  SavedQueue? oldest(bool Function(SavedQueue queue) allowed) {
    SavedQueue? found;
    for (final queue in queues) {
      if (!allowed(queue)) continue;
      if (found == null || queue.updatedMs < found.updatedMs) found = queue;
    }
    return found;
  }

  final untouched = oldest(
    (queue) => queue.id != activeId && !queue.pinned && !queue.edited,
  );
  return (untouched ?? oldest((queue) => queue.id != activeId && !queue.pinned))
      ?.id;
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

  /// Lo más que se guarda. Como las colas se crean solas al reproducir cosas
  /// distintas, al llegar al tope se saca la que hace más que no se usa.
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

  SavedQueue add({String? name, String source = ''}) {
    final names = [for (final queue in queues.value) queue.name];
    final queue = SavedQueue(
      id: newQueueId([for (final queue in queues.value) queue.id]),
      name: uniqueQueueName(name, names),
      source: source,
      updatedMs: DateTime.now().millisecondsSinceEpoch,
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
    // Ponerle nombre es trabajo de la persona: pasa a contar como tocada.
    update(queue.copyWith(name: clean, edited: true));
  }

  void togglePin(String id) {
    final queue = byId(id);
    if (queue == null) return;
    update(queue.copyWith(pinned: !queue.pinned));
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
