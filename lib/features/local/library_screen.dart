import 'package:flutter/material.dart';

import 'favorites_tab.dart';
import 'genre_dialogs.dart';
import 'groups_tab.dart';
import 'playlist_screen.dart';
import 'playlist_service.dart';
import 'playlist_transfer.dart';
import 'songs_tab.dart';
import '../../theme/accent.dart';

/// Biblioteca: Canciones · Favoritas · Listas · Artistas · Álbumes · Géneros ·
/// Orígenes.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  static const int _playlistsTab = 2;
  static const int _genresTab = 5;

  late final TabController _tabController = TabController(
    length: 7,
    vsync: this,
  )..addListener(_onTabChanged);

  void _onTabChanged() {
    if (!_tabController.indexIsChanging && mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    super.dispose();
  }

  /// Menú del botón +: crear una lista o traer una de otro reproductor.
  void _showPlaylistActions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.playlist_add, color: context.accent),
              title: const Text('Crear lista'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                showCreatePlaylistDialog(context);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.file_download_outlined,
                color: context.accent,
              ),
              title: const Text('Importar lista (.m3u)'),
              subtitle: const Text('Traé una lista de otro reproductor.'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                importM3uPlaylist(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 0,
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          // Pestañas como "píldoras": la elegida queda en una cápsula suave,
          // sin la rayita de abajo ni la línea divisoria de Material.
          indicator: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(18),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          indicatorPadding: const EdgeInsets.symmetric(vertical: 4),
          dividerColor: Colors.transparent,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
          labelPadding: const EdgeInsets.symmetric(horizontal: 16),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          tabs: const [
            Tab(height: 40, text: 'Canciones'),
            Tab(height: 40, text: 'Favoritas'),
            Tab(height: 40, text: 'Listas'),
            Tab(height: 40, text: 'Artistas'),
            Tab(height: 40, text: 'Álbumes'),
            Tab(height: 40, text: 'Géneros'),
            Tab(height: 40, text: 'Orígenes'),
          ],
        ),
      ),
      // Un solo botón: dos tapaban el menú ⋮ de las listas de abajo.
      floatingActionButton: _tabController.index == _playlistsTab
          ? FloatingActionButton(
              heroTag: null,
              onPressed: () => _showPlaylistActions(context),
              backgroundColor: context.accent,
              foregroundColor: Colors.white,
              tooltip: 'Nueva lista o importar',
              child: const Icon(Icons.add),
            )
          : _tabController.index == _genresTab
          ? FloatingActionButton(
              heroTag: null,
              onPressed: () => showGenreFormDialog(context),
              backgroundColor: context.accent,
              foregroundColor: Colors.white,
              tooltip: 'Crear género',
              child: const Icon(Icons.add),
            )
          : null,
      body: TabBarView(
        controller: _tabController,
        children: const [
          SongsTab(),
          FavoritesTab(),
          PlaylistLibraryScreen(),
          GroupsTab(mode: GroupMode.artist),
          GroupsTab(mode: GroupMode.album),
          GroupsTab(mode: GroupMode.genre),
          GroupsTab(mode: GroupMode.source),
        ],
      ),
    );
  }
}
