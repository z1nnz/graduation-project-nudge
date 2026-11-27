import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/screens/constellation_game_page.dart';
import 'package:nudge/screens/firefly_game_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/disk_asset_bundle.dart';

void main() {
  test('rules: watch, pick in order, a round adds a star, two slips end', () {
    final g = ConstellationGame(3);
    expect(g.stars.length, ConstellationGame.start);
    expect(g.pick(g.order.first), 'wait');
    g.step(ConstellationGame.showMs * (g.order.length + 1));
    for (var i = 0; i < g.order.length - 1; i++) {
      expect(g.pick(g.order[i]), 'link');
    }
    expect(g.pick(g.order.last), 'complete');
    expect(g.round, 2);
    expect(g.stars.length, ConstellationGame.start + 1);
    g.step(ConstellationGame.showMs * (g.order.length + 1));
    final wrong = g.order[1];
    expect(g.pick(wrong), 'slip');
    g.step(ConstellationGame.showMs * (g.order.length + 1));
    expect(g.pick(wrong), 'over');
    expect(g.done, isTrue);
    expect(g.starAt(g.stars.first + const Offset(2, 0)), 0);
    expect(ConstellationGame.grade(50), 'S');
  });

  for (final size in const [Size(390, 844), Size(1280, 800)]) {
    testWidgets(
      'plays inside the App on ${size.width}px and shares the daily plays',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final now = DateTime(2026, 11, 27, 12);
        SharedPreferences.setMockInitialValues({AppArcadePlays.dayKey(now): 1});
        await tester.pumpWidget(
          DefaultAssetBundle(
            bundle: DiskAssetBundle(),
            child: MaterialApp(home: ConstellationGamePage(seed: 3, now: now)),
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(
          find.textContaining('今天還能免費玩 2 次'),
          findsOneWidget,
          reason: 'one play already spent on fireflies',
        );
        await tester.tap(find.byKey(const Key('constellation-start')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byKey(const Key('constellation-hud')), findsOneWidget);
        await tester.pump(const Duration(seconds: 91));
        await tester.pump();
        expect(find.byKey(const Key('constellation-result')), findsOneWidget);
      },
    );
  }
}
