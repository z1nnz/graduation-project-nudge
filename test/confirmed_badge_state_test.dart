import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/confirmed_badge_state.dart';
import 'package:nudge/models/badge_record.dart';

BadgeRecord progress() => BadgeRecord(
  id: 'badge_focus_beginner',
  userId: 'local_user',
  badgeKey: 'focus_beginner',
  badgeName: '專注新手',
  progress: 25,
  target: 25,
  updatedAt: DateTime.utc(2026, 11, 24),
);
void main() {
  test(
    'local progress cannot light a star without owner server confirmation',
    () {
      final state = ConfirmedBadgeState(), g = state.begin('owner');
      expect(state.project([progress()]).single.isUnlocked, false);
      state.update(
        g,
        documentId: 'owner',
        data: {
          'unlockedBadgeDates': {'focus_beginner': '2026-11-01T08:00:00Z'},
        },
        fromCache: false,
        pendingWrites: false,
        now: DateTime.utc(2026, 11, 24),
      );
      expect(state.confirmed, true);
      expect(state.project([progress()]).single.isUnlocked, true);
    },
  );
  test('cache, pending, another document and stale account callbacks clear or cannot restore unlocks', () {
    final state = ConfirmedBadgeState(), old = state.begin('owner');
    final data = {
      'unlockedBadgeDates': {'focus_beginner': '2026-11-01T08:00:00Z'},
    };
    state.update(
      old,
      documentId: 'owner',
      data: data,
      fromCache: false,
      pendingWrites: true,
      now: DateTime.utc(2026, 11, 24),
    );
    expect(state.confirmed, false);
    final fresh = state.begin('other');
    state.update(
      old,
      documentId: 'owner',
      data: data,
      fromCache: false,
      pendingWrites: false,
      now: DateTime.utc(2026, 11, 24),
    );
    expect(state.confirmed, false);
    state.update(
      fresh,
      documentId: 'owner',
      data: data,
      fromCache: false,
      pendingWrites: false,
      now: DateTime.utc(2026, 11, 24),
    );
    expect(state.confirmed, false);
    state.update(
      fresh,
      documentId: 'other',
      data: data,
      fromCache: true,
      pendingWrites: false,
      now: DateTime.utc(2026, 11, 24),
    );
    expect(state.confirmed, false);
  });
  test('invalid and future dates are not unlocked; unrelated badge keys do not create catalogue entries', () {
    final state = ConfirmedBadgeState(), g = state.begin('owner');
    state.update(
      g,
      documentId: 'owner',
      data: {
        'unlockedBadgeDates': {
          'focus_beginner': '2026-02-30T00:00:00Z',
          'UNKNOWN': '2026-11-01T08:00:00Z',
        },
      },
      fromCache: false,
      pendingWrites: false,
      now: DateTime.utc(2026, 11, 24),
    );
    expect(state.project([progress()]).single.isUnlocked, false);
    state.update(
      g,
      documentId: 'owner',
      data: {
        'unlockedBadgeDates': {'focus_beginner': '2027-01-01T00:00:00Z'},
      },
      fromCache: false,
      pendingWrites: false,
      now: DateTime.utc(2026, 11, 24),
    );
    expect(state.project([progress()]).single.isUnlocked, false);
  });
}
