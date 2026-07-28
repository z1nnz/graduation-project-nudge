import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/activity_ledger.dart';
import 'package:nudge/models/health_activity_snapshot.dart';
import 'package:nudge/services/cloud_activity_ledger_gateway.dart';
import 'package:nudge/services/cloud_health_snapshot_gateway.dart';
import 'package:nudge/services/health_snapshot_outbox.dart';
import 'package:shared_preferences/shared_preferences.dart';

HealthActivitySnapshot queuedHealthSnapshot({int hour = 9}) {
  return HealthActivitySnapshot(
    provider: HealthSnapshotProvider.healthConnect,
    activityType: ActivityType.steps,
    metricValue: 4000 + hour.toDouble(),
    metricUnit: 'steps',
    localDate: '2026-07-28',
    periodStart: DateTime.utc(2026, 7, 27, 16),
    periodEnd: DateTime.utc(2026, 7, 28, hour),
    observedAt: DateTime.utc(2026, 7, 28, hour),
    dataOrigins: const ['android'],
  );
}

Map<String, dynamic> resultFor(int index) => {
  'status': 'accepted',
  'acknowledgedEventId': 'event-$index',
  'acknowledgedSourceRecordId': 'source-$index',
  'canonicalSessionId': 'session-$index',
  'receipt': null,
  'contributions': const [],
  'session': null,
  'wasDuplicate': false,
};

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('retryable health batches survive an outbox restart', () async {
    final blocked = HealthSnapshotOutbox(
      gateway: CloudHealthSnapshotGateway.withCallable((_) async {
        throw const ActivityCloudRetryableException('unavailable', 'offline');
      }),
    );
    await blocked.enqueueAll([queuedHealthSnapshot()]);

    expect((await blocked.flush()).retryBlocked, isTrue);
    expect(await blocked.pendingCount(), 1);

    final recovered = HealthSnapshotOutbox(
      gateway: CloudHealthSnapshotGateway.withCallable((payload) async {
        final count = (payload['snapshots'] as List).length;
        return {
          'accepted': count,
          'results': [
            for (var index = 0; index < count; index++) resultFor(index),
          ],
        };
      }),
    );

    expect((await recovered.flush()).succeeded, hasLength(1));
    expect(await recovered.pendingCount(), 0);
  });

  test(
    'an active flush drains a snapshot queued during its first call',
    () async {
      final started = Completer<void>();
      final release = Completer<void>();
      var calls = 0;
      final outbox = HealthSnapshotOutbox(
        gateway: CloudHealthSnapshotGateway.withCallable((payload) async {
          calls++;
          if (calls == 1) {
            started.complete();
            await release.future;
          }
          final count = (payload['snapshots'] as List).length;
          return {
            'accepted': count,
            'results': [
              for (var index = 0; index < count; index++) resultFor(index),
            ],
          };
        }),
      );
      await outbox.enqueueAll([queuedHealthSnapshot()]);
      final flushing = outbox.flush();
      await started.future;

      await outbox.enqueueAll([queuedHealthSnapshot(hour: 10)]);
      release.complete();
      await flushing;

      expect(calls, 2);
      expect(await outbox.pendingCount(), 0);
    },
  );
}
