import 'package:flutter/material.dart';

import '../core/app_settings.dart';

class AccentOption {
  const AccentOption(this.name, this.color);
  final String name;
  final Color color;
}

/// Tema de la app: modo (sistema/claro/oscuro/AMOLED) y color de acento.
class AppThemeController extends ChangeNotifier {
  AppThemeController._();

  static final AppThemeController instance = AppThemeController._();

  static const List<AccentOption> accents = [
    AccentOption('Naranja', Color(0xFFFF5722)),
    AccentOption('Violeta', Color(0xFF7C4DFF)),
    AccentOption('Azul', Color(0xFF2979FF)),
    AccentOption('Turquesa', Color(0xFF00BFA5)),
    AccentOption('Verde', Color(0xFF2EB85C)),
    AccentOption('Dorado', Color(0xFFFFB300)),
    AccentOption('Rosa', Color(0xFFE91E63)),
    AccentOption('Rojo', Color(0xFFE53935)),
  ];

  static const Map<String, String> modeLabels = {
    'system': 'Sistema',
    'light': 'Claro',
    'dark': 'Oscuro',
    'amoled': 'AMOLED',
  };

  String _mode = AppSettings.instance.themeMode;
  int _accentIndex = AppSettings.instance.accentIndex;

  String get mode => _mode;
  int get accentIndex => _accentIndex.clamp(0, accents.length - 1);
  Color get accent => accents[accentIndex].color;

  ThemeMode get themeMode => switch (_mode) {
    'light' => ThemeMode.light,
    'dark' || 'amoled' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  Future<void> setMode(String value) async {
    if (!modeLabels.containsKey(value) || value == _mode) return;
    _mode = value;
    notifyListeners();
    await AppSettings.instance.setThemeMode(value);
  }

  Future<void> setAccent(int index) async {
    if (index == _accentIndex) return;
    _accentIndex = index;
    notifyListeners();
    await AppSettings.instance.setAccentIndex(index);
  }

  ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.light,
    ).copyWith(primary: accent, onPrimary: Colors.white);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      primaryColor: accent,
      scaffoldBackgroundColor: const Color(0xFFF9F9F9),
      cardColor: Colors.white,
      appBarTheme: AppBarTheme(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
      ),
      snackBarTheme: _snackBarTheme(
        background: const Color(0xFF2B2B2B),
        foreground: Colors.white,
      ),
    );
  }

  /// Avisos chicos y flotantes, no la barra ancha de Material.
  ///
  /// Un aviso es una confirmación ("listo, se agregó"), no algo que haya que
  /// leer: ocupa lo que mide su texto, se queda cerca del borde de abajo y se
  /// va solo. La duración va en `showNotice`, porque el tema no la define.
  static SnackBarThemeData _snackBarTheme({
    required Color background,
    required Color foreground,
  }) => SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    backgroundColor: background,
    contentTextStyle: TextStyle(color: foreground, fontSize: 13),
    elevation: 3,
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(22)),
    ),
    actionTextColor: Colors.white,
  );

  ThemeData dark() {
    final amoled = _mode == 'amoled';
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
    ).copyWith(primary: accent, onPrimary: Colors.white);
    final base = amoled ? Colors.black : const Color(0xFF121212);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: amoled
          ? scheme.copyWith(surface: Colors.black)
          : scheme,
      primaryColor: accent,
      scaffoldBackgroundColor: base,
      cardColor: amoled ? const Color(0xFF0B0B0B) : const Color(0xFF1F1F1F),
      canvasColor: base,
      appBarTheme: AppBarTheme(
        // Las barras llevan el color de acento, también en oscuro.
        backgroundColor: accent,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      snackBarTheme: _snackBarTheme(
        background: amoled ? const Color(0xFF1A1A1A) : const Color(0xFF2E2E2E),
        foreground: Colors.white,
      ),
    );
  }
}
