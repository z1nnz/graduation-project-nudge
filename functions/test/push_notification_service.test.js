import assert from "node:assert/strict";
import test from "node:test";

import {
  buildPushDeliveryJob,
  createDeliverPushJobHandler,
  createUpdatePushInstallationHandler,
  normalizePushInstallationRequest,
} from "../src/push-notification-service.js";

function setDotted(target, key, value) {
  const parts = key.split(".");
  let cursor = target;
  for (const part of parts.slice(0, -1)) {
    cursor[part] ||= {};
    cursor = cursor[part];
  }
  cursor[parts.at(-1)] = structuredClone(value);
}

function fakeFirestore(seed = {}) {
  const documents = new Map(
    Object.entries(seed).map(([path, value]) => [
      path,
      structuredClone(value),
    ]),
  );
  const snapshotFor = ref => ({
    exists: documents.has(ref.path),
    data: () => structuredClone(documents.get(ref.path)),
  });
  const set = (ref, data) => documents.set(ref.path, structuredClone(data));
  const update = (ref, patch) => {
    if (!documents.has(ref.path)) throw new Error(`missing ${ref.path}`);
    const next = structuredClone(documents.get(ref.path));
    for (const [key, value] of Object.entries(patch)) {
      setDotted(next, key, value);
    }
    documents.set(ref.path, next);
  };
  const reference = (collection, id) => ({
    id,
    path: `${collection}/${id}`,
    get: async () => snapshotFor({ path: `${collection}/${id}` }),
    set: async data => set({ path: `${collection}/${id}` }, data),
    update: async patch => update({ path: `${collection}/${id}` }, patch),
    delete: async () => documents.delete(`${collection}/${id}`),
  });
  return {
    documents,
    collection: collection => ({
      doc: id => reference(collection, id),
    }),
    runTransaction: async callback =>
      callback({
        get: async ref => snapshotFor(ref),
        set,
        update,
        create: (ref, data) => {
          if (documents.has(ref.path)) throw new Error("already exists");
          set(ref, data);
        },
        delete: ref => documents.delete(ref.path),
      }),
  };
}

const registerRequest = {
  auth: { uid: "user-one" },
  data: {
    action: "register",
    installationId: "installation_001",
    platform: "android",
    token: "fcm-token-that-is-long-enough-for-validation-001",
    clientRequestId: "push-request-001",
  },
};

test("push installation input rejects secrets and unstable identities", () => {
  assert.equal(
    normalizePushInstallationRequest(registerRequest.data).platform,
    "android",
  );
  assert.throws(
    () =>
      normalizePushInstallationRequest({
        ...registerRequest.data,
        token: "short",
      }),
    error => error.code === "invalid-argument",
  );
  assert.throws(
    () =>
      normalizePushInstallationRequest({
        ...registerRequest.data,
        platform: "browser",
      }),
    error => error.code === "invalid-argument",
  );
});

test("push installation registration is audited, idempotent and revocable", async () => {
  const firestore = fakeFirestore({
    "notification_preferences/user-one": {
      schemaVersion: 1,
      userId: "user-one",
      delivery: {
        localScheduled: true,
        inApp: true,
        pushConfigured: false,
      },
    },
  });
  const handler = createUpdatePushInstallationHandler({
    firestore,
    clock: () => new Date("2026-07-29T03:00:00.000Z"),
  });

  const first = await handler(registerRequest);
  const replay = await handler(registerRequest);
  assert.equal(first.configured, true);
  assert.equal(first.activeInstallationCount, 1);
  assert.equal(replay.replayed, true);
  assert.equal(
    firestore.documents.get("push_delivery_state/user-one").configured,
    true,
  );
  assert.equal(
    firestore.documents.get("notification_preferences/user-one").delivery
      .pushConfigured,
    true,
  );
  const audit = firestore.documents.get(
    "audit_events/push-installation--user-one--push-request-001",
  );
  assert.equal(JSON.stringify(audit).includes(registerRequest.data.token), false);

  const revoked = await handler({
    auth: { uid: "user-one" },
    data: {
      action: "revoke",
      installationId: "installation_001",
      clientRequestId: "push-request-002",
    },
  });
  assert.equal(revoked.configured, false);
  assert.equal(
    firestore.documents.get(
      "push_installations/user-one--installation_001",
    ).token,
    undefined,
  );
  assert.equal(
    firestore.documents.get("notification_preferences/user-one").delivery
      .pushConfigured,
    false,
  );
});

