import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/screens/ai_assistant_page.dart';
import 'package:nudge/screens/commission_hall_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/disk_asset_bundle.dart';

const _tasks = [
  {'title': '完成 2 小時讀書', 'done': true},
  {'title': '步行超過 6000 步', 'done': false},
  {'title': '運動 30 分鐘', 'done': false},
];

Future<void> _pump(
  WidgetTester tester,
  Widget child,
  Size size, {
  bool still = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    DefaultAssetBundle(
      bundle: DiskAssetBundle(),
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: size, disableAnimations: still),
          child: child,
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final size in const [Size(390, 844), Size(1280, 800)]) {
    testWidgets(
      'commissions are pinned notes and the map is a path on ${size.width}px',
      (tester) async {
        await _pump(tester, const CommissionHallPage(tasks: _tasks), size);
        expect(find.byKey(const Key('hall-notes')), findsOneWidget);
        expect(find.text('步行超過 6000 步'), findsOneWidget);
        expect(
          find.byKey(const Key('note-stamp')),
          findsOneWidget,
          reason: 'the finished one is stamped',
        );
        final path =
            tester
                    .widget<CustomPaint>(find.byKey(const Key('hall-path')))
                    .painter!
                as AdventurePathPainter;
        expect(path.flags, 1);
        expect(path.steps, 3);
        expect(find.byKey(const Key('room-player')), findsOneWidget);
      },
    );
  }

  testWidgets('an answer becomes a note that can be pinned to the board', (
    tester,
  ) async {
    await _pump(
      tester,
      Scaffold(
        body: CommissionNote(
          text: '每天先讀 20 分鐘',
          onPin: () => PinnedNotes.add('每天先讀 20 分鐘'),
        ),
      ),
      const Size(390, 844),
    );
    await tester.tap(find.byKey(const Key('pin-note')));
    await tester.pump();
    expect(await PinnedNotes.load(), ['每天先讀 20 分鐘']);
    await _pump(
      tester,
      const CommissionHallPage(tasks: []),
      const Size(390, 844),
    );
    await tester.pump();
    expect(
      find.text('每天先讀 20 分鐘'),
      findsOneWidget,
      reason: 'pinned note shows on the board',
    );
  });

  testWidgets('阿紙 thinks with a question mark; reduced motion holds still', (
    tester,
  ) async {
    await _pump(
      tester,
      const Scaffold(body: ScrollThinking()),
      const Size(390, 844),
    );
    expect(find.text('阿紙在想…'), findsOneWidget);
    expect(find.text('?'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('阿紙在想…'), findsOneWidget);
  });
}
