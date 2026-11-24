import 'badge_record.dart';

/// Read-only projection of an owner's server-confirmed badge dates.
class ConfirmedBadgeState {
  String? _userId;
  Map<String, DateTime>? _dates;
  int _generation = 0;
  String? get userId => _userId;
  bool get confirmed => _userId != null && _dates != null;
  int begin(String? userId) {
    _userId = userId;
    _dates = null;
    return ++_generation;
  }

  bool isCurrent(int generation) => generation == _generation;
  void fail(int generation) {
    if (isCurrent(generation)) _dates = null;
  }

  void update(
    int generation, {
    required String documentId,
    required Map<String, dynamic>? data,
    required bool fromCache,
    required bool pendingWrites,
    required DateTime now,
  }) {
    if (!isCurrent(generation)) return;
    if (_userId == null ||
        documentId != _userId ||
        data == null ||
        fromCache ||
        pendingWrites) {
      _dates = null;
      return;
    }
    final raw = data['unlockedBadgeDates'];
    if (raw != null && raw is! Map) {
      _dates = null;
      return;
    }
    final dates = <String, DateTime>{};
    if (raw is Map) {
      for (final entry in raw.entries) {
        final value = entry.value;
        if (entry.key is! String ||
            value is! String ||
            !RegExp(
              r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?(?:Z|[+-]\d{2}:\d{2})?$',
            ).hasMatch(value)) {
          continue;
        }
        final year = int.parse(value.substring(0, 4)),
            month = int.parse(value.substring(5, 7)),
            day = int.parse(value.substring(8, 10));
        if (month < 1 ||
            month > 12 ||
            day < 1 ||
            day > DateTime.utc(year, month + 1, 0).day) {
          continue;
        }
        if (int.parse(value.substring(11, 13)) > 23 ||
            int.parse(value.substring(14, 16)) > 59 ||
            int.parse(value.substring(17, 19)) > 59) {
          continue;
        }
        final at = DateTime.tryParse(value);
        if (at == null || at.isAfter(now)) continue;
        dates[entry.key as String] = at;
      }
    }
    _dates = dates;
  }

  List<BadgeRecord> project(List<BadgeRecord> progress) => [
    for (final badge in progress)
      badge.copyWith(
        userId: _userId ?? '',
        isUnlocked: _dates?[badge.badgeKey] != null,
        unlockedAt: _dates?[badge.badgeKey],
        clearUnlockedAt: _dates?[badge.badgeKey] == null,
        progress:
            _dates?[badge.badgeKey] != null && badge.progress < badge.target
            ? badge.target
            : badge.progress,
      ),
  ];
}
