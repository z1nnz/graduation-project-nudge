import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/daily_summary.dart';
import 'package:nudge/screens/statistics_page.dart';
import 'package:nudge/screens/personal_analysis_page.dart';
import 'package:nudge/screens/weekly_report_page.dart';
import 'package:nudge/screens/daily_records_page.dart';
import 'package:nudge/screens/today_data_page.dart';
import 'package:nudge/screens/today_advice_page.dart';
import 'package:nudge/screens/score_explanation_page.dart';
import 'package:nudge/screens/discipline_identity_page.dart';
import 'package:nudge/state/app_state.dart';
import 'package:nudge/theme/game_ui.dart';
import 'package:provider/provider.dart';

class _LibraryState extends AppState {
  @override
  List<DailySummary> get dailySummaries => [
    DailySummary(
      date: DateTime.now().toIso8601String().substring(0, 10),
      completedTasks: 2,
      totalTasks: 3,
      focusMinutes: 50,
      sleepHours: 7.5,
      steps: 4200,
      exerciseMinutes: 20,
      disciplineScore: 68,
    ),
  ];
}

Future<void> _capture(
  WidgetTester tester,
  GlobalKey boundary,
  String name,
) async {
  final output = Platform.environment['NUDGE_QA_SCREENSHOT_DIR'];
  if (output == null) {
    return;
  }
  await tester.runAsync(() async {
    final box =
        boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await box.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    await Directory(output).create(recursive: true);
    await File('$output/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(() async {
    final loader = FontLoader('Cubic11')
      ..addFont(rootBundle.load('assets/fonts/Cubic11.ttf'));
    await loader.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  final pages = <String, (Widget, String)>{
    'statistics': (const StatisticsPage(), '翻開統計書'),
    'analysis': (const PersonalAnalysisPage(), '聽聽今日建議'),
    'weekly': (const WeeklyReportPage(), '翻開每週報告'),
    'daily': (const DailyRecordsPage(), '翻開每日紀錄'),
    'today_data': (const TodayDataPage(), '查看今日數據'),
    'advice': (const TodayAdvicePage(), '聽聽今日建議'),
    'score': (const ScoreExplanationPage(), '翻開分數手冊'),
    'identity': (const DisciplineIdentityPage(), '查看冒險者證書'),
  };
  for (final dark in [false, true]) {
    for (final entry in pages.entries) {
      testWidgets(
        '${entry.key} opens as a library scene and preserves its document at 360px / 1.15 / ${dark ? 'dark' : 'light'}',
        (tester) async {
          tester.view.physicalSize = const Size(360, 780);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final state = _LibraryState(), boundary = GlobalKey();
          await tester.pumpWidget(
            ChangeNotifierProvider<AppState>.value(
              value: state,
              child: RepaintBoundary(
                key: boundary,
                child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: ThemeData(
                    brightness: dark ? Brightness.dark : Brightness.light,
                    fontFamily: 'Cubic11',
                    appBarTheme: GameTheme.appBar(),
                    textButtonTheme: GameTheme.secondaryButton(dark: dark),
                    elevatedButtonTheme: GameTheme.primaryButton(),
                    chipTheme: GameTheme.chips(dark: dark),
                    colorScheme: ColorScheme.fromSeed(
                      seedColor: GamePalette.goldDeep,
                      brightness: dark ? Brightness.dark : Brightness.light,
                    ),
                  ),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      disableAnimations: true,
                      textScaler: TextScaler.linear(1.15),
                    ),
                    child: child!,
                  ),
                  home: Scaffold(body: entry.value.$1),
                ),
              ),
            ),
          );
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 80)),
          );
          await tester.pump();
          expect(find.text(entry.value.$2), findsOneWidget);
          await _capture(
            tester,
            boundary,
            'r2-app-${entry.key}-${dark ? 'dark' : 'light'}-scene',
          );
          await tester.tap(find.text(entry.value.$2));
          await tester.pump();
          expect(find.text('闔上，回到場景'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await _capture(
            tester,
            boundary,
            'r2-app-${entry.key}-${dark ? 'dark' : 'light'}-document',
          );
          await tester.pumpWidget(const SizedBox.shrink());
          state.dispose();
        },
      );
    }
  }
}
