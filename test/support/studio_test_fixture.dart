import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/daily_summary.dart';
import 'package:nudge/models/user_model.dart';
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

class StudioTestState extends AppState {
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
