import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/activity_ledger.dart';
import 'package:nudge/services/focus_activity_ledger_controller.dart';

void main() {
  test(
    'records one stable lifecycle for a paused and completed focus',
    () async {
      final events = <({String id, ActivityEventType type, int seconds})>[];
      final controller = FocusActivityLedgerController(
        clock: () => DateTime.utc(2026, 7, 28, 2),
        sessionIdFactory: (_) => 'focus-session-1',
        eventSink:
            ({
              required sessionId,
              required eventType,
              required elapsedSeconds,
              required occurredAt,
            }) async {
              events.add((
                id: sessionId,
                type: eventType,
                seconds: elapsedSeconds,
              ));
            },
      );

      await controller.startOrResume(elapsedSeconds: 0);
      await controller.startOrResume(elapsedSeconds: 3);
      await controller.pause(elapsedSeconds: 600);
      await controller.pause(elapsedSeconds: 601);
      await controller.startOrResume(elapsedSeconds: 600);
      await controller.complete(elapsedSeconds: 1500);

      expect(events, [
        (id: 'focus-session-1', type: ActivityEventType.started, seconds: 0),
        (id: 'focus-session-1', type: ActivityEventType.paused, seconds: 600),
        (id: 'focus-session-1', type: ActivityEventType.resumed, seconds: 600),
        (
          id: 'focus-session-1',
          type: ActivityEventType.completed,
          seconds: 1500,
        ),
      ]);
      expect(controller.hasActiveSession, isFalse);
    },
  );

  test('discard closes a session and the next start gets a new id', () async {
    final eventIds = <String>[];
    var sequence = 0;
    final controller = FocusActivityLedgerController(
      sessionIdFactory: (_) => 'focus-session-${++sequence}',
      eventSink:
          ({
            required sessionId,
            required eventType,
            required elapsedSeconds,
            required occurredAt,
          }) async {
            eventIds.add('$sessionId:${eventType.name}:$elapsedSeconds');
          },
    );

    await controller.startOrResume(elapsedSeconds: 0);
    await controller.discard(elapsedSeconds: -1);
    await controller.startOrResume(elapsedSeconds: 0);

    expect(eventIds, [
      'focus-session-1:started:0',
      'focus-session-1:discarded:0',
      'focus-session-2:started:0',
    ]);
    expect(controller.sessionId, 'focus-session-2');
  });
}
