import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/widgets/community_scene_header.dart';

Widget host(Widget scene) => MaterialApp(
  home: MediaQuery(
    data: const MediaQueryData(
      size: Size(360, 760),
      disableAnimations: true,
      textScaler: TextScaler.linear(1.15),
    ),
    child: Scaffold(body: scene),
  ),
);

void main() {
  testWidgets('the courtyard guide describes the scene', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      host(const CommunitySceneHeader(family: true, greeting: '花圃在庭院中央。')),
    );
    expect(find.bySemanticsLabel('家庭庭院的嚮導'), findsOneWidget);
    await tester.tap(find.text('問問嚮導'));
    await tester.pumpAndSettle();
    expect(find.text('花圃在庭院中央。'), findsOneWidget);
    await tester.tap(find.text('關閉'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    semantics.dispose();
  });

  testWidgets('the scene exposes only the selected landmark at 360px', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      host(
        const CommunitySceneSections(
          family: false,
          greeting: '到日曆看共讀時間。',
          sections: [
            CommunitySceneSection(
              label: '共讀日曆',
              icon: Icons.calendar_month,
              children: [Text('共同自習時間')],
            ),
            CommunitySceneSection(
              label: '挑戰壁畫',
              icon: Icons.extension,
              children: [Text('我的挑戰紀錄')],
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('共讀日曆'), findsOneWidget);
    expect(find.text('共同自習時間'), findsNothing);
    await tester.tap(find.text('共讀日曆'));
    await tester.pumpAndSettle();
    expect(find.text('共同自習時間'), findsOneWidget);
    expect(find.text('我的挑戰紀錄'), findsNothing);
    await tester.tap(find.text('關閉'));
    await tester.pumpAndSettle();
    expect(find.text('共同自習時間'), findsNothing);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
