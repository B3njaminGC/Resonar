import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/audio_service.dart';
import '../../library/genre_store.dart';
import '../../library/track_index.dart';
import 'widgets/track_tile.dart';
import '../../theme/accent.dart';

/// Búsqueda dentro de la biblioteca (título, artista, álbum o nombre de archivo).
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final AudioService _audio = AudioService();
  final TrackIndex _index = TrackIndex.instance;
  final GenreStore _genres = GenreStore.instance;
  final TextEditingController _controller = TextEditingController();

  /// Lo que se busca, ya en minúsculas, una entrada por canción y en el mismo
  /// orden que [_tracks]. Se arma una sola vez por biblioteca y no en cada
  /// tecla: antes cada letra recorría todas las canciones llamando cinco veces
  /// a `toLowerCase` y dos veces al almacén de géneros, y en una biblioteca
  /// grande eso alcanzaba para que la música se trabara un instante.
  List<String> _haystack = const [];
  List<TrackInfo> _tracks = const [];

  /// Resultados visibles. Se recalculan cuando el texto se queda quieto.
  List<TrackInfo> _results = const [];

  Timer? _debounce;

  static const Duration _typingPause = Duration(milliseconds: 180);

  @override
  void initState() {
    super.initState();
    _rebuildHaystack();
    _applyQuery();
    _index.addListener(_onLibraryChanged);
    _genres.addListener(_onLibraryChanged);
    _controller.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onQueryChanged);
    _index.removeListener(_onLibraryChanged);
    _genres.removeListener(_onLibraryChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onLibraryChanged() {
    _rebuildHaystack();
    if (mounted) setState(_applyQuery);
  }

  void _rebuildHaystack() {
    final tracks = _index.tracks;
    _tracks = tracks;
    _haystack = [
      for (final track in tracks)
        searchTextOf(
          title: track.title,
          fileName: titleFromPath(track.path),
          artist: track.artist,
          album: track.album,
          genre: track.genre,
        ),
    ];
  }

  /// Mientras la persona escribe no se filtra nada: se espera a que suelte el
  /// teclado un instante. Así una palabra de ocho letras filtra una vez y no
  /// ocho.
  void _onQueryChanged() {
    _debounce?.cancel();
    _debounce = Timer(_typingPause, () {
      if (mounted) setState(_applyQuery);
    });
  }

  void _applyQuery() {
    final query = _controller.text.trim();
    if (query.isEmpty) {
      _results = _tracks;
      return;
    }
    _results = [
      for (var i = 0; i < _tracks.length; i++)
        if (matchesSearch(_haystack[i], query)) _tracks[i],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Buscar por título, artista o álbum…',
                prefixIcon: Icon(Icons.search, color: context.accent),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _controller,
                  builder: (context, value, _) => value.text.isEmpty
                      ? const SizedBox.shrink()
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: _controller.clear,
                        ),
                ),
                filled: true,
                fillColor: isDark ? const Color(0xFF1F1F1F) : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: _results.isEmpty
                ? const Center(
                    child: Text(
                      'No se encontraron canciones con ese criterio.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _results.length,
                    itemExtent: 72,
                    itemBuilder: (context, i) => TrackTile(
                      track: _results[i],
                      onTap: () => _audio.setPlaylistAndPlay(
                        [for (final track in _results) track.file],
                        i,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
