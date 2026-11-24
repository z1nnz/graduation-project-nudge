import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/widgets/game_facility_scene.dart';

void main() {
  testWidgets(
    'library objects, guide dialogue and parchment preserve feature actions at 360px and 1.15 text',
    (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      try {
        var clicks = 0;
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                disableAnimations: true,
                textScaler: TextScaler.linear(1.15),
              ),
              child: child!,
            ),
            home: Scaffold(
              body: GameFacilityScene(
                title: '紀錄館',
                background: 'assets/scenes/library/library_room.webp',
                guideLine: '這是你自己的紀錄。',
                foreground: Positioned(
                  top: 120,
                  right: 12,
                  child: TextButton(
                    onPressed: () => clicks += 10,
                    child: const Text('場景物件'),
                  ),
                ),
                child: ListView(
                  children: [
                    GameArtifact(
                      child: TextButton(
                        onPressed: () => clicks++,
                        child: const Text('保留的功能'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('保留的功能'), findsNothing);
        await tester.tap(find.text('場景物件'));
        expect(clicks, 10);
        expect(find.bySemanticsLabel('翻開紀錄簿'), findsWidgets);
        expect(find.bySemanticsLabel('與墨墨交談'), findsWidgets);
        await tester.tap(find.text('翻開紀錄簿'));
        await tester.pump();
        expect(find.text('保留的功能'), findsOneWidget);
        await tester.tap(find.text('保留的功能'));
        expect(clicks, 11);
        await tester.tap(find.text('闔上，回到場景'));
        await tester.pump();
        await tester.tap(find.bySemanticsLabel('與墨墨交談').first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.bySemanticsLabel('墨墨：這是你自己的紀錄。'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('關閉對話').last);
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );
  testWidgets(
    'reduced motion has no running scene ticker and a null metric stays unknown',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: GameFacilityScene(
                title: '書架',
                background: 'assets/scenes/library/library_room.webp',
                child: const GameMetricGauge(),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.transientCallbackCount, 0);
      await tester.tap(find.text('翻開紀錄簿'));
      await tester.pump();
      expect(find.bySemanticsLabel('紀錄沙漏'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