test("one token claim moves atomically between accounts", async () => {
  const firestore = fakeFirestore({
    "notification_preferences/user-one": {
      userId: "user-one",
      delivery: { pushConfigured: false },
    },
    "notification_preferences/user-two": {
      userId: "user-two",
      delivery: { pushConfigured: false },
    },
  });
  const handler = createUpdatePushInstallationHandler({
    firestore,
    clock: () => new Date("2026-07-29T03:05:00.000Z"),
  });

  await handler(registerRequest);
  const moved = await handler({
    auth: { uid: "user-two" },
    data: {
      ...registerRequest.data,
      installationId: "installation_002",
      clientRequestId: "push-request-002",
    },
  });

  assert.equal(moved.configured, true);
  assert.deepEqual(
    firestore.documents.get("push_delivery_state/user-one")
      .activeInstallationIds,
    [],
  );
  assert.equal(
    firestore.documents.get("notification_preferences/user-one").delivery
      .pushConfigured,
    false,
  );
  assert.equal(
    firestore.documents.get(
      "push_installations/user-one--installation_001",
    ).status,
    "revoked",
  );
  assert.deepEqual(
    firestore.documents.get("push_delivery_state/user-two")
      .activeInstallationIds,
    ["installation_002"],
  );
});

test("first push opt-in creates the shared default notification preferences", async () => {
  const firestore = fakeFirestore();
  const handler = createUpdatePushInstallationHandler({
    firestore,
    clock: () => new Date("2026-07-29T03:06:00.000Z"),
  });

  await handler(registerRequest);

  const preferences = firestore.documents.get(
    "notification_preferences/user-one",
  );
  assert.equal(preferences.delivery.pushConfigured, true);
  assert.equal(preferences.channels.tasks.timeLabel, "20:30");
  assert.deepEqual(Object.keys(preferences.channels).sort(), [
    "deadline",
    "rooms",
    "sleep",
    "tasks",
  ]);
});

test("delivery sends only server-held tokens and revokes invalid ones", async () => {
  const notification = {
    notificationId: "family-request--request-001--pending",
    recipientUserId: "child",
    actorUserId: "guardian",
    actorPrincipalId: "guardian",
    category: "relationship",
    kind: "family_invitation",
    title: "新的家庭連結邀請",
    body: "家長邀請你建立家庭連結。",
    route: "guardian",
    createdAt: "2026-07-29T03:10:00.000Z",
    updatedAt: "2026-07-29T03:10:00.000Z",
  };
  const job = buildPushDeliveryJob(notification);
  assert.equal(job.actorUserId, notification.actorUserId);
  assert.equal(job.actorPrincipalId, notification.actorPrincipalId);
  const firestore = fakeFirestore({
    [`push_delivery_jobs/${job.jobId}`]: job,
    "push_delivery_state/child": {
      userId: "child",
      configured: true,
      activeInstallationIds: ["device_good", "device_stale"],
    },
    "notification_preferences/child": {
      userId: "child",
      categories: { relationshipUpdates: true },
      delivery: { pushConfigured: true },
    },
    "push_installations/child--device_good": {
      userId: "child",
      installationId: "device_good",
      platform: "android",
      token: "good-token-that-is-long-enough-for-fcm-001",
      tokenHash: "good-hash",
      status: "active",
    },
    "push_installations/child--device_stale": {
      userId: "child",
      installationId: "device_stale",
      platform: "ios",
      token: "stale-token-that-is-long-enough-for-fcm-002",
      tokenHash: "stale-hash",
      status: "active",
    },
    "push_token_claims/stale-hash": {
      userId: "child",
      installationId: "device_stale",
    },
  });
  let capturedMessage;
  let sendCount = 0;
  const handler = createDeliverPushJobHandler({
    firestore,
    messaging: {
      sendEachForMulticast: async message => {
        sendCount += 1;
        capturedMessage = message;
        return {
          successCount: 1,
          failureCount: 1,
          responses: [
            { success: true, messageId: "message-001" },
            {
              success: false,
              error: {
                code: "messaging/registration-token-not-registered",
              },
            },
          ],
        };
      },
    },
    clock: () => new Date("2026-07-29T03:11:00.000Z"),
  });

  const result = await handler({
    data: { exists: true },
    params: { jobId: job.jobId },
  });

  assert.equal(result.status, "partial");
  assert.deepEqual(capturedMessage.tokens, [
    "good-token-that-is-long-enough-for-fcm-001",
    "stale-token-that-is-long-enough-for-fcm-002",
  ]);
  assert.equal(capturedMessage.data.route, "guardian");
  assert.deepEqual(
    firestore.documents.get("push_delivery_state/child").activeInstallationIds,
    ["device_good"],
  );
  assert.equal(
    firestore.documents.get("push_installations/child--device_stale").status,
    "revoked",
  );
  assert.equal(firestore.documents.has("push_token_claims/stale-hash"), false);
  assert.equal(
    firestore.documents.get(`push_delivery_jobs/${job.jobId}`).status,
    "partial",
  );
  assert.equal(
    [...firestore.documents.keys()].some(path =>
      path.startsWith("push_delivery_leases/")
    ),
    false,
  );
  const replay = await handler({
    data: { exists: true },
    params: { jobId: job.jobId },
  });
  assert.equal(replay.status, "partial");
  assert.equal(sendCount, 1);
});

