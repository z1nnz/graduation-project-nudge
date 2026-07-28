enum ActivityType { focus, study, exercise, steps, sleep, custom }

enum ActivitySource { app, health, device, web }

enum ActivityEventType {
  started,
  paused,
  resumed,
  completed,
  metricSynced,
  discarded,
}

enum ActivityRecordStatus { accepted, settled }

enum ActivitySessionStatus { active, paused, completed, discarded }

Map<String, dynamic> _stringMap(Object? value, String field) {
  if (value is! Map) {
    throw FormatException('$field must be an object');
  }
  return Map<String, dynamic>.from(value);
}

T _enumValue<T extends Enum>(List<T> values, Object? value, String field) {
  if (value is! String) {
    throw FormatException('$field must be a string');
  }
  return values.firstWhere(
    (item) => item.name == value,
    orElse: () => throw FormatException('Unsupported $field: $value'),
  );
}

DateTime _dateValue(Object? value, String field) {
  if (value is! String) {
    throw FormatException('$field must be a timestamp');
  }
  return DateTime.parse(value).toUtc();
}

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
  final bool isActive;
  final DateTime? validFrom;
  final DateTime? validUntil;

  const DeviceAssignmentGrant({
    required this.deviceId,
    required this.userId,
    this.isActive = true,
    this.validFrom,
    this.validUntil,
  });

  bool allowsActivityAt(DateTime occurredAt) {
    if (!isActive) return false;
    if (validFrom != null && occurredAt.isBefore(validFrom!)) return false;
    if (validUntil != null && !occurredAt.isBefore(validUntil!)) return false;
    return true;
  }
}

class ActivityEvidence {
  final String eventId;
  final String sourceRecordId;
  final String sessionId;
  final String? activityCorrelationId;
  final String submittedByUserId;
  final String actorUserId;
  final List<String> roomIds;
  final ActivityType activityType;
  final ActivitySource source;
  final ActivityEventType eventType;
  final double metricValue;
  final String metricUnit;
  final DateTime occurredAt;
  final DateTime? receivedAt;
  final String? deviceId;

  ActivityEvidence({
    required this.eventId,
    required this.sourceRecordId,
    required this.sessionId,
    this.activityCorrelationId,
    required this.submittedByUserId,
    required this.actorUserId,
    required List<String> roomIds,
    required this.activityType,
    required this.source,
    required this.eventType,
    required this.metricValue,
    required this.metricUnit,
    required this.occurredAt,
    this.receivedAt,
    this.deviceId,
  }) : roomIds = List.unmodifiable(roomIds);

  Map<String, dynamic> toCloudJson() => {
    'eventId': eventId,
    'sourceRecordId': sourceRecordId,
    'sessionId': sessionId,
    'activityCorrelationId': activityCorrelationId,
    'actorUserId': actorUserId,
    'roomIds': roomIds,
    'activityType': activityType.name,
    'source': source.name,
    'eventType': eventType.name,
    'metricValue': metricValue,
    'metricUnit': metricUnit,
    'occurredAt': occurredAt.toUtc().toIso8601String(),
    if (deviceId != null) 'deviceId': deviceId,
  };

  Map<String, dynamic> toOutboxJson() => {
    ...toCloudJson(),
    'submittedByUserId': submittedByUserId,
    if (receivedAt != null) 'receivedAt': receivedAt!.toUtc().toIso8601String(),
  };

  factory ActivityEvidence.fromOutboxJson(Map<Object?, Object?> raw) {
    final data = Map<String, dynamic>.from(raw);
    return ActivityEvidence(
      eventId: data['eventId'] as String,
      sourceRecordId: data['sourceRecordId'] as String,
      sessionId: data['sessionId'] as String,
      activityCorrelationId: data['activityCorrelationId'] as String?,
      submittedByUserId: data['submittedByUserId'] as String,
      actorUserId: data['actorUserId'] as String,
      roomIds: (data['roomIds'] as List? ?? const [])
          .whereType<String>()
          .toList(),
      activityType: _enumValue(
        ActivityType.values,
        data['activityType'],
        'activityType',
      ),
      source: _enumValue(
        ActivitySource.values,
        data['source'],
        'activity source',
      ),
      eventType: _enumValue(
        ActivityEventType.values,
        data['eventType'],
        'event type',
      ),
      metricValue: (data['metricValue'] as num).toDouble(),
      metricUnit: data['metricUnit'] as String,
      occurredAt: _dateValue(data['occurredAt'], 'occurredAt'),
      receivedAt: data['receivedAt'] == null
          ? null
          : _dateValue(data['receivedAt'], 'receivedAt'),
      deviceId: data['deviceId'] as String?,
    );
  }
}

class ActivitySessionSnapshot {
  final String activitySessionId;
  final String actorUserId;
  final ActivityType activityType;
  final ActivitySessionStatus status;
  final DateTime startedAt;
  final DateTime? endedAt;
  final double metricValue;
  final String metricUnit;
  final List<String> sourceSessionIds;

  ActivitySessionSnapshot({
    required this.activitySessionId,
    required this.actorUserId,
    required this.activityType,
    required this.status,
    required this.startedAt,
    required this.endedAt,
    required this.metricValue,
    required this.metricUnit,
    required List<String> sourceSessionIds,
  }) : sourceSessionIds = List.unmodifiable(sourceSessionIds);

