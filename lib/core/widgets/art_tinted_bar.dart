import 'package:flutter/material.dart';

/// Fondo de una barra que se tiñe con el color de la carátula.
///
/// Con [tint] dibuja un degradado de izquierda a derecha (del color a [base])
/// y anima el cambio. Con `null` queda lisa, del color [base].
///
/// Ojo: `TweenAnimationBuilder` no admite un `end` nulo (revienta y deja la
/// pantalla en gris), así que sin color se anima hacia [base] en vez de hacia
/// "nada". Hay una prueba que mira esto.
class ArtTintedBar extends StatelessWidget {
  const ArtTintedBar({
    super.key,
    required this.tint,
    required this.base,
    required this.dark,
    required this.height,
    required this.child,
  });

  final Color? tint;
  final Color base;
  final bool dark;
  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: tint ?? base),
      duration: const Duration(milliseconds: 600),
      builder: (context, color, child) {
        final tinted = Color.alphaBlend(
          (color ?? base).withValues(alpha: dark ? 0.5 : 0.32),
          base,
        );
        // Sin carátula "tinted" y "base" coinciden: queda lisa. (Mezclar el
        // propio color de base con alfa no cambia nada.)
        final start = (color == null || color == base) ? base : tinted;
        return Material(
          color: base,
          elevation: 8,
          // Ink y no un Container: así el toque sigue dibujando su ondita por
          // encima del degradado.
          child: Ink(
            height: height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [start, base],
              ),
            ),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
