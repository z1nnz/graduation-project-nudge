import assert from "node:assert/strict";
import test from "node:test";

import { createEquipRewardAvatarHandler } from "../src/reward-avatar-service.js";

class MemoryFirestore {
  constructor(seed = {}) {
    this.data = new Map(Object.entries(seed));
  }

  collection(name) {
    return { doc: id => ({ id, path: `${name}/${id}` }) };
  }

  async runTransaction(callback) {
    const transaction = {
      get: async ref => {
        const value = this.data.get(ref.path);
        return { exists: value !== undefined, data: () => structuredClone(value) };
      },
      create: (ref, value) => {
        if (this.data.has(ref.path)) throw new Error("already exists");
        this.data.set(ref.path, structuredClone(value));
      },
      update: (ref, value) => {
        const current = this.data.get(ref.path);
        if (current === undefined) throw new Error("missing document");
        this.data.set(ref.path, { ...structuredClone(current), ...structuredClone(value) });
      },
    };
    return callback(transaction);
  }
}

const baseProfile = {
  skinToneIndex: 0,
  faceShapeIndex: 0,
  hairStyleIndex: 0,
  hairColorIndex: 0,
  eyeStyleIndex: 0,
  eyebrowStyleIndex: 0,
  mouthStyleIndex: 0,
  outfitStyleIndex: 0,
  outfitColorIndex: 0,
  accessoryIndex: 0,
  backgroundColorIndex: 0,
  avatarIconIndex: 0,
  useCustomImage: false,
  customImagePath: null,
};

function request(data) {
  return { auth: { uid: "user-1" }, data: {
    avatarProfile: baseProfile,
    backgroundTheme: "softGlow",
    faceCatalogItemId: null,
    iconCatalogItemId: null,
    clientRequestId: "equip-default",
    sourceSurface: "app",
    ...data,
  } };
}

test("Cloud equipment rejects a forged paid unlock and accepts owned stages", async () => {
  const firestore = new MemoryFirestore({
    "users/user-1": {
      unlockedAvatarItems: [],
      avatarExperienceLedger: {},
    },
    "public_profiles/user-1": { avatarProfile: baseProfile },
  });
  const handler = createEquipRewardAvatarHandler({
    firestore,
    clock: () => new Date("2026-08-02T10:00:00.000Z"),
  });
  await assert.rejects(
    handler(request({
      avatarProfile: {
        ...baseProfile,
        faceShapeIndex: 12,
        avatarIconIndex: 12,
      },
      clientRequestId: "forged-paid-stage",
    })),
    error => error.code === "failed-precondition",
  );

  firestore.data.set("users/user-1", {
    unlockedAvatarItems: ["faceShape:12"],
    avatarExperienceLedger: {},
  });
  const equipped = await handler(request({
    avatarProfile: {
      ...baseProfile,
      faceShapeIndex: 12,
      avatarIconIndex: 12,
    },
    clientRequestId: "owned-paid-stage",
  }));
  assert.equal(equipped.avatarSeries, "月影忍者");
  assert.equal(
    firestore.data.get("users/user-1").avatarProfile.faceShapeIndex,
    12,
  );
  assert.equal(
    firestore.data.get("public_profiles/user-1").avatarProfile.faceShapeIndex,
    12,
  );
});

test("Cloud equipment validates evolution XP, background ownership and replay", async () => {
  const firestore = new MemoryFirestore({
    "users/user-1": {
      unlockedAvatarItems: ["faceShape:12", "appBackground:1"],
      avatarExperienceLedger: {
        "1970-01-01": { "月影忍者": 10_000 },
      },
    },
  });
  const handler = createEquipRewardAvatarHandler({
    firestore,
    clock: () => new Date("2026-08-02T10:00:00.000Z"),
  });
  const command = request({
    avatarProfile: {
      ...baseProfile,
      faceShapeIndex: 13,
      avatarIconIndex: 13,
    },
    backgroundTheme: "nightStudy",
    clientRequestId: "equip-evolved-stage",
  });
  const first = await handler(command);
  const replay = await handler(command);

  assert.equal(first.avatarProfile.faceShapeIndex, 13);
  assert.equal(first.backgroundTheme, "nightStudy");
  assert.equal(replay.replayed, true);
  assert.equal(
    [...firestore.data.keys()].filter(key =>
      key.startsWith("reward_ledger_entries/equipment_"),
    ).length,
    1,
  );
});

test("Cloud equipment is fenced during reward baseline cutover", async () => {
  const firestore = new MemoryFirestore({
    "system_state/reward_ledger_cutover": { writesPaused: true },
    "users/user-1": { unlockedAvatarItems: [], avatarExperienceLedger: {} },
  });
  const handler = createEquipRewardAvatarHandler({
    firestore,
    clock: () => new Date("2026-08-02T10:00:00.000Z"),
  });
  await assert.rejects(
    handler(request({})),
    error => error.code === "unavailable",
  );
});
