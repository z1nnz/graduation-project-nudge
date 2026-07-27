enum ActivityType { focus, study, exercise, steps, sleep, custom }

enum ActivitySource { app, health, device, web }

enum ActivityEventType { started, paused, resumed, completed, metricSynced }

class RoomMembershipGrant {
  final String roomId;
  final String userId;
  final bool isActive;
  final bool sharingConsented;
  final DateTime? activeFrom;
  final DateTime? activeUntil;

  const RoomMembershipGrant({
    required this.roomId,
    required this.userId,
    this.isActive = true,
    this.sharingConsented = true,
    this.activeFrom,
    this.activeUntil,
  });

  bool allowsContributionAt(DateTime occurredAt) {
    if (!isActive || !sharingConsented) return false;
    if (activeFrom != null && occurredAt.isBefore(activeFrom!)) return false;
    if (activeUntil != null && !occurredAt.isBefore(activeUntil!)) return false;
    return true;
  }
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

  ActivityEvidence({
    required this.eventId,
    required this.sourceRecordId,
    required this.sessionId,
    required this.submittedByUserId,
    required this.actorUserId,
    required List<String> roomIds,
    required this.activityType,
    required this.source,
    required this.eventType,
    required this.metricValue,
    required this.metricUnit,
    required this.occurredAt,
    this.deviceId,
  }) : roomIds = List.unmodifiable(roomIds);
}

class ActivityReceipt {
  final String receiptId;
  final String eventId;
  final String sourceRecordId;
  final String sessionId;
  final String actorUserId;
  final ActivityType activityType;
  final String activityFingerprint;
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
    required this.activityFingerprint,
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
  final ActivityReceipt? receipt;
  final List<RoomContribution> contributions;
  final bool wasDuplicate;

  ActivityRecordResult({
    required this.receipt,
    required List<RoomContribution> contributions,
    required this.wasDuplicate,
  }) : contributions = List.unmodifiable(contributions);

  bool get isSettled => receipt != null;
}
