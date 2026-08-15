import { createHash } from "node:crypto";

import { HttpsError } from "firebase-functions/v2/https";

const STAFF_ROLES = new Set(["developer", "operator", "admin"]);
const DEVICE_PATTERN = /^nudge-[A-Za-z0-9._-]{2,90}$/;
const IDENTIFIER_PATTERN = /^[A-Za-z0-9][A-Za-z0-9._-]{1,95}$/;
const REQUEST_PATTERN = /^[A-Za-z0-9_-]{8,128}$/;

function text(value) {
  return typeof value === "string" ? value.trim() : "";
}

export function normalizeDeviceAssignmentCommand(data) {
  const action = text(data?.action);
  const deviceId = text(data?.deviceId);
  const assignedUserId = text(data?.assignedUserId);
  const clientRequestId = text(data?.clientRequestId);
  const sourceSurface = text(data?.sourceSurface);
  const allowedRoomIds = data?.allowedRoomIds;
  if (!new Set(["assign", "revoke"]).has(action)) {
    throw new HttpsError("invalid-argument", "Device action is invalid.");
  }
  if (!DEVICE_PATTERN.test(deviceId)) {
    throw new HttpsError("invalid-argument", "Device ID is invalid.");
  }
  if (!IDENTIFIER_PATTERN.test(assignedUserId)) {
    throw new HttpsError("invalid-argument", "Assigned user ID is invalid.");
  }
  if (!REQUEST_PATTERN.test(clientRequestId) || sourceSurface !== "admin_web") {
    throw new HttpsError(
      "invalid-argument",
      "Device commands require a stable Admin Web request ID.",
    );
  }
  if (!Array.isArray(allowedRoomIds) || allowedRoomIds.length > 20) {
    throw new HttpsError("invalid-argument", "Allowed room IDs are invalid.");
  }
  const rooms = allowedRoomIds.map(value => text(value));
  if (
    rooms.some(roomId => !IDENTIFIER_PATTERN.test(roomId)) ||
    new Set(rooms).size !== rooms.length
  ) {
    throw new HttpsError("invalid-argument", "Allowed room IDs are invalid.");
  }
  return {
    action,
    deviceId,
    assignedUserId,
    allowedRoomIds: rooms,
    clientRequestId,
    sourceSurface,
  };
}

function fingerprint(input) {
  return createHash("sha256").update(JSON.stringify(input)).digest("hex");
}

function isStaff(profile) {
  return profile?.developerAccess === true || STAFF_ROLES.has(text(profile?.staffRole));
}

function sameRoomScope(left, right) {
  if (!Array.isArray(left) || left.length !== right.length) return false;
  const leftSet = new Set(left);
  return leftSet.size === right.length && right.every(value => leftSet.has(value));
}

