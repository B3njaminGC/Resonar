import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/audio_service.dart';
import 'art_palette.dart';

/// Color dominante de la carátula de la canción que suena, compartido por
/// todo lo que se tiñe con ella (hoy, el minirreproductor).
///
/// Se calcula una sola vez por carátula y se avisa a quien escuche.
class ArtTint {
  ArtTint._();

  static final ArtTint instance = ArtTint._();

  /// `null` si no hay carátula o es casi gris.
  final ValueNotifier<Color?> color = ValueNotifier<Color?>(null);

  bool _started = false;
  Uint8List? _last;

  /// Empieza a seguir la carátula. Se puede llamar las veces que sea.
  void start() {
    if (_started) return;
    _started = true;
    AudioService().artworkBytesNotifier.addListener(_update);
    _update();
  }

  Future<void> _update() async {
    final bytes = AudioService().artworkBytesNotifier.value;
    if (identical(bytes, _last)) return;
    _last = bytes;
    if (bytes == null) {
      color.value = null;
      return;
    }
    final found = await ArtPalette.dominant(bytes);
    // Si mientras tanto cambió la carátula, este resultado ya no sirve.
    if (identical(bytes, _last)) color.value = found;
  }
}
