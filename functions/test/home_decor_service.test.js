import assert from "node:assert/strict";
import test from "node:test";

import { createArrangeHomeDecorHandler } from "../src/home-decor-service.js";

class MemoryFirestore {
  constructor(seed = {}) {
    this.data = new Map(Object.entries(seed));
  }

  collection(name) {
    return { doc: id => ({ id, path: `${name}/${id}` }) };
  }

  async runTransaction(callback) {
    return callback({
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
    });
  }
}

const clock = () => new Date("2026-11-23T10:00:00.000Z");

function setup(user, extra = {}) {
  const firestore = new MemoryFirestore({ "users/user-1": user, ...extra });
  return { firestore, handler: createArrangeHomeDecorHandler({ firestore, clock }) };
}

function arrange(arrangement, clientRequestId = "decor-arrange-1") {
  return { auth: { uid: "user-1" }, data: { arrangement, clientRequestId, sourceSurface: "app" } };
}

test("owned and free variants can be arranged", async () => {
  const { firestore, handler } = setup({ unlockedAvatarItems: ["homeDecor:101"] });
  const result = await handler(arrange({ rug: 0, curtain: 1, lamp: 0 }));
  assert.deepEqual(result.homeDecor, { rug: 0, curtain: 1, lamp: 0 });
  assert.equal(result.replayed, false);
  assert.deepEqual(firestore.data.get("users/user-1").homeDecor, { rug: 0, curtain: 1, lamp: 0 });
  const entry = [...firestore.data.entries()].find(([key]) => key.startsWith("reward_ledger_entries/decor_"));
  assert.equal(entry[1].entryType, "decorArrangement");
  assert.equal(entry[1].disciplineCoinsDelta, 0);
  assert.equal(entry[1].characterExperienceDelta, 0);
});

test("unowned variant is rejected", async () => {
  const { firestore, handler } = setup({ unlockedAvatarItems: ["homeDecor:101"] });
  await assert.rejects(
    handler(arrange({ rug: 0, curtain: 2, lamp: 0 })),
    error => error.code === "failed-precondition",
  );
  assert.equal(firestore.data.get("users/user-1").homeDecor, undefined);
});

test("arrangement must name every slot with a known variant", async () => {
  for (const arrangement of [{ rug: 0, curtain: 0 }, { rug: 7, curtain: 0, lamp: 0 }, { rug: 0, curtain: 0, lamp: 0, sofa: 1 }, { rug: "0", curtain: 0, lamp: 0 }]) {
    const { handler } = setup({ unlockedAvatarItems: [] });
    await assert.rejects(handler(arrange(arrangement)), error => error.code === "invalid-argument");
  }
});

test("replaying the same request returns the stored result", async () => {
  const { handler } = setup({ unlockedAvatarItems: [] });
  await handler(arrange({ rug: 0, curtain: 0, lamp: 0 }, "decor-replay"));
  const replay = await handler(arrange({ rug: 0, curtain: 0, lamp: 0 }, "decor-replay"));
  assert.equal(replay.replayed, true);
  await assert.rejects(
    handler(arrange({ rug: 0, curtain: 1, lamp: 0 }, "decor-replay")),
    error => error.code === "already-exists",
  );
});

test("paused ledger blocks arrangement", async () => {
  const { handler } = setup(
    { unlockedAvatarItems: [] },
    { "system_state/reward_ledger_cutover": { writesPaused: true } },
  );
  await assert.rejects(handler(arrange({ rug: 0, curtain: 0, lamp: 0 })), error => error.code === "unavailable");
});

test("signed-out callers are rejected", async () => {
  const { handler } = setup({ unlockedAvatarItems: [] });
  await assert.rejects(
    handler({ data: arrange({ rug: 0, curtain: 0, lamp: 0 }).data }),
    error => error.code === "unauthenticated",
  );
});
