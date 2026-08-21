import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/activity_ledger.dart';
import 'package:nudge/services/android_nudge_ble_transport.dart';
import 'package:nudge/services/nudge_device_bridge.dart';
import 'package:nudge/services/nudge_device_coordinator.dart';
import 'package:nudge/services/nudge_device_presentation.dart';

class FakeBleTransport implements NudgeBleTransport {
  final controller = StreamController<NudgeBleTransportEvent>.broadcast();
  final commands = <String>[];
  final pendingEvents = <String>[];
  int scans = 0;
  int disconnects = 0;
  bool acknowledgeContextWrites = true;

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
    final decoded = jsonDecode(commandJson);
    if (acknowledgeContextWrites &&
        decoded is Map &&
        const {'context', 'sound'}.contains(decoded['type'])) {
      controller.add(
        NudgeBleTransportEvent(
          type: NudgeBleEventType.state,
          deviceId: 'nudge-a1b2c3',
          payload: jsonEncode({
            'v': 1,
            'phase': 'idle',
            'remaining': 0,
            'pending': 0,
            'selectedRoomId': decoded['selectedRoomId'] ?? 'room-b',
            'contextRevision': decoded['contextRevision'],
          }),
        ),
      );
    }
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
  'roomContextId': 'room-study',
  'sequence': 1,
  'activityType': 'focus',
  'eventType': 'started',
  'metricValue': 0,
  'metricUnit': 'minutes',
  'occurredAtEpochMs': 1786759200000,
});

void emitDeviceState(FakeBleTransport transport, {int contextRevision = 0}) {
  transport.controller.add(
    NudgeBleTransportEvent(
      type: NudgeBleEventType.state,
      deviceId: 'nudge-a1b2c3',
      payload: jsonEncode({
        'v': 1,
        'phase': 'idle',
        'remaining': 0,
        'pending': 0,
        'contextRevision': contextRevision,
      }),
    ),
  );
}

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

  test(
    'presentation is filtered by the Cloud assignment before BLE write',
    () async {
      final transport = FakeBleTransport();
      const assignment = DeviceAssignmentGrant(
        deviceId: 'nudge-a1b2c3',
        userId: 'alice',
        allowedRoomIds: ['room-b'],
      );
      final coordinator = NudgeDeviceCoordinator(
        transport: transport,
        bridge: NudgeDeviceBridge(
          resolveAssignment: (_) async => assignment,
          resolveRoomIds: (_) async => assignment.allowedRoomIds,
          currentActorUserId: () => 'alice',
          enqueueEvidence: (_) async {},
          writeAcknowledgement: transport.writeCommand,
        ),
        validateAssignment: (_) async => true,
        resolveAssignment: (_) async => assignment,
      );
      await coordinator.start();
      transport.controller.add(
        const NudgeBleTransportEvent(
          type: NudgeBleEventType.connected,
          deviceId: 'nudge-a1b2c3',
        ),
      );
      emitDeviceState(transport);
      await Future<void>.delayed(Duration.zero);

      final selected = await coordinator.syncPresentation(
        const NudgeDevicePresentation(
          rooms: [
            NudgeDeviceRoomContext(
              id: 'room-a',
              label: 'Study',
              goalLabel: '25 min',
            ),
            NudgeDeviceRoomContext(
              id: 'room-b',
              label: 'Walk',
              goalLabel: '6000 steps',
            ),
          ],
          selectedRoomId: 'room-a',
          personalGoalLabel: 'Focus 25 min',
          character: NudgeDeviceCharacterContext(
            name: 'Nudgie',
            level: 3,
            stage: 2,
          ),
        ),
      );

      expect(selected, 'room-b');
      expect(transport.commands.single, contains('"id":"room-b"'));
      expect(transport.commands.single, isNot(contains('"id":"room-a"')));

      await coordinator.syncSoundEnabled(false);
      expect(transport.commands, hasLength(2));
      expect(transport.commands.last, contains('"type":"sound"'));
      expect(transport.commands.last, contains('"enabled":false'));
      expect(transport.commands.last, isNot(contains('"rooms"')));
      await coordinator.close();
      await transport.close();
    },
  );

  test(
    'presentation requires the device persistence acknowledgement',
    () async {
      final transport = FakeBleTransport()..acknowledgeContextWrites = false;
      const assignment = DeviceAssignmentGrant(
        deviceId: 'nudge-a1b2c3',
        userId: 'alice',
      );
      final coordinator = NudgeDeviceCoordinator(
        transport: transport,
        bridge: NudgeDeviceBridge(
          resolveAssignment: (_) async => assignment,
          resolveRoomIds: (_) async => const [],
          currentActorUserId: () => 'alice',
          enqueueEvidence: (_) async {},
          writeAcknowledgement: transport.writeCommand,
        ),
        validateAssignment: (_) async => true,
        resolveAssignment: (_) async => assignment,
        contextAckTimeout: const Duration(milliseconds: 10),
      );
      await coordinator.start();
      transport.controller.add(
        const NudgeBleTransportEvent(
          type: NudgeBleEventType.connected,
          deviceId: 'nudge-a1b2c3',
        ),
      );
      emitDeviceState(transport);
      await Future<void>.delayed(Duration.zero);

      await expectLater(
        coordinator.syncPresentation(
          const NudgeDevicePresentation(
            rooms: [],
            selectedRoomId: null,
            personalGoalLabel: 'Focus',
            character: NudgeDeviceCharacterContext(
              name: 'Nudgie',
              level: 1,
              stage: 1,
            ),
          ),
        ),
        throwsStateError,
      );
      await coordinator.close();
      await transport.close();
    },
  );

  test('a later revision cannot acknowledge a lost mutation', () async {
    final transport = FakeBleTransport()..acknowledgeContextWrites = false;
    const assignment = DeviceAssignmentGrant(
      deviceId: 'nudge-a1b2c3',
      userId: 'alice',
    );
    final coordinator = NudgeDeviceCoordinator(
      transport: transport,
      bridge: NudgeDeviceBridge(
        resolveAssignment: (_) async => assignment,
        resolveRoomIds: (_) async => const [],
        currentActorUserId: () => 'alice',
        enqueueEvidence: (_) async {},
        writeAcknowledgement: transport.writeCommand,
      ),
      validateAssignment: (_) async => true,
      resolveAssignment: (_) async => assignment,
      contextAckTimeout: const Duration(milliseconds: 20),
    );
    await coordinator.start();
    transport.controller.add(
      const NudgeBleTransportEvent(
        type: NudgeBleEventType.connected,
        deviceId: 'nudge-a1b2c3',
      ),
    );
    emitDeviceState(transport);
    await Future<void>.delayed(Duration.zero);

    final pending = coordinator.syncPresentation(
      const NudgeDevicePresentation(
        rooms: [],
        selectedRoomId: null,
        personalGoalLabel: 'Focus',
        character: NudgeDeviceCharacterContext(
          name: 'Nudgie',
          level: 1,
          stage: 1,
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    final revision =
        (jsonDecode(transport.commands.single) as Map)['contextRevision']
            as int;
    emitDeviceState(transport, contextRevision: revision + 1);

    await expectLater(pending, throwsStateError);
    await coordinator.close();
    await transport.close();
  });
}
