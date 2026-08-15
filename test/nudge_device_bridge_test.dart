import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/activity_ledger.dart';
import 'package:nudge/services/activity_ledger_outbox.dart';
import 'package:nudge/services/cloud_activity_ledger_gateway.dart';
import 'package:nudge/services/nudge_device_bridge.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('ACKs only after assigned evidence is durably enqueued', () async {
    final operations = <String>[];
    ActivityEvidence? queued;
    final bridge = NudgeDeviceBridge(
      resolveAssignment: (deviceId) async =>
          DeviceAssignmentGrant(deviceId: deviceId, userId: 'alice'),
      resolveRoomIds: (_) async => const ['room-study'],
      currentActorUserId: () => 'alice',
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
          const DeviceAssignmentGrant(deviceId: 'desk-1', userId: 'alice'),
      resolveRoomIds: (_) async => const [],
      currentActorUserId: () => 'alice',
      enqueueEvidence: (_) async => throw StateError('disk full'),
      writeAcknowledgement: (_) async => acknowledgements++,
    );

    await expectLater(bridge.acceptEventJson(eventJson), throwsStateError);
    expect(acknowledgements, 0);
  });

  test('rejects inactive or mismatched assignments before enqueue', () async {
    var enqueues = 0;
    final bridge = NudgeDeviceBridge(
      resolveAssignment: (_) async => const DeviceAssignmentGrant(
        deviceId: 'another-device',
        userId: 'alice',
      ),
      resolveRoomIds: (_) async => const [],
      currentActorUserId: () => 'alice',
      enqueueEvidence: (_) async => enqueues++,
      writeAcknowledgement: (_) async {},
    );

    await expectLater(bridge.acceptEventJson(eventJson), throwsStateError);
    expect(enqueues, 0);
  });

  test('validates occurrence-time assignment and signed-in account', () async {
    var enqueues = 0;
    final expiredBridge = NudgeDeviceBridge(
      resolveAssignment: (_) async => DeviceAssignmentGrant(
        deviceId: 'desk-1',
        userId: 'alice',
        validUntil: DateTime.fromMillisecondsSinceEpoch(
          1786759200000,
          isUtc: true,
        ),
      ),
      resolveRoomIds: (_) async => const [],
      currentActorUserId: () => 'alice',
      enqueueEvidence: (_) async => enqueues++,
      writeAcknowledgement: (_) async {},
    );
    final switchedAccountBridge = NudgeDeviceBridge(
      resolveAssignment: (_) async =>
          const DeviceAssignmentGrant(deviceId: 'desk-1', userId: 'alice'),
      resolveRoomIds: (_) async => const [],
      currentActorUserId: () => 'bob',
      enqueueEvidence: (_) async => enqueues++,
      writeAcknowledgement: (_) async {},
    );

    await expectLater(
      expiredBridge.acceptEventJson(eventJson),
      throwsStateError,
    );
    await expectLater(
      switchedAccountBridge.acceptEventJson(eventJson),
      throwsStateError,
    );
    expect(enqueues, 0);
  });

  test('real outbox is reopenably durable before ACK', () async {
    final gateway = CloudActivityLedgerGateway.withCallable((_) async => null);
    final outbox = ActivityLedgerOutbox(
      gateway: gateway,
      getActorId: () => 'alice',
    );
    final bridge = NudgeDeviceBridge.withOutbox(
      resolveAssignment: (_) async =>
          const DeviceAssignmentGrant(deviceId: 'desk-1', userId: 'alice'),
      resolveRoomIds: (_) async => const [],
      currentActorUserId: () => 'alice',
      outbox: outbox,
      writeAcknowledgement: (_) async {
        final reopened = ActivityLedgerOutbox(
          gateway: gateway,
          getActorId: () => 'alice',
        );
        expect(await reopened.pendingCount(), 1);
      },
    );

    await bridge.acceptEventJson(eventJson);
    expect(await outbox.pendingCount(), 1);
  });
}
