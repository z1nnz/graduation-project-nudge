import assert from "node:assert/strict";
import test from "node:test";

import { createPurchaseRewardItemHandler } from "../src/reward-purchase-service.js";

class MemoryFirestore {
  constructor(seed = {}) {
    this.data = new Map(Object.entries(seed));
  }

  collection(name) {
    return {
      doc: id => ({ id, path: `${name}/${id}` }),
    };
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

function request(data) {
  return { auth: { uid: "user-1" }, data };
}

test("a built-in starter purchase creates one debit and one unlock", async () => {
  const firestore = new MemoryFirestore({
    "users/user-1": {
      disciplineCoins: 120,
      unlockedAvatarItems: [],
    },
  });
  const handler = createPurchaseRewardItemHandler({
    firestore,
    clock: () => new Date("2026-08-02T10:00:00.000Z"),
  });
  const input = {
    category: "faceShape",
    index: 12,
    catalogItemId: null,
    clientRequestId: "purchase-moon-ninja",
    sourceSurface: "app",
  };

  const first = await handler(request(input));
  const replay = await handler(request(input));

  assert.equal(first.disciplineCoins, 0);
  assert.equal(first.itemKey, "faceShape:12");
  assert.equal(replay.replayed, true);
  assert.deepEqual(
    firestore.data.get("users/user-1").unlockedAvatarItems,
    ["faceShape:12"],
  );
  assert.equal(
    [...firestore.data.keys()].filter(key => key.startsWith("reward_ledger_entries/"))
      .length,
    1,
  );
});

test("the server rejects evolution stages and insufficient balances", async () => {
  const firestore = new MemoryFirestore({
    "users/user-1": { disciplineCoins: 119, unlockedAvatarItems: [] },
  });
  const handler = createPurchaseRewardItemHandler({ firestore, clock: Date.now });

  await assert.rejects(
    handler(request({
      category: "faceShape",
      index: 13,
      catalogItemId: null,
      clientRequestId: "purchase-evolution-stage",
      sourceSurface: "app",
    })),
    error => error.code === "failed-precondition",
  );
  await assert.rejects(
    handler(request({
      category: "faceShape",
      index: 12,
      catalogItemId: null,
      clientRequestId: "purchase-without-balance",
      sourceSurface: "app",
    })),
    error => error.code === "failed-precondition",
  );
});

test("a published evolution chain sells only its initial catalog stage", async () => {
  const firestore = new MemoryFirestore({
    "users/user-1": { disciplineCoins: 80, unlockedAvatarItems: [] },
    "shop_items/forest-event": {
      status: "published",
      type: "avatar_series",
      price: 80,
      start_time: null,
      end_time: null,
      character_stages: [
        { stage: 1, catalog_index: 18, shop_eligible: true, coin_price: 80 },
        { stage: 2, catalog_index: 19, shop_eligible: false, coin_price: 0 },
        { stage: 3, catalog_index: 20, shop_eligible: false, coin_price: 0 },
      ],
    },
  });
  const handler = createPurchaseRewardItemHandler({
    firestore,
    clock: () => new Date("2026-08-02T10:00:00.000Z"),
  });

  const purchased = await handler(request({
    category: "faceShape",
    index: 18,
    catalogItemId: "forest-event",
    clientRequestId: "purchase-forest-event",
    sourceSurface: "web",
  }));

  assert.equal(purchased.disciplineCoins, 0);
  assert.deepEqual(purchased.unlockedAvatarItems, ["faceShape:18"]);
  await assert.rejects(
    handler(request({
      category: "faceShape",
      index: 19,
      catalogItemId: "forest-event",
      clientRequestId: "purchase-forest-evolution",
      sourceSurface: "web",
    })),
    error => error.code === "failed-precondition",
  );
});

test("purchase rejects malformed catalog chains and corrupt reward projections", async () => {
  const malformedCatalog = new MemoryFirestore({
    "users/user-1": { disciplineCoins: 80, unlockedAvatarItems: [] },
    "shop_items/not-a-series": {
      status: "published",
      type: "event_character",
      price: 80,
      character_stages: [
        { stage: 1, catalog_index: 18, shop_eligible: true, coin_price: 80 },
      ],
    },
  });
  const malformedHandler = createPurchaseRewardItemHandler({
    firestore: malformedCatalog,
    clock: () => new Date("2026-08-02T10:00:00.000Z"),
  });
  await assert.rejects(
    malformedHandler(request({
      category: "faceShape",
      index: 18,
      catalogItemId: "not-a-series",
      clientRequestId: "malformed-chain",
      sourceSurface: "web",
    })),
    error => error.code === "failed-precondition",
  );

  const corruptProjection = new MemoryFirestore({
    "users/user-1": {
      disciplineCoins: "120",
      unlockedAvatarItems: ["faceShape:12"],
    },
  });
  const corruptHandler = createPurchaseRewardItemHandler({
    firestore: corruptProjection,
    clock: () => new Date("2026-08-02T10:00:00.000Z"),
  });
  await assert.rejects(
    corruptHandler(request({
      category: "faceShape",
      index: 12,
      catalogItemId: null,
      clientRequestId: "corrupt-balance",
      sourceSurface: "app",
    })),
    error => error.code === "failed-precondition",
  );
});

test("purchase rejects an invalid server clock", async () => {
  const firestore = new MemoryFirestore({
    "users/user-1": { disciplineCoins: 120, unlockedAvatarItems: [] },
  });
  const handler = createPurchaseRewardItemHandler({
    firestore,
    clock: () => "not-a-date",
  });

  await assert.rejects(
    handler(request({
      category: "faceShape",
      index: 12,
      catalogItemId: null,
      clientRequestId: "invalid-clock",
      sourceSurface: "app",
    })),
    error => error.code === "internal",
  );
});

test("purchase respects the cutover fence and unlock projection limit", async () => {
  const paused = new MemoryFirestore({
    "system_state/reward_ledger_cutover": { writesPaused: true },
    "users/user-1": { disciplineCoins: 120, unlockedAvatarItems: [] },
  });
  const pausedHandler = createPurchaseRewardItemHandler({
    firestore: paused,
    clock: () => new Date("2026-08-02T10:00:00.000Z"),
  });
  await assert.rejects(
    pausedHandler(request({
      category: "faceShape",
      index: 12,
      catalogItemId: null,
      clientRequestId: "paused-purchase",
      sourceSurface: "app",
    })),
    error => error.code === "unavailable",
  );

  const full = new MemoryFirestore({
    "users/user-1": {
      disciplineCoins: 120,
      unlockedAvatarItems: Array.from(
        { length: 500 },
        (_, index) => `legacy:${index}`,
      ),
    },
  });
  const fullHandler = createPurchaseRewardItemHandler({
    firestore: full,
    clock: () => new Date("2026-08-02T10:00:00.000Z"),
  });
  await assert.rejects(
    fullHandler(request({
      category: "faceShape",
      index: 12,
      catalogItemId: null,
      clientRequestId: "full-unlock-projection",
      sourceSurface: "app",
    })),
    error => error.code === "failed-precondition",
  );
});
