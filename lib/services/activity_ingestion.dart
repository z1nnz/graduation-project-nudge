import 'dart:convert';

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

class _ActivitySessionState {
  final String canonicalSessionId;
  final String actorUserId;
  final ActivityType activityType;
  final DateTime startedAt;
  final Set<String> sourceSessionIds;
  ActivitySessionStatus status;
  DateTime? endedAt;
  double metricValue;
  String metricUnit;

  _ActivitySessionState({
    required this.canonicalSessionId,
    required this.actorUserId,
    required this.activityType,
    required this.startedAt,
    required this.sourceSessionIds,
    required this.status,
    required this.metricValue,
    required this.metricUnit,
  });

  ActivitySessionSnapshot snapshot() => ActivitySessionSnapshot(
    activitySessionId: canonicalSessionId,
    actorUserId: actorUserId,
    activityType: activityType,
    status: status,
    startedAt: startedAt,
    endedAt: endedAt,
    metricValue: metricValue,
    metricUnit: metricUnit,
    sourceSessionIds: sourceSessionIds.toList(growable: false),
  );
}

class InMemoryActivityIngestion implements ActivityIngestion {
  final DateTime Function() _clock;
  final Map<(String roomId, String userId), RoomMembershipGrant>
  _roomMemberships;
  final List<DeviceAssignmentGrant> _deviceAssignments;
  final Map<String, ActivityRecordResult> _resultsByEventId = {};
  final Map<String, String> _signaturesByEventId = {};
  final Map<String, ActivityRecordResult> _resultsBySourceRecord = {};
  final Map<String, String> _signaturesBySourceRecord = {};
  final Map<String, ActivityRecordResult> _settlementsByFingerprint = {};
  final Map<(String, ActivityType), _ActivitySessionState> _openSessions = {};
  final Map<(String, ActivityType, String), _ActivitySessionState>
  _sessionsByAlias = {};
  final Map<(String, ActivityType, String), _ActivitySessionState>
  _sessionsByCanonicalId = {};
  int _issuedPersonalRewardCount = 0;
  int _issuedReceiptCount = 0;

  InMemoryActivityIngestion({
    DateTime Function()? clock,
    List<RoomMembershipGrant> roomMemberships = const [],
    List<DeviceAssignmentGrant> deviceAssignments = const [],
  }) : _clock = clock ?? DateTime.now,
       _roomMemberships = roomMemberships.fold({}, (grants, grant) {
         grants[(grant.roomId, grant.userId)] = grant;
         return grants;
       }),
       _deviceAssignments = List.unmodifiable(deviceAssignments);

  int get issuedPersonalRewardCount => _issuedPersonalRewardCount;

  int get issuedReceiptCount => _issuedReceiptCount;

  List<ActivitySessionSnapshot> get activitySessions => _sessionsByCanonicalId
      .values
      .map((session) => session.snapshot())
      .toList(growable: false);

