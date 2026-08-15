import assert from "node:assert/strict";
import test from "node:test";

import {
  createManageRoomResonanceHandler,
  normalizeRoomResonanceRequest,
} from "../src/room-resonance-service.js";

function fakeFirestore(seed = {}) {
  const documents = new Map(
    Object.entries(seed).map(([path, data]) => [
      path,
      structuredClone(data),
    ]),
  );
  const documentReference = path => ({
    id: path.split("/").at(-1),
    path,
    collection(name) {
      return collectionReference(`${path}/${name}`);
    },
  });
  const collectionReference = path => ({
    doc(id) {
      return documentReference(`${path}/${id}`);
    },
  });
  return {
    documents,
    collection: collectionReference,
    runTransaction: async callback => callback({
      get: async ref => ({
        exists: documents.has(ref.path),
        data: () => structuredClone(documents.get(ref.path)),
      }),
      set: (ref, data) => documents.set(ref.path, structuredClone(data)),
      create: (ref, data) => {
        if (documents.has(ref.path)) throw new Error("already exists");
        documents.set(ref.path, structuredClone(data));
      },
      update: (ref, patch) => {
        if (!documents.has(ref.path)) throw new Error("missing document");
        documents.set(ref.path, {
          ...documents.get(ref.path),
          ...structuredClone(patch),
        });
      },
    }),
  };
}

function roomSeed() {
  return {
    "rooms/room-study": {
      id: "room-study",
      status: "active",
      memberIds: ["alice", "bob"],
    },
    "rooms/room-study/members/alice": {
      memberId: "alice",
      approvalStatus: "approved",
    },
    "rooms/room-study/members/bob": {
      memberId: "bob",
      approvalStatus: "approved",
    },
  };
}

function request(uid, data) {
  return { auth: uid ? { uid } : null, data };
}

const base = {
  roomId: "room-study",
  sourceSurface: "app",
};

test("resonance accepts only bounded cues and responses", () => {
  assert.equal(
    normalizeRoomResonanceRequest({
      ...base,
      action: "publish",
      cueKey: "gentle_restart",
      clientRequestId: "resonance-publish-001",
    }).cueKey,
    "gentle_restart",
  );
  assert.throws(
    () => normalizeRoomResonanceRequest({
      ...base,
      action: "publish",
      cueKey: "I studied 180 minutes and feel awful",
      clientRequestId: "resonance-publish-002",
    }),
    error => error.code === "invalid-argument",
  );
  assert.throws(
    () => normalizeRoomResonanceRequest({
      ...base,
      action: "acknowledge",
      ownerUserId: "alice",
      generationId: "resonance-publish-001",
      responseKey: "send me your health data",
      clientRequestId: "resonance-ack-001",
    }),
    error => error.code === "invalid-argument",
  );
});

test("resonance requires authentication before reading room state", async () => {
  const handler = createManageRoomResonanceHandler({
    firestore: null,
    clock: () => new Date(),
  });
  await assert.rejects(
    () => handler(request(null, {
      ...base,
      action: "set_preference",
      enabled: true,
      clientRequestId: "resonance-pref-001",
    })),
    error => error.code === "unauthenticated",
  );
});

test("publishing is opt-in and disabling sharing withdraws the cue", async () => {
  const firestore = fakeFirestore(roomSeed());
  const handler = createManageRoomResonanceHandler({
    firestore,
    clock: () => new Date("2026-08-15T10:00:00.000Z"),
  });

  await assert.rejects(
    () => handler(request("alice", {
      ...base,
      action: "publish",
      cueKey: "gentle_restart",
      clientRequestId: "resonance-publish-001",
    })),
    error => error.code === "failed-precondition",
  );

  await handler(request("alice", {
    ...base,
    action: "set_preference",
    enabled: true,
    clientRequestId: "resonance-pref-001",
  }));
  const published = await handler(request("alice", {
    ...base,
    action: "publish",
    cueKey: "gentle_restart",
    clientRequestId: "resonance-publish-001",
  }));
  assert.equal(published.signal.visibility, "room_members_only");
  assert.equal(published.signal.cueKey, "gentle_restart");
  assert.equal(
    Object.hasOwn(published.signal, "metricValue"),
    false,
  );

  await handler(request("alice", {
    ...base,
    action: "set_preference",
    enabled: false,
    clientRequestId: "resonance-pref-002",
  }));
  assert.equal(
    firestore.documents.get("room_resonance_signals/room-study--alice").status,
    "withdrawn",
  );
});

test("another approved member acknowledges once without taking control", async () => {
  const firestore = fakeFirestore({
    ...roomSeed(),
    "room_resonance_preferences/room-study--alice": {
      schemaVersion: 1,
      roomId: "room-study",
      userId: "alice",
      enabled: true,
    },
  });
  const handler = createManageRoomResonanceHandler({
    firestore,
    clock: () => new Date("2026-08-15T10:00:00.000Z"),
  });
  const published = await handler(request("alice", {
    ...base,
    action: "publish",
    cueKey: "open_to_company",
    clientRequestId: "resonance-publish-003",
  }));

  const acknowledgementRequest = request("bob", {
    ...base,
    sourceSurface: "web",
    action: "acknowledge",
    ownerUserId: "alice",
    generationId: published.signal.generationId,
    responseKey: "with_you",
    clientRequestId: "resonance-ack-003",
  });
  const first = await handler(acknowledgementRequest);
  const replay = await handler(acknowledgementRequest);
  assert.equal(first.replayed, false);
  assert.equal(replay.replayed, true);
  assert.equal(first.signal.acknowledgementCount, 1);
  assert.equal(
    firestore.documents.get("room_resonance_signals/room-study--alice")
      .acknowledgementCount,
    1,
  );

  await assert.rejects(
    () => handler(request("alice", {
      ...base,
      action: "acknowledge",
      ownerUserId: "alice",
      generationId: published.signal.generationId,
      responseKey: "with_you",
      clientRequestId: "resonance-ack-owner-001",
    })),
    error => error.code === "permission-denied",
  );
});

test("acknowledgement fails closed on corrupt or expired signal state", async () => {
  const firestore = fakeFirestore({
    ...roomSeed(),
    "room_resonance_signals/room-study--alice": {
      schemaVersion: 1,
      signalId: "room-study--alice",
      roomId: "room-study",
      ownerUserId: "alice",
      generationId: "resonance-publish-corrupt",
      cueKey: "gentle_restart",
      status: "active",
      visibility: "room_members_only",
      acknowledgementCount: "many",
      createdAt: "2026-08-15T09:00:00.000Z",
      updatedAt: "2026-08-15T09:00:00.000Z",
      expiresAt: "not-a-date",
      withdrawnAt: null,
    },
  });
  const handler = createManageRoomResonanceHandler({
    firestore,
    clock: () => new Date("2026-08-15T10:00:00.000Z"),
  });

  await assert.rejects(
    () => handler(request("bob", {
      ...base,
      action: "acknowledge",
      ownerUserId: "alice",
      generationId: "resonance-publish-corrupt",
      responseKey: "with_you",
      clientRequestId: "resonance-ack-corrupt",
    })),
    error => error.code === "failed-precondition",
  );
  assert.equal(
    firestore.documents.has(
      "room_resonance_acknowledgements/room-study--alice--resonance-publish-corrupt--bob",
    ),
    false,
  );
});
