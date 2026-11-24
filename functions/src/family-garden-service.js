import { createHash, randomUUID } from "node:crypto";
import { FieldValue } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";

const offset = 8 * 60 * 60 * 1000;
const week = 7 * 24 * 60 * 60 * 1000;
const snippets = Object.freeze([
  "這週我踏出了第一步。", "我記得留時間休息。", "我重新開始了。",
  "我完成了一件重要的事。", "我找到適合自己的節奏。",
  "謝謝你願意聽我說。", "謝謝你的耐心。", "謝謝你陪我試一次。",
  "謝謝你讓我自己決定。", "謝謝你為我加油。",
]);

export function familyReviewDate(now) {
  const local = new Date(now.getTime() + offset);
  const sunday = new Date(Date.UTC(local.getUTCFullYear(), local.getUTCMonth(),
    local.getUTCDate() - local.getUTCDay() - (local.getUTCDay() === 0 && local.getUTCHours() < 18 ? 7 : 0)));
  return sunday.toISOString().slice(0, 10);
}

export function gardenStages(sessions, consent) {
  const stages = { sunflower: 0, sapling: 0, moonflower: 0 };
  for (const session of sessions) {
    if (session.status !== "completed" || !(session.metricValue > 0)) continue;
    if (session.activityKind === "focus" && consent.summary === true) stages.sunflower++;
    if (session.activityKind === "exercise" && consent.healthTrends === true) stages.sapling++;
    if (session.activityKind === "sleep" && consent.healthTrends === true) {
      const began = Date.parse(session.startedAt);
      const ended = Date.parse(session.endedAt);
      const hour = new Date(began + offset).getUTCHours();
      if (began < ended && hour >= 18 && hour < 23) stages.moonflower++;
    }
  }
  for (const key of Object.keys(stages)) stages[key] = Math.min(stages[key], 3);
  return stages;
}

function identity(value) {
  if (typeof value !== "string" || !/^[^/]{1,180}$/.test(value)) {
    throw new HttpsError("invalid-argument", "Invalid family scope.");
  }
  return value;
}

function message(value, max) {
  const text = typeof value === "string" ? value.trim() : "";
  if (!text || [...text].length > max) throw new HttpsError("invalid-argument", "Message length is invalid.");
  return text;
}

function docHash(values) {
  return createHash("sha256").update(JSON.stringify(values)).digest("hex");
}

function participant(link, uid) {
  return link?.status === "active" && [link.guardianId, link.childId].includes(uid) &&
    link.participantIds?.includes(uid);
}

