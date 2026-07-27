import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/room_activity_session.dart';

void main() {
  final startedAt = DateTime.utc(2026, 7, 27, 9);

  test('member starts and owns their own room activity session', () {
    final session = RoomActivitySession.start(
      sessionId: 'session-alice-focus',
      roomId: 'room-study',
      actorId: 'alice',
      activityKind: RoomActivityKind.focus,
      metricUnit: 'minutes',
      targetValue: 25,
      source: RoomActivitySource.app,
      now: startedAt,
    );

    expect(session.status, RoomActivitySessionStatus.active);
    expect(session.metricValue, 0);
    expect(session.actorId, 'alice');
    expect(session.toJson()['activityKind'], 'focus');
  });

  test('member can pause, resume, and complete without a room owner', () {
    final started = RoomActivitySession.start(
      sessionId: 'session-alice-exercise',
      roomId: 'room-exercise',
      actorId: 'alice',
      activityKind: RoomActivityKind.exercise,
      metricUnit: 'minutes',
      targetValue: 30,
      source: RoomActivitySource.web,
      now: startedAt,
    );

    final paused = started.transition(
      actorId: 'alice',
      nextStatus: RoomActivitySessionStatus.paused,
      metricValue: 12,
      now: startedAt.add(const Duration(minutes: 12)),
    );
    final resumed = paused.transition(
      actorId: 'alice',
      nextStatus: RoomActivitySessionStatus.active,
      metricValue: 12,
      now: startedAt.add(const Duration(minutes: 15)),
    );
    final completed = resumed.transition(
      actorId: 'alice',
      nextStatus: RoomActivitySessionStatus.completed,
      metricValue: 30,
      now: startedAt.add(const Duration(minutes: 33)),
    );

    expect(paused.status, RoomActivitySessionStatus.paused);
    expect(resumed.status, RoomActivitySessionStatus.active);
    expect(completed.status, RoomActivitySessionStatus.completed);
    expect(completed.endedAt, isNotNull);
  });

  test('room owner cannot transition another member session', () {
    final session = RoomActivitySession.start(
      sessionId: 'session-alice-steps',
      roomId: 'room-steps',
      actorId: 'alice',
      activityKind: RoomActivityKind.steps,
      metricUnit: 'steps',
      targetValue: 8000,
      source: RoomActivitySource.health,
      now: startedAt,
    );

    expect(
      () => session.transition(
        actorId: 'room-owner',
        nextStatus: RoomActivitySessionStatus.completed,
        metricValue: 8000,
        now: startedAt.add(const Duration(hours: 8)),
      ),
      throwsStateError,
    );
  });

  test('terminal sessions cannot resume and progress cannot decrease', () {
    final started = RoomActivitySession.start(
      sessionId: 'session-alice-sleep',
      roomId: 'room-sleep',
      actorId: 'alice',
      activityKind: RoomActivityKind.sleep,
      metricUnit: 'hours',
      targetValue: 7,
      source: RoomActivitySource.health,
      now: startedAt,
    );
    final completed = started.transition(
      actorId: 'alice',
      nextStatus: RoomActivitySessionStatus.completed,
      metricValue: 7.5,
      now: startedAt.add(const Duration(hours: 8)),
    );

    expect(
      () => completed.transition(
        actorId: 'alice',
        nextStatus: RoomActivitySessionStatus.active,
        metricValue: 7.5,
        now: startedAt.add(const Duration(hours: 9)),
      ),
      throwsStateError,
    );
    expect(
      () => started.transition(
        actorId: 'alice',
        nextStatus: RoomActivitySessionStatus.paused,
        metricValue: -1,
        now: startedAt.add(const Duration(minutes: 1)),
      ),
      throwsArgumentError,
    );
  });
}
