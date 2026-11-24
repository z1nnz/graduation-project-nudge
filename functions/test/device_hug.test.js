import assert from "node:assert/strict";
import test from "node:test";
import { createDeviceHugHandler } from "../src/device-hug.js";

function fixture(now = { ms: Date.parse("2026-11-24T08:00:00Z") }) {
  const docs = new Map();
  const ref = path => ({ path, id: path.split("/").pop() });
  const node = prefix => ({
    doc: id => {
      const path = prefix + "/" + id;
      return { ...ref(path), collection: name => node(path + "/" + name) };
    },
  });
  const firestore = {
    collection: name => node(name),
    runTransaction: task => task({
      getAll: (...refs) => refs.map(r => ({ exists: docs.has(r.path), data: () => docs.get(r.path) })),
      set: (r, value) => docs.set(r.path, value),
      create: (r, value) => {
        if (docs.has(r.path)) throw Object.assign(new Error("exists"), { code: 6 });
        docs.set(r.path, value);
      },
    }),
  };
  const call = (uid, data) =>
    createDeviceHugHandler(firestore, () => new Date(now.ms))({ auth: uid ? { uid } : undefined, data });
  const befriend = (a, b) => {
    docs.set(`users/${a}/friends/${b}`, { uid: b });
    docs.set(`users/${b}/friends/${a}`, { uid: a });
  };
  return { call, docs, befriend, now };
}

test("friends can send a hug that lands as a device_hug notification", async () => {
  const { call, docs, befriend } = fixture();
  befriend("alice", "bob");
  const result = await call("alice", { toUserId: "bob" });
  assert.equal(result.sent, true);
  const notice = [...docs.entries()].find(([path]) => path.startsWith("user_notifications/"));
  assert.ok(notice, "notification created");
  const [, data] = notice;
  assert.equal(data.kind, "device_hug");
  assert.equal(data.recipientUserId, "bob");
  assert.equal(data.actorUserId, "alice");
  assert.equal(data.status, "unread");
});

test("only signed-in mutual friends, never yourself", async () => {
  const { call, docs } = fixture();
  await assert.rejects(call(null, { toUserId: "bob" }), { code: "unauthenticated" });
  await assert.rejects(call("alice", { toUserId: "alice" }), { code: "invalid-argument" });
  await assert.rejects(call("alice", { toUserId: "a/b" }), { code: "invalid-argument" });
  docs.set("users/alice/friends/bob", { uid: "bob" }); // one-sided
  await assert.rejects(call("alice", { toUserId: "bob" }), { code: "permission-denied" });
});

test("one hug per friend every 10 minutes", async () => {
  const { call, befriend, now } = fixture();
  befriend("alice", "bob");
  await call("alice", { toUserId: "bob" });
  await assert.rejects(call("alice", { toUserId: "bob" }), { code: "resource-exhausted" });
  now.ms += 10 * 60 * 1000;
  assert.equal((await call("alice", { toUserId: "bob" })).sent, true);
});

test("deleted accounts and blocked users cannot receive hugs", async () => {
  const { call, docs, befriend } = fixture();
  befriend("alice", "bob");
  docs.set("account_deletion_fences/bob", {});
  await assert.rejects(call("alice", { toUserId: "bob" }), { code: "permission-denied" });
  docs.delete("account_deletion_fences/bob");
  docs.set("social_safety/alice", { blocked: ["bob"] });
  await assert.rejects(call("alice", { toUserId: "bob" }), { code: "permission-denied" });
});
