import 'daily_summary.dart';

/// One plant kind in the starlight garden, grown by one kind of action.
/// Thresholds match the Web garden (web_dashboard/assets/garden_core.js).
class GardenPlant {
  const GardenPlant(this.id, this.name, this.verb, this.row, this.thresholds);
  final String id, name, verb;

  /// Row in assets/scenes/garden/plants.webp (5 growth stages per row).
  final int row;
  final List<double> thresholds;

  static const flower = GardenPlant('flower', '星光百合', '專注', 4, [
    1,
    25,
    75,
    150,
    300,
  ]);
  static const tree = GardenPlant('tree', '蘋果樹', '運動', 3, [
    1,
    20,
    60,
    120,
    200,
  ]);
  static const moonflower = GardenPlant('moonflower', '月鈴花', '睡眠', 2, [
    1,
    7,
    21,
    35,
    49,
  ]);
  static const meadow = GardenPlant('meadow', '向日葵', '走路', 0, [
    1,
    5000,
    20000,
    40000,
    70000,
  ]);
  static const all = [flower, tree, moonflower, meadow];

  double amount(DailySummary d) => switch (id) {
    'flower' => d.focusMinutes.toDouble(),
    'tree' => d.exerciseMinutes.toDouble(),
    'moonflower' => d.sleepHours,
    _ => d.steps.toDouble(),
  };

  String get unit => switch (id) {
    'flower' || 'tree' => '分鐘',
    'moonflower' => '小時',
    _ => '步',
  };

  /// 0 (bare soil) to 5 for a weekly total.
  int stageFor(double total) {
    var stage = 0;
    for (final t in thresholds) {
      if (total >= t) stage++;
    }
    return stage;
  }
}

/// A plant's growth in one week.
class GardenWeek {
  const GardenWeek(this.start, this.total, this.stage);
  final DateTime start;
  final double total;
  final int stage;
}

abstract final class GardenGrowth {
  static const minLevel = 10;

  /// Monday of the week containing [day] (local, date only).
  static DateTime weekStart(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return d.subtract(Duration(days: d.weekday - 1));
  }

  /// The last [weeks] weeks (oldest first) for [plant] from daily summaries.
  static List<GardenWeek> weeksFor(
    GardenPlant plant,
    List<DailySummary> days,
    DateTime now, {
    int weeks = 3,
  }) {
    final thisWeek = weekStart(now);
    final out = <GardenWeek>[];
    for (var i = weeks - 1; i >= 0; i--) {
      final start = thisWeek.subtract(Duration(days: 7 * i));
      final end = start.add(const Duration(days: 7));
      var total = 0.0;
      for (final d in days) {
        final date = DateTime.tryParse(d.date);
        if (date == null || date.isBefore(start) || !date.isBefore(end)) {
          continue;
        }
        total += plant.amount(d);
      }
      out.add(GardenWeek(start, total, plant.stageFor(total)));
    }
    return out;
  }
}
