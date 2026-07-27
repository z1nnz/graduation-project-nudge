import '../models/activity_ledger.dart';

abstract interface class ActivityIngestion {
  ActivityRecordResult recordActivity(ActivityEvidence evidence);
}

class ActivityAuthorizationException implements Exception {
  final String message;

  const ActivityAuthorizationException(this.message);

  @override
  String toString() => 'ActivityAuthorizationException: $message';
}

class ActivityValidationException implements Exception {
  final String message;

  const ActivityValidationException(this.message);

  @override
  String toString() => 'ActivityValidationException: $message';
}

class InMemoryActivityIngestion implements ActivityIngestion {
  final DateTime Function() _clock;
  final Set<(String roomId, String userId)> _roomMemberships;
  final Set<(String deviceId, String userId)> _deviceAssignments;
  final Map<String, ActivityRecordResult> _resultsByEventId = {};
  final Map<String, ActivityRecordResult> _resultsBySourceRecord = {};
  int _issuedPersonalRewardCount = 0;

  InMemoryActivityIngestion({
    DateTime Function()? clock,
    List<RoomMembershipGrant> roomMemberships = const [],
    List<DeviceAssignmentGrant> deviceAssignments = const [],
  }) : _clock = clock ?? DateTime.now,
       _roomMemberships = roomMemberships
           .map((grant) => (grant.roomId, grant.userId))
           .toSet(),
       _deviceAssignments = deviceAssignments
           .map((grant) => (grant.deviceId, grant.userId))
           .toSet();

  int get issuedPersonalRewardCount => _issuedPersonalRewardCount;

  @override
  ActivityRecordResult recordActivity(ActivityEvidence evidence) {
    if (evidence.metricValue < 0) {
      throw const ActivityValidationException(
        'Activity metrics cannot be negative.',
      );
    }

    if (evidence.source == ActivitySource.device) {
      final deviceId = evidence.deviceId;
      if (deviceId == null ||
          evidence.submittedByUserId != 'device:$deviceId' ||
          !_deviceAssignments.contains((deviceId, evidence.actorUserId))) {
        throw const ActivityAuthorizationException(
          'The device is not assigned to this actor.',
        );
      }
    } else if (evidence.submittedByUserId != evidence.actorUserId) {
      throw const ActivityAuthorizationException(
        'Only the actor can control this activity.',
      );
    }

    final existing = _resultsByEventId[evidence.eventId];
    if (existing != null) {
      return ActivityRecordResult(
        receipt: existing.receipt,
        contributions: existing.contributions,
        wasDuplicate: true,
      );
    }
    final sourceRecordKey = [
      evidence.source.name,
      evidence.actorUserId,
      evidence.activityType.name,
      evidence.sourceRecordId,
    ].join(':');
    final sourceRecordResult = _resultsBySourceRecord[sourceRecordKey];
    if (sourceRecordResult != null) {
      _resultsByEventId[evidence.eventId] = sourceRecordResult;
      return ActivityRecordResult(
        receipt: sourceRecordResult.receipt,
        contributions: sourceRecordResult.contributions,
        wasDuplicate: true,
      );
    }

    final verifiedAt = _clock();
    final rewardIssued =
        evidence.eventType == ActivityEventType.completed ||
        evidence.eventType == ActivityEventType.metricSynced;
    if (rewardIssued) {
      _issuedPersonalRewardCount++;
    }

    final receiptId = 'receipt_${evidence.eventId}';
    final receipt = ActivityReceipt(
      receiptId: receiptId,
      eventId: evidence.eventId,
      sourceRecordId: evidence.sourceRecordId,
      sessionId: evidence.sessionId,
      actorUserId: evidence.actorUserId,
      activityType: evidence.activityType,
      acceptedMetric: evidence.metricValue,
      metricUnit: evidence.metricUnit,
      personalRewardIssued: rewardIssued,
      characterExperienceIssued: rewardIssued,
      verifiedAt: verifiedAt,
    );
    final contributionRoomIds = rewardIssued
        ? evidence.roomIds.toSet()
        : const <String>{};
    final contributions = contributionRoomIds
        .where(
          (roomId) => _roomMemberships.contains((roomId, evidence.actorUserId)),
        )
        .map(
          (roomId) => RoomContribution(
            contributionId: '${receiptId}_$roomId',
            receiptId: receiptId,
            roomId: roomId,
            actorUserId: evidence.actorUserId,
            metricValue: evidence.metricValue,
            metricUnit: evidence.metricUnit,
            createdAt: verifiedAt,
          ),
        )
        .toList(growable: false);
    final result = ActivityRecordResult(
      receipt: receipt,
      contributions: contributions,
      wasDuplicate: false,
    );
    _resultsByEventId[evidence.eventId] = result;
    _resultsBySourceRecord[sourceRecordKey] = result;
    return result;
  }
}
