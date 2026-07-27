import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/activity_ledger.dart';
import 'package:nudge/services/activity_ingestion.dart';

void main() {
  test(
    'replaying one event returns the same receipt without another reward',
    () {
      final clock = DateTime.utc(2026, 7, 27, 9);
      final ingestion = InMemoryActivityIngestion(clock: () => clock);
      final evidence = ActivityEvidence(
        eventId: 'event-focus-1',
        sourceRecordId: 'app-focus-1',
        sessionId: 'session-focus-1',
        submittedByUserId: 'alice',
        actorUserId: 'alice',
        roomIds: const ['room-study'],
        activityType: ActivityType.focus,
        source: ActivitySource.app,
        eventType: ActivityEventType.completed,
        metricValue: 25,
        metricUnit: 'minutes',
        occurredAt: clock,
      );

      final first = ingestion.recordActivity(evidence);
      final replay = ingestion.recordActivity(evidence);

      expect(first.wasDuplicate, isFalse);
      expect(replay.wasDuplicate, isTrue);
      expect(replay.receipt.receiptId, first.receipt.receiptId);
      expect(replay.receipt.personalRewardIssued, isTrue);
      expect(ingestion.issuedPersonalRewardCount, 1);
    },
  );

  test(
    'one receipt contributes to every joined room but not an unjoined room',
    () {
      final clock = DateTime.utc(2026, 7, 27, 10);
      final ingestion = InMemoryActivityIngestion(
        clock: () => clock,
        roomMemberships: const [
          RoomMembershipGrant(roomId: 'room-study', userId: 'alice'),
          RoomMembershipGrant(roomId: 'room-steps', userId: 'alice'),
        ],
      );
      final evidence = ActivityEvidence(
        eventId: 'event-steps-1',
        sourceRecordId: 'health-steps-2026-07-27',
        sessionId: 'session-steps-1',
        submittedByUserId: 'alice',
        actorUserId: 'alice',
        roomIds: const ['room-study', 'room-steps', 'room-private'],
        activityType: ActivityType.steps,
        source: ActivitySource.health,
        eventType: ActivityEventType.metricSynced,
        metricValue: 8000,
        metricUnit: 'steps',
        occurredAt: clock,
      );

      final result = ingestion.recordActivity(evidence);

      expect(
        result.contributions.map((contribution) => contribution.roomId),
        unorderedEquals(['room-study', 'room-steps']),
      );
      expect(result.receipt.personalRewardIssued, isTrue);
      expect(ingestion.issuedPersonalRewardCount, 1);
    },
  );

  test('room owner cannot record another member activity', () {
    final clock = DateTime.utc(2026, 7, 27, 11);
    final ingestion = InMemoryActivityIngestion(
      clock: () => clock,
      roomMemberships: const [
        RoomMembershipGrant(roomId: 'room-study', userId: 'owner'),
        RoomMembershipGrant(roomId: 'room-study', userId: 'alice'),
      ],
    );
    final evidence = ActivityEvidence(
      eventId: 'event-owner-controls-member',
      sourceRecordId: 'web-focus-1',
      sessionId: 'session-alice-1',
      submittedByUserId: 'owner',
      actorUserId: 'alice',
      roomIds: const ['room-study'],
      activityType: ActivityType.focus,
      source: ActivitySource.web,
      eventType: ActivityEventType.completed,
      metricValue: 25,
      metricUnit: 'minutes',
      occurredAt: clock,
    );

    expect(
      () => ingestion.recordActivity(evidence),
      throwsA(isA<ActivityAuthorizationException>()),
    );
    expect(ingestion.issuedPersonalRewardCount, 0);
  });

  test('the same source record cannot mint a second personal reward', () {
    final clock = DateTime.utc(2026, 7, 27, 12);
    final ingestion = InMemoryActivityIngestion(
      clock: () => clock,
      roomMemberships: const [
        RoomMembershipGrant(roomId: 'room-steps', userId: 'alice'),
      ],
    );
    ActivityEvidence evidence(String eventId) => ActivityEvidence(
      eventId: eventId,
      sourceRecordId: 'health-steps-2026-07-27',
      sessionId: 'session-steps-2026-07-27',
      submittedByUserId: 'alice',
      actorUserId: 'alice',
      roomIds: const ['room-steps'],
      activityType: ActivityType.steps,
      source: ActivitySource.health,
      eventType: ActivityEventType.metricSynced,
      metricValue: 8000,
      metricUnit: 'steps',
      occurredAt: clock,
    );

    final first = ingestion.recordActivity(evidence('health-import-1'));
    final replay = ingestion.recordActivity(evidence('health-import-2'));

    expect(replay.wasDuplicate, isTrue);
    expect(replay.receipt.receiptId, first.receipt.receiptId);
    expect(ingestion.issuedPersonalRewardCount, 1);
  });

  test('a device can only record activity for its assigned user', () {
    final clock = DateTime.utc(2026, 7, 27, 13);
    final ingestion = InMemoryActivityIngestion(
      clock: () => clock,
      deviceAssignments: const [
        DeviceAssignmentGrant(deviceId: 'desk-1', userId: 'alice'),
      ],
    );
    ActivityEvidence evidence(String actorUserId) => ActivityEvidence(
      eventId: 'device-event-$actorUserId',
      sourceRecordId: 'desk-1-sequence-$actorUserId',
      sessionId: 'device-session-$actorUserId',
      submittedByUserId: 'device:desk-1',
      actorUserId: actorUserId,
      roomIds: const [],
      activityType: ActivityType.focus,
      source: ActivitySource.device,
      eventType: ActivityEventType.completed,
      metricValue: 25,
      metricUnit: 'minutes',
      occurredAt: clock,
      deviceId: 'desk-1',
    );

    expect(
      ingestion.recordActivity(evidence('alice')).receipt.actorUserId,
      'alice',
    );
    expect(
      () => ingestion.recordActivity(evidence('bob')),
      throwsA(isA<ActivityAuthorizationException>()),
    );
  });

  test('a device event must be submitted by the assigned device identity', () {
    final clock = DateTime.utc(2026, 7, 27, 13, 30);
    final ingestion = InMemoryActivityIngestion(
      clock: () => clock,
      deviceAssignments: const [
        DeviceAssignmentGrant(deviceId: 'desk-1', userId: 'alice'),
      ],
    );
    final evidence = ActivityEvidence(
      eventId: 'forged-device-event',
      sourceRecordId: 'forged-device-record',
      sessionId: 'device-session-alice',
      submittedByUserId: 'device:desk-2',
      actorUserId: 'alice',
      roomIds: const [],
      activityType: ActivityType.focus,
      source: ActivitySource.device,
      eventType: ActivityEventType.completed,
      metricValue: 25,
      metricUnit: 'minutes',
      occurredAt: clock,
      deviceId: 'desk-1',
    );

    expect(
      () => ingestion.recordActivity(evidence),
      throwsA(isA<ActivityAuthorizationException>()),
    );
  });

  test('duplicate room ids create only one contribution per room', () {
    final clock = DateTime.utc(2026, 7, 27, 14);
    final ingestion = InMemoryActivityIngestion(
      clock: () => clock,
      roomMemberships: const [
        RoomMembershipGrant(roomId: 'room-study', userId: 'alice'),
      ],
    );
    final evidence = ActivityEvidence(
      eventId: 'event-duplicate-room',
      sourceRecordId: 'app-focus-duplicate-room',
      sessionId: 'session-duplicate-room',
      submittedByUserId: 'alice',
      actorUserId: 'alice',
      roomIds: const ['room-study', 'room-study'],
      activityType: ActivityType.focus,
      source: ActivitySource.app,
      eventType: ActivityEventType.completed,
      metricValue: 25,
      metricUnit: 'minutes',
      occurredAt: clock,
    );

    final result = ingestion.recordActivity(evidence);

    expect(result.contributions, hasLength(1));
    expect(result.contributions.single.roomId, 'room-study');
  });

  test('negative activity metrics are rejected before rewards are issued', () {
    final clock = DateTime.utc(2026, 7, 27, 16);
    final ingestion = InMemoryActivityIngestion(clock: () => clock);
    final evidence = ActivityEvidence(
      eventId: 'event-invalid-metric',
      sourceRecordId: 'health-invalid-metric',
      sessionId: 'session-invalid-metric',
      submittedByUserId: 'alice',
      actorUserId: 'alice',
      roomIds: const [],
      activityType: ActivityType.steps,
      source: ActivitySource.health,
      eventType: ActivityEventType.metricSynced,
      metricValue: -1,
      metricUnit: 'steps',
      occurredAt: clock,
    );

    expect(
      () => ingestion.recordActivity(evidence),
      throwsA(isA<ActivityValidationException>()),
    );
    expect(ingestion.issuedPersonalRewardCount, 0);
  });
}
