import assert from "node:assert/strict";
import test from "node:test";
import { randomUUID } from "node:crypto";
import { deleteApp, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { createRoomLobbyHandler, normalizeLobbyRoom } from "../src/room-lobby-service.js";

const settings = {
  name: "Library", description: "", tags: ["study", "quiet", "study"], roomType: "study",
  theme: "library", dailyGoalValue: 25, memberLimit: 2, approval: true,
  voiceEnabled: true, visibility: "private", question: "When are you free?",
};

test("room settings retain canonical metadata and constrain approval and capacity", () => {
  const room = normalizeLobbyRoom(settings);
  assert.equal(room.goalSourceType, "focusMinutes");
  assert.equal(room.joinMode, "approval");
  assert.deepEqual(room.tags, ["study", "quiet"]);
  assert.throws(() => normalizeLobbyRoom({ ...settings, memberLimit: 9 }), { code: "invalid-argument" });
  assert.throws(() => normalizeLobbyRoom({ ...settings, approval: false }), { code: "invalid-argument" });
  assert.throws(() => normalizeLobbyRoom({ ...settings, roomType: "constructor" }), { code: "invalid-argument" });
});

test("invitations enforce expiry, revocation, approval, answers and concurrent capacity", {
  skip: !process.env.FIRESTORE_EMULATOR_HOST,
}, async () => {
  const unique = randomUUID();
  const app = initializeApp({ projectId: "nudge-discipline-app" }, unique);
  let now = new Date("2026-11-24T00:00:00Z");
  try {
    const db = getFirestore(app);
    const handle = createRoomLobbyHandler(db, () => now);
    const owner = "owner-" + unique;
    const guestA = "guest-a-" + unique;
    const guestB = "guest-b-" + unique;
    const invoke = (uid, action, data = {}) => handle({ auth: { uid }, data: { action, ...data } });
    const { roomId } = await invoke(owner, "create", settings);
    await assert.rejects(invoke(guestA, "preview", { roomId }), { code: "permission-denied" });
    await assert.rejects(invoke(guestA, "invite", { roomId }), { code: "permission-denied" });
    const old = await invoke(owner, "invite", { roomId });
    await invoke(owner, "revoke", { roomId });
    await assert.rejects(invoke(guestA, "preview", { token: old.code }), { code: "not-found" });
    const expired = await invoke(owner, "invite", { roomId });
    now = new Date(expired.expiresAt);
    await assert.rejects(invoke(guestA, "preview", { token: expired.code }), { code: "not-found" });
    const { code } = await invoke(owner, "invite", { roomId });
    assert.equal((await invoke(guestA, "preview", { token: code })).question, settings.question);
    await assert.rejects(invoke(guestA, "join", { token: code }), { code: "invalid-argument" });
    const outcomes = await Promise.allSettled([guestA, guestB].map(uid => invoke(uid, "join", { token: code, answer: "晚上" })));
    const success = outcomes.find(outcome => outcome.status === "fulfilled");
    assert.equal(success.value.approvalStatus, "pending");
    assert.equal(outcomes.find(outcome => outcome.status === "rejected").reason.code, "resource-exhausted");
    await assert.rejects(invoke(guestA, "applications", { roomId }), { code: "permission-denied" });
    assert.equal((await invoke(owner, "applications", { roomId })).answers[0].answer, "晚上");
    assert.equal((await db.collection("rooms").doc(roomId).collection("events").get()).size, 1);
  } finally { await deleteApp(app); }
});
