import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/screens/garden_park_pages.dart';
import 'package:nudge/widgets/world_life.dart';

void main() {
  testWidgets('the park map lists its rides as labelled buttons', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: const ParkScenePage(),
      ),
    );
    await tester.pump();
    for (final label in [
      '摩天輪：接星星',
      '撈魚攤：星光釣魚',
      '舞台：鐘塔節奏',
      '旋轉木馬：記憶配對',
      '跳房子：跳一跳',
      '螢火蟲燈：在 App 裡玩螢火蟲燈籠',
    ]) {
      expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
    }
    expect(ParkScenePage.arcade.toString(), endsWith('/arcade.html'));
    semantics.dispose();
  });

  test('the garden dresses for the season', () {
    expect(GardenSeason.of(DateTime(2026, 4, 1)), GardenSeason.spring);
    expect(GardenSeason.of(DateTime(2026, 7, 1)).fall, WorldFall.fireflies);
    expect(GardenSeason.of(DateTime(2026, 10, 1)).label, '秋楓');
    expect(GardenSeason.of(DateTime(2026, 1, 1)).fall, WorldFall.snow);
  });

  for (final season in GardenSeason.values) {
    testWidgets('critters paint in ${season.name} on phone and desktop', (
      tester,
    ) async {
      for (final size in const [Size(390, 844), Size(1280, 800)]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: SizedBox.fromSize(
                size: size / 2,
                child: CustomPaint(
                  painter: GardenLifePainter(frame: 30, season: season),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      }
      expect(
        GardenLifePainter(
          frame: 1,
          season: season,
        ).shouldRepaint(GardenLifePainter(frame: 2, season: season)),
        isTrue,
      );
    });
  }
}
