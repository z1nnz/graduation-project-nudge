import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { FieldPath } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";

const catalog = JSON.parse(readFileSync(new URL("./town-event-catalog.json", import.meta.url)));
const day = 86_400_000;
const offset = 8 * 3_600_000;
const epochMonday = Date.parse("2020-01-06T00:00:00+08:00");
const localDay = timestamp => new Date(Date.parse(timestamp) + offset).toISOString().slice(0, 10);

export function townEventWeek(now) {
  const number = Math.floor((now.getTime() - epochMonday) / (7 * day));
  const start = epochMonday + number * 7 * day;
  const [key, title, target, unit, activity, mode, minimum] = catalog[(number % catalog.length + catalog.length) % catalog.length];
  return { key, title, target, unit, activity, mode, minimum: minimum || 0, week: localDay(new Date(start).toISOString()),
    startsAt: new Date(start).toISOString(), endsAt: new Date(start + 7 * day).toISOString() };
}

export function aggregateTownEvent(goal, records, excluded) {
  const counted = new Set();
  let total = 0;
  for (const record of records) {
    if (record.activityType !== goal.activity || !record.actorUserId || excluded.has(record.actorUserId) ||
        !record.id || record.correctionOfReceiptId || !Number.isFinite(Date.parse(record.verifiedAt)) ||
        record.verifiedAt < goal.startsAt || record.verifiedAt >= goal.endsAt ||
        !Number.isFinite(record.acceptedMetric) || record.acceptedMetric <= 0 || record.acceptedMetric < goal.minimum) continue;
    const key = goal.mode === "daily" ? JSON.stringify([record.actorUserId, localDay(record.verifiedAt)]) :
      record.activityFingerprint || record.id;
    if (counted.has(key)) continue;
    counted.add(key);
    total += goal.mode === "sum" ? record.acceptedMetric : 1;
  }
  return Math.round(total * 100) / 100;
}

function completedEarlySleep(doc) {
  const data = doc.data();
  const start = Date.parse(data.startedAt);
  const end = Date.parse(data.endedAt);
  const hour = new Date(start + offset).getUTCHours();
  if (data.activityKind !== "sleep" || data.status !== "completed" || !(start < end) ||
      hour < 18 || hour >= 23 || !(data.metricValue > 0)) return null;
  return { id: doc.id, activityType: "earlySleep", verifiedAt: data.endedAt,
    actorUserId: data.actorUserId, acceptedMetric: 1 };
}

export function createTownEventPreferences(db) {
  return async ({ auth, data }) => {
    if (!auth?.uid) throw new HttpsError("unauthenticated", "Sign-in is required.");
    if (typeof data?.excluded !== "boolean") throw new HttpsError("invalid-argument", "A preference is required.");
    await db.collection("town_event_preferences").doc(auth.uid).set({ excluded: data.excluded });
    return { excluded: data.excluded };
  };
}

async function distributeCelebration(db, job, now) {
  return db.runTransaction(async tx => {
    const state = (await tx.get(job)).data();
    if (!state || state.done) return false;
    let users = db.collection("users").orderBy(FieldPath.documentId()).limit(150);
    if (state.after) users = users.startAfter(state.after);
    const page = await tx.get(users);
    const fences = page.size ? await tx.getAll(...page.docs.map(doc => db.collection("account_deletion_fences").doc(doc.id))) : [];
    for (const [index, user] of page.docs.entries()) {
      if (fences[index].exists) continue;
      const id = "town-goal-" + createHash("sha256").update(JSON.stringify([job.id, user.id])).digest("hex");
      const notice = db.collection("user_notifications").doc(id);
      tx.create(notice, { schemaVersion: 1, notificationId: id, recipientUserId: user.id,
        actorUserId: null, actorPrincipalId: "system", category: "social", kind: "town_goal_celebration",
        route: "town-goals", sourceType: "town_event", sourceId: job.id,
        title: "全鎮點亮了廣場燈塔", body: state.title, status: "unread", createdAt: now, updatedAt: now });
    }
    tx.update(job, { after: page.docs.at(-1)?.id || null, done: page.size < 150 });
    return page.size === 150;
  });
}

export function createTownEventSchedule(db, clock = () => new Date()) {
  return async () => {
    const goal = townEventWeek(clock());
    const now = clock().toISOString();
    const window = (name, field) => db.collection(name).where(field, ">=", goal.startsAt).where(field, "<", goal.endsAt);
    const [excluded, activity] = await Promise.all([
      db.collection("town_event_preferences").where("excluded", "==", true).get(),
      goal.activity === "earlySleep" ? window("activity_sessions", "endedAt").get() :
        window("activity_receipts", "verifiedAt").get(),
    ]);
    const records = goal.activity === "earlySleep" ? activity.docs.map(completedEarlySleep).filter(Boolean) :
      activity.docs.map(doc => ({ ...doc.data(), id: doc.id }));
    const total = aggregateTownEvent(goal, records, new Set(excluded.docs.map(doc => doc.id)));
    const aggregate = db.collection("town_events").doc("current");
    const job = db.collection("town_event_jobs").doc(goal.week);
    await db.runTransaction(async tx => {
      const [previous, delivery] = await tx.getAll(aggregate, job);
      if (previous.data()?.updatedAt > now || previous.data()?.startsAt > goal.startsAt) return;
      const reached = total >= goal.target && !delivery.exists;
      tx.set(aggregate, { week: goal.week, title: goal.title, target: goal.target, unit: goal.unit, total,
        startsAt: goal.startsAt, endsAt: goal.endsAt, updatedAt: now, celebrated: reached || delivery.exists });
      if (reached) tx.create(job, { title: goal.title, after: null, done: false });
    });
    const pending = await db.collection("town_event_jobs").where("done", "==", false).limit(4).get();
    for (const entry of pending.docs) {
      for (let index = 0; index < 8; index++) {
        if (!(await distributeCelebration(db, entry.ref, now))) break;
      }
    }
  };
}
