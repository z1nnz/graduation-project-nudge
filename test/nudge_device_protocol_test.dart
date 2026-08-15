import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/activity_ledger.dart';
import 'package:nudge/services/nudge_device_protocol.dart';

void main() {
  const payload = <String, dynamic>{
    'protocolVersion': 1,
    'messageType': 'activity_event',
    'eventId': 'desk-1:focus-42:completed:8',
    'sourceRecordId': 'desk-1:focus-42:completed:8',
    'deviceId': 'desk-1',
    'sessionId': 'focus-42',
    'activityCorrelationId': 'focus-cloud-42',
    'sequence': 8,
    'activityType': 'focus',
    'eventType': 'completed',
    'metricValue': 25.0,
    'metricUnit': 'minutes',
    'occurredAtEpochMs': 1786759200000,
  };

  test('maps a validated device event into canonical Ledger evidence', () {
    final event = NudgeDeviceActivityEvent.fromJson(payload);
    final evidence = event.toEvidence(
      actorUserId: 'alice',
      roomIds: const ['room-study'],
    );

    expect(event.sequence, 8);
    expect(evidence.eventId, payload['eventId']);
    expect(evidence.sourceRecordId, payload['sourceRecordId']);
    expect(evidence.sessionId, 'focus-42');
    expect(evidence.activityCorrelationId, 'focus-cloud-42');
    expect(evidence.submittedByUserId, 'alice');
    expect(evidence.actorUserId, 'alice');
    expect(evidence.roomIds, const ['room-study']);
    expect(evidence.activityType, ActivityType.focus);
    expect(evidence.source, ActivitySource.app);
    expect(evidence.eventType, ActivityEventType.completed);
    expect(evidence.metricValue, 25);
    expect(evidence.metricUnit, 'minutes');
    expect(
      evidence.occurredAt,
      DateTime.fromMillisecondsSinceEpoch(1786759200000, isUtc: true),
    );
    expect(evidence.deviceId, isNull);
  });

  test('rejects unsupported protocol versions', () {
    expect(
      () =>
          NudgeDeviceActivityEvent.fromJson({...payload, 'protocolVersion': 2}),
      throwsA(isA<DeviceMessageFormatException>()),
    );
  });

  test(
    'rejects an event id that does not bind the device session and sequence',
    () {
      expect(
        () => NudgeDeviceActivityEvent.fromJson({
          ...payload,
          'eventId': 'attacker-controlled-id',
          'sourceRecordId': 'attacker-controlled-id',
        }),
        throwsA(isA<DeviceMessageFormatException>()),
      );
    },
  );

  test('rejects non-focus metrics and impossible completion values', () {
    expect(
      () => NudgeDeviceActivityEvent.fromJson({
        ...payload,
        'metricUnit': 'seconds',
      }),
      throwsA(isA<DeviceMessageFormatException>()),
    );
    expect(
      () => NudgeDeviceActivityEvent.fromJson({...payload, 'metricValue': -1}),
      throwsA(isA<DeviceMessageFormatException>()),
    );
  });

  test('requires assignment identity from the trusted App boundary', () {
    final event = NudgeDeviceActivityEvent.fromJson(payload);

    expect(
      () => event.toEvidence(actorUserId: ' ', roomIds: const []),
      throwsArgumentError,
    );
  });

  test('rejects identifiers whose composed Ledger identity exceeds 256', () {
    final longId = 'a' * 96;
    expect(
      () => NudgeDeviceActivityEvent.fromJson({
        ...payload,
        'deviceId': longId,
        'sessionId': longId,
        'eventId': '$longId:$longId:completed:${'9' * 60}',
        'sourceRecordId': '$longId:$longId:completed:${'9' * 60}',
        'sequence': int.parse('9' * 18),
      }),
      throwsA(isA<DeviceMessageFormatException>()),
    );
  });
}
