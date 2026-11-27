import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/screens/dressing_room_page.dart';
import 'package:nudge/widgets/player_avatar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/disk_asset_bundle.dart';

final opened = <Type>[];

Future<void> _pump(WidgetTester tester, Size size, {bool still = true}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    DefaultAssetBundle(
      bundle: DiskAssetBundle(),
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: size, disableAnimations: still),
          child: DressingRoomPage(
            nickname: '小明',
            level: 5,
            openPage: (_, page) => opened.add(page.runtimeType),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _step(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final size in const [Size(390, 844), Size(1280, 800)]) {
    testWidgets('mirror, rack, pillar and player on a ${size.width}px screen', (
      tester,
    ) async {
      await _pump(tester, size);
      expect(find.byKey(const Key('dressing-mirror')), findsOneWidget);
      expect(find.byKey(const Key('dressing-rack')), findsOneWidget);
      expect(find.byKey(const Key('dressing-pillar')), findsOneWidget);
      expect(find.byKey(const Key('dressing-player')), findsOneWidget);
      for (final label in ['衣架', '立鏡', '名片', '書架', '光圈']) {
        expect(
          find.bySemanticsLabel(RegExp(label)),
          findsWidgets,
          reason: label,
        );
      }
    });
  }

  testWidgets('the rack puts a garment on and saves the look on this device', (
    tester,
  ) async {
    await _pump(tester, const Size(390, 844));
    await tester.tap(find.bySemanticsLabel(RegExp('衣架')).first);
    await _step(tester);
    expect(find.byKey(const Key('dressing-rack-panel')), findsOneWidget);
    await tester.tap(find.byKey(const Key('wear-outfit-forest')));
    await _step(tester);
    expect((await PlayerLookStore.load()).outfit, 'forest');
    await tester.tap(find.text('頭飾'));
    await _step(tester);
    await tester.tap(find.byKey(const Key('wear-headwear-none')));
    await _step(tester);
    expect((await PlayerLookStore.load()).headwear, isNull);
  });

  testWidgets('the name card turns over', (tester) async {
    await _pump(tester, const Size(390, 844));
    await tester.tap(find.bySemanticsLabel(RegExp('名片')).first);
    await _step(tester);
    expect(find.byKey(const Key('name-card-front')), findsOneWidget);
    expect(find.text('小明'), findsOneWidget);
    await tester.tap(find.byKey(const Key('name-card-flip')));
    await _step(tester);
    expect(find.byKey(const Key('name-card-back')), findsOneWidget);
  });

  testWidgets(
    'reduced motion: the light pillar opens evolution without animating',
    (tester) async {
      await _pump(tester, const Size(390, 844));
      await tester.tap(find.bySemanticsLabel(RegExp('光圈')).first);
      await tester.pump();
      await _step(tester);
      expect(opened.last.toString(), 'AvatarEvolutionPage');
    },
  );
}
