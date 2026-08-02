import '../models/activity_ledger.dart';

abstract final class TaskActivityEvidenceFactory {
  static String activityDateKeyFor(DateTime occurredAt) {
    final shifted = occurredAt.toUtc().add(const Duration(hours: 3));
    final year = shifted.year.toString().padLeft(4, '0');
    final month = shifted.month.toString().padLeft(2, '0');
    final day = shifted.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static String _stableTaskKey(String value) {
    var hash = BigInt.parse('14695981039346656037');
    final prime = BigInt.from(1099511628211);
    final mask = BigInt.parse('18446744073709551615');
    for (final codeUnit in value.codeUnits) {
      hash = (hash ^ BigInt.from(codeUnit)) * prime & mask;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }

  static ActivityEvidence build({
    required String userId,
    required String taskId,
    required String activityDateKey,
    required bool completed,
    required DateTime occurredAt,
    ActivitySource source = ActivitySource.app,
  }) {
    final normalizedUserId = userId.trim();
    final normalizedTaskId = taskId.trim();
    final normalizedDateKey = activityDateKey.trim();
    if (normalizedUserId.isEmpty ||
        normalizedTaskId.isEmpty ||
        normalizedTaskId.length > 256 ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(normalizedDateKey)) {
      throw ArgumentError('Task activity evidence is invalid.');
    }
    final occurredAtUtc = occurredAt.toUtc();
    final correlationId = [
      'task',
      normalizedUserId,
      _stableTaskKey(normalizedTaskId),
      normalizedDateKey,
    ].join(':');
    final eventId = [
      correlationId,
      completed ? '1' : '0',
      occurredAtUtc.microsecondsSinceEpoch,
    ].join(':');

    return ActivityEvidence(
      eventId: eventId,
      sourceRecordId: eventId,
      sessionId: correlationId,
      activityCorrelationId: correlationId,
      submittedByUserId: normalizedUserId,
      actorUserId: normalizedUserId,
      roomIds: const [],
      activityType: ActivityType.task,
      source: source,
      eventType: ActivityEventType.metricSynced,
      metricValue: completed ? 1 : 0,
      metricUnit: 'completion',
      occurredAt: occurredAtUtc,
      taskId: normalizedTaskId,
    );
  }
}
