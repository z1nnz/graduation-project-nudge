import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/screens/game_rooms.dart';

void main() {
  Future<void> pumpRoom(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: true,
            textScaler: const TextScaler.linear(1.15),
          ),
          child: child!,
        ),
        home: page,
      ),
    );
    await tester.pump();
  }

  final rooms = <String, (Widget, List<String>)>{
    '委託所': (
      const CommissionHallPage(),
      ['告示板：今天的委託', '問阿紙：AI 助理', '掛鐘：提醒中心', '冒險地圖：行事曆'],
    ),
    '問阿紙': (const AskScrollPage(), ['翻開書：問阿紙問題', '黑板：今日建議']),
    '工作室': (
      const WorkshopPage(),
      ['鈴鐺：提醒與通知', '地球儀：一般設定', '鑰匙：帳號', '盾牌：資料保險箱', '窗戶：關於 Nudge'],
    ),
    '資料保險箱': (const VaultPage(), ['保險箱大門：匯出與刪除', '同意封蠟：健康資料同意']),
    '裝置工作台': (const DeviceBenchPage(), ['Nudge 裝置：連線與狀態', '筆記本：使用說明']),
  };

  for (final MapEntry(key: title, value: (page, labels)) in rooms.entries) {
    testWidgets(
      '$title is a room whose objects are labelled buttons at 360px',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await pumpRoom(tester, page);
        expect(find.text(title), findsWidgets);
        for (final label in labels) {
          expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
        }
        expect(find.byKey(const ValueKey('scene-npc')), findsOneWidget);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );
  }

  testWidgets('tablets get the landscape room with its own spots', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: const WorkshopPage(),
      ),
    );
    await tester.pump();
    final images = tester
        .widgetList<Image>(find.byType(Image))
        .map((i) => (i.image as AssetImage).assetName);
    expect(images, contains('assets/scenes/workshop/workshop_wide.webp'));
    final bell = tester.getRect(
      find.byKey(const ValueKey('scene-object-bell')),
    );
    expect(bell.width, greaterThanOrEqualTo(44));
    expect(tester.takeException(), isNull);
  });
}
