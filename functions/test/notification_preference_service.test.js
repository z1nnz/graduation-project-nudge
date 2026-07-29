import assert from "node:assert/strict";
import test from "node:test";

import {
  createUpdateNotificationPreferencesHandler,
  defaultNotificationChannels,
  normalizeNotificationPreferenceRequest,
} from "../src/notification-preference-service.js";

function fakeFirestore() {
  const documents = new Map();
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
          data: () => documents.get(ref.path),
        }),
        set: (ref, data) => documents.set(ref.path, structuredClone(data)),
        create: (ref, data) => {
          if (documents.has(ref.path)) throw new Error("already exists");
          documents.set(ref.path, structuredClone(data));
        },
      }),
  };
}

test("notification input requires the complete supported channel set", () => {
  assert.deepEqual(
    normalizeNotificationPreferenceRequest({
      clientRequestId: "notification-request-001",
      sourceSurface: "app",
      channels: defaultNotificationChannels(),
    }).channels,
    defaultNotificationChannels(),
  );
  assert.throws(
    () =>
      normalizeNotificationPreferenceRequest({
        clientRequestId: "notification-request-001",
        sourceSurface: "app",
        channels: {
          tasks: { enabled: true, timeLabel: "25:99" },
        },
      }),
    error => error.code === "invalid-argument",
  );
});

test("notification handler rejects unauthenticated callers", async () => {
  const handler = createUpdateNotificationPreferencesHandler({
    firestore: null,
    clock: () => new Date(),
  });
  await assert.rejects(
    () =>
      handler({
        auth: null,
        data: {
          clientRequestId: "notification-request-001",
          sourceSurface: "app",
          channels: defaultNotificationChannels(),
        },
      }),
    error => error.code === "unauthenticated",
  );
});

test("notification handler writes current state and one idempotent audit", async () => {
  const firestore = fakeFirestore();
  firestore.documents.set("push_delivery_state/user-one", {
    configured: true,
    activeInstallationIds: ["installation-001"],
  });
  const handler = createUpdateNotificationPreferencesHandler({
    firestore,
    clock: () => new Date("2026-07-29T01:00:00.000Z"),
  });
  const request = {
    auth: { uid: "user-one" },
    data: {
      clientRequestId: "notification-request-001",
      sourceSurface: "web",
      channels: {
        ...defaultNotificationChannels(),
        rooms: { enabled: false, timeLabel: "19:30" },
      },
    },
  };

  const first = await handler(request);
  const replay = await handler(request);

  assert.equal(first.replayed, false);
  assert.equal(replay.replayed, true);
  assert.equal(first.preferences.channels.rooms.enabled, false);
  assert.equal(first.preferences.delivery.pushConfigured, true);
  assert.equal(
    firestore.documents.get("notification_preferences/user-one").userId,
    "user-one",
  );
  assert.equal(
    [...firestore.documents.keys()].filter(key =>
      key.startsWith("audit_events/"),
    ).length,
    1,
  );
});
