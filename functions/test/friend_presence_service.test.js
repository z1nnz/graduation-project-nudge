import assert from "node:assert/strict";
import test from "node:test";
import { createManageFriendPresenceHandler } from "../src/friend-presence-service.js";

function fixture() {
  const docs = new Map();
  const firestore = {
    collection: name => ({ doc: id => name + "/" + id }),
    runTransaction: task => task({
      getAll: (...refs) => refs.map(ref => ({ exists: docs.has(ref), data: () => docs.get(ref) })),
      set: (ref, value) => docs.set(ref, value),
      delete: ref => docs.delete(ref),
    }),
  };
  const auth = { uid: "alice" };
  const call = data => createManageFriendPresenceHandler(firestore, () => 1000)({ auth, data });
  return { call, docs };
}

test("presence is opt-in, shares only a building and uses the server clock", async () => {
  const { call, docs } = fixture();
  await assert.rejects(call({ action: "heartbeat", building: "tower" }), { code: "permission-denied" });
  await call({ action: "consent", enabled: true });
  await assert.rejects(call({ action: "heartbeat", building: "private-room" }), { code: "invalid-argument" });
  await call({ action: "heartbeat", building: "tower", roomId: "private-room" });
  const record = docs.get("presence/alice");
  assert.deepEqual(Object.keys(record).sort(), ["building", "expiresAt", "page", "uid", "updatedAt"]);
  assert.equal(record.page, "tower");
  assert.equal(record.updatedAt.toMillis(), 1000);
  assert.equal(record.expiresAt.toMillis(), 301000);
  await call({ action: "consent", enabled: false });
  assert.equal(docs.has("presence/alice"), false);
  await assert.rejects(call({ action: "heartbeat", building: "tower" }), { code: "permission-denied" });
});

test("closing an older facility does not erase a newer visit", async () => {
  const { call, docs } = fixture();
  await call({ action: "consent", enabled: true });
  const older = await call({ action: "heartbeat", building: "tower" });
  const newer = await call({ action: "heartbeat", building: "library" });
  await call({ action: "leave", version: older.version });
  assert.equal(docs.get("presence/alice").building, "library");
  await call({ action: "leave", version: newer.version });
  assert.equal(docs.has("presence/alice"), false);
});
