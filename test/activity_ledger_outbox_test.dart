import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/activity_ledger.dart';
import 'package:nudge/services/activity_ingestion.dart';
import 'package:nudge/services/activity_ledger_outbox.dart';
import 'package:nudge/services/cloud_activity_ledger_gateway.dart';
import 'package:shared_preferences/shared_preferences.dart';

ActivityEvidence queuedEvidence({String suffix = '1'}) => ActivityEvidence(
  eventId: 'event-offline-$suffix',
  sourceRecordId: 'source-offline-$suffix',
  sessionId: 'session-offline-1',
  activityCorrelationId: 'correlation-offline-1',
  submittedByUserId: 'user-1',
  actorUserId: 'user-1',
  roomIds: const ['room-a'],
  activityType: ActivityType.focus,
  source: ActivitySource.app,
  eventType: ActivityEventType.completed,
  metricValue: 25,
  metricUnit: 'minutes',
  occurredAt: DateTime.utc(2026, 7, 28, 1, 25),
);

Map<String, dynamic> acceptedResult() => {
  'status': 'settled',
  'acknowledgedEventId': 'event-offline-1',
  'acknowledgedSourceRecordId': 'source-offline-1',
  'canonicalSessionId': 'correlation-offline-1',
  'wasDuplicate': false,
  'receipt': {
    'receiptId': 'receipt-offline-1',
    'eventId': 'event-offline-1',
    'sourceRecordId': 'source-offline-1',
    'activitySessionId': 'correlation-offline-1',
    'actorUserId': 'user-1',
    'activityType': 'focus',
    'activityFingerprint': 'fingerprint-offline-1',
    'acceptedMetric': 25,
    'metricUnit': 'minutes',
    'rewardEligible': true,
    'rewardIssued': false,
    'characterExperienceEligible': true,
    'characterExperienceIssued': false,
    'verifiedAt': '2026-07-28T01:25:01.000Z',
    'correctionOfReceiptId': null,
  },
  'contributions': const [],
  'session': {
    'activitySessionId': 'correlation-offline-1',
    'actorUserId': 'user-1',
    'activityType': 'focus',
    'status': 'completed',
    'startedAt': '2026-07-28T01:00:00.000Z',
    'endedAt': '2026-07-28T01:25:00.000Z',
    'metricValue': 25,
    'metricUnit': 'minutes',
    'sourceSessionIds': ['session-offline-1'],
  },
};

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('retryable failures survive restart and flush exactly once', () async {
    var attempts = 0;
    final unavailable = CloudActivityLedgerGateway.withCallable((_) async {
      attempts++;
      throw const ActivityCloudRetryableException('unavailable', 'offline');
    });
    final firstOutbox = ActivityLedgerOutbox(gateway: unavailable);

    await firstOutbox.enqueue(queuedEvidence());
    await firstOutbox.enqueue(queuedEvidence());
    final blocked = await firstOutbox.flush();

    expect(blocked.retryBlocked, isTrue);
    expect(blocked.succeeded, isEmpty);
    expect(await firstOutbox.pendingCount(), 1);
    expect(attempts, 1);

    final recovered = CloudActivityLedgerGateway.withCallable((_) async {
      attempts++;
      return acceptedResult();
    });
    final restartedOutbox = ActivityLedgerOutbox(gateway: recovered);
    final flushed = await restartedOutbox.flush();

    expect(flushed.retryBlocked, isFalse);
    expect(flushed.succeeded.single.receipt?.receiptId, 'receipt-offline-1');
    expect(await restartedOutbox.pendingCount(), 0);
    expect(attempts, 2);
  });

  test('concurrent enqueues preserve every unique event', () async {
    final outbox = ActivityLedgerOutbox(
      gateway: CloudActivityLedgerGateway.withCallable((_) async {
        return acceptedResult();
      }),
    );

    await Future.wait([
      for (var index = 0; index < 20; index++)
        outbox.enqueue(queuedEvidence(suffix: '$index')),
    ]);

    expect(await outbox.pendingCount(), 20);
  });

  test(
    'a queued event can be cancelled before its local mutation commits',
    () async {
      final outbox = ActivityLedgerOutbox(
        gateway: CloudActivityLedgerGateway.withCallable((_) async {
          return acceptedResult();
        }),
      );
      final evidence = queuedEvidence(suffix: 'cancelled-before-commit');

      await outbox.enqueue(evidence);
      await outbox.cancel(evidence);

      expect(await outbox.pendingCount(), 0);
    },
  );

  test('pending activity is flushed only by its authenticated actor', () async {
    var activeActorId = 'user-2';
    var calls = 0;
    final outbox = ActivityLedgerOutbox(
      gateway: CloudActivityLedgerGateway.withCallable((_) async {
        calls++;
        return acceptedResult();
      }),
      getActorId: () => activeActorId,
    );
    await outbox.enqueue(queuedEvidence());

    final otherAccount = await outbox.flush();

    expect(otherAccount.retryBlocked, isFalse);
    expect(otherAccount.succeeded, isEmpty);
    expect(calls, 0);
    expect(await outbox.pendingCount(), 1);

    activeActorId = 'user-1';
    final owner = await outbox.flush();

    expect(owner.succeeded, hasLength(1));
    expect(calls, 1);
    expect(await outbox.pendingCount(), 0);
  });

  test(
    'an account switch during flush never dead-letters prior activity',
    () async {
      var activeActorId = 'user-1';
      final outbox = ActivityLedgerOutbox(
        gateway: CloudActivityLedgerGateway.withCallable((_) async {
          activeActorId = 'user-2';
          throw const ActivityAuthorizationException('account switched');
        }),
        getActorId: () => activeActorId,
      );
      await outbox.enqueue(queuedEvidence());

      final report = await outbox.flush();

      expect(report.permanentlyRejected, 0);
      expect(await outbox.pendingCount(), 1);
    },
  );

  test(
    'a flush drains an event queued while its first call is in flight',
    () async {
      final callStarted = Completer<void>();
      final releaseCall = Completer<void>();
      var calls = 0;
      final outbox = ActivityLedgerOutbox(
        gateway: CloudActivityLedgerGateway.withCallable((_) async {
          calls++;
          if (calls == 1) {
            callStarted.complete();
            await releaseCall.future;
          }
          return acceptedResult();
        }),
      );

      await outbox.enqueue(queuedEvidence());
      final flushing = outbox.flush();
      await callStarted.future;

      final queuedDuringFlush = outbox.enqueue(queuedEvidence(suffix: '2'));
      releaseCall.complete();
      await flushing;
      await queuedDuringFlush;

      expect(calls, 2);
      expect(await outbox.pendingCount(), 0);
    },
  );
}
