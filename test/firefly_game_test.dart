import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/screens/firefly_game_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/disk_asset_bundle.dart';

Future<void> _pump(
  WidgetTester tester,
  Size size, {
  bool still = false,
  DateTime? now,
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
          child: FireflyGamePage(
            seed: 5,
            now: now ?? DateTime(2026, 11, 27, 12),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  test(
    'rules: only glowing fireflies are caught, combos chain, 45 seconds',
    () {
      final g = FireflyGame(3);
      final f = g.flies.first;
      while (!g.flyAt(f).lit) {
        g.step(10);
      }
      final (e1, p1) = g.catchAt(g.flyAt(f).at);
      expect(e1, 'catch');
      expect(p1, 10);
      expect(g.catchAt(const Offset(-40, -40)).$1, 'miss');
      expect(g.combo, 0);
      g.step(FireflyGame.durationMs);
      expect(g.done, isTrue);
      expect(g.catchAt(Offset.zero).$1, 'miss');
      expect(FireflyGame.grade(300), 'S');
      expect(FireflyGame.grade(0), 'C');
    },
  );

  test('three free plays a day, the day turns at 05:00', () async {
    SharedPreferences.setMockInitialValues({});
    final noon = DateTime(2026, 11, 27, 12);
    expect(await AppArcadePlays.left(noon), 3);
    await AppArcadePlays.spend(noon);
    expect(await AppArcadePlays.left(noon), 2);
    expect(
      await AppArcadePlays.left(DateTime(2026, 11, 28, 4)),
      2,
      reason: 'before 5am is still the same day',
    );
    expect(await AppArcadePlays.left(DateTime(2026, 11, 28, 6)), 3);
  });

  for (final size in const [Size(390, 844), Size(1280, 800)]) {
    testWidgets(
      'plays inside the App on ${size.width}px and ends with a result',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        await _pump(tester, size);
        await tester.pump();
        expect(find.textContaining('今天還能免費玩 3 次'), findsOneWidget);
        await tester.tap(find.byKey(const Key('firefly-start')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byKey(const Key('firefly-hud')), findsOneWidget);
        for (var i = 0; i < 10; i++) {
          await tester.tapAt(
            tester.getCenter(find.byKey(const Key('firefly-field'))),
          );
          await tester.pump(const Duration(milliseconds: 300));
        }
        await tester.pump(const Duration(seconds: 46));
        await tester.pump();
        expect(find.byKey(const Key('firefly-result')), findsOneWidget);
        expect(find.textContaining('今天還能免費玩 2 次'), findsOneWidget);
      },
    );
  }

  testWidgets('no plays left: the start button explains and stays off', (
    tester,
  ) async {
    final now = DateTime(2026, 11, 27, 12);
    SharedPreferences.setMockInitialValues({AppArcadePlays.dayKey(now): 3});
    await _pump(tester, const Size(390, 844), now: now, still: true);
    await tester.pump();
    final b = tester.widget<FilledButton>(
      find.byKey(const Key('firefly-start')),
    );
    expect(b.onPressed, isNull);
    expect(find.textContaining('用完了'), findsOneWidget);
  });
}
