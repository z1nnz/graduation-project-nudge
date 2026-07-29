import { HttpsError } from "firebase-functions/v2/https";

const TERMINAL_REQUEST_STATUSES = new Set([
  "accepted",
  "declined",
  "cancelled",
]);

function normalizedString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function requireRequestIdentity(data) {
  const senderId = normalizedString(data?.senderId);
  const receiverId = normalizedString(data?.receiverId);
  if (!senderId || !receiverId || senderId === receiverId) {
    throw new Error("Relationship request identity is invalid.");
  }
  return { senderId, receiverId };
}

function requestLabels(scopeType, data) {
  if (scopeType === "family") {
    return {
      category: "relationship",
      invitationKind: "family_invitation",
      invitationTitle: "新的家庭連結邀請",
      invitationBody: `${normalizedString(data.senderNickname) || "一位使用者"} 邀請你建立家庭連結。`,
      route: "guardian",
    };
  }
  if (scopeType === "group") {
    const groupName = normalizedString(data.groupName) || "一個團體";
    return {
      category: "relationship",
      invitationKind: "group_invitation",
      invitationTitle: "新的團體邀請",
      invitationBody: `你收到加入「${groupName}」的邀請。`,
      route: "groups",
    };
  }
  throw new Error("Unsupported relationship notification scope.");
}

export function buildRelationshipInvitationNotification({
  scopeType,
  requestId,
  requestData,
  actorUserId,
  now,
}) {
  const identity = requireRequestIdentity(requestData);
  const labels = requestLabels(scopeType, requestData);
  const notificationId = `${scopeType}-request--${requestId}--pending`;
  return {
    schemaVersion: 1,
    notificationId,
    recipientUserId: identity.receiverId,
    category: labels.category,
    kind: labels.invitationKind,
    sourceType: `${scopeType}_request`,
    sourceId: requestId,
    actorUserId: identity.senderId,
    actorPrincipalId: normalizedString(actorUserId),
    title: labels.invitationTitle,
    body: labels.invitationBody,
    route: labels.route,
    status: "unread",
    createdAt: now,
    updatedAt: now,
  };
}

export function buildRelationshipOutcomeNotification({
  scopeType,
  requestId,
  beforeData,
  afterData,
  actorUserId,
  now,
}) {
  const previousStatus = normalizedString(beforeData?.status);
  const status = normalizedString(afterData?.status);
  if (
    previousStatus === status ||
    !TERMINAL_REQUEST_STATUSES.has(status)
  ) {
    return null;
  }
  const identity = requireRequestIdentity(afterData);
  const labels = requestLabels(scopeType, afterData);
  const cancelled = status === "cancelled";
  const recipientUserId = cancelled
    ? identity.receiverId
    : identity.senderId;
  const actionActorUserId = cancelled
    ? identity.senderId
    : identity.receiverId;
  const statusLabel = {
    accepted: "已接受",
    declined: "已拒絕",
    cancelled: "已取消",
  }[status];
  const scopeLabel = scopeType === "family" ? "家庭連結邀請" : "團體邀請";
  const notificationId = `${scopeType}-request--${requestId}--${status}`;
  return {
    schemaVersion: 1,
    notificationId,
    recipientUserId,
    category: labels.category,
    kind: `${scopeType}_invitation_${status}`,
    sourceType: `${scopeType}_request`,
    sourceId: requestId,
    actorUserId: actionActorUserId,
    actorPrincipalId: normalizedString(actorUserId),
    title: `${scopeLabel}${statusLabel}`,
    body: `${scopeLabel}的最新狀態為「${statusLabel}」。`,
    route: labels.route,
    status: "unread",
    createdAt: now,
    updatedAt: now,
  };
}

function auditEvent({
  auditEventId,
  scopeType,
  requestId,
  actorUserId,
  recipientUserId,
  action,
  authType,
  actorPrincipalId,
  now,
}) {
  return {
    schemaVersion: 1,
    auditEventId,
    category: "relationship",
    action,
    actorUserId,
    targetType: `${scopeType}_request`,
    targetId: requestId,
    authType: normalizedString(authType) || "unknown",
    actorPrincipalId: normalizedString(actorPrincipalId),
    result: {
      recipientUserId,
    },
    createdAt: now,
  };
}

