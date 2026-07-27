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
      expect(replay.receipt!.receiptId, first.receipt!.receiptId);
      expect(replay.receipt!.personalRewardIssued, isTrue);
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
      expect(result.receipt!.personalRewardIssued, isTrue);
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
    expect(replay.receipt!.receiptId, first.receipt!.receiptId);
    expect(ingestion.issuedPersonalRewardCount, 1);
  });

  test('the same session settled by app and device issues one receipt', () {
    final clock = DateTime.utc(2026, 7, 27, 12, 30);
    final ingestion = InMemoryActivityIngestion(
      clock: () => clock,
      roomMemberships: const [
        RoomMembershipGrant(roomId: 'room-study', userId: 'alice'),
      ],
      deviceAssignments: const [
        DeviceAssignmentGrant(deviceId: 'desk-1', userId: 'alice'),
      ],
    );
    final appResult = ingestion.recordActivity(
      ActivityEvidence(
        eventId: 'app-complete-1',
        sourceRecordId: 'app-record-1',
        sessionId: 'shared-session-1',
        submittedByUserId: 'alice',
        actorUserId: 'alice',
        roomIds: const ['room-study'],
        activityType: ActivityType.focus,
        source: ActivitySource.app,
        eventType: ActivityEventType.completed,
        metricValue: 25,
        metricUnit: 'minutes',
        occurredAt: clock,
      ),
    );
    final deviceResult = ingestion.recordActivity(
      ActivityEvidence(
        eventId: 'device-complete-1',
        sourceRecordId: 'device-record-1',
        sessionId: 'shared-session-1',
        submittedByUserId: 'device:desk-1',
        actorUserId: 'alice',
        roomIds: const ['room-study'],
        activityType: ActivityType.focus,
        source: ActivitySource.device,
        eventType: ActivityEventType.completed,
        metricValue: 25,
        metricUnit: 'minutes',
        occurredAt: clock,
        deviceId: 'desk-1',
      ),
    );

    expect(deviceResult.wasDuplicate, isTrue);
    expect(deviceResult.receipt!.receiptId, appResult.receipt!.receiptId);
    expect(ingestion.issuedPersonalRewardCount, 1);
    expect(deviceResult.contributions, hasLength(1));
  });

  test(
    'different app and device session ids merge into one active session',
    () {
      final startedAt = DateTime.utc(2026, 7, 27, 12, 30);
      final completedAt = startedAt.add(const Duration(minutes: 25));
      final ingestion = InMemoryActivityIngestion(
        clock: () => completedAt,
        roomMemberships: const [
          RoomMembershipGrant(roomId: 'room-app', userId: 'alice'),
          RoomMembershipGrant(roomId: 'room-device', userId: 'alice'),
        ],
        deviceAssignments: const [
          DeviceAssignmentGrant(deviceId: 'desk-1', userId: 'alice'),
        ],
      );
      ActivityEvidence evidence({
        required String eventId,
        required String sessionId,
        required ActivitySource source,
        required ActivityEventType eventType,
        required List<String> roomIds,
        required DateTime occurredAt,
      }) => ActivityEvidence(
        eventId: eventId,
        sourceRecordId: 'record-$eventId',
        sessionId: sessionId,
        submittedByUserId: source == ActivitySource.device
            ? 'device:desk-1'
            : 'alice',
        actorUserId: 'alice',
        roomIds: roomIds,
        activityType: ActivityType.focus,
        source: source,
        eventType: eventType,
        metricValue: eventType == ActivityEventType.completed ? 25 : 0,
        metricUnit: 'minutes',
        occurredAt: occurredAt,
        deviceId: source == ActivitySource.device ? 'desk-1' : null,
      );

      ingestion.recordActivity(
        evidence(
          eventId: 'app-start',
          sessionId: 'app-local-session',
          source: ActivitySource.app,
          eventType: ActivityEventType.started,
          roomIds: const ['room-app'],
          occurredAt: startedAt,
        ),
      );
      ingestion.recordActivity(
        evidence(
          eventId: 'device-start',
          sessionId: 'device-local-session',
          source: ActivitySource.device,
          eventType: ActivityEventType.started,
          roomIds: const ['room-device'],
          occurredAt: startedAt,
        ),
      );
      final appSettlement = ingestion.recordActivity(
        evidence(
          eventId: 'app-complete',
          sessionId: 'app-local-session',
          source: ActivitySource.app,
          eventType: ActivityEventType.completed,
          roomIds: const ['room-app'],
          occurredAt: completedAt,
        ),
      );
      final deviceSettlement = ingestion.recordActivity(
        evidence(
          eventId: 'device-complete',
          sessionId: 'device-local-session',
          source: ActivitySource.device,
          eventType: ActivityEventType.completed,
          roomIds: const ['room-device'],
          occurredAt: completedAt,
        ),
      );

      expect(deviceSettlement.wasDuplicate, isTrue);
      expect(
        deviceSettlement.receipt!.receiptId,
        appSettlement.receipt!.receiptId,
      );
      expect(
        deviceSettlement.contributions.map(
          (contribution) => contribution.roomId,
        ),
        unorderedEquals(['room-app', 'room-device']),
      );
      expect(ingestion.issuedReceiptCount, 1);
      expect(ingestion.issuedPersonalRewardCount, 1);
      expect(ingestion.activitySessions, hasLength(1));
      expect(
        ingestion.activitySessions.single.status,
        ActivitySessionStatus.completed,
      );
      expect(
        ingestion.activitySessions.single.sourceSessionIds,
        unorderedEquals(['app-local-session', 'device-local-session']),
      );
    },
  );

  test('a completed activity session cannot be paused', () {
    final startedAt = DateTime.utc(2026, 7, 27, 12, 30);
    final completedAt = startedAt.add(const Duration(minutes: 25));
    final ingestion = InMemoryActivityIngestion(clock: () => completedAt);
    ActivityEvidence evidence(
      String eventId,
      ActivityEventType eventType,
      DateTime occurredAt,
    ) => ActivityEvidence(
      eventId: eventId,
      sourceRecordId: 'record-$eventId',
      sessionId: 'closed-session',
      submittedByUserId: 'alice',
      actorUserId: 'alice',
      roomIds: const [],
      activityType: ActivityType.focus,
      source: ActivitySource.app,
      eventType: eventType,
      metricValue: eventType == ActivityEventType.started ? 0 : 25,
      metricUnit: 'minutes',
      occurredAt: occurredAt,
    );

    ingestion.recordActivity(
      evidence('start', ActivityEventType.started, startedAt),
    );
    ingestion.recordActivity(
      evidence('complete', ActivityEventType.completed, completedAt),
    );

    expect(
      () => ingestion.recordActivity(
        evidence('late-pause', ActivityEventType.paused, completedAt),
      ),
      throwsA(isA<ActivityValidationException>()),
    );
  });

  test('reusing an event id with a different actor is rejected', () {
    final clock = DateTime.utc(2026, 7, 27, 12, 45);
    final ingestion = InMemoryActivityIngestion(clock: () => clock);
    ActivityEvidence evidence(String actor) => ActivityEvidence(
      eventId: 'shared-event-id',
      sourceRecordId: 'record-$actor',
      sessionId: 'session-$actor',
      submittedByUserId: actor,
      actorUserId: actor,
      roomIds: const [],
      activityType: ActivityType.focus,
      source: ActivitySource.app,
      eventType: ActivityEventType.completed,
      metricValue: 25,
      metricUnit: 'minutes',
      occurredAt: clock,
    );

    ingestion.recordActivity(evidence('alice'));

    expect(
      () => ingestion.recordActivity(evidence('bob')),
      throwsA(isA<ActivityValidationException>()),
    );
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
      ingestion.recordActivity(evidence('alice')).receipt!.actorUserId,
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

  test('device assignment is authorized at the activity occurrence time', () {
    final transferredAt = DateTime.utc(2026, 7, 27, 14);
    final ingestion = InMemoryActivityIngestion(
      deviceAssignments: [
        DeviceAssignmentGrant(
          deviceId: 'desk-1',
          userId: 'alice',
          validUntil: transferredAt,
        ),
        DeviceAssignmentGrant(
          deviceId: 'desk-1',
          userId: 'bob',
          validFrom: transferredAt,
        ),
      ],
    );
    ActivityEvidence evidence(String actor, DateTime occurredAt) =>
        ActivityEvidence(
          eventId: '$actor-${occurredAt.microsecondsSinceEpoch}',
          sourceRecordId: '$actor-${occurredAt.microsecondsSinceEpoch}',
          sessionId: '$actor-${occurredAt.microsecondsSinceEpoch}',
          submittedByUserId: 'device:desk-1',
          actorUserId: actor,
          roomIds: const [],
          activityType: ActivityType.focus,
          source: ActivitySource.device,
          eventType: ActivityEventType.completed,
          metricValue: 25,
          metricUnit: 'minutes',
          occurredAt: occurredAt,
          deviceId: 'desk-1',
        );

    expect(
      ingestion
          .recordActivity(
            evidence(
              'alice',
              transferredAt.subtract(const Duration(minutes: 1)),
            ),
          )
          .isSettled,
      isTrue,
    );
    expect(
      () => ingestion.recordActivity(
        evidence('alice', transferredAt.add(const Duration(minutes: 1))),
      ),
      throwsA(isA<ActivityAuthorizationException>()),
    );
    expect(
      ingestion
          .recordActivity(
            evidence('bob', transferredAt.add(const Duration(minutes: 1))),
          )
          .isSettled,
      isTrue,
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

  test('activity before membership or without consent is not contributed', () {
    final occurredAt = DateTime.utc(2026, 7, 27, 14);
    final ingestion = InMemoryActivityIngestion(
      clock: () => occurredAt,
      roomMemberships: [
        RoomMembershipGrant(
          roomId: 'joined-later',
          userId: 'alice',
          activeFrom: occurredAt.add(const Duration(minutes: 1)),
        ),
        const RoomMembershipGrant(
          roomId: 'no-consent',
          userId: 'alice',
          sharingConsented: false,
        ),
        const RoomMembershipGrant(roomId: 'active-room', userId: 'alice'),
      ],
    );
    final result = ingestion.recordActivity(
      ActivityEvidence(
        eventId: 'membership-time-event',
        sourceRecordId: 'membership-time-record',
        sessionId: 'membership-time-session',
        submittedByUserId: 'alice',
        actorUserId: 'alice',
        roomIds: const ['joined-later', 'no-consent', 'active-room'],
        activityType: ActivityType.focus,
        source: ActivitySource.app,
        eventType: ActivityEventType.completed,
        metricValue: 25,
        metricUnit: 'minutes',
        occurredAt: occurredAt,
      ),
    );

    expect(result.contributions.map((contribution) => contribution.roomId), [
      'active-room',
    ]);
  });

  test('cached contribution lists cannot be mutated by callers', () {
    final clock = DateTime.utc(2026, 7, 27, 15);
    final ingestion = InMemoryActivityIngestion(
      clock: () => clock,
      roomMemberships: const [
        RoomMembershipGrant(roomId: 'room-study', userId: 'alice'),
      ],
    );
    final evidence = ActivityEvidence(
      eventId: 'immutable-event',
      sourceRecordId: 'immutable-record',
      sessionId: 'immutable-session',
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
    final result = ingestion.recordActivity(evidence);

    expect(
      () => result.contributions[0] = RoomContribution(
        contributionId: 'forged',
        receiptId: 'forged',
        roomId: 'forged',
        actorUserId: 'mallory',
        metricValue: 999,
        metricUnit: 'minutes',
        createdAt: clock,
      ),
      throwsUnsupportedError,
    );
    expect(
      ingestion.recordActivity(evidence).contributions.single.roomId,
      'room-study',
    );
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

  test('non-finite activity metrics are rejected before settlement', () {
    final clock = DateTime.utc(2026, 7, 27, 16, 30);
    final ingestion = InMemoryActivityIngestion(clock: () => clock);
    ActivityEvidence evidence(double metric) => ActivityEvidence(
      eventId: 'event-$metric',
      sourceRecordId: 'record-$metric',
      sessionId: 'session-$metric',
      submittedByUserId: 'alice',
      actorUserId: 'alice',
      roomIds: const [],
      activityType: ActivityType.steps,
      source: ActivitySource.health,
      eventType: ActivityEventType.metricSynced,
      metricValue: metric,
      metricUnit: 'steps',
      occurredAt: clock,
    );

    expect(
      () => ingestion.recordActivity(evidence(double.nan)),
      throwsA(isA<ActivityValidationException>()),
    );
    expect(
      () => ingestion.recordActivity(evidence(double.infinity)),
      throwsA(isA<ActivityValidationException>()),
    );
    expect(ingestion.issuedPersonalRewardCount, 0);
  });
}
