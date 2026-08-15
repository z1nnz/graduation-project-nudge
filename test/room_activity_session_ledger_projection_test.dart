import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/room_activity_session.dart';

void main() {
  test('canonical Ledger session restores a room activity for App UI', () {
    final session = RoomActivitySession.fromCanonicalLedger({
      'activitySessionId': 'session-1',
      'actorUserId': 'user-1',
      'activityType': 'focus',
      'status': 'paused',
      'source': 'app',
      'roomIds': ['room-a'],
      'roomTargetValue': 50,
      'startedAt': '2026-08-15T08:00:00.000Z',
      'updatedAt': '2026-08-15T08:25:00.000Z',
      'endedAt': null,
      'metricValue': 25,
      'metricUnit': 'minutes',
      'sourceSessionIds': ['session-1'],
    }, expectedRoomId: 'room-a');

    expect(session.sessionId, 'session-1');
    expect(session.roomId, 'room-a');
    expect(session.actorId, 'user-1');
    expect(session.activityKind, RoomActivityKind.focus);
    expect(session.status, RoomActivitySessionStatus.paused);
    expect(session.source, RoomActivitySource.app);
    expect(session.targetValue, 50);
    expect(session.metricValue, 25);
    expect(session.updatedAt, DateTime.parse('2026-08-15T08:25:00.000Z'));
  });

  test('canonical Ledger session rejects another room context', () {
    expect(
      () => RoomActivitySession.fromCanonicalLedger({
        'activitySessionId': 'session-1',
        'actorUserId': 'user-1',
        'activityType': 'focus',
        'status': 'active',
        'source': 'web',
        'roomIds': ['room-a'],
        'roomTargetValue': 25,
        'startedAt': '2026-08-15T08:00:00.000Z',
        'updatedAt': '2026-08-15T08:00:00.000Z',
        'endedAt': null,
        'metricValue': 0,
        'metricUnit': 'minutes',
        'sourceSessionIds': ['session-1'],
      }, expectedRoomId: 'room-b'),
      throwsFormatException,
    );
  });
}