export function createRelationshipRequestCreatedHandler({
  firestore,
  scopeType,
}) {
  return async event => {
    const snapshot = event.data;
    if (!snapshot) return null;
    const requestId = event.params.requestId;
    const requestData = snapshot.data();
    if (requestData.status !== "pending") return null;
    const now = event.time || new Date().toISOString();
    const notification = buildRelationshipInvitationNotification({
      scopeType,
      requestId,
      requestData,
      actorUserId: event.authId,
      now,
    });
    const auditEventId = `${scopeType}-request--${requestId}--created`;
    const batch = firestore.batch();
    batch.set(
      firestore.collection("user_notifications").doc(
        notification.notificationId,
      ),
      notification,
    );
    batch.set(
      firestore.collection("audit_events").doc(auditEventId),
      auditEvent({
        auditEventId,
        scopeType,
        requestId,
        actorUserId: notification.actorUserId,
        actorPrincipalId: notification.actorPrincipalId,
        recipientUserId: notification.recipientUserId,
        action: `relationship.${scopeType}.invitation.created`,
        authType: event.authType,
        now,
      }),
    );
    await batch.commit();
    return notification;
  };
}

export function createRelationshipRequestUpdatedHandler({
  firestore,
  scopeType,
}) {
  return async event => {
    const before = event.data?.before;
    const after = event.data?.after;
    if (!before?.exists || !after?.exists) return null;
    const requestId = event.params.requestId;
    const now = event.time || new Date().toISOString();
    const notification = buildRelationshipOutcomeNotification({
      scopeType,
      requestId,
      beforeData: before.data(),
      afterData: after.data(),
      actorUserId: event.authId,
      now,
    });
    if (!notification) return null;
    const action =
      `relationship.${scopeType}.invitation.${after.data().status}`;
    const auditEventId =
      `${scopeType}-request--${requestId}--${after.data().status}`;
    const pendingRef = firestore
      .collection("user_notifications")
      .doc(`${scopeType}-request--${requestId}--pending`);
    const notificationRef = firestore
      .collection("user_notifications")
      .doc(notification.notificationId);
    const auditRef = firestore.collection("audit_events").doc(auditEventId);

    await firestore.runTransaction(async transaction => {
      const pending = await transaction.get(pendingRef);
      if (pending.exists) {
        transaction.update(pendingRef, {
          status: "resolved",
          resolvedAt: now,
          updatedAt: now,
        });
      }
      transaction.set(notificationRef, notification);
      transaction.set(
        auditRef,
        auditEvent({
          auditEventId,
          scopeType,
          requestId,
          actorUserId: notification.actorUserId,
          actorPrincipalId: notification.actorPrincipalId,
          recipientUserId: notification.recipientUserId,
          action,
          authType: event.authType,
          now,
        }),
      );
    });
    return notification;
  };
}

export function normalizeMarkNotificationReadRequest(data) {
  const notificationId = normalizedString(data?.notificationId);
  if (!/^[A-Za-z0-9_-]{8,256}$/.test(notificationId)) {
    throw new HttpsError(
      "invalid-argument",
      "A valid notificationId is required.",
    );
  }
  return { notificationId };
}

export function createMarkNotificationReadHandler({ firestore, clock }) {
  return async request => {
    const userId = request.auth?.uid;
    if (!userId) {
      throw new HttpsError(
        "unauthenticated",
        "Authentication is required to update a notification.",
      );
    }
    const input = normalizeMarkNotificationReadRequest(request.data);
    const notificationRef = firestore
      .collection("user_notifications")
      .doc(input.notificationId);
    const auditRef = firestore
      .collection("audit_events")
      .doc(`notification-read--${userId}--${input.notificationId}`);
    const now = clock().toISOString();

    return firestore.runTransaction(async transaction => {
      const snapshot = await transaction.get(notificationRef);
      const existingAudit = await transaction.get(auditRef);
      if (!snapshot.exists) {
        throw new HttpsError("not-found", "The notification was not found.");
      }
      const notification = snapshot.data();
      if (notification.recipientUserId !== userId) {
        throw new HttpsError(
          "permission-denied",
          "The notification belongs to another account.",
        );
      }
      if (notification.status === "read" && existingAudit.exists) {
        return {
          replayed: true,
          notificationId: input.notificationId,
          status: "read",
          auditEventId: auditRef.id,
        };
      }
      if (notification.status !== "read") {
        transaction.update(notificationRef, {
          status: "read",
          readAt: now,
          updatedAt: now,
        });
      }
      transaction.set(auditRef, {
        schemaVersion: 1,
        auditEventId: auditRef.id,
        category: "notifications",
        action: "notifications.in_app.read",
        actorUserId: userId,
        targetType: "user_notification",
        targetId: input.notificationId,
        result: {
          status: "read",
        },
        createdAt: now,
      });
      return {
        replayed: false,
        notificationId: input.notificationId,
        status: "read",
        auditEventId: auditRef.id,
      };
    });
  };
}
