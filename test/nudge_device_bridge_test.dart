import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/activity_ledger.dart';
import 'package:nudge/services/nudge_device_bridge.dart';

void main() {
  final eventJson = jsonEncode({
    'protocolVersion': 1,
    'messageType': 'activity_event',
    'eventId': 'desk-1:focus-42:completed:8',
    'sourceRecordId': 'desk-1:focus-42:completed:8',
    'deviceId': 'desk-1',
    'sessionId': 'focus-42',
    'sequence': 8,
    'activityType': 'focus',
    'eventType': 'completed',
    'metricValue': 25,
    'metricUnit': 'minutes',
    'occurredAtEpochMs': 1786759200000,
  });

  test('ACKs only after assigned evidence is durably enqueued', () async {
    final operations = <String>[];
    ActivityEvidence? queued;
    final bridge = NudgeDeviceBridge(
      resolveAssignment: (deviceId) async => NudgeDeviceAssignment(
        deviceId: deviceId,
        actorUserId: 'alice',
        roomIds: const ['room-study'],
      ),
      enqueueEvidence: (evidence) async {
        queued = evidence;
        operations.add('enqueued');
      },
      writeAcknowledgement: (command) async {
        expect(jsonDecode(command), {
          'protocolVersion': 1,
          'type': 'ack',
          'eventId': 'desk-1:focus-42:completed:8',
        });
        operations.add('acked');
      },
    );

    final evidence = await bridge.acceptEventJson(eventJson);

    expect(operations, ['enqueued', 'acked']);
    expect(queued, same(evidence));
    expect(evidence.submittedByUserId, 'alice');
    expect(evidence.source, ActivitySource.app);
    expect(evidence.deviceId, isNull);
    expect(evidence.sourceRecordId, startsWith('desk-1:'));
  });

  test('does not ACK when durable enqueue fails', () async {
    var acknowledgements = 0;
    final bridge = NudgeDeviceBridge(
      resolveAssignment: (_) async =>
          const NudgeDeviceAssignment(deviceId: 'desk-1', actorUserId: 'alice'),
      enqueueEvidence: (_) async => throw StateError('disk full'),
      writeAcknowledgement: (_) async => acknowledgements++,
    );

    await expectLater(bridge.acceptEventJson(eventJson), throwsStateError);
    expect(acknowledgements, 0);
  });

  test('rejects inactive or mismatched assignments before enqueue', () async {
    var enqueues = 0;
    final bridge = NudgeDeviceBridge(
      resolveAssignment: (_) async => const NudgeDeviceAssignment(
        deviceId: 'another-device',
        actorUserId: 'alice',
      ),
      enqueueEvidence: (_) async => enqueues++,
      writeAcknowledgement: (_) async {},
    );

    await expectLater(bridge.acceptEventJson(eventJson), throwsStateError);
    expect(enqueues, 0);
  });
}
