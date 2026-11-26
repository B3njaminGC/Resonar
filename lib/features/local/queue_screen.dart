import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/audio_service.dart';
import '../../core/queue_store.dart';
import '../../core/widgets/track_artwork.dart';
import '../../library/track_index.dart';
import 'playlist_transfer.dart';
import '../../theme/accent.dart';
import '../../theme/notice.dart';

class QueueScreen extends StatelessWidget {
  const QueueScreen({super.key, this.showAppBar = false});

  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    final audio = AudioService();
    final content = Column(
      children: [
        _QueueSwitcher(audio: audio),
        Expanded(
          child: ValueListenableBuilder<List<File>>(
            valueListenable: audio.queueNotifier,
            builder: (context, files, _) => files.isEmpty
                ? const Center(
                    child: Text(
                      'No hay canciones en la cola actual.\n'
                      'Reproduce una canción o una lista.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : _Queue(files: files, audio: audio),
          ),
        ),
      ],
    );
    return showAppBar
        ? Scaffold(
            appBar: AppBar(title: const Text('Cola de reproducción')),
            body: content,
          )
        : content;
  }
}

class _Queue extends StatelessWidget {
  const _Queue({required this.files, required this.audio});

  final List<File> files;
  final AudioService audio;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int?>(
      stream: audio.player.currentIndexStream,
      initialData: audio.currentIndex,
      builder: (context, snapshot) {
        final currentIndex = snapshot.data;
        final list = ReorderableListView.builder(
          itemCount: files.length,
          onReorderItem: audio.reorderQueue,
          // Sin esto, Flutter arrastra desde cualquier parte de la fila pero
          // exige mantener apretado. Se arrastra solo desde las rayitas, y
          // desde ahí al toque (ver `ReorderableDragStartListener` abajo).
          buildDefaultDragHandles: false,
          itemBuilder: (context, index) {
            final file = files[index];
            final info =
                TrackIndex.instance.infoFor(file.path) ??
                TrackInfo.fromFile(file);
            final isPlayingNow = index == currentIndex;
            // La misma canción puede estar varias veces en la cola: la clave
            // incluye la posición para que sea única.
            final key = ValueKey('$index|${file.path}');
            return Dismissible(
              key: key,
              direction: DismissDirection.endToStart,
              background: const ColoredBox(
                color: Colors.redAccent,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: EdgeInsets.only(right: 20),
                    child: Icon(Icons.delete_outline, color: Colors.white),
                  ),
                ),
              ),
              onDismissed: (_) => audio.removeFromQueue(index),
              child: ListTile(
                leading: Stack(
                  children: [
                    LocalTrackArtwork(file: file, size: 48, borderRadius: 24),
                    if (isPlayingNow)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: context.accent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.equalizer,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                title: Text(
                  info.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: isPlayingNow
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: isPlayingNow ? context.accent : null,
                  ),
                ),
                subtitle: Text(
                  info.artistLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                // Arrastra en cuanto el dedo se mueve, sin esperar. El relleno
                // es zona de agarre: las rayitas solas son un blanco chico.
                trailing: ReorderableDragStartListener(
                  index: index,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                    child: Icon(Icons.drag_handle),
                  ),
                ),
                onTap: () => audio.seekToQueueIndex(index),
              ),
            );
          },
        );
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: () =>
                        showSaveQueueAsPlaylistDialog(context, files),
                    icon: const Icon(Icons.playlist_add),
                    label: const Text('Guardar como lista'),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Exportar cola como .m3u',
                    icon: const Icon(Icons.ios_share),
                    onPressed: () => exportPlaylistAsM3u(context, 'Cola actual', [
                      for (final file in files) file.path,
                    ]),
                  ),
                ],
              ),
            ),
            Expanded(child: list),
          ],
        );
      },
    );
  }
}

/// Fila de colas arriba de todo: tocás una para pasar a ella, mantenés para
/// cambiarle el nombre o borrarla, y "Nueva" arranca una vacía.
///
/// Cada cola guarda su canción, su segundo, su mezcla y su bucle, así que al
/// volver a una sigue exactamente donde la dejaste.
class _QueueSwitcher extends StatelessWidget {
  const _QueueSwitcher({required this.audio});

  final AudioService audio;

  @override
  Widget build(BuildContext context) {
    final store = QueueStore.instance;
    return ValueListenableBuilder<List<SavedQueue>>(
      valueListenable: store.queues,
      builder: (context, queues, _) => ValueListenableBuilder<String>(
        valueListenable: store.activeId,
        builder: (context, activeId, _) => ValueListenableBuilder<List<File>>(
          // La cola activa cuenta con lo que tiene cargado ahora, no con la
          // última foto guardada.
          valueListenable: audio.queueNotifier,
          builder: (context, live, _) => SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              children: [
                for (final queue in queues)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onLongPress: () => _showMenu(context, queue),
                      child: ChoiceChip(
                        selected: queue.id == activeId,
                        label: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 170),
                          child: Text(
                            '${queue.name} · '
                            '${queue.id == activeId ? live.length : queue.paths.length}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        onSelected: (_) => audio.switchToQueue(queue.id),
                      ),
                    ),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: const Text('Nueva'),
                  onPressed: () => _newQueue(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _newQueue(BuildContext context) async {
    final store = QueueStore.instance;
    if (audio.playlistFiles.isEmpty) {
      showNotice(context, 'Esta cola está vacía: sumale canciones desde tu música.');
      return;
    }
    if (store.isFull) {
      showNotice(context, 'Ya hay ${QueueStore.maxQueues} colas. Borrá alguna.');
      return;
    }
    final queue = await audio.startNewQueue();
    if (queue != null && context.mounted) {
      showNotice(context, '${queue.name}: sumale canciones desde tu música.');
    }
  }

  Future<void> _showMenu(BuildContext context, SavedQueue queue) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Cambiar nombre'),
              onTap: () => Navigator.pop(sheet, 'rename'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Borrar cola'),
              onTap: () => Navigator.pop(sheet, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || choice == null) return;
    if (choice == 'rename') {
      await _rename(context, queue);
    } else {
      await _delete(context, queue);
    }
  }

  Future<void> _rename(BuildContext context, SavedQueue queue) async {
    final controller = TextEditingController(text: queue.name);
    final name = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Nombre de la cola'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 30,
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (value) => Navigator.pop(dialog, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, controller.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null) QueueStore.instance.rename(queue.id, name);
  }

  Future<void> _delete(BuildContext context, SavedQueue queue) async {
    final store = QueueStore.instance;
    final count = queue.id == store.activeId.value
        ? audio.playlistFiles.length
        : queue.paths.length;
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('¿Borrar "${queue.name}"?'),
        content: Text(
          count == 0
              ? 'La cola está vacía.'
              : 'Se pierde la cola con sus $count canciones. Las canciones '
                    'siguen en tu teléfono.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (sure == true) await audio.deleteQueue(queue.id);
  }
}
