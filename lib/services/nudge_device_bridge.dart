import 'dart:convert';

import '../models/activity_ledger.dart';
import 'nudge_device_protocol.dart';

typedef DeviceAssignmentResolver =
    Future<NudgeDeviceAssignment?> Function(String deviceId);
typedef DeviceEvidenceEnqueuer =
    Future<void> Function(ActivityEvidence evidence);
typedef DeviceAcknowledgementWriter = Future<void> Function(String commandJson);

class NudgeDeviceAssignment {
  const NudgeDeviceAssignment({
    required this.deviceId,
    required this.actorUserId,
    this.roomIds = const [],
    this.isActive = true,
  });

  final String deviceId;
  final String actorUserId;
  final List<String> roomIds;
  final bool isActive;
}

class NudgeDeviceBridge {
  const NudgeDeviceBridge({
    required DeviceAssignmentResolver resolveAssignment,
    required DeviceEvidenceEnqueuer enqueueEvidence,
    required DeviceAcknowledgementWriter writeAcknowledgement,
  }) : _resolveAssignment = resolveAssignment,
       _enqueueEvidence = enqueueEvidence,
       _writeAcknowledgement = writeAcknowledgement;

  final DeviceAssignmentResolver _resolveAssignment;
  final DeviceEvidenceEnqueuer _enqueueEvidence;
  final DeviceAcknowledgementWriter _writeAcknowledgement;

  Future<ActivityEvidence> acceptEventJson(String eventJson) async {
    final decoded = jsonDecode(eventJson);
    if (decoded is! Map) {
      throw const DeviceMessageFormatException(
        'Device activity event must be a JSON object.',
      );
    }
    final event = NudgeDeviceActivityEvent.fromJson(
      Map<String, dynamic>.from(decoded),
    );
    final assignment = await _resolveAssignment(event.deviceId);
    if (assignment == null ||
        !assignment.isActive ||
        assignment.deviceId != event.deviceId ||
        assignment.actorUserId.trim().isEmpty) {
      throw StateError('The device has no active assignment for this account.');
    }

    final evidence = event.toEvidence(
      actorUserId: assignment.actorUserId,
      roomIds: assignment.roomIds,
    );

    // enqueueEvidence must complete only after the local outbox write is
    // durable. The device queue remains untouched if this throws.
    await _enqueueEvidence(evidence);
    await _writeAcknowledgement(
      jsonEncode({
        'protocolVersion': nudgeDeviceProtocolVersion,
        'type': 'ack',
        'eventId': event.eventId,
      }),
    );
    return evidence;
  }
}