  @override
  ActivityRecordResult recordActivity(ActivityEvidence evidence) {
    _validateEvidence(evidence);
    _authorizeEvidence(evidence);

    final evidenceSignature = _evidenceSignature(evidence);
    final existing = _resultsByEventId[evidence.eventId];
    if (existing != null) {
      if (_signaturesByEventId[evidence.eventId] != evidenceSignature) {
        throw const ActivityValidationException(
          'The event ID is already used by different activity evidence.',
        );
      }
      return _duplicate(existing);
    }

    final sourceRecordKey = [
      evidence.source.name,
      evidence.actorUserId,
      evidence.activityType.name,
      evidence.eventType.name,
      evidence.sourceRecordId,
    ].join(':');
    final sourceRecordResult = _resultsBySourceRecord[sourceRecordKey];
    if (sourceRecordResult != null) {
      if (_signaturesBySourceRecord[sourceRecordKey] != evidenceSignature) {
        throw const ActivityValidationException(
          'The source record is already used by different activity evidence.',
        );
      }
      _rememberEvent(evidence, evidenceSignature, sourceRecordResult);
      return _duplicate(sourceRecordResult);
    }

    final isSettlement = _isSettlement(evidence.eventType);
    final canonicalSessionId = _resolveCanonicalSession(evidence);
    final activityFingerprint = _activityFingerprint(
      evidence,
      canonicalSessionId,
    );
    final settledResult = isSettlement
        ? _settlementsByFingerprint[activityFingerprint]
        : null;
    if (settledResult != null) {
      _validateSettlementCompatibility(evidence, settledResult);
      final mergedResult = _mergeEligibleContributions(evidence, settledResult);
      _replaceCachedResult(settledResult, mergedResult);
      _rememberEvent(evidence, evidenceSignature, mergedResult);
      _rememberSourceRecord(sourceRecordKey, evidenceSignature, mergedResult);
      return _duplicate(mergedResult);
    }

    final verifiedAt = _clock();
    ActivityReceipt? receipt;
    if (isSettlement) {
      _issuedPersonalRewardCount++;
      _issuedReceiptCount++;
      receipt = ActivityReceipt(
        receiptId: 'receipt_${evidence.eventId}',
        eventId: evidence.eventId,
        sourceRecordId: evidence.sourceRecordId,
        sessionId: canonicalSessionId,
        actorUserId: evidence.actorUserId,
        activityType: evidence.activityType,
        activityFingerprint: activityFingerprint,
        acceptedMetric: evidence.metricValue,
        metricUnit: evidence.metricUnit,
        personalRewardIssued: true,
        characterExperienceIssued: true,
        verifiedAt: verifiedAt,
      );
    }
    final contributionRoomIds = isSettlement
        ? evidence.roomIds.toSet()
        : const <String>{};
    final contributions = contributionRoomIds
        .where((roomId) {
          final grant = _roomMemberships[(roomId, evidence.actorUserId)];
          return grant?.allowsContributionAt(evidence.occurredAt) ?? false;
        })
        .map(
          (roomId) => RoomContribution(
            contributionId: '${receipt!.receiptId}_$roomId',
            receiptId: receipt.receiptId,
            roomId: roomId,
            actorUserId: evidence.actorUserId,
            metricValue: evidence.metricValue,
            metricUnit: evidence.metricUnit,
            createdAt: verifiedAt,
          ),
        )
        .toList(growable: false);
    final result = ActivityRecordResult(
      status: isSettlement
          ? ActivityRecordStatus.settled
          : ActivityRecordStatus.accepted,
      receipt: receipt,
      contributions: contributions,
      wasDuplicate: false,
    );
    _rememberEvent(evidence, evidenceSignature, result);
    _rememberSourceRecord(sourceRecordKey, evidenceSignature, result);
    if (isSettlement) {
      _settlementsByFingerprint[activityFingerprint] = result;
    }
    return result;
  }

  void _validateEvidence(ActivityEvidence evidence) {
    if (!evidence.metricValue.isFinite || evidence.metricValue < 0) {
      throw const ActivityValidationException(
        'Activity metrics must be finite and non-negative.',
      );
    }
    final requiredValues = [
      evidence.eventId,
      evidence.sourceRecordId,
      evidence.sessionId,
      evidence.submittedByUserId,
      evidence.actorUserId,
      evidence.metricUnit,
    ];
    if (requiredValues.any((value) => value.trim().isEmpty)) {
      throw const ActivityValidationException(
        'Activity identifiers and metric units cannot be empty.',
      );
    }
  }

  void _authorizeEvidence(ActivityEvidence evidence) {
    if (evidence.source == ActivitySource.device) {
      final deviceId = evidence.deviceId;
      if (deviceId == null ||
          evidence.submittedByUserId != 'device:$deviceId' ||
          !_deviceAssignments.any(
            (grant) =>
                grant.deviceId == deviceId &&
                grant.userId == evidence.actorUserId &&
                grant.allowsActivityAt(evidence.occurredAt),
          )) {
        throw const ActivityAuthorizationException(
          'The device is not assigned to this actor.',
        );
      }
    } else if (evidence.submittedByUserId != evidence.actorUserId) {
      throw const ActivityAuthorizationException(
        'Only the actor can control this activity.',
      );
    }
  }

