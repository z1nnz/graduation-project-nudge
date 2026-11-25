import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/daily_summary.dart';
import 'package:nudge/models/garden_growth.dart';

DailySummary day(
  String date, {
  int focus = 0,
  double sleep = 0,
  int steps = 0,
  int exercise = 0,
}) => DailySummary.fromJson({
  'date': date,
  'completedTasks': 0,
  'totalTasks': 0,
  'disciplineScore': 0,
  'focusMinutes': focus,
  'sleepHours': sleep,
  'steps': steps,
  'exerciseMinutes': exercise,
});

void main() {
  test('weeks start on Monday and only count their own days', () {
    final now = DateTime(2026, 11, 25); // Wednesday
    expect(GardenGrowth.weekStart(now), DateTime(2026, 11, 23));
    final days = [
      day('2026-11-23', focus: 80),
      day('2026-11-25', focus: 80),
      day('2026-11-20', focus: 30), // previous week
      day('2026-11-02', focus: 999), // too old
    ];
    final weeks = GardenGrowth.weeksFor(GardenPlant.flower, days, now);
    expect(weeks.map((w) => w.total), [0, 30, 160]);
    expect(weeks.map((w) => w.stage), [0, 2, 4]);
  });

  test('stages follow the Web garden thresholds for every plant', () {
    expect(GardenPlant.flower.stageFor(300), 5);
    expect(GardenPlant.tree.stageFor(19), 1);
    expect(GardenPlant.moonflower.stageFor(21), 3);
    expect(GardenPlant.meadow.stageFor(0), 0);
    expect(GardenPlant.meadow.stageFor(70000), 5);
  });
}