test("delivery skips accounts that never enabled push", async () => {
  const notification = {
    notificationId: "group-request--request-001--pending",
    recipientUserId: "member",
    category: "relationship",
    kind: "group_invitation",
    title: "新的團體邀請",
    body: "你收到團體邀請。",
    route: "groups",
    createdAt: "2026-07-29T03:20:00.000Z",
    updatedAt: "2026-07-29T03:20:00.000Z",
  };
  const job = buildPushDeliveryJob(notification);
  const firestore = fakeFirestore({
    [`push_delivery_jobs/${job.jobId}`]: job,
  });
  const handler = createDeliverPushJobHandler({
    firestore,
    messaging: {
      sendEachForMulticast: async () => {
        throw new Error("must not send");
      },
    },
    clock: () => new Date("2026-07-29T03:21:00.000Z"),
  });
  const result = await handler({
    data: { exists: true },
    params: { jobId: job.jobId },
  });
  assert.equal(result.status, "skipped");
  assert.equal(result.reason, "preferences_missing");
  assert.equal(
    firestore.documents.has(`audit_events/push-delivery--${job.jobId}`),
    true,
  );
});

test("delivery drops a job when account deletion is fenced", async () => {
  const jobId = "group-request--request-fenced--pending";
  const firestore = fakeFirestore({
    [`push_delivery_jobs/${jobId}`]: {
      schemaVersion: 1,
      jobId,
      notificationId: jobId,
      recipientUserId: "other-member",
      category: "relationship",
      kind: "group_invitation",
      title: "新的團體邀請",
      body: "你收到團體邀請。",
      route: "groups",
      status: "pending",
      attemptCount: 0,
    },
    [`user_notifications/${jobId}`]: {
      notificationId: jobId,
      recipientUserId: "other-member",
      actorUserId: "member",
      actorPrincipalId: "member",
    },
    "account_deletion_fences/member": {
      status: "deleting",
    },
  });
  let sendCount = 0;
  const handler = createDeliverPushJobHandler({
    firestore,
    messaging: {
      sendEachForMulticast: async () => {
        sendCount += 1;
        throw new Error("must not send");
      },
    },
    clock: () => new Date("2026-07-29T03:25:00.000Z"),
  });

  const result = await handler({
    data: { exists: true },
    params: { jobId },
  });

  assert.equal(result.status, "cancelled_account_deletion");
  assert.equal(sendCount, 0);
  assert.equal(firestore.documents.has(`push_delivery_jobs/${jobId}`), false);
  assert.equal(
    firestore.documents.has(`audit_events/push-delivery--${jobId}`),
    false,
  );
});

test("delivery records a terminal audit after the retry budget", async () => {
  const jobId = "group-request--request-002--pending";
  const firestore = fakeFirestore({
    [`push_delivery_jobs/${jobId}`]: {
      schemaVersion: 1,
      jobId,
      notificationId: jobId,
      recipientUserId: "member",
      category: "relationship",
      kind: "group_invitation",
      title: "新的團體邀請",
      body: "你收到團體邀請。",
      route: "groups",
      status: "pending",
      attemptCount: 4,
    },
    "push_delivery_state/member": {
      userId: "member",
      configured: true,
      activeInstallationIds: ["device_retry"],
    },
    "notification_preferences/member": {
      userId: "member",
      delivery: { pushConfigured: true },
    },
    "push_installations/member--device_retry": {
      userId: "member",
      installationId: "device_retry",
      platform: "android",
      token: "retry-token-that-is-long-enough-for-fcm-001",
      tokenHash: "retry-hash",
      status: "active",
    },
  });
  const handler = createDeliverPushJobHandler({
    firestore,
    messaging: {
      sendEachForMulticast: async () => {
        const error = new Error("service unavailable");
        error.code = "messaging/server-unavailable";
        throw error;
      },
    },
    clock: () => new Date("2026-07-29T03:30:00.000Z"),
    maxAttempts: 5,
  });

  const result = await handler({
    data: { exists: true },
    params: { jobId },
  });
  assert.equal(result.status, "failed");
  assert.equal(
    firestore.documents.get(`push_delivery_jobs/${jobId}`).attemptCount,
    5,
  );
  assert.equal(
    firestore.documents.has(`audit_events/push-delivery--${jobId}`),
    true,
  );
});
