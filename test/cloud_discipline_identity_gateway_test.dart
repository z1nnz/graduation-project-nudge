import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/discipline_identity_snapshot.dart';
import 'package:nudge/services/cloud_discipline_identity_gateway.dart';

Map<String, dynamic> responseSnapshot() => {
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
    'key': 'steady_builder',
    'title': '穩定築路者',
    'description': '持續留下行動紀錄。',
  },
  'recovery': {
    'state': 'steady',
    'recommendedFocusMinutes': 25,
    'message': '依自己的負荷選擇下一個行動。',
  },
  'metrics': {
    'activeDays': 8,
    'completedSessions': 12,
    'focusMinutes': 240,
    'exerciseMinutes': 30,
    'activityKinds': ['exercise', 'focus'],
    'lastActiveDay': '2026-08-15',
  },
  'updatedAt': '2026-08-15T10:00:00.000Z',
};

void main() {
  test('refresh validates the signed-in user snapshot', () async {
    Map<String, dynamic>? payload;
    final gateway = CloudDisciplineIdentityGateway.withCallable((value) async {
      payload = value;
      return {'snapshot': responseSnapshot()};
    });

    final snapshot = await gateway.refresh(expectedUserId: 'user-1');

    expect(payload, isEmpty);
    expect(snapshot.personaKey, DisciplinePersonaKey.steadyBuilder);
  });

  test('refresh rejects a malformed callable response', () async {
    final gateway = CloudDisciplineIdentityGateway.withCallable(
      (_) async => {'snapshot': 'invalid'},
    );

    await expectLater(
      gateway.refresh(expectedUserId: 'user-1'),
      throwsA(isA<DisciplineIdentityException>()),
    );
  });
}
