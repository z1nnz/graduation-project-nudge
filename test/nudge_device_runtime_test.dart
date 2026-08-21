import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/services/activity_ledger_outbox.dart';
import 'package:nudge/services/android_nudge_ble_transport.dart';
import 'package:nudge/services/cloud_activity_ledger_gateway.dart';
import 'package:nudge/services/firestore_device_assignment_repository.dart';
import 'package:nudge/services/nudge_device_runtime.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RuntimeBleTransport implements NudgeBleTransport {
  final eventsController = StreamController<NudgeBleTransportEvent>.broadcast();
  final pendingEvents = <String>[];
  final commands = <String>[];

  @override
  Stream<NudgeBleTransportEvent> get events => eventsController.stream;

  @override
  Future<void> scanAndConnect() async {}

  @override
  Future<String> readPendingEvent() async => pendingEvents.removeAt(0);

  @override
  Future<void> writeCommand(String commandJson) async {
    commands.add(commandJson);
  }

  @override
  Future<void> disconnect() async {}
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'runtime resolves Cloud assignment and flushes only after durable ACK',
    () async {
      final operations = <String>[];
      final transport = _RuntimeBleTransport();
      final outbox = ActivityLedgerOutbox(
        gateway: CloudActivityLedgerGateway.withCallable((request) async {
          operations.add('cloud');
          final evidence = request['evidence'] as Map<String, dynamic>;
          return {
            'status': 'accepted',
            'acknowledgedEventId': evidence['eventId'],
            'acknowledgedSourceRecordId': evidence['sourceRecordId'],
            'canonicalSessionId': 'focus-42',
            'wasDuplicate': false,
            'receipt': null,
            'contributions': const [],
            'session': {
              'activitySessionId': 'focus-42',
              'actorUserId': 'alice',
              'activityType': 'focus',
              'status': 'active',
              'startedAt': '2026-08-15T10:00:00.000Z',
              'endedAt': null,
              'metricValue': 0,
              'metricUnit': 'minutes',
              'sourceSessionIds': ['focus-42'],
            },
          };
        }),
        getActorId: () => 'alice',
        writePending: (encoded) async {
          operations.add('durable');
          return (await SharedPreferences.getInstance()).setString(
            'activity_ledger_outbox_v1',
            encoded,
          );
        },
      );
      final runtime = NudgeDeviceRuntime(
        transport: transport,
        assignmentRepository: FirestoreDeviceAssignmentRepository.withReader(
          (_) async => {
            'schemaVersion': 1,
            'assignmentId': 'nudge-a1b2c3',
            'deviceId': 'nudge-a1b2c3',
            'assignedUserId': 'alice',
            'status': 'active',
            'allowedRoomIds': ['room-study'],
            'validFrom': '2026-08-15T01:00:00.000Z',
            'validUntil': null,
            'updatedAt': '2026-08-15T01:00:00.000Z',
          },
        ),
        activityLedgerOutbox: outbox,
        currentActorUserId: () => 'alice',
        prepareFocusCorrelation: () async => 'focus-42',
      );
      transport.pendingEvents.add(
        jsonEncode({
          'protocolVersion': 1,
          'messageType': 'activity_event',
          'eventId': 'nudge-a1b2c3:focus-42:started:1',
          'sourceRecordId': 'nudge-a1b2c3:focus-42:started:1',
          'deviceId': 'nudge-a1b2c3',
          'sessionId': 'focus-42',
          'activityCorrelationId': 'focus-42',
          'sequence': 1,
          'activityType': 'focus',
          'eventType': 'started',
          'metricValue': 0,
          'metricUnit': 'minutes',
          'occurredAtEpochMs': 1786759200000,
        }),
      );

      await runtime.coordinator.start();
      transport.eventsController.add(
        const NudgeBleTransportEvent(
          type: NudgeBleEventType.connected,
          deviceId: 'nudge-a1b2c3',
        ),
      );
      transport.eventsController.add(
        const NudgeBleTransportEvent(
          type: NudgeBleEventType.state,
          deviceId: 'nudge-a1b2c3',
          payload: '{"v":1,"phase":"running","remaining":120,"pending":1}',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await runtime.flushCloudEvents();

      expect(operations.take(2), ['durable', 'cloud']);
      expect(jsonDecode(transport.commands.single)['type'], 'ack');
      expect(await outbox.pendingCount(), 0);

      await runtime.close();
      await transport.eventsController.close();
    },
  );
}
