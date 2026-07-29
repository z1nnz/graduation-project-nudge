import assert from "node:assert/strict";
import test from "node:test";

import {
  buildRelationshipInvitationNotification,
  buildRelationshipOutcomeNotification,
  createMarkNotificationReadHandler,
} from "../src/user-notification-service.js";

test("family request creates a recipient-owned in-app notification", () => {
  const notification = buildRelationshipInvitationNotification({
    scopeType: "family",
    requestId: "family-request-001",
    requestData: {
      senderId: "guardian",
      receiverId: "child",
      senderNickname: "家長",
    },
    actorUserId: "guardian",
    now: "2026-07-29T02:00:00.000Z",
  });

  assert.equal(notification.recipientUserId, "child");
  assert.equal(notification.kind, "family_invitation");
  assert.equal(notification.status, "unread");
});

test("accepted group request notifies the sender and resolves once", () => {
  const notification = buildRelationshipOutcomeNotification({
    scopeType: "group",
    requestId: "group-request-001",
    beforeData: {
      senderId: "manager",
      receiverId: "member",
      groupName: "同行團",
      status: "pending",
    },
    afterData: {
      senderId: "manager",
      receiverId: "member",
      groupName: "同行團",
      status: "accepted",
    },
    actorUserId: "member",
    now: "2026-07-29T02:10:00.000Z",
  });

  assert.equal(notification.recipientUserId, "manager");
  assert.equal(notification.kind, "group_invitation_accepted");
  assert.equal(
    buildRelationshipOutcomeNotification({
      scopeType: "group",
      requestId: "group-request-001",
      beforeData: { status: "accepted" },
      afterData: { status: "accepted" },
      actorUserId: "member",
      now: "2026-07-29T02:10:00.000Z",
    }),
    null,
  );
});

function fakeReadFirestore(notification) {
  const documents = new Map([
    [`user_notifications/${notification.notificationId}`, notification],
  ]);
  return {
    documents,
    collection: collection => ({
      doc: id => ({ id, path: `${collection}/${id}` }),
    }),
    runTransaction: async callback =>
      callback({
        get: async ref => ({
          exists: documents.has(ref.path),
          data: () => documents.get(ref.path),
        }),
        update: (ref, patch) =>
          documents.set(ref.path, {
            ...documents.get(ref.path),
            ...structuredClone(patch),
          }),
        set: (ref, data) => documents.set(ref.path, structuredClone(data)),
      }),
  };
}

test("only the recipient can mark a notification read with audit", async () => {
  const firestore = fakeReadFirestore({
    notificationId: "family-request--request-001--pending",
    recipientUserId: "child",
    status: "unread",
  });
  const handler = createMarkNotificationReadHandler({
    firestore,
    clock: () => new Date("2026-07-29T02:20:00.000Z"),
  });

  await assert.rejects(
    () =>
      handler({
        auth: { uid: "outsider" },
        data: {
          notificationId: "family-request--request-001--pending",
        },
      }),
    error => error.code === "permission-denied",
  );
  const result = await handler({
    auth: { uid: "child" },
    data: {
      notificationId: "family-request--request-001--pending",
    },
  });
  assert.equal(result.status, "read");
  assert.equal(
    firestore.documents.get(
      "user_notifications/family-request--request-001--pending",
    ).status,
    "read",
  );
  assert.equal(
    [...firestore.documents.keys()].filter(key =>
      key.startsWith("audit_events/"),
    ).length,
    1,
  );
});
