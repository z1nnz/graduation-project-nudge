import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/discipline_identity_snapshot.dart';

Map<String, dynamic> validSnapshot() => {
  'schemaVersion': 1,
  'snapshotId': 'user-1',
  'userId': 'user-1',
  'visibility': 'private',
  'window': {
    'days': 28,
    'startedAt': '2026-07-18T21:00:00.000Z',
    'endedAt': '2026-08-15T10:00:00.000Z',
  },
  'persona': {
    'key': 'comeback_builder',
    'title': '復原建築師',
    'description': '中斷後仍願意重新開始。',
  },
  'recovery': {
    'state': 'returning',
    'recommendedFocusMinutes': 15,
    'message': '今天再完成一個小段落就足夠。',
  },
  'metrics': {
    'activeDays': 4,
    'completedSessions': 7,
    'focusMinutes': 120,
    'exerciseMinutes': 30,
    'activityKinds': ['exercise', 'focus'],
    'lastActiveDay': '2026-08-15',
  },
  'updatedAt': '2026-08-15T10:00:00.000Z',
};

void main() {
  test('parses a Cloud-built discipline identity snapshot', () {
    final snapshot = DisciplineIdentitySnapshot.fromMap(
      validSnapshot(),
      expectedUserId: 'user-1',
    );

    expect(snapshot.personaKey, DisciplinePersonaKey.comebackBuilder);
    expect(snapshot.recoveryState, DisciplineRecoveryState.returning);
    expect(snapshot.recommendedFocusMinutes, 15);
    expect(snapshot.activeDays, 4);
    expect(snapshot.activityKinds, ['exercise', 'focus']);
  });

  test('rejects snapshots for another user or a public visibility', () {
    expect(
      () => DisciplineIdentitySnapshot.fromMap(
        validSnapshot(),
        expectedUserId: 'other-user',
      ),
      throwsFormatException,
    );
    expect(
      () => DisciplineIdentitySnapshot.fromMap({
        ...validSnapshot(),
        'visibility': 'summary',
      }, expectedUserId: 'user-1'),
      throwsFormatException,
    );
  });

  test('rejects incomplete recovery and impossible metrics', () {
    final invalidRecovery = validSnapshot();
    invalidRecovery['recovery'] = {
      'state': 'returning',
      'recommendedFocusMinutes': 0,
      'message': '',
    };
    expect(
      () => DisciplineIdentitySnapshot.fromMap(
        invalidRecovery,
        expectedUserId: 'user-1',
      ),
      throwsFormatException,
    );

    final invalidMetrics = validSnapshot();
    invalidMetrics['metrics'] = {
      ...(validSnapshot()['metrics'] as Map<String, dynamic>),
      'activeDays': 29,
    };
    expect(
      () => DisciplineIdentitySnapshot.fromMap(
        invalidMetrics,
        expectedUserId: 'user-1',
      ),
      throwsFormatException,
    );
  });
}
