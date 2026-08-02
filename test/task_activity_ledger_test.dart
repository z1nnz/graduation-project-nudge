import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/activity_ledger.dart';
import 'package:nudge/services/task_activity_ledger.dart';

void main() {
  test(
    'task state changes share one daily correlation and remain auditable',
    () {
      final completed = TaskActivityEvidenceFactory.build(
        userId: 'user-1',
        taskId: 'daily-review',
        activityDateKey: '2026-07-28',
        completed: true,
        occurredAt: DateTime.parse('2026-07-28T09:25:00+08:00'),
      );
      final reopened = TaskActivityEvidenceFactory.build(
        userId: 'user-1',
        taskId: 'daily-review',
        activityDateKey: '2026-07-28',
        completed: false,
        occurredAt: DateTime.parse('2026-07-28T09:29:00+08:00'),
      );

      expect(
        completed.activityCorrelationId,
        'task:user-1:6aac647c1ff1ff95:2026-07-28',
      );
      expect(reopened.activityCorrelationId, completed.activityCorrelationId);
      expect(completed.taskId, 'daily-review');
      expect(completed.sessionId, completed.activityCorrelationId);
      expect(reopened.sessionId, reopened.activityCorrelationId);
      expect(completed.eventId, isNot(reopened.eventId));
      expect(completed.sourceRecordId, completed.eventId);
      expect(completed.activityType, ActivityType.task);
      expect(completed.source, ActivitySource.app);
      expect(completed.eventType, ActivityEventType.metricSynced);
      expect(completed.metricValue, 1);
      expect(reopened.metricValue, 0);
      expect(completed.metricUnit, 'completion');
      expect(completed.roomIds, isEmpty);
    },
  );

  test('task Ledger identifiers remain within the Cloud contract limit', () {
    final evidence = TaskActivityEvidenceFactory.build(
      userId: 'user-1',
      taskId: List.filled(256, 'x').join(),
      activityDateKey: '2026-07-28',
      completed: true,
      occurredAt: DateTime.parse('2026-07-28T09:25:00+08:00'),
    );

    expect(evidence.activityCorrelationId!.length, lessThanOrEqualTo(256));
    expect(evidence.sessionId.length, lessThanOrEqualTo(256));
    expect(evidence.eventId.length, lessThanOrEqualTo(256));
    expect(evidence.sourceRecordId.length, lessThanOrEqualTo(256));
    expect(
      () => TaskActivityEvidenceFactory.build(
        userId: 'user-1',
        taskId: List.filled(257, 'x').join(),
        activityDateKey: '2026-07-28',
        completed: true,
        occurredAt: DateTime.parse('2026-07-28T09:25:00+08:00'),
      ),
      throwsArgumentError,
    );
  });

  test('task activity date changes at the Taipei 05:00 reset boundary', () {
    expect(
      TaskActivityEvidenceFactory.activityDateKeyFor(
        DateTime.parse('2026-07-28T04:59:00+08:00'),
      ),
      '2026-07-27',
    );
    expect(
      TaskActivityEvidenceFactory.activityDateKeyFor(
        DateTime.parse('2026-07-28T05:00:00+08:00'),
      ),
      '2026-07-28',
    );
  });
}
