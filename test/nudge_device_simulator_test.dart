import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/activity_ledger.dart';
import 'package:nudge/services/activity_ingestion.dart';
import 'package:nudge/services/nudge_device_simulator.dart';

class _LoseFirstAcknowledgement implements ActivityIngestion {
  final ActivityIngestion delegate;
  bool _shouldLoseAcknowledgement = true;

  _LoseFirstAcknowledgement(this.delegate);

  @override
  ActivityRecordResult recordActivity(ActivityEvidence evidence) {
    final result = delegate.recordActivity(evidence);
    if (_shouldLoseAcknowledgement) {
      _shouldLoseAcknowledgement = false;
      throw const DeviceTransportException('Simulated acknowledgement loss.');
    }
    return result;
  }
}

class _MissingSettlementReceipt implements ActivityIngestion {
  @override
  ActivityRecordResult recordActivity(ActivityEvidence evidence) {
    return ActivityRecordResult(
      status: ActivityRecordStatus.accepted,
      receipt: null,
      contributions: const [],
      wasDuplicate: false,
    );
  }
}

void main() {
  test(
    'offline device queues activity and flushes it once after reconnecting',
    () {
      final clock = DateTime.utc(2026, 7, 27, 14);
      final ingestion = InMemoryActivityIngestion(
        clock: () => clock,
        roomMemberships: const [
          RoomMembershipGrant(roomId: 'room-study', userId: 'alice'),
        ],
        deviceAssignments: const [
          DeviceAssignmentGrant(deviceId: 'desk-1', userId: 'alice'),
        ],
      );
      final device = NudgeDeviceSimulator(
        deviceId: 'desk-1',
        assignedUserId: 'alice',
        ingestion: ingestion,
        clock: () => clock,
        startsOnline: false,
      );

      device.startActivity(
        sessionId: 'device-session-1',
        roomIds: const ['room-study'],
        activityType: ActivityType.focus,
        metricUnit: 'minutes',
      );
      device.completeActivity(
        sessionId: 'device-session-1',
        roomIds: const ['room-study'],
        activityType: ActivityType.focus,
        metricValue: 25,
        metricUnit: 'minutes',
      );

      expect(device.pendingEventCount, 2);
      expect(device.confirmedResults, isEmpty);

      device.setOnline(true);

      expect(device.pendingEventCount, 0);
      expect(device.confirmedResults, hasLength(2));
      expect(
        device.confirmedResults.last.receipt!.personalRewardIssued,
        isTrue,
      );
      expect(device.confirmedResults.last.contributions, hasLength(1));
      expect(ingestion.issuedPersonalRewardCount, 1);

      device.flush();

      expect(device.confirmedResults, hasLength(2));
      expect(ingestion.issuedPersonalRewardCount, 1);
    },
  );

  test('pause and resume do not settle room progress or issue rewards', () {
    final clock = DateTime.utc(2026, 7, 27, 15);
    final ingestion = InMemoryActivityIngestion(
      clock: () => clock,
      roomMemberships: const [
        RoomMembershipGrant(roomId: 'room-study', userId: 'alice'),
      ],
      deviceAssignments: const [
        DeviceAssignmentGrant(deviceId: 'desk-1', userId: 'alice'),
      ],
    );
    final device = NudgeDeviceSimulator(
      deviceId: 'desk-1',
      assignedUserId: 'alice',
      ingestion: ingestion,
      clock: () => clock,
    );

    device.startActivity(
      sessionId: 'device-session-2',
      roomIds: const ['room-study'],
      activityType: ActivityType.focus,
      metricUnit: 'minutes',
    );
    device.pauseActivity(
      sessionId: 'device-session-2',
      roomIds: const ['room-study'],
      activityType: ActivityType.focus,
      metricValue: 10,
      metricUnit: 'minutes',
    );
    device.resumeActivity(
      sessionId: 'device-session-2',
      roomIds: const ['room-study'],
      activityType: ActivityType.focus,
      metricValue: 10,
      metricUnit: 'minutes',
    );
    device.completeActivity(
      sessionId: 'device-session-2',
      roomIds: const ['room-study'],
      activityType: ActivityType.focus,
      metricValue: 25,
      metricUnit: 'minutes',
    );

    expect(device.confirmedResults, hasLength(4));
    expect(
      device.confirmedResults
          .take(3)
          .every(
            (result) => result.receipt == null && result.contributions.isEmpty,
          ),
      isTrue,
    );
    expect(device.confirmedResults.last.receipt, isNotNull);
    expect(device.confirmedResults.last.contributions, hasLength(1));
    expect(ingestion.issuedReceiptCount, 1);
    expect(ingestion.issuedPersonalRewardCount, 1);
  });

  test('online event stays queued until a lost acknowledgement is retried', () {
    final clock = DateTime.utc(2026, 7, 27, 16);
    final ingestion = InMemoryActivityIngestion(
      clock: () => clock,
      deviceAssignments: const [
        DeviceAssignmentGrant(deviceId: 'desk-1', userId: 'alice'),
      ],
    );
    final unreliableTransport = _LoseFirstAcknowledgement(ingestion);
    final device = NudgeDeviceSimulator(
      deviceId: 'desk-1',
      assignedUserId: 'alice',
      ingestion: unreliableTransport,
      clock: () => clock,
    );

    device.completeActivity(
      sessionId: 'ack-loss-session',
      roomIds: const [],
      activityType: ActivityType.focus,
      metricValue: 25,
      metricUnit: 'minutes',
    );

    expect(device.pendingEventCount, 1);
    expect(device.confirmedResults, isEmpty);
    expect(device.lastSyncError, isA<DeviceTransportException>());
    expect(ingestion.issuedPersonalRewardCount, 1);

    device.flush();

    expect(device.pendingEventCount, 0);
    expect(device.confirmedResults, hasLength(1));
    expect(device.confirmedResults.single.wasDuplicate, isTrue);
    expect(device.lastSyncError, isNull);
    expect(ingestion.issuedPersonalRewardCount, 1);
  });

  test('permanent invalid events do not block later queued events', () {
    final clock = DateTime.utc(2026, 7, 27, 17);
    final ingestion = InMemoryActivityIngestion(
      clock: () => clock,
      deviceAssignments: const [
        DeviceAssignmentGrant(deviceId: 'desk-1', userId: 'alice'),
      ],
    );
    final device = NudgeDeviceSimulator(
      deviceId: 'desk-1',
      assignedUserId: 'alice',
      ingestion: ingestion,
      clock: () => clock,
    );

    device.completeActivity(
      sessionId: 'invalid-session',
      roomIds: const [],
      activityType: ActivityType.focus,
      metricValue: -1,
      metricUnit: 'minutes',
    );
    device.startActivity(
      sessionId: 'valid-session',
      roomIds: const [],
      activityType: ActivityType.focus,
      metricUnit: 'minutes',
    );

    expect(device.pendingEventCount, 0);
    expect(device.failedEvents, hasLength(1));
    expect(
      device.failedEvents.single.error,
      isA<ActivityValidationException>(),
    );
    expect(device.confirmedResults, hasLength(1));
    expect(
      device.confirmedResults.single.status,
      ActivityRecordStatus.accepted,
    );
  });

  test('terminal events are not confirmed without a settlement receipt', () {
    final clock = DateTime.utc(2026, 7, 27, 18);
    final device = NudgeDeviceSimulator(
      deviceId: 'desk-protocol',
      assignedUserId: 'alice',
      ingestion: _MissingSettlementReceipt(),
      clock: () => clock,
    );

    device.completeActivity(
      sessionId: 'protocol-session',
      roomIds: const [],
      activityType: ActivityType.focus,
      metricValue: 25,
      metricUnit: 'minutes',
    );

    expect(device.pendingEventCount, 0);
    expect(device.confirmedResults, isEmpty);
    expect(device.failedEvents, hasLength(1));
    expect(device.failedEvents.single.error, isA<DeviceProtocolException>());
  });
}
