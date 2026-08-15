import 'dart:convert';

import '../models/activity_ledger.dart';
import 'activity_ledger_outbox.dart';
import 'nudge_device_protocol.dart';

typedef DeviceAssignmentResolver =
    Future<DeviceAssignmentGrant?> Function(String deviceId);
typedef DeviceRoomResolver =
    Future<List<String>> Function(DeviceAssignmentGrant assignment);
typedef CurrentActorResolver = String? Function();
typedef DeviceEvidenceEnqueuer =
    Future<void> Function(ActivityEvidence evidence);
typedef DeviceAcknowledgementWriter = Future<void> Function(String commandJson);

class NudgeDeviceBridge {
  const NudgeDeviceBridge({
    required DeviceAssignmentResolver resolveAssignment,
    required DeviceRoomResolver resolveRoomIds,
    required CurrentActorResolver currentActorUserId,
    required DeviceEvidenceEnqueuer enqueueEvidence,
    required DeviceAcknowledgementWriter writeAcknowledgement,
  }) : _resolveAssignment = resolveAssignment,
       _resolveRoomIds = resolveRoomIds,
       _currentActorUserId = currentActorUserId,
       _enqueueEvidence = enqueueEvidence,
       _writeAcknowledgement = writeAcknowledgement;

  NudgeDeviceBridge.withOutbox({
    required DeviceAssignmentResolver resolveAssignment,
    required DeviceRoomResolver resolveRoomIds,
    required CurrentActorResolver currentActorUserId,
    required ActivityLedgerOutbox outbox,
    required DeviceAcknowledgementWriter writeAcknowledgement,
  }) : this(
         resolveAssignment: resolveAssignment,
         resolveRoomIds: resolveRoomIds,
         currentActorUserId: currentActorUserId,
         enqueueEvidence: outbox.enqueue,
         writeAcknowledgement: writeAcknowledgement,
       );

  final DeviceAssignmentResolver _resolveAssignment;
  final DeviceRoomResolver _resolveRoomIds;
  final CurrentActorResolver _currentActorUserId;
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
    final currentActorUserId = _currentActorUserId()?.trim();
    final assignment = await _resolveAssignment(event.deviceId);
    if (assignment == null ||
        assignment.deviceId != event.deviceId ||
        currentActorUserId == null ||
        currentActorUserId.isEmpty ||
        assignment.userId != currentActorUserId ||
        !assignment.allowsActivityAt(event.occurredAt)) {
      throw StateError('The device has no active assignment for this account.');
    }
    final roomIds = await _resolveRoomIds(assignment);

    final evidence = event.toEvidence(
      actorUserId: currentActorUserId,
      roomIds: roomIds,
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
