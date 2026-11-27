import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/collection_book.dart';
import 'package:nudge/models/daily_summary.dart';
import 'package:nudge/screens/collection_book_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/disk_asset_bundle.dart';

DailySummary _day(String date, int focus) => DailySummary(
  date: date,
  completedTasks: 0,
  totalTasks: 0,
  focusMinutes: focus,
  sleepHours: 0,
  steps: 0,
  exerciseMinutes: 0,
  disciplineScore: 0,
);

Future<void> _pump(
  WidgetTester tester,
  Size size,
  List<DailySummary> days, {
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
          child: CollectionBookPage(summaries: days),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _step(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

void main() {
  for (final size in const [Size(390, 844), Size(1280, 800)]) {
    testWidgets('all 24 keepsakes sit in the glass case on ${size.width}px', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await _pump(tester, size, const []);
      for (final k in CollectionBook.catalog) {
        expect(
          find.byKey(Key('keepsake-${k.id}')),
          findsOneWidget,
          reason: k.id,
        );
      }
      expect(find.textContaining('已收藏 0／24'), findsOneWidget);
    });
  }

  testWidgets('a new keepsake arrives in a box, flies in and is remembered', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await _pump(tester, const Size(390, 844), [
      _day('2026-11-20', 30),
    ], still: false);
    await tester.pump();
    expect(find.byKey(const Key('collection-gift-box')), findsOneWidget);
    expect(find.textContaining('新收藏'), findsOneWidget);
    await _step(tester);
    expect(find.byKey(const Key('collection-arriving')), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(CollectionBookPage.seenKey), hasLength(1));
  });

  testWidgets('seen keepsakes do not arrive again; tapping shows the label', (
    tester,
  ) async {
    final book = CollectionBook.fromSummaries([_day('2026-11-20', 30)]);
    SharedPreferences.setMockInitialValues({
      CollectionBookPage.seenKey: [book.drops.single.item.id],
    });
    await _pump(tester, const Size(390, 844), [_day('2026-11-20', 30)]);
    await _step(tester);
    expect(find.byKey(const Key('collection-gift-box')), findsNothing);
    await tester.tap(find.byKey(Key('keepsake-${book.drops.single.item.id}')));
    await tester.pump();
    expect(find.textContaining('第一次撿到：2026-11-20'), findsOneWidget);
  });

  testWidgets('reduced motion: the arrival is instant and the wall is still', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await _pump(tester, const Size(390, 844), [_day('2026-11-22', 130)]);
    await _step(tester);
    expect(find.byKey(const Key('collection-arriving')), findsNothing);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
