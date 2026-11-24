import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/theme/game_ui.dart';

void main() {
  test('every app bar is a wooden title bar with the pixel font', () {
    final bar = GameTheme.appBar();
    expect(bar.backgroundColor, const Color(0xFF5A3826));
    expect(bar.foregroundColor, const Color(0xFFFFE6A3));
    expect(bar.titleTextStyle?.fontFamily, 'Cubic11');
  });

  test('all platforms use the same soft "door" page transition', () {
    final t = GameTheme.pageTransitions();
    for (final platform in TargetPlatform.values) {
      expect(t.builders[platform], isA<GameDoorTransitionsBuilder>());
    }
  });

  test('tabs, chips and inputs follow the wood and gold palette', () {
    expect(GameTheme.tabBar().indicatorColor, GamePalette.gold);
    expect(
      GameTheme.chips(dark: false).side?.color,
      GamePalette.light.panelBorder,
    );
    final input = GameTheme.inputs(dark: false);
    expect(
      (input.enabledBorder as OutlineInputBorder).borderSide.color,
      GamePalette.light.panelBorder,
    );
  });

  testWidgets('pushing a page fades and settles it in', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(pageTransitionsTheme: GameTheme.pageTransitions()),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const Text('next')),
            ),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final fade = tester.widget<FadeTransition>(
      find
          .ancestor(
            of: find.text('next'),
            matching: find.byType(FadeTransition),
          )
          .first,
    );
    expect(fade.opacity.value, inExclusiveRange(0.0, 1.0));
    await tester.pumpAndSettle();
    expect(find.text('next'), findsOneWidget);
  });
}
