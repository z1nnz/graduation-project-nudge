import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nudge/models/avatar_profile.dart';
import 'package:nudge/models/cabin_layout.dart';
import 'package:nudge/models/cabin_presentation.dart';
import 'package:nudge/widgets/immersive_cabin.dart';

CabinPresentation _presentation({bool device = false, bool focusing = false}) =>
    CabinPresentation(
      bookStage: 2,
      plantStage: 2,
      badgeCount: 2,
      showGlobe: device,
      globeGlowing: device && focusing,
      decor: {'rug': 0, 'curtain': 0, 'lamp': 0},
      bubbleText: '完成 2 小時讀書',
      questCount: 3,
    );

Future<Map<String, int>> _pump(
  WidgetTester tester, {
  bool still = false,
  bool device = false,
  bool focusing = false,
  bool tour = false,
  int level = 7,
  String account = 'me',
  int socialUnread = 0,
  int parcels = 0,
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
          presentation: _presentation(device: device, focusing: focusing),
          profile: AvatarProfile.initial(),
          level: level,
          accountKey: account,
          socialUnread: socialUnread,
          parcelCount: parcels,
          onOpenParcel: () => hit('parcel'),
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
          onOpenMenu: () => hit('menu'),
          onOpenShop: () => hit('shop'),
          onOpenDevice: () => hit('device'),
          showTour: tour,
          onTourDone: () => hit('tourDone'),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  return opened;
}

void main() {
  // The cabin reads the player's look and pet from this device.
  setUp(() => SharedPreferences.setMockInitialValues({}));

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
      'cabin-menu': 'menu',
      'cabin-decor': 'decor',
    }.entries) {
      // Tap near the top-right of each object: the companion may stand in
      // front of its centre, and tapping the companion greets it instead.
      final r = tester.getRect(find.byKey(Key(entry.key)));
      final round = entry.key == 'cabin-menu' || entry.key == 'cabin-decor';
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
    // The bubble types its line out.
    expect(find.text('完成 2 小時讀書'), findsNothing);
    await tester.pump(const Duration(seconds: 2));
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

  testWidgets('cabin 2.0: the lamp dims the room and the plant gets watered', (
    tester,
  ) async {
    await tester.runAsync(() => _pump(tester));
    expect(find.byKey(const Key('cabin-lamp-off')), findsNothing);
    await tester.tap(find.byKey(const Key('cabin-lamp')));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byKey(const Key('cabin-lamp-off')), findsOneWidget);
    expect(find.textContaining('關燈了'), findsOneWidget);
    await tester.tap(find.byKey(const Key('cabin-lamp')));
    await tester.pump();
    expect(find.byKey(const Key('cabin-lamp-off')), findsNothing);

    final before = tester.getCenter(find.byKey(const Key('cabin-companion')));
    await tester.tap(find.byKey(const Key('cabin-plant')));
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final after = tester.getCenter(find.byKey(const Key('cabin-companion')));
    expect(
      after.dx,
      lessThan(before.dx),
      reason: 'the companion walks to the plant',
    );
    expect(find.textContaining('澆點水'), findsOneWidget);
  });

  testWidgets('poking the companion cheers; long press opens the character', (
    tester,
  ) async {
    late Map<String, int> opened;
    await tester.runAsync(() async => opened = await _pump(tester));
    await tester.tap(find.byKey(const Key('cabin-companion')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('pose-effect-cheer')), findsOneWidget);
    expect(find.byKey(const Key('companion-hearts')), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(const Key('companion-hearts')), findsNothing);
    await tester.longPress(find.byKey(const Key('cabin-companion')));
    expect(opened['character'], 1);
  });

  testWidgets('a parcel waits by the door only when one arrived', (
    tester,
  ) async {
    late Map<String, int> opened;
    await tester.runAsync(() async => opened = await _pump(tester));
    expect(find.byKey(const Key('cabin-parcel')), findsNothing);
    await tester.runAsync(() async => opened = await _pump(tester, parcels: 2));
    expect(find.byKey(const Key('cabin-parcel')), findsOneWidget);
    expect(find.text('2'), findsWidgets);
    await tester.tap(find.byKey(const Key('cabin-parcel')));
    expect(opened['parcel'], 1);
  });

  testWidgets('tapping the window opens the weather city picker', (
    tester,
  ) async {
    await tester.runAsync(() => _pump(tester));
    final r = tester.getRect(find.byKey(const Key('cabin-window')));
    await tester.tapAt(r.topCenter + const Offset(0, 8));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('窗外的天氣'), findsWidgets);
    expect(find.byKey(const Key('weather-city-台北')), findsOneWidget);
  });

  testWidgets('reduced motion keeps the cabin still', (tester) async {
    await tester.runAsync(() => _pump(tester, still: true));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('object signs appear only while pressing', (tester) async {
    await tester.runAsync(() => _pump(tester));
    expect(find.text('委託 3'), findsNothing);
    final r = tester.getRect(find.byKey(const Key('cabin-quest-board')));
    final gesture = await tester.startGesture(Offset(r.right - 6, r.top + 6));
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('委託 3'), findsOneWidget);
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('委託 3'), findsNothing);
  });

  testWidgets('walking kicks up dust', (tester) async {
    await tester.runAsync(() => _pump(tester));
    await tester.tapAt(const Offset(80, 640));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byKey(const Key('cabin-dust')), findsWidgets);
  });

  testWidgets('the hotbar opens the five main features', (tester) async {
    late Map<String, int> opened;
    await tester.runAsync(() async => opened = await _pump(tester));
    for (final entry in {
      'hotbar-quests': ('委託', 'quests'),
      'hotbar-rooms': ('自律房', 'rooms'),
      'hotbar-focus': ('專注', 'desk'),
      'hotbar-social': ('社交', 'companions'),
      'hotbar-shop': ('商城', 'shop'),
    }.entries) {
      final slot = find.byKey(Key(entry.key));
      expect(
        find.descendant(of: slot, matching: find.text(entry.value.$1)),
        findsOneWidget,
        reason: entry.key,
      );
      await tester.tap(slot);
      expect(opened[entry.value.$2], 1, reason: entry.key);
    }
    // Open quests are counted on the quest slot.
    expect(
      find.descendant(
        of: find.byKey(const Key('hotbar-quests')),
        matching: find.text('3'),
      ),
      findsOneWidget,
    );
    // Focus is the main action, so its slot is the biggest.
    final focus = tester.getSize(find.byKey(const Key('hotbar-focus')));
    final shop = tester.getSize(find.byKey(const Key('hotbar-shop')));
    expect(focus.height, greaterThan(shop.height));
  });

  testWidgets('the globe appears and opens the device once one is linked', (
    tester,
  ) async {
    late Map<String, int> opened;
    await tester.runAsync(() async => opened = await _pump(tester));
    expect(find.byKey(const Key('cabin-globe')), findsNothing);
    await tester.runAsync(
      () async => opened = await _pump(tester, device: true),
    );
    final r = tester.getRect(find.byKey(const Key('cabin-globe')));
    await tester.tapAt(Offset(r.right - 3, r.top + 3));
    expect(opened['device'], 1);
  });

  testWidgets('when the desk device focuses, the cabin companion reads too', (
    tester,
  ) async {
    await tester.runAsync(() => _pump(tester, device: true, focusing: true));
    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byKey(const Key('sprite-read')), findsOneWidget);
    expect(find.text('桌上的我也在專注，一起加油！'), findsOneWidget);
  });

  testWidgets('first visit: the companion walks the user through the cabin', (
    tester,
  ) async {
    late Map<String, int> opened;
    await tester.runAsync(() async => opened = await _pump(tester, tour: true));
    await tester.pump(const Duration(seconds: 3));
    expect(find.byKey(const Key('cabin-tour')), findsOneWidget);
    expect(find.textContaining('我是你的夥伴'), findsOneWidget);
    expect(find.text('1 / 6'), findsOneWidget);

    for (var step = 2; step <= 6; step++) {
      await tester.tap(find.text('下一步'));
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('$step / 6'), findsOneWidget);
    }
    // While the tour runs, room objects stay out of reach.
    expect(opened['quests'], isNull);

    await tester.tap(find.text('開始第一次專注'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(opened['desk'], 1);
    expect(opened['tourDone'], 1);
    expect(find.byKey(const Key('cabin-tour')), findsNothing);
  });

  testWidgets('the tour can be skipped at any step', (tester) async {
    late Map<String, int> opened;
    await tester.runAsync(() async => opened = await _pump(tester, tour: true));
    await tester.pump(const Duration(seconds: 3));
    await tester.tap(find.text('下一步'));
    await tester.pump(const Duration(seconds: 3));
    await tester.tap(find.text('略過'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(opened['tourDone'], 1);
    expect(opened['desk'], isNull);
    expect(find.byKey(const Key('cabin-tour')), findsNothing);
  });

  testWidgets('no tour once it has been seen', (tester) async {
    await tester.runAsync(() => _pump(tester));
    expect(find.byKey(const Key('cabin-tour')), findsNothing);
  });

  testWidgets('a new level plays a full-screen celebration', (tester) async {
    await tester.runAsync(() => _pump(tester));
    expect(find.byKey(const Key('cabin-celebration')), findsNothing);
    await tester.runAsync(() => _pump(tester, level: 8));
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.byKey(const Key('cabin-celebration')), findsOneWidget);
    expect(find.text('升級！'), findsOneWidget);
    expect(find.text('Lv 8'), findsOneWidget);
    await tester.tap(find.byKey(const Key('cabin-celebration')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('cabin-celebration')), findsNothing);
  });

  testWidgets('switching to an account with a higher level is no level-up', (
    tester,
  ) async {
    await tester.runAsync(() => _pump(tester));
    await tester.runAsync(() => _pump(tester, level: 14, account: 'other'));
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.byKey(const Key('cabin-celebration')), findsNothing);
  });

  testWidgets('the social slot shows a dot for unread news', (tester) async {
    await tester.runAsync(() => _pump(tester));
    expect(find.byKey(const Key('hotbar-social-dot')), findsNothing);
    await tester.runAsync(() => _pump(tester, socialUnread: 2));
    await tester.pump();
    expect(find.byKey(const Key('hotbar-social-dot')), findsOneWidget);
    expect(find.bySemanticsLabel('社交，有新消息'), findsOneWidget);
  });

  testWidgets(
    'cabin 3.0: noon opens the drapes, folds the futon, ticks the clock',
    (tester) async {
      await tester.runAsync(() => _pump(tester, still: true));
      expect(find.byKey(const Key('cabin-drapes-open')), findsOneWidget);
      expect(find.byKey(const Key('cabin-futon-folded')), findsOneWidget);
      expect(find.byKey(const Key('cabin-clock')), findsOneWidget);
      expect(find.byKey(const Key('cabin-near')), findsOneWidget);
      expect(find.byKey(const Key('cabin-companion')), findsOneWidget);
      expect(find.byKey(const Key('cabin-blanket')), findsNothing);
    },
  );
}
