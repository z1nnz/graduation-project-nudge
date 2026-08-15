import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/room_activity_session.dart';

void main() {
  final canonicalFixtures =
      jsonDecode(
            File(
              'test/fixtures/canonical_room_activity_session_contract.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;

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

  test(
    'legacy canonical session uses room metadata until its next transition',
    () {
      final session = RoomActivitySession.fromCanonicalLedger(
        {
          'activitySessionId': 'session-before-room-contract',
          'actorUserId': 'member-a',
          'activityType': 'focus',
          'source': 'app',
          'status': 'active',
          'roomIds': ['room-a'],
          'metricValue': 10,
          'metricUnit': 'minutes',
          'startedAt': '2026-08-08T08:00:00.000Z',
          'endedAt': null,
        },
        expectedRoomId: 'room-a',
        fallbackTargetValue: 25,
      );

      expect(session.targetValue, 25);
      expect(session.updatedAt, DateTime.utc(2026, 8, 8, 8));
    },
  );

  test('one canonical session keeps an independent presentation per room', () {
    final sessions = RoomActivitySessionLedgerProjection.restore(
      documents: [
        {
          'activitySessionId': 'session-shared',
          'actorUserId': 'member-a',
          'activityType': 'focus',
          'source': 'app',
          'status': 'active',
          'roomIds': ['room-a', 'room-b'],
          'roomTargetValue': 25,
          'metricValue': 10,
          'metricUnit': 'minutes',
          'startedAt': '2026-08-15T08:00:00.000Z',
          'updatedAt': '2026-08-15T08:10:00.000Z',
          'endedAt': null,
        },
      ],
      actorUserId: 'member-a',
      roomTargetValues: const {'room-a': 25, 'room-b': 40},
    );

    expect(sessions, hasLength(2));
    expect(
      sessions[RoomActivitySessionLedgerProjection.key(
            'room-a',
            'session-shared',
          )]
          ?.roomId,
      'room-a',
    );
    expect(
      sessions[RoomActivitySessionLedgerProjection.key(
            'room-b',
            'session-shared',
          )]
          ?.roomId,
      'room-b',
    );
  });

  test('App and Web share malformed canonical session fixtures', () {
    expect(
      () => RoomActivitySession.fromCanonicalLedger(
        Map<String, dynamic>.from(canonicalFixtures['valid'] as Map),
        expectedRoomId: 'room-a',
      ),
      returnsNormally,
    );
    for (final fixture in canonicalFixtures['invalid'] as List) {
      final data = Map<String, dynamic>.from(fixture as Map);
      expect(
        () => RoomActivitySession.fromCanonicalLedger(
          Map<String, dynamic>.from(data['session'] as Map),
          expectedRoomId: 'room-a',
        ),
        throwsA(anything),
        reason: data['name'] as String,
      );
    }
  });
}
