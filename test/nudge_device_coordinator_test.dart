import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/activity_ledger.dart';
import 'package:nudge/services/android_nudge_ble_transport.dart';
import 'package:nudge/services/nudge_device_bridge.dart';
import 'package:nudge/services/nudge_device_coordinator.dart';

class FakeBleTransport implements NudgeBleTransport {
  final controller = StreamController<NudgeBleTransportEvent>.broadcast();
  final commands = <String>[];
  final pendingEvents = <String>[];
  int scans = 0;
  int disconnects = 0;

  @override
  Stream<NudgeBleTransportEvent> get events => controller.stream;

  @override
  Future<void> scanAndConnect() async => scans++;

  @override
  Future<void> disconnect() async => disconnects++;

  @override
  Future<String> readPendingEvent() async =>
      pendingEvents.isEmpty ? '' : pendingEvents.removeAt(0);

  @override
  Future<void> writeCommand(String commandJson) async {
    commands.add(commandJson);
  }

  Future<void> close() => controller.close();
}

String activityEvent() => jsonEncode({
  'protocolVersion': 1,
  'messageType': 'activity_event',
  'eventId': 'nudge-a1b2c3:focus-42:started:1',
  'sourceRecordId': 'nudge-a1b2c3:focus-42:started:1',
  'deviceId': 'nudge-a1b2c3',
  'sessionId': 'focus-42',
  'sequence': 1,
  'activityType': 'focus',
  'eventType': 'started',
  'metricValue': 0,
  'metricUnit': 'minutes',
  'occurredAtEpochMs': 1786759200000,
});

void main() {
  test('pending BLE events are durably queued before ACK', () async {
    final transport = FakeBleTransport()..pendingEvents.add(activityEvent());
    final operations = <String>[];
    final bridge = NudgeDeviceBridge(
      resolveAssignment: (_) async => const DeviceAssignmentGrant(
        deviceId: 'nudge-a1b2c3',
        userId: 'alice',
      ),
      resolveRoomIds: (_) async => const ['room-study'],
      currentActorUserId: () => 'alice',
      enqueueEvidence: (_) async => operations.add('durable'),
      writeAcknowledgement: (command) async {
        operations.add('ack');
        await transport.writeCommand(command);
      },
    );
    final coordinator = NudgeDeviceCoordinator(
      transport: transport,
      bridge: bridge,
    );

    await coordinator.start();
    transport.controller.add(
      const NudgeBleTransportEvent(
        type: NudgeBleEventType.connected,
        deviceId: 'nudge-a1b2c3',
      ),
    );
    transport.controller.add(
      const NudgeBleTransportEvent(
        type: NudgeBleEventType.state,
        deviceId: 'nudge-a1b2c3',
        payload: '{"v":1,"phase":"running","remaining":120,"pending":1}',
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(operations, ['durable', 'ack']);
    expect(coordinator.state.pendingEvents, 0);
    expect(coordinator.state.phase, 'running');
    expect(transport.commands.single, contains('"type":"ack"'));
    await coordinator.close();
    await transport.close();
  });

  test('configure requires a connected assigned device', () async {
    final transport = FakeBleTransport();
    final coordinator = NudgeDeviceCoordinator(
      transport: transport,
      bridge: NudgeDeviceBridge(
        resolveAssignment: (_) async => null,
        resolveRoomIds: (_) async => const [],
        currentActorUserId: () => 'alice',
        enqueueEvidence: (_) async {},
        writeAcknowledgement: transport.writeCommand,
      ),
      validateAssignment: (_) async => false,
    );

    await expectLater(
      coordinator.configureFocus(
        sessionId: 'focus-42',
        activityCorrelationId: 'focus-42',
        durationSeconds: 1500,
      ),
      throwsStateError,
    );
    await coordinator.close();
    await transport.close();
  });

  test('lifecycle action revalidates assignment after connection', () async {
    final transport = FakeBleTransport();
    var assigned = true;
    final coordinator = NudgeDeviceCoordinator(
      transport: transport,
      bridge: NudgeDeviceBridge(
        resolveAssignment: (_) async => null,
        resolveRoomIds: (_) async => const [],
        currentActorUserId: () => 'alice',
        enqueueEvidence: (_) async {},
        writeAcknowledgement: transport.writeCommand,
      ),
      validateAssignment: (_) async => assigned,
    );
    await coordinator.start();
    transport.controller.add(
      const NudgeBleTransportEvent(
        type: NudgeBleEventType.connected,
        deviceId: 'nudge-a1b2c3',
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(coordinator.state.status, NudgeDeviceConnectionStatus.connected);

    assigned = false;
    await expectLater(coordinator.sendAction('start'), throwsStateError);

    expect(transport.commands, isEmpty);
    expect(transport.disconnects, 1);
    expect(coordinator.state.status, NudgeDeviceConnectionStatus.error);
    await coordinator.close();
    await transport.close();
  });
}
