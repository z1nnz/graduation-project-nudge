import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/adventure_log.dart';
import 'package:nudge/models/daily_summary.dart';

DailySummary _day(String date, {int focus = 0, int done = 0, int total = 0}) =>
    DailySummary(
      date: date,
      completedTasks: done,
      totalTasks: total,
      focusMinutes: focus,
      sleepHours: 0,
      steps: 0,
      exerciseMinutes: 0,
      disciplineScore: 0,
    );

void main() {
  test('covers the seven days ending today, oldest first', () {
    final log = AdventureLog.fromSummaries([
      _day('2026-11-23', focus: 50, done: 2, total: 3),
      _day('2026-11-20', focus: 100, done: 4, total: 4),
      _day('2026-11-16', focus: 999), // eight days ago: outside the week
    ], todayKey: '2026-11-23');
    expect(log.days.map((d) => d.date), [
      '2026-11-17',
      '2026-11-18',
      '2026-11-19',
      '2026-11-20',
      '2026-11-21',
      '2026-11-22',
      '2026-11-23',
    ]);
    expect(log.days.map((d) => d.focusMinutes), [0, 0, 0, 100, 0, 0, 50]);
    expect(log.totalFocusMinutes, 150);
    expect(log.questsDone, 6);
    expect(log.activeDays, 2);
    expect(log.bestDay?.date, '2026-11-20');
  });

  test('the companion line follows how the week went', () {
    String line(int activeDays) => AdventureLog.fromSummaries([
      for (var i = 0; i < activeDays; i++) _day('2026-11-${23 - i}', focus: 30),
    ], todayKey: '2026-11-23').companionLine;
    expect(line(0), contains('新的冒險'));
    expect(line(3), contains('3 天'));
    expect(line(7), contains('每一天'));
  });

  test('an empty week has no best day', () {
    final log = AdventureLog.fromSummaries([], todayKey: '2026-11-23');
    expect(log.bestDay, isNull);
    expect(log.totalFocusMinutes, 0);
  });
}
