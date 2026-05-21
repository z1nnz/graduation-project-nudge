import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/daily_summary.dart';

class AppLocalData {
  final List<Map<String, dynamic>> tasks;
  final int focusMinutes;
  final double sleepHours;
  final int steps;
  final int exerciseMinutes;
  final bool isHealthConnected;
  final List<DailySummary> dailySummaries;

  const AppLocalData({
    required this.tasks,
    required this.focusMinutes,
    required this.sleepHours,
    required this.steps,
    required this.exerciseMinutes,
    required this.isHealthConnected,
    required this.dailySummaries,
  });
}

class LocalStorageService {
  static const String tasksKey = 'tasks';
  static const String focusMinutesKey = 'focusMinutes';
  static const String sleepHoursKey = 'sleepHours';
  static const String stepsKey = 'steps';
  static const String exerciseMinutesKey = 'exerciseMinutes';
  static const String isHealthConnectedKey = 'isHealthConnected';
  static const String dailySummariesKey = 'dailySummaries';

  static Future<AppLocalData> loadAppData({
    required List<Map<String, dynamic>> defaultTasks,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final String? tasksString = prefs.getString(tasksKey);
    final int focusMinutes = prefs.getInt(focusMinutesKey) ?? 0;
    final double sleepHours = prefs.getDouble(sleepHoursKey) ?? 0.0;
    final int steps = prefs.getInt(stepsKey) ?? 0;
    final int exerciseMinutes = prefs.getInt(exerciseMinutesKey) ?? 0;
    final bool isHealthConnected = prefs.getBool(isHealthConnectedKey) ?? false;

    final String? summariesString = prefs.getString(dailySummariesKey);

    List<Map<String, dynamic>> tasks = defaultTasks;
    List<DailySummary> summaries = [];

    if (tasksString != null && tasksString.isNotEmpty) {
      final List decoded = jsonDecode(tasksString);
      tasks = decoded.map((item) => Map<String, dynamic>.from(item)).toList();
    }

    if (summariesString != null && summariesString.isNotEmpty) {
      final List decoded = jsonDecode(summariesString);
      summaries = decoded
          .map((item) => DailySummary.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }

    return AppLocalData(
      tasks: tasks,
      focusMinutes: focusMinutes,
      sleepHours: sleepHours,
      steps: steps,
      exerciseMinutes: exerciseMinutes,
      isHealthConnected: isHealthConnected,
      dailySummaries: summaries,
    );
  }

  static Future<void> saveTasks(List<Map<String, dynamic>> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(tasksKey, jsonEncode(tasks));
  }

  static Future<void> saveFocusMinutes(int focusMinutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(focusMinutesKey, focusMinutes);
  }

  static Future<void> saveHealthData({
    required double sleepHours,
    required int steps,
    required int exerciseMinutes,
    required bool isHealthConnected,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(sleepHoursKey, sleepHours);
    await prefs.setInt(stepsKey, steps);
    await prefs.setInt(exerciseMinutesKey, exerciseMinutes);
    await prefs.setBool(isHealthConnectedKey, isHealthConnected);
  }

  static Future<void> saveDailySummaries(List<DailySummary> summaries) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = summaries.map((e) => e.toJson()).toList();
    await prefs.setString(dailySummariesKey, jsonEncode(jsonList));
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
