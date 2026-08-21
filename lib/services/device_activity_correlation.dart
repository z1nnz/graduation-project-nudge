import '../models/activity_ledger.dart';
import 'activity_ledger_outbox.dart';

typedef DeviceActivityActorResolver = String? Function();
typedef ExistingDeviceActivityCorrelationResolver = String? Function();
typedef ExistingDeviceActivityConfirmationResolver = bool Function();

class DeviceActivityCorrelationException implements Exception {
  const DeviceActivityCorrelationException(this.message);

  final String message;

  @override
  String toString() => 'DeviceActivityCorrelationException: $message';
}

/// Confirms a canonical Cloud Activity Session before configuring hardware.
class DeviceActivityCorrelationService {
  DeviceActivityCorrelationService({
    required ActivityLedgerOutbox outbox,
    required DeviceActivityActorResolver currentActorUserId,
    required ExistingDeviceActivityCorrelationResolver existingCorrelationId,
    required ExistingDeviceActivityConfirmationResolver
    isExistingCorrelationCloudConfirmed,
    DateTime Function()? clock,
  }) : _outbox = outbox,
       _currentActorUserId = currentActorUserId,
       _existingCorrelationId = existingCorrelationId,
       _isExistingCorrelationCloudConfirmed =
           isExistingCorrelationCloudConfirmed,
       _clock = clock ?? DateTime.now;

  final ActivityLedgerOutbox _outbox;
  final DeviceActivityActorResolver _currentActorUserId;
  final ExistingDeviceActivityCorrelationResolver _existingCorrelationId;
  final ExistingDeviceActivityConfirmationResolver
  _isExistingCorrelationCloudConfirmed;
  final DateTime Function() _clock;

  Future<String> prepareFocusCorrelation() async {
    final actorUserId = _currentActorUserId()?.trim() ?? '';
    if (actorUserId.isEmpty) {
      throw const DeviceActivityCorrelationException('請先登入再設定實體裝置。');
    }

    final existing = _existingCorrelationId()?.trim() ?? '';
    if (existing.isNotEmpty) {
      if (_isExistingCorrelationCloudConfirmed()) return existing;
      final report = await _outbox.flush();
      _requireCloudAcceptance(report);
      if (!report.succeeded.any(
        (result) => result.canonicalSessionId == existing,
      )) {
        throw const DeviceActivityCorrelationException(
          'Cloud 尚未確認目前 App 專注，不能讓實體裝置共用。',
        );
      }
      return existing;
    }

    final occurredAt = _clock().toUtc();
    final proposedCorrelationId =
        'device-focus-correlation-${occurredAt.microsecondsSinceEpoch}';
    final eventId = '$proposedCorrelationId-started';
    await _outbox.enqueue(
      ActivityEvidence(
        eventId: eventId,
        sourceRecordId: eventId,
        sessionId: proposedCorrelationId,
        activityCorrelationId: proposedCorrelationId,
        submittedByUserId: actorUserId,
        actorUserId: actorUserId,
        roomIds: const [],
        activityType: ActivityType.focus,
        source: ActivitySource.app,
        eventType: ActivityEventType.started,
        metricValue: 0,
        metricUnit: 'minutes',
        occurredAt: occurredAt,
      ),
    );
    final report = await _outbox.flush();
    _requireCloudAcceptance(report);
    final matches = report.succeeded.where(
      (candidate) => candidate.acknowledgedEventId == eventId,
    );
    if (matches.isEmpty || matches.first.canonicalSessionId.trim().isEmpty) {
      throw const DeviceActivityCorrelationException(
        'Cloud 未確認本次裝置活動關聯，尚未傳送到硬體。',
      );
    }
    return matches.first.canonicalSessionId;
  }

  void _requireCloudAcceptance(ActivityLedgerFlushReport report) {
    if (report.retryBlocked) {
      throw const DeviceActivityCorrelationException(
        '目前無法連上 Cloud，活動已保留但尚不能啟動實體裝置。',
      );
    }
    if (report.permanentlyRejected > 0) {
      throw const DeviceActivityCorrelationException('Cloud 拒絕活動關聯，請先修正帳號或權限。');
    }
  }
}
