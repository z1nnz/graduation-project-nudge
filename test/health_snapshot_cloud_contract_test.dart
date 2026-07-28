import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/activity_ledger.dart';
import 'package:nudge/models/health_activity_snapshot.dart';
import 'package:nudge/services/cloud_health_snapshot_gateway.dart';

HealthActivitySnapshot healthSnapshot({
  HealthSnapshotProvider provider = HealthSnapshotProvider.healthConnect,
  double metricValue = 4321,
}) {
  return HealthActivitySnapshot(
    provider: provider,
    activityType: ActivityType.steps,
    metricValue: metricValue,
    metricUnit: 'steps',
    localDate: '2026-07-28',
    periodStart: DateTime.utc(2026, 7, 27, 16),
    periodEnd: DateTime.utc(2026, 7, 28, 9),
    observedAt: DateTime.utc(2026, 7, 28, 9),
    dataOrigins: const ['android'],
    roomIds: const ['room-steps'],
  );
}

Map<String, dynamic> acceptedHealthResult(int index) => {
  'status': 'accepted',
  'acknowledgedEventId': 'health-event-$index',
  'acknowledgedSourceRecordId': 'health-source-$index',
  'canonicalSessionId': 'health-session-$index',
  'receipt': null,
  'contributions': const [],
  'session': null,
  'wasDuplicate': false,
};

void main() {
  test('platform health snapshot parses into the Cloud contract', () {
    final snapshot = HealthActivitySnapshot.fromPlatformMap({
      'activityType': 'sleep',
      'metricValue': 7.5,
      'metricUnit': 'hours',
      'localDate': '2026-07-28',
      'periodStart': '2026-07-27T04:00:00.000Z',
      'periodEnd': '2026-07-28T01:00:00.000Z',
      'observedAt': '2026-07-28T01:00:00.000Z',
      'dataOrigins': ['com.apple.Health'],
    }, provider: HealthSnapshotProvider.appleHealth);

    expect(snapshot.activityType, ActivityType.sleep);
    expect(snapshot.provider, HealthSnapshotProvider.appleHealth);
    expect(snapshot.toCloudJson(), {
      'activityType': 'sleep',
      'metricValue': 7.5,
      'metricUnit': 'hours',
      'localDate': '2026-07-28',
      'periodStart': '2026-07-27T04:00:00.000Z',
      'periodEnd': '2026-07-28T01:00:00.000Z',
      'observedAt': '2026-07-28T01:00:00.000Z',
      'dataOrigins': ['com.apple.Health'],
      'roomIds': const [],
    });
  });

  test('gateway groups one provider and parses every result', () async {
    Map<String, dynamic>? sent;
    final gateway = CloudHealthSnapshotGateway.withCallable((payload) async {
      sent = payload;
      return {
        'accepted': 2,
        'results': [acceptedHealthResult(1), acceptedHealthResult(2)],
      };
    });

    final results = await gateway.ingest([
      healthSnapshot(),
      healthSnapshot(metricValue: 5000),
    ]);

    expect(sent?['provider'], 'healthConnect');
    expect(sent?['snapshots'], hasLength(2));
    expect(results, hasLength(2));
    expect(results.last.canonicalSessionId, 'health-session-2');
  });

  test('gateway rejects a mixed provider batch', () async {
    final gateway = CloudHealthSnapshotGateway.withCallable((_) async => {});

    expect(
      () => gateway.ingest([
        healthSnapshot(),
        healthSnapshot(provider: HealthSnapshotProvider.appleHealth),
      ]),
      throwsA(isA<Exception>()),
    );
  });
}
