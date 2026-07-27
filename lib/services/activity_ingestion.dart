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

class InMemoryActivityIngestion implements ActivityIngestion {
  final DateTime Function() _clock;
  final Map<(String roomId, String userId), RoomMembershipGrant>
  _roomMemberships;
  final Set<(String deviceId, String userId)> _deviceAssignments;
  final Map<String, ActivityRecordResult> _resultsByEventId = {};
  final Map<String, String> _signaturesByEventId = {};
  final Map<String, ActivityRecordResult> _resultsBySourceRecord = {};
  final Map<String, String> _signaturesBySourceRecord = {};
  final Map<String, ActivityRecordResult> _settlementsByFingerprint = {};
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
       _deviceAssignments = deviceAssignments
           .map((grant) => (grant.deviceId, grant.userId))
           .toSet();

  int get issuedPersonalRewardCount => _issuedPersonalRewardCount;

  int get issuedReceiptCount => _issuedReceiptCount;

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
    final activityFingerprint = _activityFingerprint(evidence);
    final settledResult = isSettlement
        ? _settlementsByFingerprint[activityFingerprint]
        : null;
    if (settledResult != null) {
      _rememberEvent(evidence, evidenceSignature, settledResult);
      _rememberSourceRecord(sourceRecordKey, evidenceSignature, settledResult);
      return _duplicate(settledResult);
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
        sessionId: evidence.sessionId,
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
      receipt: existing.receipt,
      contributions: existing.contributions,
      wasDuplicate: true,
    );
  }

  bool _isSettlement(ActivityEventType eventType) {
    return eventType == ActivityEventType.completed ||
        eventType == ActivityEventType.metricSynced;
  }

  String _activityFingerprint(ActivityEvidence evidence) {
    return jsonEncode([
      evidence.actorUserId,
      evidence.sessionId,
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
      'deviceId': evidence.deviceId,
    });
  }
}
