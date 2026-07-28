import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/activity_ledger.dart';

void main() {
  test('ActivityEvidence emits only the client-owned Cloud contract', () {
    final evidence = ActivityEvidence(
      eventId: 'event-1',
      sourceRecordId: 'source-1',
      sessionId: 'session-1',
      activityCorrelationId: 'correlation-1',
      submittedByUserId: 'user-1',
      actorUserId: 'user-1',
      roomIds: const ['room-a', 'room-b'],
      activityType: ActivityType.focus,
      source: ActivitySource.app,
      eventType: ActivityEventType.completed,
      metricValue: 25,
      metricUnit: 'minutes',
      occurredAt: DateTime.parse('2026-07-28T09:25:00+08:00'),
      receivedAt: DateTime.parse('2026-07-28T09:25:01Z'),
    );

    expect(evidence.toCloudJson(), {
      'eventId': 'event-1',
      'sourceRecordId': 'source-1',
      'sessionId': 'session-1',
      'activityCorrelationId': 'correlation-1',
      'actorUserId': 'user-1',
      'roomIds': ['room-a', 'room-b'],
      'activityType': 'focus',
      'source': 'app',
      'eventType': 'completed',
      'metricValue': 25.0,
      'metricUnit': 'minutes',
      'occurredAt': '2026-07-28T01:25:00.000Z',
    });
  });

  test('ActivityRecordResult parses the canonical Cloud receipt', () {
    final result = ActivityRecordResult.fromCloudJson({
      'status': 'settled',
      'acknowledgedEventId': 'event-1',
      'acknowledgedSourceRecordId': 'source-1',
      'canonicalSessionId': 'correlation-1',
      'wasDuplicate': false,
      'receipt': {
        'receiptId': 'receipt-1',
        'eventId': 'event-1',
        'sourceRecordId': 'source-1',
        'activitySessionId': 'correlation-1',
        'actorUserId': 'user-1',
        'activityType': 'focus',
        'activityFingerprint': 'fingerprint-1',
        'acceptedMetric': 25,
        'metricUnit': 'minutes',
        'rewardEligible': true,
        'rewardIssued': false,
        'characterExperienceEligible': true,
        'characterExperienceIssued': false,
        'verifiedAt': '2026-07-28T01:25:01.000Z',
        'correctionOfReceiptId': null,
      },
      'contributions': [
        {
          'contributionId': 'contribution-1',
          'receiptId': 'receipt-1',
          'roomId': 'room-a',
          'actorUserId': 'user-1',
          'metricValue': 25,
          'metricUnit': 'minutes',
          'occurredAt': '2026-07-28T01:25:00.000Z',
          'createdAt': '2026-07-28T01:25:01.000Z',
        },
      ],
      'session': {
        'activitySessionId': 'correlation-1',
        'actorUserId': 'user-1',
        'activityType': 'focus',
        'status': 'completed',
        'startedAt': '2026-07-28T01:00:00.000Z',
        'endedAt': '2026-07-28T01:25:00.000Z',
        'metricValue': 25,
        'metricUnit': 'minutes',
        'sourceSessionIds': ['session-1'],
      },
    });

    expect(result.status, ActivityRecordStatus.settled);
    expect(result.receipt?.sessionId, 'correlation-1');
    expect(result.receipt?.rewardEligible, isTrue);
    expect(result.receipt?.personalRewardIssued, isFalse);
    expect(result.receipt?.characterExperienceEligible, isTrue);
    expect(result.contributions.single.roomId, 'room-a');
    expect(
      result.contributions.single.occurredAt,
      DateTime.parse('2026-07-28T01:25:00.000Z'),
    );
    expect(result.session?.status, ActivitySessionStatus.completed);
  });
}