  factory ActivitySessionSnapshot.fromCloudJson(Object? raw) {
    final data = _stringMap(raw, 'session');
    return ActivitySessionSnapshot(
      activitySessionId: data['activitySessionId'] as String,
      actorUserId: data['actorUserId'] as String,
      activityType: _enumValue(
        ActivityType.values,
        data['activityType'],
        'activityType',
      ),
      status: _enumValue(
        ActivitySessionStatus.values,
        data['status'],
        'session status',
      ),
      startedAt: _dateValue(data['startedAt'], 'startedAt'),
      endedAt: data['endedAt'] == null
          ? null
          : _dateValue(data['endedAt'], 'endedAt'),
      metricValue: (data['metricValue'] as num).toDouble(),
      metricUnit: data['metricUnit'] as String,
      sourceSessionIds: (data['sourceSessionIds'] as List? ?? const [])
          .whereType<String>()
          .toList(),
    );
  }
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
  final bool rewardEligible;
  final bool personalRewardIssued;
  final bool characterExperienceEligible;
  final bool characterExperienceIssued;
  final DateTime verifiedAt;
  final String? correctionOfReceiptId;

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
    this.rewardEligible = true,
    required this.personalRewardIssued,
    this.characterExperienceEligible = true,
    required this.characterExperienceIssued,
    required this.verifiedAt,
    this.correctionOfReceiptId,
  });

  factory ActivityReceipt.fromCloudJson(Object? raw) {
    final data = _stringMap(raw, 'receipt');
    return ActivityReceipt(
      receiptId: data['receiptId'] as String,
      eventId: data['eventId'] as String,
      sourceRecordId: data['sourceRecordId'] as String,
      sessionId: data['activitySessionId'] as String,
      actorUserId: data['actorUserId'] as String,
      activityType: _enumValue(
        ActivityType.values,
        data['activityType'],
        'activityType',
      ),
      activityFingerprint: data['activityFingerprint'] as String,
      acceptedMetric: (data['acceptedMetric'] as num).toDouble(),
      metricUnit: data['metricUnit'] as String,
      rewardEligible: data['rewardEligible'] as bool? ?? false,
      personalRewardIssued: data['rewardIssued'] as bool? ?? false,
      characterExperienceEligible:
          data['characterExperienceEligible'] as bool? ?? false,
      characterExperienceIssued:
          data['characterExperienceIssued'] as bool? ?? false,
      verifiedAt: _dateValue(data['verifiedAt'], 'verifiedAt'),
      correctionOfReceiptId: data['correctionOfReceiptId'] as String?,
    );
  }
}

class RoomContribution {
  final String contributionId;
  final String receiptId;
  final String roomId;
  final String actorUserId;
  final double metricValue;
  final String metricUnit;
  final DateTime? occurredAt;
  final DateTime createdAt;

  const RoomContribution({
    required this.contributionId,
    required this.receiptId,
    required this.roomId,
    required this.actorUserId,
    required this.metricValue,
    required this.metricUnit,
    this.occurredAt,
    required this.createdAt,
  });

  factory RoomContribution.fromCloudJson(Object? raw) {
    final data = _stringMap(raw, 'contribution');
    return RoomContribution(
      contributionId: data['contributionId'] as String,
      receiptId: data['receiptId'] as String,
      roomId: data['roomId'] as String,
      actorUserId: data['actorUserId'] as String,
      metricValue: (data['metricValue'] as num).toDouble(),
      metricUnit: data['metricUnit'] as String,
      occurredAt: data['occurredAt'] == null
          ? null
          : _dateValue(data['occurredAt'], 'occurredAt'),
      createdAt: _dateValue(data['createdAt'], 'createdAt'),
    );
  }
}

class ActivityRecordResult {
  final ActivityRecordStatus status;
  final String acknowledgedEventId;
  final String acknowledgedSourceRecordId;
  final String canonicalSessionId;
  final ActivityReceipt? receipt;
  final List<RoomContribution> contributions;
  final ActivitySessionSnapshot? session;
  final bool wasDuplicate;

  ActivityRecordResult({
    required this.status,
    required this.acknowledgedEventId,
    required this.acknowledgedSourceRecordId,
    required this.canonicalSessionId,
    required this.receipt,
    required List<RoomContribution> contributions,
    this.session,
    required this.wasDuplicate,
  }) : contributions = List.unmodifiable(contributions);

  bool get isSettled => receipt != null;

  factory ActivityRecordResult.fromCloudJson(Map<Object?, Object?> raw) {
    final data = Map<String, dynamic>.from(raw);
    final contributions = (data['contributions'] as List? ?? const [])
        .map(RoomContribution.fromCloudJson)
        .toList();
    return ActivityRecordResult(
      status: _enumValue(
        ActivityRecordStatus.values,
        data['status'],
        'record status',
      ),
      acknowledgedEventId: data['acknowledgedEventId'] as String,
      acknowledgedSourceRecordId: data['acknowledgedSourceRecordId'] as String,
      canonicalSessionId: data['canonicalSessionId'] as String,
      receipt: data['receipt'] == null
          ? null
          : ActivityReceipt.fromCloudJson(data['receipt']),
      contributions: contributions,
      session: data['session'] == null
          ? null
          : ActivitySessionSnapshot.fromCloudJson(data['session']),
      wasDuplicate: data['wasDuplicate'] as bool? ?? false,
    );
  }
}
