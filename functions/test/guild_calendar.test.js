import assert from "node:assert/strict";
import test from "node:test";
import { randomUUID } from "node:crypto";
import { deleteApp, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { createGuildCalendarHandler, createGuildEventSchedule, eventSettings } from "../src/guild-calendar-service.js";

const settings = {
  title: "Study together", kind: "study", voiceEnabled: true,
  startsAt: "2026-11-25T12:00:00Z", endsAt: "2026-11-25T13:00:00Z",
};

test("guild event sets reminder and room closure relative to its own times", () => {
  const now = Date.parse("2026-11-25T11:00:00Z");
  const event = eventSettings(settings, now);
  assert.equal(event.remindAt, "2026-11-25T11:30:00.000Z");
  assert.equal(event.closeAt, "2026-11-25T14:00:00.000Z");
  assert.throws(() => eventSettings({ ...settings, endsAt: settings.startsAt }, now),
    { code: "invalid-argument" });
});

test("attendance is private; room and reminders follow the published schedule", {
  skip: !process.env.FIRESTORE_EMULATOR_HOST,
}, async () => {
  const suffix = randomUUID();
  const app = initializeApp({ projectId: "nudge-discipline-app" }, suffix);
  let now = new Date("2026-11-25T11:10:00Z");
  try {
    const db = getFirestore(app);
    const handler = createGuildCalendarHandler(db, () => now);
    const schedule = createGuildEventSchedule(db, () => now);
    const owner = "guild-owner-" + suffix;
    const member = "guild-member-" + suffix;
    const outsider = "guild-outsider-" + suffix;
    const groupId = "guild-" + suffix;
    const invoke = (uid, action, data = {}) => handler({ auth: { uid }, data: { ...data, groupId, action } });
    await db.collection("groups").doc(groupId).set({ status: "active", ownerId: owner, memberIds: [owner, member] });
    await assert.rejects(invoke(outsider, "list"), { code: "permission-denied" });
    await assert.rejects(invoke(member, "create", settings), { code: "permission-denied" });
    await invoke(owner, "create", settings);
    const eventId = (await invoke(owner, "list")).events[0].id;
    await assert.rejects(invoke(member, "join", { eventId }), { code: "failed-precondition" });
    await invoke(member, "rsvp", { eventId, status: "going" });
    assert.equal((await invoke(owner, "list")).events[0].status, null);
    for (const body of ["One", "Two", "Three"]) await invoke(owner, "pin", { body });
    await assert.rejects(invoke(owner, "pin", { body: "Four" }), { code: "resource-exhausted" });
    const noticeId = (await invoke(member, "list")).notices[0].id;
    await invoke(member, "ack", { noticeId });
    assert.equal((await invoke(member, "list")).notices.find(notice => notice.id === noticeId).count, undefined);
    const view = (await invoke(owner, "list")).notices.find(notice => notice.id === noticeId);
    assert.equal(view.count, 1);
    assert.equal(Object.values(view).includes(member), false);
    now = new Date("2026-11-25T11:30:00Z");
    await schedule();
    await schedule();
    const notifications = await db.collection("user_notifications").where("recipientUserId", "==", member).get();
    assert.equal(notifications.size, 1);
    assert.equal(notifications.docs[0].data().kind, "guild_event_reminder");
    now = new Date("2026-11-25T12:00:00Z");
    await schedule();
    const { roomId } = await invoke(member, "join", { eventId });
    const room = db.collection("rooms").doc(roomId);
    assert.equal((await room.get()).data().ownerId, owner);
    assert.equal((await room.get()).data().voiceEnabled, true);
    const projection = (await room.collection("members").doc(member).get()).data();
    assert.equal(projection.approvalStatus, "approved");
    assert.equal(projection.activeSessionId, null);
    assert.equal((await room.collection("activity_sessions").get()).size, 0);
    now = new Date("2026-11-25T14:00:00Z");
    await schedule();
    assert.equal((await room.get()).data().status, "closed");
  } finally { await deleteApp(app); }
});
