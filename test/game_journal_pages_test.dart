import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/daily_summary.dart';
import 'package:nudge/models/user_model.dart';
import 'package:nudge/screens/calendar_page.dart';
import 'package:nudge/screens/calendar_day_detail_page.dart';
import 'package:nudge/screens/health_page.dart';
import 'package:nudge/screens/future_letter_page.dart';
import 'package:nudge/screens/time_capsule_page.dart';
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

class _JournalState extends AppState {
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
  @override
  List<Map<String, dynamic>> get timeCapsules => [
    {
      'title': 'past-open',
      'meta': '2020-01-01 解鎖',
      'message': 'EXPIRED CONTENT',
    },
    {
      'title': 'future-closed',
      'meta': '2099-01-01 解鎖',
      'message': 'DO NOT REVEAL FUTURE',
    },
    {
      'title': 'invalid-closed',
      'meta': '2026-02-31 解鎖',
      'message': 'DO NOT REVEAL INVALID',
    },
  ];
  @override
  Future<void> saveFutureLetter(
    String state,
    String action,
    String note,
  ) async {
    throw StateError('offline letter fixture');
  }

  @override
  Future<void> saveTimeCapsule(
    String title,
    String date,
    String message,
  ) async {
    throw StateError('offline fixture');
  }
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
    'calendar': (const CalendarPage(), '翻開月份手札'),
    'day': (
      CalendarDayDetailPage(
        date: DateTime.now(),
        summary: summary(),
        dueTasks: const [],
      ),
      '翻開這一天',
    ),
    'health': (const HealthPage(), '翻開健康手冊'),
    'letter': (const FutureLetterPage(), '坐到寫信桌'),
    'capsule': (const TimeCapsulePage(), '查看樹下膠囊'),
  };
  for (final dark in [false, true]) {
    for (final entry in pages.entries) {
      testWidgets(
        '${entry.key} room and original document at 360px / 1.15 / $dark',
        (tester) async {
          tester.view.physicalSize = const Size(360, 780);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final state = _JournalState(), key = GlobalKey();
          await tester.pumpWidget(shell(state, entry.value.$1, key, dark));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 80)),
          );
          await tester.pump();
          expect(find.text(entry.value.$2), findsOneWidget);
          await capture(tester, key, 'r4-app-${entry.key}-$dark-scene');
          await tester.tap(find.text(entry.value.$2));
          await tester.pump();
          expect(find.text('闔上，回到場景'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await capture(tester, key, 'r4-app-${entry.key}-$dark-document');
          if (entry.key == 'calendar') {
            final day = find.byKey(ValueKey('journal-day-${summary().date}'));
            await tester.ensureVisible(day);
            final size = tester.getSize(day);
            expect(size.width, greaterThanOrEqualTo(44));
            expect(size.height, greaterThanOrEqualTo(44));
            await tester.tap(day);
            await tester.pumpAndSettle();
            expect(find.text('翻開這一天'), findsNothing);
            expect(find.text(summary().date), findsWidgets);
            expect(tester.takeException(), isNull);
          }
          if (entry.key == 'letter') {
            await tester.ensureVisible(find.text('產生未來的信'));
            await tester.tap(find.text('產生未來的信'));
            await tester.pump(const Duration(milliseconds: 700));
            expect(find.textContaining('我知道你現在'), findsOneWidget);
            await tester.ensureVisible(find.text('保存並同步到雲端'));
            await tester.pumpAndSettle();
            await tester.tap(find.text('保存並同步到雲端'));
            await tester.pumpAndSettle();
            expect(find.text('這次沒有完成保存，寫信草稿已保留。'), findsOneWidget);
            expect(tester.takeException(), isNull);
          }
          await tester.pumpWidget(const SizedBox.shrink());
          state.dispose();
        },
      );
    }
  }
  testWidgets(
    'health scene props show exact data and open the existing metric and goal dialog',
    (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final state = _JournalState(), key = GlobalKey();
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(shell(state, const HealthPage(), key, false));
      await tester.pump();
      expect(find.bySemanticsLabel('床與月亮・睡眠 7.5 / 7 小時'), findsOneWidget);
      await tester.tap(find.text('床與月亮・睡眠'));
      await tester.pumpAndSettle();
      expect(find.textContaining('7.5'), findsWidgets);
      await tester.tap(find.text('追蹤'));
      await tester.pumpAndSettle();
      expect(find.text('開始追蹤'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capture(tester, key, 'r4-app-health-goal');
      await tester.pumpWidget(const SizedBox.shrink());
      semantics.dispose();
      state.dispose();
    },
  );
  testWidgets(
    'legacy capsule invalid/future dates stay closed and failed save retains the draft',
    (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final state = _JournalState(), key = GlobalKey();
      await tester.pumpWidget(
        shell(state, const TimeCapsulePage(), key, false),
      );
      await tester.pump();
      await tester.tap(find.text('查看樹下膠囊'));
      await tester.pump();
      for (final title in ['future-closed', 'invalid-closed']) {
        await tester.scrollUntilVisible(
          find.text(title),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(find.text(title));
        await tester.pumpAndSettle();
        await tester.tap(find.text(title));
        await tester.pumpAndSettle();
        expect(
          find.textContaining(
            title == 'future-closed' ? '此膠囊將在 2099' : '日期無法核對',
          ),
          findsOneWidget,
        );
        await tester.pumpAndSettle();
      }
      expect(find.text('DO NOT REVEAL FUTURE'), findsNothing);
      expect(find.text('DO NOT REVEAL INVALID'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('past-open'),
        -250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('past-open'));
      await tester.pumpAndSettle();
      expect(find.text('EXPIRED CONTENT'), findsOneWidget);
      await tester.ensureVisible(find.text('保存時間膠囊'));
      await tester.tap(find.text('保存時間膠囊'));
      await tester.pump();
      expect(find.text('這次沒有完成保存，草稿已保留。'), findsOneWidget);
      expect(find.text('期末前的我'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
    },
  );
}