  void _rememberEvent(
    ActivityEvidence evidence,
    String evidenceSignature,
    ActivityRecordResult result,
  ) {
    _resultsByEventId[evidence.eventId] = result;
    _signaturesByEventId[evidence.eventId] = evidenceSignature;
  }

  void _rememberSourceRecord(
    String sourceRecordKey,
    String evidenceSignature,
    ActivityRecordResult result,
  ) {
    _resultsBySourceRecord[sourceRecordKey] = result;
    _signaturesBySourceRecord[sourceRecordKey] = evidenceSignature;
  }

  ActivityRecordResult _duplicate(ActivityRecordResult existing) {
    return ActivityRecordResult(
      status: existing.status,
      receipt: existing.receipt,
      contributions: existing.contributions,
      wasDuplicate: true,
    );
  }

  bool _isSettlement(ActivityEventType eventType) {
    return eventType == ActivityEventType.completed ||
        eventType == ActivityEventType.metricSynced;
  }

  String _resolveCanonicalSession(ActivityEvidence evidence) {
    if (evidence.eventType == ActivityEventType.metricSynced) {
      final canonicalKey = (
        evidence.actorUserId,
        evidence.activityType,
        evidence.sessionId,
      );
      _sessionsByCanonicalId.putIfAbsent(
        canonicalKey,
        () => _ActivitySessionState(
          canonicalSessionId: evidence.sessionId,
          actorUserId: evidence.actorUserId,
          activityType: evidence.activityType,
          startedAt: evidence.occurredAt,
          sourceSessionIds: {evidence.sessionId},
          status: ActivitySessionStatus.completed,
          metricValue: evidence.metricValue,
          metricUnit: evidence.metricUnit,
        )..endedAt = evidence.occurredAt,
      );
      return evidence.sessionId;
    }

    final openKey = (evidence.actorUserId, evidence.activityType);
    final aliasKey = (
      evidence.actorUserId,
      evidence.activityType,
      evidence.sessionId,
    );
    var session = _sessionsByAlias[aliasKey];
    if (session == null) {
      session = _openSessions[openKey];
      if (session == null) {
        if (evidence.eventType == ActivityEventType.paused ||
            evidence.eventType == ActivityEventType.resumed) {
          throw const ActivityValidationException(
            'The activity session is not active.',
          );
        }
        session = _ActivitySessionState(
          canonicalSessionId: evidence.sessionId,
          actorUserId: evidence.actorUserId,
          activityType: evidence.activityType,
          startedAt: evidence.occurredAt,
          sourceSessionIds: {evidence.sessionId},
          status: ActivitySessionStatus.active,
          metricValue: 0,
          metricUnit: evidence.metricUnit,
        );
        _openSessions[openKey] = session;
        _sessionsByCanonicalId[(
              evidence.actorUserId,
              evidence.activityType,
              session.canonicalSessionId,
            )] =
            session;
      } else {
        session.sourceSessionIds.add(evidence.sessionId);
      }
      _sessionsByAlias[aliasKey] = session;
    }

    if (session.status == ActivitySessionStatus.completed) {
      if (evidence.eventType != ActivityEventType.completed) {
        throw const ActivityValidationException(
          'A completed activity session cannot change state.',
        );
      }
      final endedAt = session.endedAt;
      if (endedAt != null &&
          evidence.occurredAt.difference(endedAt).abs() >
              const Duration(minutes: 5)) {
        throw const ActivityValidationException(
          'The completed session ID was reused for another activity.',
        );
      }
      return session.canonicalSessionId;
    }

    switch (evidence.eventType) {
      case ActivityEventType.started:
        break;
      case ActivityEventType.paused:
        session.status = ActivitySessionStatus.paused;
        session.metricValue = evidence.metricValue;
        session.metricUnit = evidence.metricUnit;
        break;
      case ActivityEventType.resumed:
        session.status = ActivitySessionStatus.active;
        session.metricValue = evidence.metricValue;
        session.metricUnit = evidence.metricUnit;
        break;
      case ActivityEventType.completed:
        session.status = ActivitySessionStatus.completed;
        session.endedAt = evidence.occurredAt;
        session.metricValue = evidence.metricValue;
        session.metricUnit = evidence.metricUnit;
        if (identical(_openSessions[openKey], session)) {
          _openSessions.remove(openKey);
        }
        break;
      case ActivityEventType.metricSynced:
        break;
    }
    return session.canonicalSessionId;
  }

