enum ActivityType { focus, study, exercise, steps, sleep, custom }

enum ActivitySource { app, health, device, web }

enum ActivityEventType { started, paused, resumed, completed, metricSynced }

class RoomMembershipGrant {
  final String roomId;
  final String userId;

  const RoomMembershipGrant({required this.roomId, required this.userId});
}

class DeviceAssignmentGrant {
  final String deviceId;
  final String userId;

  const DeviceAssignmentGrant({required this.deviceId, required this.userId});
}

class ActivityEvidence {
  final String eventId;
  final String sourceRecordId;
  final String sessionId;
  final String submittedByUserId;
  final String actorUserId;
  final List<String> roomIds;
  final ActivityType activityType;
  final ActivitySource source;
  final ActivityEventType eventType;
  final double metricValue;
  final String metricUnit;
  final DateTime occurredAt;
  final String? deviceId;

  const ActivityEvidence({
    required this.eventId,
    required this.sourceRecordId,
    required this.sessionId,
    required this.submittedByUserId,
    required this.actorUserId,
    required this.roomIds,
    required this.activityType,
    required this.source,
    required this.eventType,
    required this.metricValue,
    required this.metricUnit,
    required this.occurredAt,
    this.deviceId,
  });
}

class ActivityReceipt {
  final String receiptId;
  final String eventId;
  final String sourceRecordId;
  final String sessionId;
  final String actorUserId;
  final ActivityType activityType;
  final double acceptedMetric;
  final String metricUnit;
  final bool personalRewardIssued;
  final bool characterExperienceIssued;
  final DateTime verifiedAt;

  const ActivityReceipt({
    required this.receiptId,
    required this.eventId,
    required this.sourceRecordId,
    required this.sessionId,
    required this.actorUserId,
    required this.activityType,
    required this.acceptedMetric,
    required this.metricUnit,
    required this.personalRewardIssued,
    required this.characterExperienceIssued,
    required this.verifiedAt,
  });
}

class RoomContribution {
  final String contributionId;
  final String receiptId;
  final String roomId;
  final String actorUserId;
  final double metricValue;
  final String metricUnit;
  final DateTime createdAt;

  const RoomContribution({
    required this.contributionId,
    required this.receiptId,
    required this.roomId,
    required this.actorUserId,
    required this.metricValue,
    required this.metricUnit,
    required this.createdAt,
  });
}

class ActivityRecordResult {
  final ActivityReceipt receipt;
  final List<RoomContribution> contributions;
  final bool wasDuplicate;

  const ActivityRecordResult({
    required this.receipt,
    required this.contributions,
    required this.wasDuplicate,
  });
}
