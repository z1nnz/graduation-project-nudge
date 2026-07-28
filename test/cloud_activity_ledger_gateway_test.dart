import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/activity_ledger.dart';
import 'package:nudge/services/cloud_activity_ledger_gateway.dart';

ActivityEvidence evidence() => ActivityEvidence(
  eventId: 'event-1',
  sourceRecordId: 'source-1',
  sessionId: 'session-1',
  activityCorrelationId: 'correlation-1',
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

Map<String, dynamic> cloudResult() => {
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
  'contributions': const [],
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
};

void main() {
  test('gateway sends the callable envelope and parses its receipt', () async {
    Map<String, dynamic>? captured;
    final gateway = CloudActivityLedgerGateway.withCallable((payload) async {
      captured = payload;
      return cloudResult();
    });

    final result = await gateway.recordActivity(evidence());

    expect(captured?.keys, ['evidence']);
    expect(captured?['evidence']['submittedByUserId'], isNull);
    expect(captured?['evidence']['source'], 'app');
    expect(result.receipt?.receiptId, 'receipt-1');
  });

  test('gateway rejects non-map callable responses', () async {
    final gateway = CloudActivityLedgerGateway.withCallable(
      (_) async => 'not-a-ledger-result',
    );

    await expectLater(
      gateway.recordActivity(evidence()),
      throwsA(isA<ActivityCloudProtocolException>()),
    );
  });
}
