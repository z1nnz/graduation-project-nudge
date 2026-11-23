import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/avatar_profile.dart';
import 'package:nudge/models/cabin_layout.dart';
import 'package:nudge/models/cabin_presentation.dart';
import 'package:nudge/widgets/immersive_cabin.dart';

CabinPresentation _presentation() => const CabinPresentation(
  bookStage: 2,
  plantStage: 2,
  badgeCount: 2,
  showGlobe: false,
  globeGlowing: false,
  decor: {'rug': 0, 'curtain': 0, 'lamp': 0},
  bubbleText: '完成 2 小時讀書',
  questCount: 3,
);

Future<Map<String, int>> _pump(
  WidgetTester tester, {
  bool still = false,
}) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final opened = <String, int>{};
  void hit(String k) => opened[k] = (opened[k] ?? 0) + 1;
  final layout = await CabinLayout.load(rootBundle);
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(412, 915),
          disableAnimations: still,
        ),
        child: ImmersiveHome(
          layout: layout,
          presentation: _presentation(),
          profile: AvatarProfile.initial(),
          level: 7,
          coins: 128,
          streak: 6,
          now: DateTime(2026, 11, 23, 12),
          onOpenQuests: () => hit('quests'),
          onOpenDesk: () => hit('desk'),
          onOpenRecords: () => hit('records'),
          onOpenBadges: () => hit('badges'),
          onOpenCompanions: () => hit('companions'),
          onOpenRooms: () => hit('rooms'),
          onOpenCharacter: () => hit('character'),
          onOpenDecor: () => hit('decor'),
          onOpenBackpack: () => hit('backpack'),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  return opened;
}

void main() {
  setUp(rootBundle.clear);

  testWidgets('room objects open their features', (tester) async {
    late Map<String, int> opened;
    await tester.runAsync(() async => opened = await _pump(tester));
    for (final entry in {
      'cabin-quest-board': 'quests',
      'cabin-desk': 'desk',
      'cabin-shelf': 'records',
      'cabin-badges': 'badges',
      'cabin-door-family': 'companions',
      'cabin-door-group': 'rooms',
      'cabin-backpack': 'backpack',
      'cabin-decor': 'decor',
    }.entries) {
      // Tap near the top-right of each object: the companion may stand in
      // front of its centre, and tapping the companion greets it instead.
      final r = tester.getRect(find.byKey(Key(entry.key)));
      final round = entry.key == 'cabin-backpack' || entry.key == 'cabin-decor';
      await tester.tapAt(round ? r.center : Offset(r.right - 6, r.top + 6));
      expect(opened[entry.value], 1, reason: entry.key);
    }
  });

  testWidgets('the HUD shows level, coins and streak without cards', (
    tester,
  ) async {
    await tester.runAsync(() => _pump(tester));
    expect(find.text('7'), findsOneWidget);
    expect(find.text('◎ 128'), findsOneWidget);
    expect(find.text('🔥 6'), findsOneWidget);
    expect(find.byType(Card), findsNothing);
    expect(find.text('完成 2 小時讀書'), findsOneWidget);
  });

  testWidgets('tapping the floor walks the companion there', (tester) async {
    await tester.runAsync(() => _pump(tester));
    final before = tester.getCenter(find.byKey(const Key('cabin-companion')));
    await tester.tapAt(const Offset(80, 640));
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final after = tester.getCenter(find.byKey(const Key('cabin-companion')));
    expect(after.dx, lessThan(before.dx - 20));
  });

  testWidgets('poking the companion cheers; long press opens the character', (
    tester,
  ) async {
    late Map<String, int> opened;
    await tester.runAsync(() async => opened = await _pump(tester));
    await tester.tap(find.byKey(const Key('cabin-companion')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('pose-effect-cheer')), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.longPress(find.byKey(const Key('cabin-companion')));
    expect(opened['character'], 1);
  });

  testWidgets('reduced motion keeps the cabin still', (tester) async {
    await tester.runAsync(() => _pump(tester, still: true));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.hasRunningAnimations, isFalse);
  });
}