  void _validateSettlementCompatibility(
    ActivityEvidence evidence,
    ActivityRecordResult settledResult,
  ) {
    final receipt = settledResult.receipt;
    if (receipt == null ||
        receipt.metricUnit != evidence.metricUnit ||
        receipt.acceptedMetric != evidence.metricValue) {
      throw const ActivityValidationException(
        'The activity settlement conflicts with its existing receipt.',
      );
    }
  }

  ActivityRecordResult _mergeEligibleContributions(
    ActivityEvidence evidence,
    ActivityRecordResult settledResult,
  ) {
    final receipt = settledResult.receipt!;
    final contributionsByRoom = {
      for (final contribution in settledResult.contributions)
        contribution.roomId: contribution,
    };
    final createdAt = _clock();
    for (final roomId in evidence.roomIds.toSet()) {
      final grant = _roomMemberships[(roomId, evidence.actorUserId)];
      if (contributionsByRoom.containsKey(roomId) ||
          !(grant?.allowsContributionAt(evidence.occurredAt) ?? false)) {
        continue;
      }
      contributionsByRoom[roomId] = RoomContribution(
        contributionId: '${receipt.receiptId}_$roomId',
        receiptId: receipt.receiptId,
        roomId: roomId,
        actorUserId: evidence.actorUserId,
        metricValue: receipt.acceptedMetric,
        metricUnit: receipt.metricUnit,
        createdAt: createdAt,
      );
    }
    return ActivityRecordResult(
      status: ActivityRecordStatus.settled,
      receipt: receipt,
      contributions: contributionsByRoom.values.toList(growable: false),
      wasDuplicate: false,
    );
  }

  void _replaceCachedResult(
    ActivityRecordResult oldResult,
    ActivityRecordResult newResult,
  ) {
    for (final entry in _resultsByEventId.entries.toList(growable: false)) {
      if (identical(entry.value, oldResult)) {
        _resultsByEventId[entry.key] = newResult;
      }
    }
    for (final entry in _resultsBySourceRecord.entries.toList(
      growable: false,
    )) {
      if (identical(entry.value, oldResult)) {
        _resultsBySourceRecord[entry.key] = newResult;
      }
    }
    for (final entry in _settlementsByFingerprint.entries.toList(
      growable: false,
    )) {
      if (identical(entry.value, oldResult)) {
        _settlementsByFingerprint[entry.key] = newResult;
      }
    }
  }

  String _activityFingerprint(
    ActivityEvidence evidence,
    String canonicalSessionId,
  ) {
    return jsonEncode([
      evidence.actorUserId,
      canonicalSessionId,
      evidence.activityType.name,
    ]);
  }

  String _evidenceSignature(ActivityEvidence evidence) {
    final roomIds = evidence.roomIds.toSet().toList()..sort();
    return jsonEncode({
      'sourceRecordId': evidence.sourceRecordId,
      'sessionId': evidence.sessionId,
      'submittedByUserId': evidence.submittedByUserId,
      'actorUserId': evidence.actorUserId,
      'roomIds': roomIds,
      'activityType': evidence.activityType.name,
      'source': evidence.source.name,
      'eventType': evidence.eventType.name,
      'metricValue': evidence.metricValue,
      'metricUnit': evidence.metricUnit,
      'occurredAt': evidence.occurredAt.toUtc().toIso8601String(),
      'receivedAt': evidence.receivedAt?.toUtc().toIso8601String(),
      'deviceId': evidence.deviceId,
    });
  }
}
