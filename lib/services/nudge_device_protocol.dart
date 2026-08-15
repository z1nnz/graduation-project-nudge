import '../models/activity_ledger.dart';

const nudgeDeviceProtocolVersion = 1;

class DeviceMessageFormatException implements FormatException {
  const DeviceMessageFormatException(this.message);

  @override
  final String message;

  @override
  dynamic get source => null;

  @override
  int? get offset => null;

  @override
  String toString() => 'DeviceMessageFormatException: $message';
}

class NudgeDeviceActivityEvent {
  const NudgeDeviceActivityEvent({
    required this.eventId,
    required this.sourceRecordId,
    required this.deviceId,
    required this.sessionId,
    required this.activityCorrelationId,
    required this.sequence,
    required this.activityType,
    required this.eventType,
    required this.metricValue,
    required this.metricUnit,
    required this.occurredAt,
  });

  final String eventId;
  final String sourceRecordId;
  final String deviceId;
  final String sessionId;
  final String? activityCorrelationId;
  final int sequence;
  final ActivityType activityType;
  final ActivityEventType eventType;
  final double metricValue;
  final String metricUnit;
  final DateTime occurredAt;

  factory NudgeDeviceActivityEvent.fromJson(Map<String, dynamic> json) {
    if (json['protocolVersion'] != nudgeDeviceProtocolVersion) {
      throw const DeviceMessageFormatException(
        'Unsupported device protocol version.',
      );
    }
    if (json['messageType'] != 'activity_event') {
      throw const DeviceMessageFormatException(
        'Device message must be an activity_event.',
      );
    }

    final deviceId = _boundedIdentifier(json['deviceId'], 'deviceId');
    final sessionId = _boundedIdentifier(json['sessionId'], 'sessionId');
    final correlationValue = json['activityCorrelationId'];
    final activityCorrelationId = correlationValue == null
        ? null
        : _boundedIdentifier(correlationValue, 'activityCorrelationId');
    final sequenceValue = json['sequence'];
    if (sequenceValue is! int || sequenceValue < 1) {
      throw const DeviceMessageFormatException(
        'sequence must be a positive integer.',
      );
    }

    final eventType = switch (json['eventType']) {
      'started' => ActivityEventType.started,
      'paused' => ActivityEventType.paused,
      'resumed' => ActivityEventType.resumed,
      'completed' => ActivityEventType.completed,
      _ => throw const DeviceMessageFormatException(
        'Unsupported device eventType.',
      ),
    };
    if (json['activityType'] != 'focus') {
      throw const DeviceMessageFormatException(
        'The first device protocol supports focus activity only.',
      );
    }
    if (json['metricUnit'] != 'minutes') {
      throw const DeviceMessageFormatException(
        'Focus device events must use minutes.',
      );
    }
    final metricValue = json['metricValue'];
    if (metricValue is! num ||
        !metricValue.isFinite ||
        metricValue < 0 ||
        metricValue > 1440) {
      throw const DeviceMessageFormatException(
        'metricValue must be a finite focus duration from 0 to 1440 minutes.',
      );
    }

    final epochValue = json['occurredAtEpochMs'];
    if (epochValue is! int || epochValue <= 0) {
      throw const DeviceMessageFormatException(
        'occurredAtEpochMs must be a positive integer.',
      );
    }
    final eventId = _nonEmptyString(json['eventId'], 'eventId', 256);
    final sourceRecordId = _nonEmptyString(
      json['sourceRecordId'],
      'sourceRecordId',
      256,
    );
    final expectedEventId =
        '$deviceId:$sessionId:${eventType.name}:$sequenceValue';
    if (eventId != expectedEventId || sourceRecordId != eventId) {
      throw const DeviceMessageFormatException(
        'Device event identity does not match its payload.',
      );
    }

    return NudgeDeviceActivityEvent(
      eventId: eventId,
      sourceRecordId: sourceRecordId,
      deviceId: deviceId,
      sessionId: sessionId,
      activityCorrelationId: activityCorrelationId,
      sequence: sequenceValue,
      activityType: ActivityType.focus,
      eventType: eventType,
      metricValue: metricValue.toDouble(),
      metricUnit: 'minutes',
      occurredAt: DateTime.fromMillisecondsSinceEpoch(epochValue, isUtc: true),
    );
  }

  ActivityEvidence toEvidence({
    required String actorUserId,
    required List<String> roomIds,
  }) {
    final normalizedActor = actorUserId.trim();
    if (normalizedActor.isEmpty) {
      throw ArgumentError.value(
        actorUserId,
        'actorUserId',
        'A trusted device assignment is required.',
      );
    }
    return ActivityEvidence(
      eventId: eventId,
      sourceRecordId: sourceRecordId,
      sessionId: sessionId,
      activityCorrelationId: activityCorrelationId,
      submittedByUserId: normalizedActor,
      actorUserId: normalizedActor,
      roomIds: List.unmodifiable(roomIds),
      activityType: activityType,
      // The signed-in App is the authenticated Cloud submitter. The stable
      // sourceRecordId retains the device provenance without asking the
      // user-ingestion endpoint to trust an unauthenticated BLE identity.
      source: ActivitySource.app,
      eventType: eventType,
      metricValue: metricValue,
      metricUnit: metricUnit,
      occurredAt: occurredAt,
    );
  }
}

final _identifierPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,95}$');

String _boundedIdentifier(Object? value, String field) {
  final result = _nonEmptyString(value, field, 96);
  if (!_identifierPattern.hasMatch(result)) {
    throw DeviceMessageFormatException('$field has an invalid format.');
  }
  return result;
}

String _nonEmptyString(Object? value, String field, int maximumLength) {
  if (value is! String ||
      value.isEmpty ||
      value.length > maximumLength ||
      value != value.trim()) {
    throw DeviceMessageFormatException('$field must be a bounded string.');
  }
  return value;
}
