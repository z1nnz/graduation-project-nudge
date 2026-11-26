import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/screens/login_page.dart';
import 'package:nudge/screens/register_page.dart';
import 'package:nudge/screens/settings_page.dart';
import 'package:nudge/screens/account_page.dart';
import 'package:nudge/screens/my_profile_page.dart';
import 'package:nudge/screens/about_page.dart';
import 'package:nudge/screens/privacy_data_page.dart';
import 'package:nudge/screens/nudge_device_page.dart';

import 'support/studio_test_fixture.dart';

void main() {
  setUpAll(() async {
    await (FontLoader(
      'Cubic11',
    )..addFont(rootBundle.load('assets/fonts/Cubic11.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  final pages = <String, (Widget, String)>{
    'login': (const LoginPage(), '領取入鎮通行證'),
    'register': (const RegisterPage(), '填寫入鎮通行證'),
    'settings': (const SettingsPage(), '查看工作室設定'),
    'account': (const AccountPage(), '查看帳號鑰匙'),
    'profile': (const MyProfilePage(), '打開我的名片'),
    'about': (const AboutPage(), '翻開旅程手冊'),
    'privacy': (const PrivacyDataPage(), '打開資料保險箱'),
    'device': (const NudgeDevicePage(), '操作裝置工作台'),
  };
  for (final dark in [false, true]) {
    for (final entry in pages.entries) {
      testWidgets(
        '${entry.key} room and original document at 360px / 1.15 / $dark',
        (tester) async {
          tester.view.physicalSize = const Size(360, 780);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final semantics = tester.ensureSemantics();
          final state = StudioTestState(), key = GlobalKey();
          await tester.pumpWidget(shell(state, entry.value.$1, key, dark));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 80)),
          );
          await tester.pump();
          expect(find.text(entry.value.$2), findsOneWidget);
          expect(find.bySemanticsLabel(entry.value.$2), findsWidgets);
          await capture(tester, key, 'r5-app-${entry.key}-$dark-scene');
          await tester.tap(find.text(entry.value.$2));
          await tester.pump();
          expect(find.text('闔上，回到場景'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await capture(tester, key, 'r5-app-${entry.key}-$dark-document');
          for (var i = 0; i < 6; i++) {
            final scroll = find.byType(Scrollable);
            if (scroll.evaluate().isNotEmpty) {
              await tester.drag(scroll.first, const Offset(0, -450));
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
            }
          }
          await tester.pumpWidget(const SizedBox.shrink());
          state.dispose();
          semantics.dispose();
        },
      );
    }
  }
}
