import assert from "node:assert/strict";
import test from "node:test";
import { randomUUID } from "node:crypto";
import { deleteApp, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { createSocialSafetyHandler, hiddenBySafety } from "../src/social-safety-service.js";
import { createFriendCabinVisitHandler } from "../src/friend-cabin-visit.js";

test("a block hides the peer in either direction", () => {
  assert.equal(hiddenBySafety({ blocked: ["peer"] }, "peer"), true);
  assert.equal(hiddenBySafety({ blockedBy: ["peer"] }, "peer"), true);
  assert.equal(hiddenBySafety(undefined, "peer"), false);
  assert.equal(hiddenBySafety({ blocked: ["peer"] }, "another"), false);
});

test("Cloud gating, family confirmation, report status and moderation audit", {
  skip: !process.env.FIRESTORE_EMULATOR_HOST,
}, async () => {
  const suffix = randomUUID();
  const app = initializeApp({ projectId: "nudge-discipline-app" }, suffix);
  try {
    const db = getFirestore(app);
    const call = createSocialSafetyHandler(db);
    const cabin = createFriendCabinVisitHandler(db);
    const [owner, child, guest, outsider, staff] = ["owner", "child", "guest", "outsider", "staff"].map(role => role + suffix);
    const invoke = (uid, action, data = {}) => call({ auth: { uid }, data: { ...data, action } });
    const room = db.collection("rooms").doc("safety-" + suffix);
    const link = db.collection("family_links").doc("safety-" + suffix);
    const users = db.collection("users");
    const batch = db.batch();
    for (const uid of [owner, child, guest, outsider, staff]) {
      batch.set(users.doc(uid), { displayName: "Resident", ...(uid === staff ? { staffRole: "operator" } : {}) });
      batch.set(db.collection("public_profiles").doc(uid), { nickname: "Resident" });
    }
    batch.set(users.doc(owner).collection("friends").doc(guest), { id: guest });
    batch.set(users.doc(guest).collection("friends").doc(owner), { id: owner });
    batch.set(db.collection("friend_visit_settings").doc(owner), { allowVisits: true, shareCabin: true });
    batch.set(link, { status: "active", guardianId: owner, childId: child, participantIds: [owner, child] });
    batch.set(room, { status: "active", ownerId: owner, visibility: "private", memberIds: [owner, child, guest] });
    for (const uid of [owner, child, guest]) {
      batch.set(room.collection("members").doc(uid), { memberId: uid, approvalStatus: "approved" });
      batch.set(room.collection("messages").doc(uid), { senderId: uid, type: "text", text: "Hello", createdAt: new Date().toISOString() });
    }
    await batch.commit();

    const view = await invoke(child, "familyView", { linkId: link.id });
    assert.equal(view.isChild, true);
    await assert.rejects(invoke(owner, "setChildProtection", {
      linkId: link.id, allowVoice: false, allowStrangerMentions: false, confirm: true,
    }), { code: "permission-denied" });
    await assert.rejects(invoke(outsider, "familyView", { linkId: link.id }), { code: "permission-denied" });
    await invoke(child, "setChildProtection", {
      linkId: link.id, allowVoice: false, allowStrangerMentions: false, confirm: true,
    });
    assert.deepEqual(await invoke(owner, "familyView", { linkId: link.id }),
      { isChild: false, allowVoice: false, allowStrangerMentions: false });

    await invoke(owner, "report", { type: "roomMessage", targetId: guest, roomId: room.id, reason: "spam", details: "Repeated links" });
    assert.equal((await invoke(owner, "reports")).reports[0].status, "pending");
    await assert.rejects(invoke(outsider, "staffReports"), { code: "permission-denied" });
    const queue = await invoke(staff, "staffReports");
    const report = queue.reports.find(entry => entry.id.includes(room.id));
    assert.equal(report.evidence, "Hello");
    await assert.rejects(invoke(owner, "review", { reportId: report.id, status: "reviewed" }), { code: "permission-denied" });
    await invoke(staff, "review", { reportId: report.id, status: "reviewed" });
    assert.equal((await invoke(owner, "reports")).reports[0].status, "reviewed");

    await invoke(owner, "block", { targetId: guest });
    const own = await invoke(owner, "roomMessages", { roomId: room.id });
    const peer = await invoke(guest, "roomMessages", { roomId: room.id });
    assert.equal(own.messages.some(entry => entry.senderId === guest), false);
    assert.equal(peer.messages.some(entry => entry.senderId === owner), false);
    await assert.rejects(cabin({ auth: { uid: guest }, data: { action: "leave", hostId: owner, noteKey: "cheer", stickerKey: "cheer" } }),
      { code: "permission-denied" });
    await invoke(owner, "unblock", { targetId: guest });
    const moderate = (uid, options) => invoke(uid, "moderate", { scope: "room", scopeId: room.id,
      targetId: guest, reason: "Repeated links", ...options });
    await assert.rejects(moderate(child, { operation: "mute", minutes: 10 }), { code: "permission-denied" });
    await moderate(owner, { operation: "mute", minutes: 10 });
    await moderate(owner, { operation: "deleteMessage" });
    await moderate(owner, { operation: "remove" });
    assert.equal((await room.collection("messages").doc(guest).get()).data().moderated, true);
    assert.equal((await room.collection("members").doc(guest).get()).exists, false);
    assert.equal((await room.collection("activity_sessions").get()).size, 0);
    assert.equal((await invoke(guest, "reports")).actions.length, 3);
  } finally { await deleteApp(app); }
});