export function createManageDeviceAssignmentHandler({
  firestore,
  clock = () => new Date(),
}) {
  return async request => {
    const actorUserId = request.auth?.uid;
    if (!actorUserId) {
      throw new HttpsError("unauthenticated", "Authentication is required.");
    }
    const input = normalizeDeviceAssignmentCommand(request.data);
    const inputFingerprint = fingerprint(input);
    const result = await firestore.runTransaction(async transaction => {
      const staffRef = firestore.doc(`users/${actorUserId}`);
      const userRef = firestore.doc(`users/${input.assignedUserId}`);
      const assignmentRef = firestore.doc(
        `device_assignments/${input.deviceId}`,
      );
      const transferLockRef = firestore.doc(
        `device_transfer_locks/${input.deviceId}`,
      );
      const deletionFenceRef = firestore.doc(
        `account_deletion_fences/${input.assignedUserId}`,
      );
      const auditRef = firestore.doc(
        `audit_events/device-command--${actorUserId}--${input.clientRequestId}`,
      );
      const [
        staffSnapshot,
        userSnapshot,
        assignmentSnapshot,
        transferLockSnapshot,
        deletionFenceSnapshot,
        auditSnapshot,
      ] =
        await Promise.all([
          transaction.get(staffRef),
          transaction.get(userRef),
          transaction.get(assignmentRef),
          transaction.get(transferLockRef),
          transaction.get(deletionFenceRef),
          transaction.get(auditRef),
        ]);
      if (!staffSnapshot.exists || !isStaff(staffSnapshot.data())) {
        throw new HttpsError(
          "permission-denied",
          "Staff device permission is required.",
        );
      }
      if (transferLockSnapshot.exists) {
        throw new HttpsError(
          "failed-precondition",
          "This device requires a verified queue wipe before it can be assigned.",
        );
      }
      if (auditSnapshot.exists) {
        const audit = auditSnapshot.data();
        if (audit.commandFingerprint !== inputFingerprint) {
          throw new HttpsError(
            "already-exists",
            "The request ID was already used for another command.",
          );
        }
        return { assignment: audit.result, replayed: true };
      }
      if (!userSnapshot.exists) {
        throw new HttpsError("not-found", "Assigned user does not exist.");
      }
      if (deletionFenceSnapshot.exists) {
        throw new HttpsError(
          "failed-precondition",
          "A device cannot be changed while the assigned account is deleting.",
        );
      }
      for (const roomId of input.allowedRoomIds) {
        const [roomSnapshot, memberSnapshot] = await Promise.all([
          transaction.get(firestore.doc(`rooms/${roomId}`)),
          transaction.get(
            firestore.doc(
              `rooms/${roomId}/members/${input.assignedUserId}`,
            ),
          ),
        ]);
        if (
          !roomSnapshot.exists ||
          roomSnapshot.data().status !== "active" ||
          !memberSnapshot.exists ||
          memberSnapshot.data().approvalStatus !== "approved"
        ) {
          throw new HttpsError(
            "failed-precondition",
            "Every allowed room requires an approved active membership.",
          );
        }
      }
      const now = clock().toISOString();
      const existing = assignmentSnapshot.exists
        ? assignmentSnapshot.data()
        : null;
      if (
        input.action === "assign" &&
        existing &&
        existing.assignedUserId !== input.assignedUserId
      ) {
        throw new HttpsError(
          "failed-precondition",
          "A device cannot move to another account until its local queue is verified empty and the hardware is wiped.",
        );
      }
      if (
        input.action === "assign" &&
        existing?.assignedUserId === input.assignedUserId &&
        (existing.status !== "active" ||
          !sameRoomScope(existing.allowedRoomIds, input.allowedRoomIds))
      ) {
        throw new HttpsError(
          "failed-precondition",
          "Reactivation or room-scope changes require a verified empty device queue and wipe receipt.",
        );
      }
      if (
        input.action === "revoke" &&
        (!existing || existing.assignedUserId !== input.assignedUserId)
      ) {
        throw new HttpsError(
          "failed-precondition",
          "Only the current assignment can be revoked.",
        );
      }
      const assignment = {
        schemaVersion: 1,
        assignmentId: input.deviceId,
        deviceId: input.deviceId,
        assignedUserId: input.assignedUserId,
        status: input.action === "assign" ? "active" : "revoked",
        allowedRoomIds:
          input.action === "assign" ? input.allowedRoomIds : [],
        validFrom:
          input.action === "assign"
            ? existing?.status === "active"
              ? existing.validFrom
              : now
            : existing.validFrom,
        validUntil:
          input.action === "assign" ? null : (existing.validUntil ?? now),
        updatedAt: now,
      };
      transaction.set(assignmentRef, assignment);
      transaction.set(auditRef, {
        schemaVersion: 1,
        auditEventId: auditRef.id,
        category: "device",
        actorUserId,
        targetType: "device_assignment",
        targetId: input.deviceId,
        action: `device.assignment.${input.action}`,
        sourceSurface: input.sourceSurface,
        clientRequestId: input.clientRequestId,
        commandFingerprint: inputFingerprint,
        result: assignment,
        createdAt: now,
      });
      return { assignment, replayed: false };
    });
    return {
      deviceId: result.assignment.deviceId,
      assignedUserId: result.assignment.assignedUserId,
      status: result.assignment.status,
      allowedRoomIds: result.assignment.allowedRoomIds,
      auditEventId:
        `device-command--${actorUserId}--${input.clientRequestId}`,
      replayed: result.replayed,
    };
  };
}
