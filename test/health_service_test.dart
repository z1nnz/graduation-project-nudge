import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/activity_ledger.dart';
import 'package:nudge/models/health_activity_snapshot.dart';
import 'package:nudge/services/health_service.dart';

void main() {
  test(
    'HealthServiceResult carries native snapshots into the ledger model',
    () {
      final result = HealthServiceResult.fromMap({
        'success': true,
        'message': 'ok',
        'sleepHours': 7.5,
        'steps': 4321,
        'exerciseMinutes': 35,
        'snapshots': [
          {
            'activityType': 'steps',
            'metricValue': 4321,
            'metricUnit': 'steps',
            'localDate': '2026-07-28',
            'periodStart': '2026-07-27T16:00:00.000Z',
            'periodEnd': '2026-07-28T09:00:00.000Z',
            'observedAt': '2026-07-28T09:00:00.000Z',
            'dataOrigins': ['com.example.watch'],
          },
        ],
      }, provider: HealthSnapshotProvider.healthConnect);

      expect(result.success, isTrue);
      expect(result.sleepHours, 7.5);
      expect(result.steps, 4321);
      expect(result.exerciseMinutes, 35);
      expect(result.snapshots, hasLength(1));
      expect(
        result.snapshots.single.provider,
        HealthSnapshotProvider.healthConnect,
      );
      expect(result.snapshots.single.activityType, ActivityType.steps);
      expect(result.snapshots.single.metricValue, 4321);
      expect(result.snapshots.single.dataOrigins, ['com.example.watch']);
    },
  );

  test('HealthServiceResult snapshots are immutable', () {
    final source = <HealthActivitySnapshot>[];
    final result = HealthServiceResult(
      success: true,
      message: 'ok',
      sleepHours: 0,
      steps: 0,
      exerciseMinutes: 0,
      snapshots: source,
    );

    source.add(
      HealthActivitySnapshot(
        provider: HealthSnapshotProvider.appleHealth,
        activityType: ActivityType.sleep,
        metricValue: 7,
        metricUnit: 'hours',
        localDate: '2026-07-28',
        periodStart: DateTime.utc(2026, 7, 27, 15),
        periodEnd: DateTime.utc(2026, 7, 27, 22),
        observedAt: DateTime.utc(2026, 7, 28, 9),
        dataOrigins: const ['com.apple.health'],
      ),
    );

    expect(result.snapshots, isEmpty);
    expect(() => result.snapshots.add(source.single), throwsUnsupportedError);
  });
}
