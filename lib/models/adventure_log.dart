import 'daily_summary.dart';

/// One day in the adventure log.
class AdventureDay {
  const AdventureDay(this.date, this.focusMinutes, this.questsDone);

  final String date; // yyyy-MM-dd
  final int focusMinutes;
  final int questsDone;

  bool get active => focusMinutes > 0 || questsDone > 0;
}

/// The week as an adventure: the seven days ending today, read from the
/// daily summaries the App already keeps.
class AdventureLog {
  const AdventureLog(this.days);

  /// Oldest first; the last entry is today.
  final List<AdventureDay> days;

  factory AdventureLog.fromSummaries(
    Iterable<DailySummary> summaries, {
    required String todayKey,
  }) {
    final byDate = {for (final s in summaries) s.date: s};
    final today = DateTime.parse(todayKey);
    return AdventureLog([
      for (var back = 6; back >= 0; back--)
        () {
          final date = _key(today.subtract(Duration(days: back)));
          final s = byDate[date];
          return AdventureDay(
            date,
            s?.focusMinutes ?? 0,
            s?.completedTasks ?? 0,
          );
        }(),
    ]);
  }

  static String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  int get totalFocusMinutes => days.fold(0, (sum, d) => sum + d.focusMinutes);

  int get questsDone => days.fold(0, (sum, d) => sum + d.questsDone);

  int get activeDays => days.where((d) => d.active).length;

  /// The day with the most focus, or null when nothing was focused.
  AdventureDay? get bestDay {
    AdventureDay? best;
    for (final d in days) {
      if (d.focusMinutes > (best?.focusMinutes ?? 0)) best = d;
    }
    return best;
  }

  String get companionLine => switch (activeDays) {
    0 => '這週還沒出發，沒關係，新的冒險隨時可以開始！',
    7 => '這週每一天都有前進，你真的好厲害！',
    _ => '這週有 $activeDays 天一起前進，我都記在日誌裡了。',
  };
}
