import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/character_catalog.dart';
import 'package:nudge/widgets/living_world/living_scene_banner.dart';

Widget _host(Widget child, {bool reduced = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(
      size: const Size(400, 800),
      disableAnimations: reduced,
    ),
    child: Scaffold(body: ListView(children: [child])),
  ),
);

void main() {
  test('the companion faces the way it walks', () {
    expect(
      livingWalkAnimation(const Offset(0.5, 0.8), const Offset(0.1, 0.7)),
      CharacterAnimation.walkLeft,
    );
    expect(
      livingWalkAnimation(const Offset(0.5, 0.8), const Offset(0.55, 0.3)),
      CharacterAnimation.walkUp,
    );
    expect(livingWalkDuration(200, reduced: true), Duration.zero);
    expect(livingBannerHeight(390, 1.5, 220), 260);
    expect(livingBannerHeight(1200, 1.5, 220), 340);
    expect(livingBannerHeight(390, null, 220), 220);
    expect(livingWalkDuration(10, reduced: false).inMilliseconds, 280);
    expect(livingStandPoint(const Rect.fromLTWH(0.2, 0.2, 0.2, 0.9)).dy, 0.94);
  });

  testWidgets('tapping a spot walks there, changes it, then opens it', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var opened = 0;
    await tester.pumpWidget(
      _host(
        LivingSceneBanner(
          art: 'assets/scenes/town_plaza/plaza.webp',
          title: '好友長椅',
          spots: [
            LivingSpot(
              id: 'bench',
              label: '長椅',
              rect: const Rect.fromLTWH(0.05, 0.3, 0.3, 0.3),
              onArrive: () => opened++,
            ),
          ],
        ),
      ),
    );
    expect(find.text('好友長椅'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.label == '長椅' &&
            w.properties.button == true,
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('living-spot-bench')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(opened, 0, reason: 'still walking');
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 1));
    expect(opened, 1);
    await tester.pump(const Duration(seconds: 2));
    semantics.dispose();
  });

  testWidgets('reduced motion opens the spot without the walk', (tester) async {
    var opened = 0;
    await tester.pumpWidget(
      _host(
        LivingSceneBanner(
          art: 'assets/scenes/town_plaza/plaza.webp',
          title: '廣場',
          spots: [
            LivingSpot(
              id: 'post',
              label: '郵筒',
              rect: const Rect.fromLTWH(0.6, 0.3, 0.3, 0.3),
              onArrive: () => opened++,
            ),
          ],
        ),
        reduced: true,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('living-spot-post')));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    expect(opened, 1);
    await tester.pump(const Duration(seconds: 2));
  });
}
