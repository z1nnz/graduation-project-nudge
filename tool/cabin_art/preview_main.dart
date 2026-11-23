// Offline preview of the companion cabin home with example data, for
// screenshots (acceptance evidence and the project brief). It never
// initialises Firebase and writes nothing to Cloud.
//
//   flutter build web -t tool/cabin_art/preview_main.dart -o build/cabin_preview
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:nudge/models/daily_summary.dart';
import 'package:nudge/screens/home_page.dart';
import 'package:nudge/state/app_state.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _key(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final today = DateTime.now();
  SharedPreferences.setMockInitialValues({
    'onboarding_completed_setting': true,
    'discipline_coins_setting': 128,
    'unlocked_avatar_items_setting': ['homeDecor:101'],
    'dailySummaries': jsonEncode([
      for (var i = 1; i <= 9; i++)
        DailySummary(
          date: _key(today.subtract(Duration(days: i))),
          completedTasks: 3,
          totalTasks: 4,
          focusMinutes: 40,
          sleepHours: 7,
          steps: 6000,
          exerciseMinutes: 20,
          disciplineScore: 78,
        ).toJson(),
    ]),
  });
  final appState = AppState();
  await appState.loadAllLocalData();
  runApp(
    ChangeNotifierProvider.value(
      value: appState,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7C6AE6)),
        ),
        home: HomePage(onNavigate: (_) {}, onOpenStatistics: () {}),
      ),
    ),
  );
}
