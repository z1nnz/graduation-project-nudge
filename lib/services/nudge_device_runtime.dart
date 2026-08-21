import 'dart:async';

import '../models/activity_ledger.dart';
import 'activity_ledger_outbox.dart';
import 'android_nudge_ble_transport.dart';
import 'firestore_device_assignment_repository.dart';
import 'nudge_device_bridge.dart';
import 'nudge_device_coordinator.dart';

class NudgeDeviceRuntime {
  NudgeDeviceRuntime({
    required NudgeBleTransport transport,
    required FirestoreDeviceAssignmentRepository assignmentRepository,
    required ActivityLedgerOutbox activityLedgerOutbox,
    required CurrentActorResolver currentActorUserId,
    required Future<String> Function() prepareFocusCorrelation,
    DateTime Function()? clock,
  }) : _activityLedgerOutbox = activityLedgerOutbox,
       _prepareFocusCorrelation = prepareFocusCorrelation,
       coordinator = _buildCoordinator(
         transport: transport,
         assignmentRepository: assignmentRepository,
         activityLedgerOutbox: activityLedgerOutbox,
         currentActorUserId: currentActorUserId,
         clock: clock ?? DateTime.now,
       );

  final ActivityLedgerOutbox _activityLedgerOutbox;
  final Future<String> Function() _prepareFocusCorrelation;
  final NudgeDeviceCoordinator coordinator;

  static NudgeDeviceCoordinator _buildCoordinator({
    required NudgeBleTransport transport,
    required FirestoreDeviceAssignmentRepository assignmentRepository,
    required ActivityLedgerOutbox activityLedgerOutbox,
    required CurrentActorResolver currentActorUserId,
    required DateTime Function() clock,
  }) {
    Future<DeviceAssignmentGrant?> resolveAssignment(String deviceId) async {
      final actorUserId = currentActorUserId()?.trim();
      if (actorUserId == null || actorUserId.isEmpty) return null;
      return assignmentRepository.resolve(
        deviceId: deviceId,
        currentUserId: actorUserId,
      );
    }

    final bridge = NudgeDeviceBridge(
      resolveAssignment: resolveAssignment,
      resolveRoomIds: (assignment) async => assignment.allowedRoomIds,
      currentActorUserId: currentActorUserId,
      enqueueEvidence: (evidence) async {
        await activityLedgerOutbox.enqueue(evidence);
        unawaited(_flushSafely(activityLedgerOutbox));
      },
      writeAcknowledgement: transport.writeCommand,
    );
    return NudgeDeviceCoordinator(
      transport: transport,
      bridge: bridge,
      validateAssignment: (deviceId) async {
        final assignment = await resolveAssignment(deviceId);
        return assignment != null && assignment.allowsActivityAt(clock());
      },
      clock: clock,
    );
  }

  static Future<void> _flushSafely(ActivityLedgerOutbox outbox) async {
    try {
      await outbox.flush();
    } catch (_) {
      // Durable local evidence stays queued for the next authenticated flush.
    }
  }

  Future<int> pendingCloudEvents() => _activityLedgerOutbox.pendingCount();

  Future<ActivityLedgerFlushReport> flushCloudEvents() =>
      _activityLedgerOutbox.flush();

  Future<String> prepareFocusCorrelation() => _prepareFocusCorrelation();

  Future<void> close() => coordinator.close();
}
