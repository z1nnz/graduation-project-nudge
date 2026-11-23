import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/adventure_log.dart';
import 'package:nudge/models/avatar_profile.dart';
import 'package:nudge/screens/adventure_log_page.dart';

void main() {
  testWidgets('the week reads like a page of an adventure journal', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var stats = 0;
    const log = AdventureLog([
      AdventureDay('2026-11-17', 0, 0),
      AdventureDay('2026-11-18', 30, 1),
      AdventureDay('2026-11-19', 0, 0),
      AdventureDay('2026-11-20', 100, 4), // Friday
      AdventureDay('2026-11-21', 0, 0),
      AdventureDay('2026-11-22', 0, 0),
      AdventureDay('2026-11-23', 50, 2),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: AdventureLogPage(
          log: log,
          profile: AvatarProfile.initial(),
          onOpenStatistics: () => stats++,
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('冒險日誌'), findsOneWidget);
    expect(find.text('11/17 – 11/23'), findsOneWidget);
    expect(find.text('3 小時'), findsOneWidget); // 180 minutes
    expect(find.text('7 件'), findsOneWidget);
    expect(find.text('3 天'), findsOneWidget);
    expect(find.text('最棒的一天：週五 100 分鐘'), findsOneWidget);
    expect(find.textContaining('3 天一起前進'), findsOneWidget);

    // Taller book stacks for more focus; today is marked.
    final tall = tester.getSize(find.byKey(const Key('log-books-3')));
    final short = tester.getSize(find.byKey(const Key('log-books-1')));
    final none = tester.getSize(find.byKey(const Key('log-books-0')));
    expect(tall.height, greaterThan(short.height));
    expect(short.height, greaterThan(none.height));
    expect(find.byKey(const Key('log-today')), findsOneWidget);

    await tester.tap(find.text('詳細統計'));
    expect(stats, 1);
  });
}
