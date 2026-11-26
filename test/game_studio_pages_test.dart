import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/daily_summary.dart';
import 'package:nudge/models/user_model.dart';
import 'package:nudge/screens/login_page.dart';
import 'package:nudge/screens/register_page.dart';
import 'package:nudge/screens/settings_page.dart';
import 'package:nudge/screens/account_page.dart';
import 'package:nudge/screens/my_profile_page.dart';
import 'package:nudge/screens/about_page.dart';
import 'package:nudge/screens/privacy_data_page.dart';
import 'package:nudge/screens/nudge_device_page.dart';
import 'package:nudge/screens/reminder_center_page.dart';
import 'package:nudge/state/app_state.dart';
import 'package:nudge/theme/game_ui.dart';
import 'package:provider/provider.dart';

DailySummary summary() => DailySummary(
  date: DateTime.now().toIso8601String().substring(0, 10),
  completedTasks: 2,
  totalTasks: 3,
  focusMinutes: 50,
  sleepHours: 7.5,
  steps: 4200,
  exerciseMinutes: 20,
  disciplineScore: 68,
);

class _StudioState extends AppState {
  @override
  List<DailySummary> get dailySummaries => [summary()];
  @override
  bool get isHealthConnected => true;
  @override
  double get sleepHours => 7.5;
  @override
  int get steps => 4200;
  @override
  int get exerciseMinutes => 20;
  @override
  UserModel get currentUser => UserModel(
    id: 'local-test',
    username: 'fixture',
    nickname: 'local fixture',
    signature: '',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

}

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  await tester.pumpAndSettle();
  final out = Platform.environment['NUDGE_QA_SCREENSHOT_DIR'];
  if (out == null) return;
  await tester.runAsync(() async {
    final image =
        await (key.currentContext!.findRenderObject() as RenderRepaintBoundary)
            .toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    await Directory(out).create(recursive: true);
    await File('$out/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
  });
}

Widget shell(AppState state, Widget page, GlobalKey key, bool dark) =>
    ChangeNotifierProvider<AppState>.value(
      value: state,
      child: RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: dark ? Brightness.dark : Brightness.light,
            fontFamily: 'Cubic11',
            appBarTheme: GameTheme.appBar(),
            textButtonTheme: GameTheme.secondaryButton(dark: dark),
            elevatedButtonTheme: GameTheme.primaryButton(),
            chipTheme: GameTheme.chips(dark: dark),
            inputDecorationTheme: GameTheme.inputs(dark: dark),
            pageTransitionsTheme: GameTheme.pageTransitions(),
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: true,
              textScaler: TextScaler.linear(1.15),
            ),
            child: child!,
          ),
          home: page,
        ),
      ),
    );
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
    'reminders': (const ReminderCenterPage(), '調整提醒撥桿'),
  };
  for (final dark in [false, true]) {
    for (final entry in pages.entries) {
      testWidgets(
        '${entry.key} room and original document at 360px / 1.15 / $dark',
        (tester) async {
          tester.view.physicalSize = const Size(360, 780);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final state = _StudioState(), key = GlobalKey();
          await tester.pumpWidget(shell(state, entry.value.$1, key, dark));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 80)),
          );
          await tester.pump();
          expect(find.text(entry.value.$2), findsOneWidget);
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
        },
      );
    }
  }
}
