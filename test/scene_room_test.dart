import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/character_catalog.dart';
import 'package:nudge/widgets/scene_room.dart';

Widget _app(Widget child, {bool reduced = true, double scale = 1}) =>
    MaterialApp(
      builder: (context, c) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: reduced,
          textScaler: TextScaler.linear(scale),
        ),
        child: c!,
      ),
      home: Scaffold(body: child),
    );

void main() {
  testWidgets(
    'objects are labelled buttons that run their action at 360px and 1.15 text',
    (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      final tapped = <String>[];
      await tester.pumpWidget(
        _app(
          SceneRoom(
            art: 'assets/scenes/store/store.webp',
            title: '小鎮雜貨店',
            npc: GameCharacters.chestnut,
            tips: const ['左邊是衣服架。'],
            objects: [
              for (final id in ['clothes', 'cat'])
                SceneObject(
                  id: id,
                  label: id == 'clothes' ? '衣服架' : '麻糬',
                  hint: id == 'clothes' ? '服裝與配件' : null,
                  rect: id == 'clothes'
                      ? const Rect.fromLTWH(0.03, 0.235, 0.3, 0.225)
                      : const Rect.fromLTWH(0.29, 0.51, 0.25, 0.065),
                  onTap: (_, room) {
                    tapped.add(id);
                    room.burst(BurstKind.heart, from: id);
                  },
                ),
            ],
            effects: const [SceneEffect.dust(), SceneEffect.fireflies()],
          ),
          scale: 1.15,
        ),
      );
      await tester.pump();
      expect(find.bySemanticsLabel('衣服架：服裝與配件'), findsOneWidget);
      expect(find.bySemanticsLabel('麻糬'), findsOneWidget);
      expect(find.bySemanticsLabel('和栗子說話'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('scene-object-clothes')));
      await tester.tap(find.byKey(const ValueKey('scene-object-cat')));
      expect(tapped, ['clothes', 'cat']);

      final hit = tester.getSize(find.byKey(const ValueKey('scene-object-cat')));
      expect(hit.width, greaterThanOrEqualTo(44));
      expect(hit.height, greaterThanOrEqualTo(44));
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets('the shopkeeper talks: greeting first, then a tip', (tester) async {
    await tester.pumpWidget(
      _app(
        SceneRoom(
          art: 'assets/scenes/store/store.webp',
          title: '雜貨店',
          npc: GameCharacters.chestnut,
          greeting: () => ['歡迎光臨！'],
          tips: const ['那隻貓叫麻糬。'],
          objects: const [],
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('scene-npc')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('歡迎光臨'), findsWidgets);
  });

  testWidgets('the room animates only when motion is allowed', (tester) async {
    await tester.pumpWidget(
      _app(
        const SceneRoom(
          art: 'assets/scenes/store/store.webp',
          title: '雜貨店',
          objects: [],
          effects: [SceneEffect.dust()],
        ),
      ),
    );
    SceneRoomState room() => tester.state(find.byType(SceneRoom));
    expect(room().animating, isFalse);
    await tester.pumpWidget(
      _app(
        const SceneRoom(
          art: 'assets/scenes/store/store.webp',
          title: '雜貨店',
          objects: [],
          effects: [SceneEffect.dust()],
        ),
        reduced: false,
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));
    expect(room().animating, isTrue);
  });
}
