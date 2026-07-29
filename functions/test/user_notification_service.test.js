import assert from "node:assert/strict";
import test from "node:test";

import {
  buildRelationshipInvitationNotification,
  buildRelationshipOutcomeNotification,
  createMarkNotificationReadHandler,
  createRelationshipRequestCreatedHandler,
  createRelationshipRequestUpdatedHandler,
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

function fakeRelationshipFirestore(seed = {}) {
  const documents = new Map(
    Object.entries(seed).map(([path, value]) => [
      path,
      structuredClone(value),
    ]),
  );
  const reference = (collection, id) => ({
    id,
    path: `${collection}/${id}`,
  });
  return {
    documents,
    collection: collection => ({
      doc: id => reference(collection, id),
    }),
    runTransaction: async callback =>
      callback({
        get: async ref => ({
          exists: documents.has(ref.path),
          data: () => structuredClone(documents.get(ref.path)),
        }),
        set: (ref, data) => documents.set(ref.path, structuredClone(data)),
        update: (ref, patch) =>
          documents.set(ref.path, {
            ...documents.get(ref.path),
            ...structuredClone(patch),
          }),
        delete: ref => documents.delete(ref.path),
      }),
  };
}

test("late create trigger does not resurrect a resolved invitation", async () => {
  const requestId = "family-request-002";
  const firestore = fakeRelationshipFirestore({
    [`guardian_requests/${requestId}`]: {
      senderId: "guardian",
      receiverId: "child",
      status: "accepted",
    },
  });
  const handler = createRelationshipRequestCreatedHandler({
    firestore,
    scopeType: "family",
  });

  const result = await handler({
    data: { data: () => ({ status: "pending" }) },
    params: { requestId },
    authId: "guardian",
    authType: "USER",
    time: "2026-07-29T02:05:00.000Z",
  });

  assert.equal(result, null);
  assert.equal(
    firestore.documents.has(
      `user_notifications/family-request--${requestId}--pending`,
    ),
    false,
  );
});

test("relationship triggers do not write after either account is fenced", async () => {
  const requestId = "family-request-fenced-001";
  const pendingId = `family-request--${requestId}--pending`;
  const firestore = fakeRelationshipFirestore({
    [`guardian_requests/${requestId}`]: {
      senderId: "guardian",
      receiverId: "child",
      status: "pending",
    },
    "account_deletion_fences/guardian": {
      status: "deleting",
    },
    [`user_notifications/${pendingId}`]: {
      notificationId: pendingId,
      status: "unread",
    },
    [`push_delivery_jobs/${pendingId}`]: {
      jobId: pendingId,
      status: "pending",
    },
  });
  const created = createRelationshipRequestCreatedHandler({
    firestore,
    scopeType: "family",
  });
  const createdResult = await created({
    data: { exists: true },
    params: { requestId },
    authId: "guardian",
    authType: "USER",
    time: "2026-07-29T02:05:00.000Z",
  });
  assert.equal(createdResult, null);
  assert.equal(
    firestore.documents.has(
      `audit_events/family-request--${requestId}--created`,
    ),
    false,
  );

  const updated = createRelationshipRequestUpdatedHandler({
    firestore,
    scopeType: "family",
  });
  const updatedResult = await updated({
    data: {
      before: {
        exists: true,
        data: () => ({
          senderId: "guardian",
          receiverId: "child",
          status: "pending",
        }),
      },
      after: {
        exists: true,
        data: () => ({
          senderId: "guardian",
          receiverId: "child",
          status: "accepted",
        }),
      },
    },
    params: { requestId },
    authId: "child",
    authType: "USER",
    time: "2026-07-29T02:06:00.000Z",
  });
  assert.equal(updatedResult, null);
  assert.equal(firestore.documents.has(`user_notifications/${pendingId}`), false);
  assert.equal(firestore.documents.has(`push_delivery_jobs/${pendingId}`), false);
  assert.equal(
    firestore.documents.has(
      `user_notifications/family-request--${requestId}--accepted`,
    ),
    false,
  );
});

test("terminal relationship update cancels an unsent invitation job", async () => {
  const requestId = "group-request-002";
  const pendingId = `group-request--${requestId}--pending`;
  const firestore = fakeRelationshipFirestore({
    [`user_notifications/${pendingId}`]: {
      notificationId: pendingId,
      status: "unread",
    },
    [`push_delivery_jobs/${pendingId}`]: {
      jobId: pendingId,
      status: "pending",
    },
  });
  const handler = createRelationshipRequestUpdatedHandler({
    firestore,
    scopeType: "group",
  });

  await handler({
    data: {
      before: {
        exists: true,
        data: () => ({
          senderId: "manager",
          receiverId: "member",
          groupName: "同行團",
          status: "pending",
        }),
      },
      after: {
        exists: true,
        data: () => ({
          senderId: "manager",
          receiverId: "member",
          groupName: "同行團",
          status: "accepted",
        }),
      },
    },
    params: { requestId },
    authId: "member",
    authType: "USER",
    time: "2026-07-29T02:06:00.000Z",
  });

  assert.equal(
    firestore.documents.get(`push_delivery_jobs/${pendingId}`).status,
    "cancelled",
  );
  assert.equal(
    firestore.documents.get(`user_notifications/${pendingId}`).status,
    "resolved",
  );
  assert.equal(
    firestore.documents.has(
      `push_delivery_jobs/group-request--${requestId}--accepted`,
    ),
    true,
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
