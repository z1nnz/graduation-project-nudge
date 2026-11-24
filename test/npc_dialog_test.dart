import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/character_catalog.dart';
import 'package:nudge/widgets/npc_dialog.dart';
import 'package:nudge/widgets/sprite_animation.dart';

const _lines = ['歡迎光臨！', '貨架上的東西都可以拿起來看看。'];

Future<void> _open(
  WidgetTester tester, {
  bool still = false,
  List<NpcDialogAction> actions = const [],
  double textScale = 1,
}) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: still,
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => NpcDialog.show(
                context,
                speaker: GameCharacters.chestnut,
                lines: _lines,
                actions: actions,
              ),
              child: const Text('talk'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('talk'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

NpcDialogState _dialog(WidgetTester t) =>
    t.state<NpcDialogState>(find.byType(NpcDialog));

Future<void> _tapBox(WidgetTester t) async {
  await t.tap(
    find.byKey(const ValueKey('npc-dialog-box')),
    warnIfMissed: false,
  );
  await t.pump();
}

void main() {
  testWidgets('types the line, finishes on tap, then goes on and closes', (
    tester,
  ) async {
    await _open(tester);
    expect(find.text('栗子'), findsOneWidget);
    expect(_dialog(tester).typing, isTrue);
    final talk = tester.widget<CharacterSprite>(find.byType(CharacterSprite));
    expect(talk.animation, CharacterAnimation.talk);

    await _tapBox(tester); // finish typing
    expect(_dialog(tester).typing, isFalse);
    expect(find.text(_lines[0]), findsWidgets);
    expect(find.text('▼'), findsOneWidget);
    expect(
      tester.widget<CharacterSprite>(find.byType(CharacterSprite)).animation,
      CharacterAnimation.idle,
    );

    await _tapBox(tester); // next line
    expect(_dialog(tester).line, 1);
    await tester.pump(const Duration(seconds: 2));
    expect(_dialog(tester).typing, isFalse, reason: 'typed out by itself');
    expect(find.text('▼'), findsNothing, reason: 'last line');

    await _tapBox(tester); // close
    await tester.pumpAndSettle();
    expect(find.byType(NpcDialog), findsNothing);
  });

  testWidgets('reduced motion shows each whole line at once', (tester) async {
    await _open(tester, still: true);
    expect(_dialog(tester).typing, isFalse);
    expect(find.text(_lines[0]), findsWidgets);
    await _tapBox(tester);
    expect(_dialog(tester).typing, isFalse);
    expect(find.text(_lines[1]), findsWidgets);
  });

  testWidgets('screen readers hear the speaker and the whole line', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _open(tester);
    expect(find.bySemanticsLabel('栗子：${_lines[0]}'), findsOneWidget);
    expect(find.bySemanticsLabel('關閉對話'), findsWidgets);
    final close = tester.getSize(find.byIcon(Icons.close).hitTestable());
    expect(close.width, lessThanOrEqualTo(44));
    expect(
      tester.getSize(
        find
            .ancestor(
              of: find.byIcon(Icons.close),
              matching: find.byType(SizedBox),
            )
            .first,
      ),
      const Size(44, 44),
    );
    handle.dispose();
  });

  testWidgets('actions appear after the last line and close the box', (
    tester,
  ) async {
    var went = 0;
    await _open(tester, actions: [NpcDialogAction('去委託所', () => went++)]);
    expect(find.text('去委託所'), findsNothing);
    await _tapBox(tester);
    await _tapBox(tester);
    await _tapBox(tester);
    expect(find.text('去委託所'), findsOneWidget);
    await _tapBox(tester); // does not close while there is a choice
    expect(find.byType(NpcDialog), findsOneWidget);
    await tester.tap(find.text('去委託所'));
    await tester.pumpAndSettle();
    expect(went, 1);
    expect(find.byType(NpcDialog), findsNothing);
  });

  testWidgets('the close button works mid-line', (tester) async {
    await _open(tester);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.byType(NpcDialog), findsNothing);
  });

  testWidgets('fits a 360 px screen at 1.15x text', (tester) async {
    await _open(tester, textScale: 1.15);
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });
}
