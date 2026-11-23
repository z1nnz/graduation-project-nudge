import 'badge_record.dart';
import 'daily_next_action.dart';
import 'daily_summary.dart';

/// What the companion cabin shows, derived only from data the App already
/// has. Growth objects reflect real progress; decor reflects owned variants.
class CabinPresentation {
  const CabinPresentation({
    required this.bookStage,
    required this.plantStage,
    required this.badgeCount,
    required this.showGlobe,
    required this.globeGlowing,
    required this.decor,
    required this.bubbleText,
    required this.questCount,
  });

  /// 0-3: books on the shelf, from focus days in the last 30 days.
  final int bookStage;

  /// 0-3: plant growth, from the longer of the focus and task streaks.
  final int plantStage;

  /// 0-3 badges hung in the wall frame.
  final int badgeCount;
  final bool showGlobe;
  final bool globeGlowing;
  final Map<String, int> decor;
  final String bubbleText;
  final int questCount;

  static const _focusDayMinutes = 25;
  static const _window = Duration(days: 30);

  static CabinPresentation resolve({
    required List<DailySummary> summaries,
    required List<BadgeRecord> badges,
    required Map<String, int> decor,
    required DailyNextAction action,
    required int openTaskCount,
    required bool hasDevice,
    required bool deviceFocusing,
    DateTime? today,
  }) {
    final now = today ?? DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final earliest = day.subtract(_window);
    final focusDays = summaries.where((s) {
      final date = DateTime.tryParse(s.date);
      return date != null &&
          date.isAfter(earliest) &&
          !date.isAfter(day) &&
          s.focusMinutes >= _focusDayMinutes;
    }).length;

    int streakOf(String key) => badges
        .where((b) => b.badgeKey == key)
        .fold(0, (best, b) => b.progress > best ? b.progress : best);
    final streak = [
      streakOf('focus_streak'),
      streakOf('task_streak'),
    ].reduce((a, b) => a > b ? a : b);

    return CabinPresentation(
      bookStage: _stage(focusDays, const [3, 8, 16]),
      plantStage: _stage(streak, const [1, 3, 7]),
      badgeCount: badges.where((b) => b.isUnlocked).length.clamp(0, 3),
      showGlobe: hasDevice,
      globeGlowing: hasDevice && deviceFocusing,
      decor: Map.unmodifiable(decor),
      bubbleText: action.title,
      questCount: openTaskCount,
    );
  }

  /// Number of thresholds reached, so `[3, 8, 16]` maps 0-2 → 0, 3-7 → 1,
  /// 8-15 → 2 and 16+ → 3.
  static int _stage(int value, List<int> thresholds) =>
      thresholds.where((t) => value >= t).length;
}
