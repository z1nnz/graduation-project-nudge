import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/theme/app_ui.dart';
import 'package:nudge/theme/game_ui.dart';

Widget _wrap(Widget child, {Brightness brightness = Brightness.light}) =>
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(
        body: GameBackground(child: Center(child: child)),
      ),
    );

void main() {
  testWidgets('game button reports taps and is disabled without a handler', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _wrap(
        Column(
          children: [
            GameButton(label: '接下委託', onPressed: () => taps++),
            const GameButton(label: '已完成', onPressed: null),
          ],
        ),
      ),
    );
    await tester.tap(find.text('接下委託'));
    await tester.tap(find.text('已完成'));
    expect(taps, 1);
    final semantics = tester.getSemantics(find.text('已完成'));
    expect('${semantics.flagsCollection.isEnabled}', contains('isFalse'));
  });

  testWidgets('panel shows its title and child in light and dark', (
    tester,
  ) async {
    for (final b in Brightness.values) {
      await tester.pumpWidget(
        _wrap(
          const GamePanel(title: '今日委託', child: Text('讀書 25 分')),
          brightness: b,
        ),
      );
      expect(find.text('今日委託'), findsOneWidget);
      expect(find.text('讀書 25 分'), findsOneWidget);
    }
  });

  testWidgets('chip tones are distinct', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const Row(
          children: [
            GameChip(label: '進行中', tone: GameTone.gold),
            GameChip(label: '完成', tone: GameTone.green),
          ],
        ),
      ),
    );
    Color fill(String label) =>
        (tester
                    .widget<Container>(
                      find
                          .ancestor(
                            of: find.text(label),
                            matching: find.byType(Container),
                          )
                          .first,
                    )
                    .decoration
                as BoxDecoration)
            .color!;
    expect(fill('進行中'), isNot(fill('完成')));
  });

  test('every app card gets the wooden frame', () {
    final shape = AppUI.cardShape() as RoundedRectangleBorder;
    expect(shape.side.width, 2);
    expect(shape.side.style, BorderStyle.solid);
  });

  testWidgets('dialogs look like wooden game panels', (tester) async {
    for (final dark in [false, true]) {
      final theme = GameTheme.dialog(dark: dark);
      final shape = theme.shape! as RoundedRectangleBorder;
      expect(shape.side.width, 4);
      expect(theme.titleTextStyle?.fontFamily, 'Cubic11');
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            dialogTheme: theme,
            elevatedButtonTheme: GameTheme.primaryButton(),
          ),
          home: const AlertDialog(
            title: Text('提前結束'),
            actions: [ElevatedButton(onPressed: null, child: Text('好'))],
          ),
        ),
      );
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(Material),
            )
            .first,
      );
      expect((material.shape! as RoundedRectangleBorder).side.width, 4);
    }
    final gold = GameTheme.primaryButton().style!.backgroundColor!.resolve({});
    expect(gold, GamePalette.gold);
    final wood = GameTheme.secondaryButton(
      dark: false,
    ).style!.foregroundColor!.resolve({});
    expect(wood, const Color(0xFF8A5A34));
  });
}
