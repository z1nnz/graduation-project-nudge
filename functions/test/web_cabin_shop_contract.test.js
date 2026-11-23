// Contract between the Web cabin/shop modules (web_dashboard/assets) and the
// real Cloud handlers they call (#82 slice 3). The Web builds the commands and
// reads the answers; Cloud prices, checks ownership and writes the ledger.
import assert from "node:assert/strict";
import { createRequire } from "node:module";
import test from "node:test";

import { createArrangeHomeDecorHandler } from "../src/home-decor-service.js";
import { createPurchaseRewardItemHandler } from "../src/reward-purchase-service.js";

const require = createRequire(import.meta.url);
const cabin = require("../../web_dashboard/assets/cabin_core.js");
const shop = require("../../web_dashboard/assets/reward_shop_core.js");
const catalog = require("../../web_dashboard/assets/home/home_decor_catalog.json");

class MemoryFirestore {
  constructor(seed = {}) {
    this.data = new Map(Object.entries(seed));
  }

  collection(name) {
    return { doc: id => ({ id, path: `${name}/${id}` }) };
  }

  async runTransaction(callback) {
    const writes = new Map(this.data);
    const result = await callback({
      get: async ref => {
        const value = writes.get(ref.path);
        return { exists: value !== undefined, data: () => structuredClone(value) };
      },
      create: (ref, value) => {
        if (writes.has(ref.path)) throw new Error("already exists");
        writes.set(ref.path, structuredClone(value));
      },
      update: (ref, value) => {
        const current = writes.get(ref.path);
        if (current === undefined) throw new Error("missing document");
        writes.set(ref.path, { ...structuredClone(current), ...structuredClone(value) });
      },
    });
    this.data = writes; // commit only when the callback succeeds
    return result;
  }

  user() { return this.data.get("users/web-user"); }
}

const clock = () => new Date("2026-11-23T10:00:00.000Z");
const auth = { uid: "web-user" };

test("a Web arrangement of owned decor is stored by arrangeHomeDecor and replays", async () => {
  const firestore = new MemoryFirestore({ "users/web-user": { unlockedAvatarItems: ["homeDecor:101", "homeDecor:202"] } });
  const handler = createArrangeHomeDecorHandler({ firestore, clock });
  const owned = cabin.ownedVariants(catalog, firestore.user().unlockedAvatarItems);
  let draft = cabin.normalizeArrangement(null, catalog);
  draft = cabin.choose(draft, owned, "curtain", 1);
  draft = cabin.choose(draft, owned, "lamp", 2);
  draft = cabin.choose(draft, owned, "rug", 2); // not owned: ignored on the Web
  const id = cabin.newRequestId(clock().getTime(), () => 0.5);
  const command = cabin.arrangeCommand(draft, catalog, id);
  const result = await handler({ auth, data: command });
  assert.deepEqual(result.homeDecor, { rug: 0, curtain: 1, lamp: 2 });
  assert.equal(cabin.validArrangeResult(result, command.arrangement), true);
  assert.deepEqual(firestore.user().homeDecor, { rug: 0, curtain: 1, lamp: 2 });
  // After a lost answer the Web resends the same id: Cloud replays, no second entry.
  const again = await handler({ auth, data: command });
  assert.equal(again.replayed, true);
  const entries = [...firestore.data.keys()].filter(key => key.startsWith("reward_ledger_entries/"));
  assert.equal(entries.length, 1);
  assert.deepEqual(cabin.visibleArrangement(firestore.user().homeDecor, catalog, owned), { rug: 0, curtain: 1, lamp: 2 });
});

test("Cloud refuses unowned decor and the Web explains it without claiming a save", async () => {
  const firestore = new MemoryFirestore({ "users/web-user": { unlockedAvatarItems: [] } });
  const handler = createArrangeHomeDecorHandler({ firestore, clock });
  const command = cabin.arrangeCommand({ rug: 1, curtain: 0, lamp: 0 }, catalog, "web-decor-forced-1");
  const error = await handler({ auth, data: command }).catch(e => e);
  assert.equal(error.code, "failed-precondition");
  const explained = cabin.arrangeError(error);
  assert.equal(explained.kind, "not-owned");
  assert.equal(explained.saved, "no");
  assert.equal(firestore.user().homeDecor, undefined);
});

test("every Web decor listing costs exactly what purchaseRewardItem charges, once", async () => {
  for (const listing of shop.decorListings(catalog, [])) {
    const firestore = new MemoryFirestore({ "users/web-user": { disciplineCoins: 500, unlockedAvatarItems: [] } });
    const handler = createPurchaseRewardItemHandler({ firestore, clock });
    const command = shop.purchaseCommand(listing);
    const result = await handler({ auth, data: command });
    assert.equal(shop.validPurchaseResult(result, listing), true, listing.itemKey);
    assert.equal(result.disciplineCoins, 500 - listing.price, listing.itemKey);
    const replay = await handler({ auth, data: shop.purchaseCommand(listing) });
    assert.equal(replay.replayed, true, "pressing again replays the same entry");
    assert.equal(firestore.user().disciplineCoins, 500 - listing.price, "no second charge");
    const after = shop.decorListings(catalog, firestore.user().unlockedAvatarItems).find(x => x.itemKey === listing.itemKey);
    assert.equal(after.owned, true);
  }
});

test("a published character listing is bought through the existing catalog contract", async () => {
  const item = {
    status: "published", type: "avatar_series", name: "火焰系", price: 80,
    character_stages: [
      { stage: 1, catalog_index: 40, shop_eligible: true, coin_price: 80 },
      { stage: 2, catalog_index: 41, shop_eligible: false, coin_price: 0 },
      { stage: 3, catalog_index: 42, shop_eligible: false, coin_price: 0 },
    ],
  };
  const firestore = new MemoryFirestore({
    "users/web-user": { disciplineCoins: 100, unlockedAvatarItems: [] },
    "shop_items/fire": item,
  });
  const handler = createPurchaseRewardItemHandler({ firestore, clock });
  const [listing] = shop.characterListings([{ id: "fire", ...item }], Math.floor(clock().getTime() / 1000), []);
  const result = await handler({ auth, data: shop.purchaseCommand(listing) });
  assert.equal(shop.validPurchaseResult(result, listing), true);
  assert.equal(result.disciplineCoins, 100 - listing.price);
});

test("insufficient balance and withdrawn listings map to honest no-charge messages", async () => {
  const [decor] = shop.decorListings(catalog, []);
  const poor = new MemoryFirestore({ "users/web-user": { disciplineCoins: 1, unlockedAvatarItems: [] } });
  const poorError = await createPurchaseRewardItemHandler({ firestore: poor, clock })({ auth, data: shop.purchaseCommand(decor) }).catch(e => e);
  assert.equal(shop.purchaseError(poorError).kind, "balance");
  assert.equal(shop.purchaseError(poorError).charged, "no");
  assert.equal(poor.user().disciplineCoins, 1);

  const gone = new MemoryFirestore({ "users/web-user": { disciplineCoins: 500, unlockedAvatarItems: [] } });
  const listing = { kind: "character", id: "removed", index: 40, price: 80, itemKey: "faceShape:40" };
  const goneError = await createPurchaseRewardItemHandler({ firestore: gone, clock })({ auth, data: shop.purchaseCommand(listing) }).catch(e => e);
  assert.equal(shop.purchaseError(goneError).kind, "gone");
  assert.equal(gone.user().disciplineCoins, 500);
});
