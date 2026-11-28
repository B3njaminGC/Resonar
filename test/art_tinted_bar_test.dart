import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_music_app/core/widgets/art_tinted_bar.dart';

Widget _bar(Color? tint) => MaterialApp(
  home: Scaffold(
    body: ArtTintedBar(
      tint: tint,
      base: const Color(0xFF1F1F1F),
      dark: true,
      height: 68,
      child: const Text('suena algo'),
    ),
  ),
);

void main() {
  testWidgets('sin color de carátula se dibuja sin romper', (tester) async {
    await tester.pumpWidget(_bar(null));
    expect(find.text('suena algo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('con color de carátula se dibuja sin romper', (tester) async {
    await tester.pumpWidget(_bar(Colors.deepOrange));
    await tester.pumpAndSettle();
    expect(find.text('suena algo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pasar de sin color a con color y volver no rompe', (
    tester,
  ) async {
    await tester.pumpWidget(_bar(null));
    await tester.pumpWidget(_bar(Colors.teal));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(_bar(null));
    await tester.pumpAndSettle();
    expect(find.text('suena algo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
