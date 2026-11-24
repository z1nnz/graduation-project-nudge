import assert from "node:assert/strict";
import test from "node:test";
import { randomUUID } from "node:crypto";
import { deleteApp, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import {
  createCompletedGoalLetterHandler,
  createDueFamilyLettersHandler,
  createFamilyGardenHandler,
} from "../src/family-garden-service.js";

test("scheduled letters check the child preference and deliver once for date or shared goal", {
  skip: !process.env.FIRESTORE_EMULATOR_HOST,
}, async () => {
  const suffix = randomUUID();
  const app = initializeApp({ projectId: "nudge-discipline-app" }, suffix);
  try {
    const db = getFirestore(app);
    const guardianId = "guardian-" + suffix;
    const childId = "child-" + suffix;
    const linkId = "family-" + suffix;
    const link = db.collection("family_links").doc(linkId);
    const goal = link.collection("goals").doc("goal");
    await link.set({ status: "active", guardianId, childId, participantIds: [guardianId, childId] });
    await goal.set({ status: "accepted", title: "讀一本書" });
    const before = await goal.get();
    const time = () => new Date("2026-11-24T00:00:00Z");
    const due = () => new Date("2026-11-25T01:01:00Z");
    const call = createFamilyGardenHandler(db, time);
    const schedule = options => call({ auth: { uid: guardianId }, data: {
      action: "schedule", linkId, body: "一起慢慢前進。", ...options,
    } });
    await assert.rejects(schedule({ kind: "date", date: "2026-11-31" }), { code: "invalid-argument" });
    await schedule({ kind: "date", date: "2026-11-25" });
    await schedule({ kind: "goal", goalId: goal.id });
    await schedule({ kind: "date", date: "2026-11-26" });
    const letters = db.collection("user_notifications").where("recipientUserId", "==", childId);
    await createDueFamilyLettersHandler(db, time)();
    assert.equal((await letters.get()).size, 0);
    await createDueFamilyLettersHandler(db, due)();
    await createDueFamilyLettersHandler(db, due)();
    assert.equal((await letters.get()).size, 1);
    await goal.update({ status: "completed" });
    const event = { data: { before, after: await goal.get() } };
    const complete = createCompletedGoalLetterHandler(db, due);
    await complete(event);
    await complete(event);
    assert.equal((await letters.get()).size, 2);
    await call({ auth: { uid: childId }, data: { action: "setOptOut", linkId, optedOut: true } });
    await createDueFamilyLettersHandler(db, () => new Date("2026-11-26T02:00:00Z"))();
    assert.equal((await letters.get()).size, 2);
    const saved = await db.collection("family_scheduled_letters").where("linkId", "==", linkId).get();
    assert.deepEqual(saved.docs.map(doc => doc.data().status).sort(), ["cancelled", "sent", "sent"]);
  } finally {
    await deleteApp(app);
  }
});