export function createFamilyGardenHandler(db, clock = () => new Date()) {
  return async ({ auth, data }) => {
    const uid = auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Sign-in is required.");
    const linkId = identity(data?.linkId);
    const linkRef = db.collection("family_links").doc(linkId);
    const now = clock();
    const reviewDate = familyReviewDate(now);
    const notes = db.collection("family_weekly_notes");
    return db.runTransaction(async tx => {
      const current = await tx.get(linkRef);
      const link = current.data();
      if (!participant(link, uid)) throw new HttpsError("permission-denied", "Family link is unavailable.");
      const peer = uid === link.childId ? link.guardianId : link.childId;
      const fences = await tx.getAll(...[uid, peer].map(id => db.collection("account_deletion_fences").doc(id)));
      if (fences.some(doc => doc.exists)) throw new HttpsError("permission-denied", "Family link is unavailable.");
      const noteRef = author => notes.doc(docHash([linkId, reviewDate, author]));
      const preference = db.collection("family_letter_preferences").doc(linkId);
      if (data.action === "view") {
        const consent = link.consentScopes || {};
        let stages = gardenStages([], consent);
        if (consent.summary || consent.healthTrends) {
          const results = await tx.get(db.collection("activity_sessions")
            .where("actorUserId", "==", link.childId).where("status", "==", "completed")
            .where("endedAt", ">=", new Date(now.getTime() - week).toISOString())
            .orderBy("endedAt", "desc").limit(100));
          stages = gardenStages(results.docs.map(item => item.data()), consent);
        }
        const [own, other, settings] = await tx.getAll(noteRef(uid), noteRef(peer), preference);
        const view = doc => doc.exists ? { achievement: doc.data().achievement, gratitude: doc.data().gratitude } : null;
        const goals = uid === link.guardianId
          ? await tx.get(linkRef.collection("goals").where("status", "==", "accepted").limit(50))
          : null;
        return {
          reviewDate, snippets, stages, own: view(own), other: view(other),
          isChild: uid === link.childId, optedOut: settings.data()?.optedOut === true,
          goals: goals?.docs.map(doc => ({ id: doc.id, title: String(doc.data().title || "家庭共同目標") })) || [],
        };
      }
      if (data.action === "writeReview") {
        tx.set(noteRef(uid), {
          linkId, authorId: uid, recipientId: peer, reviewDate,
          achievement: message(data.achievement, 100), gratitude: message(data.gratitude, 100),
          updatedAt: now.toISOString(),
        });
        return {};
      }
      if (data.action === "deleteReview") {
        tx.delete(noteRef(uid));
        return {};
      }
      if (data.action === "setOptOut" && uid === link.childId && typeof data.optedOut === "boolean") {
        tx.set(preference, { userId: uid, optedOut: data.optedOut });
        return {};
      }
      if (data.action === "schedule" && uid === link.guardianId) {
        if ((await tx.get(preference)).data()?.optedOut === true) {
          throw new HttpsError("failed-precondition", "Scheduled letters are disabled.");
        }
        const letter = {
          linkId, guardianId: uid, childId: link.childId, status: "pending",
          body: message(data.body, 280), createdAt: now.toISOString(),
        };
        if (data.kind === "date" && /^\d{4}-\d{2}-\d{2}$/.test(data.date)) {
          const due = Date.parse(data.date + "T09:00:00+08:00");
          if ((!Number.isFinite(due) || new Date(due + offset).toISOString().slice(0, 10) !== data.date) || due <= now.getTime() || due - now.getTime() > 366 * 86400000) {
            throw new HttpsError("invalid-argument", "Choose a future date within one year.");
          }
          letter.dueAt = new Date(due).toISOString();
        } else if (data.kind === "goal") {
          const goal = await tx.get(linkRef.collection("goals").doc(identity(data.goalId)));
          if (goal.data()?.status !== "accepted") throw new HttpsError("failed-precondition", "The shared goal is unavailable.");
          letter.goalPath = goal.ref.path;
        } else {
          throw new HttpsError("invalid-argument", "Choose a date or a shared goal.");
        }
        tx.create(db.collection("family_scheduled_letters").doc(randomUUID()), letter);
        return {};
      }
      throw new HttpsError("permission-denied", "That family action is unavailable.");
    });
  };
}

async function deliverLetter(db, ref, clock) {
  return db.runTransaction(async tx => {
    const doc = await tx.get(ref);
    const letter = doc.data();
    if (letter?.status !== "pending") return;
    const link = db.collection("family_links").doc(letter.linkId);
    const [relationship, preference, guardianFence, childFence] = await tx.getAll(
      link, db.collection("family_letter_preferences").doc(letter.linkId),
      db.collection("account_deletion_fences").doc(letter.guardianId),
      db.collection("account_deletion_fences").doc(letter.childId),
    );
    const family = relationship.data();
    const allowed = family?.status === "active" && family.guardianId === letter.guardianId &&
      family.childId === letter.childId && !guardianFence.exists && !childFence.exists &&
      preference.data()?.optedOut !== true;
    if (letter.goalPath && (await tx.get(db.doc(letter.goalPath))).data()?.status !== "completed") return;
    const now = clock().toISOString();
    if (letter.dueAt && letter.dueAt > now) return;
    tx.update(ref, {
      status: allowed ? "sent" : "cancelled", deliveredAt: now,
      dueAt: FieldValue.delete(), goalPath: FieldValue.delete(),
    });
    if (!allowed) return;
    const id = "family-scheduled--" + ref.id;
    tx.create(db.collection("user_notifications").doc(id), {
      schemaVersion: 1, notificationId: id, recipientUserId: letter.childId,
      actorUserId: letter.guardianId, actorPrincipalId: letter.guardianId,
      category: "social", kind: "family_scheduled_encouragement",
      sourceType: "family_scheduled_letter", sourceId: ref.id, route: "family-courtyard",
      title: "你收到一封家庭鼓勵信", body: letter.body, status: "unread", createdAt: now, updatedAt: now,
    });
  });
}

export function createDueFamilyLettersHandler(db, clock = () => new Date()) {
  return async () => {
    const letterRefs = await db.collection("family_scheduled_letters")
      .where("dueAt", "<=", clock().toISOString()).limit(200).get();
    for (const letter of letterRefs.docs) await deliverLetter(db, letter.ref, clock);
  };
}

export function createCompletedGoalLetterHandler(db, clock = () => new Date()) {
  return async event => {
    const target = event.data?.after;
    if (target?.data()?.status !== "completed" || event.data.before.data()?.status === "completed") return;
    const letters = await db.collection("family_scheduled_letters").where("goalPath", "==", target.ref.path).get();
    for (const letter of letters.docs) await deliverLetter(db, letter.ref, clock);
  };
}
