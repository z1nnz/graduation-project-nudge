import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/badge_record.dart';
import 'package:nudge/models/cabin_presentation.dart';
import 'package:nudge/models/daily_next_action.dart';
import 'package:nudge/models/daily_summary.dart';

final _today = DateTime(2026, 11, 23);

List<DailySummary> _focusDays(int count, {int minutes = 30}) => [
  for (var i = 0; i < count; i++)
    DailySummary(
      date: _key(_today.subtract(Duration(days: i))),
      completedTasks: 0,
      totalTasks: 0,
      focusMinutes: minutes,
      sleepHours: 0,
      steps: 0,
      exerciseMinutes: 0,
      disciplineScore: 0,
    ),
];

String _key(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

BadgeRecord _badge(String key, {int progress = 0, bool unlocked = false}) =>
    BadgeRecord(
      id: key,
      userId: 'u',
      badgeKey: key,
      badgeName: key,
      isUnlocked: unlocked,
      progress: progress,
      updatedAt: _today,
    );

CabinPresentation _resolve({
  List<DailySummary> summaries = const [],
  List<BadgeRecord> badges = const [],
  bool hasDevice = false,
  bool deviceFocusing = false,
}) => CabinPresentation.resolve(
  summaries: summaries,
  badges: badges,
  decor: const {'rug': 1, 'curtain': 0, 'lamp': 2},
  action: DailyNextAction.resolve(const []),
  openTaskCount: 2,
  hasDevice: hasDevice,
  deviceFocusing: deviceFocusing,
  today: _today,
);

void main() {
  test('book stage thresholds', () {
    expect(_resolve(summaries: _focusDays(2)).bookStage, 0);
    expect(_resolve(summaries: _focusDays(3)).bookStage, 1);
    expect(_resolve(summaries: _focusDays(8)).bookStage, 2);
    expect(_resolve(summaries: _focusDays(16)).bookStage, 3);
    expect(_resolve(summaries: _focusDays(20, minutes: 24)).bookStage, 0);
  });

  test('focus days older than 30 days do not count', () {
    final old = [
      for (var i = 31; i < 50; i++)
        DailySummary(
          date: _key(_today.subtract(Duration(days: i))),
          completedTasks: 0,
          totalTasks: 0,
          focusMinutes: 60,
          sleepHours: 0,
          steps: 0,
          exerciseMinutes: 0,
          disciplineScore: 0,
        ),
    ];
    expect(_resolve(summaries: old).bookStage, 0);
  });

  test('plant stage uses the longer streak', () {
    expect(_resolve().plantStage, 0);
    expect(
      _resolve(badges: [_badge('focus_streak', progress: 2)]).plantStage,
      1,
    );
    expect(
      _resolve(
        badges: [
          _badge('focus_streak', progress: 1),
          _badge('task_streak', progress: 4),
        ],
      ).plantStage,
      2,
    );
    expect(
      _resolve(badges: [_badge('task_streak', progress: 9)]).plantStage,
      3,
    );
  });

  test('badges cap at three', () {
    expect(
      _resolve(
        badges: [
          for (var i = 0; i < 5; i++) _badge('b$i', unlocked: true),
          _badge('x'),
        ],
      ).badgeCount,
      3,
    );
  });

  test('globe only with a device and glows only while focusing', () {
    expect(_resolve().showGlobe, isFalse);
    expect(_resolve(deviceFocusing: true).globeGlowing, isFalse);
    expect(_resolve(hasDevice: true).showGlobe, isTrue);
    expect(_resolve(hasDevice: true).globeGlowing, isFalse);
    expect(
      _resolve(hasDevice: true, deviceFocusing: true).globeGlowing,
      isTrue,
    );
  });

  test('carries decor, quest count and the next action title', () {
    final p = _resolve();
    expect(p.decor, {'rug': 1, 'curtain': 0, 'lamp': 2});
    expect(p.questCount, 2);
    expect(p.bubbleText, DailyNextAction.resolve(const []).title);
  });
}
