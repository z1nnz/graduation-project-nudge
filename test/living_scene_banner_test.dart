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

  test('phones use portrait art that fills the scene, like the Web rooms', () {
    expect(livingUsesTall(const Size(390, 844)), isTrue);
    expect(livingUsesTall(const Size(800, 600)), isTrue);
    expect(livingUsesTall(const Size(1280, 800)), isFalse);
    // Slightly narrower than the art: cover, cropping a little off the sides.
    final cover = livingArtRect(const Size(390, 650), 2 / 3);
    expect(cover.height, 650);
    expect(cover.left, closeTo((390 - 650 * 2 / 3) / 2, 0.01));
    // Much wider than the art: contain at the top, blurred copy around it.
    final contain = livingArtRect(const Size(800, 500), 2 / 3);
    expect(contain.height, 500);
    expect(contain.left, closeTo(400 - 500 / 3, 0.01));
    expect(livingFullHeight(700, 16), 700 - 16 - livingPeek);
    expect(livingFullHeight(300, 16), 320);
    // Small drawn objects still get a 44 px target inside the box.
    final spot = livingPlace(
      const Rect.fromLTWH(0.9, 0.1, 0.05, 0.02),
      const Rect.fromLTWH(-20, 0, 430, 650),
      const Size(390, 650),
    );
    expect(spot.width, greaterThanOrEqualTo(44));
    expect(spot.height, greaterThanOrEqualTo(44));
    expect(spot.right, lessThanOrEqualTo(390));
  });

  testWidgets('on a phone the banner fills the screen with the tall art', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('好友')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              LivingSceneBanner(
                art: 'assets/scenes/town_plaza/plaza.webp',
                aspect: 1.5,
                tallArt: 'assets/scenes/town_plaza/plaza_tall.webp',
                title: '好友長椅',
                spots: [
                  LivingSpot(
                    id: 'bench',
                    label: '長椅',
                    rect: const Rect.fromLTWH(0.8, 0.7, 0.16, 0.16),
                    tallRect: const Rect.fromLTWH(0.67, 0.5, 0.25, 0.08),
                    revealsBelow: true,
                    onArrive: () => opened++,
                  ),
                ],
              ),
              for (var i = 0; i < 12; i++)
                SizedBox(height: 80, child: Text('好友 $i')),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    final scene = tester.getSize(
      find.byKey(const ValueKey('living-scene-tall')),
    );
    final viewport = 844 - kToolbarHeight;
    expect(scene.height, closeTo(viewport - 16 - livingPeek, 1));
    // The first item peeks in under the scene.
    expect(tester.getTopLeft(find.text('好友 0')).dy, lessThan(844));
    final bench = tester.getRect(
      find.byKey(const ValueKey('living-spot-bench')),
    );
    expect(bench.center.dy, greaterThan(scene.height * 0.4));
    await tester.tap(find.byKey(const ValueKey('living-spot-bench')));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 1));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(opened, 1);
    // It scrolled down so the list under the scene shows.
    expect(tester.getTopLeft(find.text('好友 0')).dy, lessThan(200));
  });

  testWidgets('on a wide screen the banner keeps the landscape art', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: const [
              LivingSceneBanner(
                art: 'assets/scenes/town_plaza/plaza.webp',
                aspect: 1.5,
                tallArt: 'assets/scenes/town_plaza/plaza_tall.webp',
                title: '廣場',
                spots: [],
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('living-scene-wide')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('living-scene-wide'))).height,
      340,
    );
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
