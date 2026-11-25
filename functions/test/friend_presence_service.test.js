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

test("town presence shares only a position, a facing and a fixed emote or phrase", async () => {
  const { call, docs } = fixture();
  await assert.rejects(call({ action: "town", x: 0.5, y: 0.5, facing: "south" }), { code: "permission-denied" });
  await call({ action: "consent", enabled: true });
  docs.set("users/alice", { avatarProfile: { faceShapeIndex: 6 }, email: "secret@example.com" });
  await call({ action: "town", x: 0.123456, y: 0.9, facing: "east", emote: "wave", say: "hi", note: "free text" });
  const record = docs.get("presence/alice");
  assert.equal(record.building, "town");
  assert.equal(record.page, "town");
  assert.deepEqual(record.town, { x: 0.123, y: 0.9, facing: "east", emote: "wave", say: "hi", face: 6 });
  assert.equal(JSON.stringify(record).includes("secret"), false, "only the face index is copied from the account");
  for (const bad of [
    { x: -0.1, y: 0.5, facing: "south" },
    { x: 0.5, y: 1.2, facing: "south" },
    { x: 0.5, y: 0.5, facing: "up" },
    { x: 0.5, y: 0.5, facing: "south", emote: "rude" },
    { x: 0.5, y: 0.5, facing: "south", say: "anything I like" },
    { x: "0.5", y: 0.5, facing: "south" },
  ]) {
    await assert.rejects(call({ action: "town", ...bad }), { code: "invalid-argument" }, JSON.stringify(bad));
  }
});

test("town updates are throttled on the server clock", async () => {
  const docs = new Map();
  let clock = 10_000;
  const firestore = {
    collection: name => ({ doc: id => name + "/" + id }),
    runTransaction: task => task({
      getAll: (...refs) => refs.map(ref => ({ exists: docs.has(ref), data: () => docs.get(ref) })),
      set: (ref, value) => docs.set(ref, value),
      delete: ref => docs.delete(ref),
    }),
  };
  const call = data => createManageFriendPresenceHandler(firestore, () => clock)({ auth: { uid: "bob" }, data });
  await call({ action: "consent", enabled: true });
  const first = await call({ action: "town", x: 0.1, y: 0.1, facing: "south" });
  clock += 300;
  const fast = await call({ action: "town", x: 0.9, y: 0.9, facing: "north" });
  assert.equal(fast.throttled, true);
  assert.equal(docs.get("presence/bob").town.x, 0.1, "the fast update was dropped");
  clock += 800;
  const later = await call({ action: "town", x: 0.9, y: 0.9, facing: "north" });
  assert.ok(later.version > first.version);
  assert.equal(docs.get("presence/bob").town.x, 0.9);
});
