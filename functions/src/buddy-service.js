import { createHash } from "node:crypto";
import { FieldValue } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";
import { hiddenBySafety, safetyDocument } from "./social-safety-service.js";

const dayMs = 86_400_000;
const offset = 8 * 3_600_000;
const hash = (...parts) => createHash("sha256").update(JSON.stringify(parts)).digest("hex");
const fail = (code, message) => { throw new HttpsError(code, message); };
const dateKey = date => new Date(date.getTime() + offset).toISOString().slice(0, 10);
function identifier(value) {
  if (typeof value !== "string" || !/^[^/]{1,180}$/.test(value)) fail("invalid-argument", "Invalid identity.");
  return value;
}
function hourMinute(time) {
  if (typeof time !== "string" || !/^(?:[01]\d|2[0-3]):[0-5]\d$/.test(time)) fail("invalid-argument", "Choose a daily time.");
  return time;
}

export function nextBuddyReminder(now, time) {
  const due = Date.parse(dateKey(now) + "T" + hourMinute(time) + ":00+08:00");
  return new Date(due > now.getTime() ? due : due + dayMs).toISOString();
}
export function buddyCheckIn(left, right, now) {
  const completed = receipts => new Set(receipts.filter(item => item.acceptedMetric > 0 &&
    !item.correctionOfReceiptId && Number.isFinite(Date.parse(item.verifiedAt)))
    .map(item => dateKey(new Date(item.verifiedAt))));
  const mine = completed(left);
  const theirs = completed(right);
  const today = dateKey(now);
  const yesterday = new Date(now.getTime() - dayMs);
  const both = mine.has(today) && theirs.has(today);
  let streak = 0;
  let cursor = both ? now : yesterday;
  while (mine.has(dateKey(cursor)) && theirs.has(dateKey(cursor))) {
    streak++;
    cursor = new Date(cursor.getTime() - dayMs);
  }
  return { mine: mine.has(today), theirs: theirs.has(today), streak, interrupted: !both && streak === 0 };
}

function notice(db, id, { recipient, sender, pairId, now, kind, title }) {
  const ref = db.collection("user_notifications").doc(id);
  return [ref, { schemaVersion: 1, notificationId: id, recipientUserId: recipient, actorUserId: sender,
    actorPrincipalId: sender, sourceType: "buddy_pair", sourceId: pairId, status: "unread",
    route: "buddies", category: "social", kind, title, body: title, createdAt: now, updatedAt: now }];
}

async function hasFriendship(db, tx, uid, peer) {
  const users = db.collection("users");
  const friends = await tx.getAll(users.doc(uid).collection("friends").doc(peer), users.doc(peer).collection("friends").doc(uid));
  return friends.every(doc => doc.exists);
}

async function eraseBuddyNotices(db, pairId) {
  while (true) {
    const batch = await db.collection("user_notifications").where("sourceId", "==", pairId).limit(250).get();
    if (batch.empty) return;
    const write = db.batch();
    batch.docs.forEach(doc => write.delete(doc.ref));
    await write.commit();
  }
}

export function createBuddyHandler(db, clock = () => new Date()) {
  const pairs = db.collection("buddy_pairs");
  const accounts = db.collection("buddy_settings");
  return async ({ auth, data = {} }) => {
    const uid = auth?.uid;
    if (!uid) fail("unauthenticated", "Sign-in is required.");
    const now = clock();
    const today = dateKey(now);
    const timestamp = now.toISOString();
    const ownAccount = accounts.doc(uid);
    const byMember = member => pairs.where("participantIds", "array-contains", member);

    if (data.action === "list") {
      const [mine, friends, settings, safety] = await Promise.all([
        byMember(uid).get(), db.collection("users").doc(uid).collection("friends").get(),
        ownAccount.get(), safetyDocument(db, uid).get(),
      ]);
      const ids = new Set(friends.docs.map(doc => doc.id));
      mine.docs.forEach(doc => ids.add(doc.data().participantIds.find(member => member !== uid)));
      const profiles = ids.size ? await db.getAll(...[...ids].map(id => db.collection("public_profiles").doc(id))) : [];
      const names = new Map(profiles.map(doc => [doc.id, doc.data()?.nickname || doc.data()?.displayName || "小鎮夥伴"]));
      const outgoingFriends = new Set(friends.docs.map(doc => doc.id));
      const pairingPeers = [...new Set(mine.docs.map(doc => doc.data().participantIds.find(member => member !== uid)))];
      const availability = await Promise.all(pairingPeers.map(async peer => {
        if (!outgoingFriends.has(peer) || hiddenBySafety(safety.data(), peer)) return [peer, false];
        const [reciprocal, fence] = await db.getAll(
          db.collection("users").doc(peer).collection("friends").doc(uid),
          db.collection("account_deletion_fences").doc(peer),
        );
        return [peer, reciprocal.exists && !fence.exists];
      }));
      const canShare = new Map(availability);
      const active = mine.docs.filter(doc => doc.data().status === "active" &&
        canShare.get(doc.data().participantIds.find(member => member !== uid)));
      function receipts(person, floor) {
        return db.collection("activity_receipts").where("actorUserId", "==", person)
          .where("verifiedAt", ">=", floor).orderBy("verifiedAt", "desc").get().then(snap => snap.docs.map(doc => doc.data()));
      }
      const views = await Promise.all(active.map(async doc => {
        const data = doc.data();
        const peerId = data.participantIds.find(member => member !== uid);
        const [left, right] = await Promise.all([receipts(uid, data.acceptedAt), receipts(peerId, data.acceptedAt)]);
        return [doc.id, buddyCheckIn(left, right, now)];
      }));
      const checkIns = new Map(views);
      return { limit: settings.data()?.dailyLimit ?? 3,
        friends: friends.docs.filter(doc => !hiddenBySafety(safety.data(), doc.id))
          .map(doc => ({ id: doc.id, name: names.get(doc.id) })),
        pairs: mine.docs.map(doc => {
          const { status, proposerId, time, proposal, paused, participantIds } = doc.data();
          const peerId = participantIds.find(member => member !== uid);
          return { id: doc.id, peerId, name: names.get(peerId), status, proposerId, time, proposal,
            blocked: !canShare.get(peerId), paused: paused?.length > 0, pausedByMe: paused?.includes(uid),
            checkIn: checkIns.get(doc.id) || null };
        }),
      };
    }

    if (data.action === "limit") {
      if (!Number.isInteger(data.limit) || data.limit < 0 || data.limit > 3) fail("invalid-argument", "Choose a limit from 0 to 3.");
      await ownAccount.set({ dailyLimit: data.limit }, { merge: true });
      return {};
    }

    if (data.action === "invite") {
      const peer = identifier(data.peerId);
      if (peer === uid) fail("invalid-argument", "Choose a friend.");
      const time = hourMinute(data.time);
      return db.runTransaction(async tx => {
        const [settings, safety, fence] = await tx.getAll(ownAccount, safetyDocument(db, uid),
          db.collection("account_deletion_fences").doc(peer));
        if (fence.exists || hiddenBySafety(safety.data(), peer) || !(await hasFriendship(db, tx, uid, peer))) {
          fail("permission-denied", "Friendship is required.");
        }
        const own = await tx.get(byMember(uid));
        if (own.docs.some(doc => doc.data().participantIds.includes(peer))) fail("already-exists", "This pair already exists.");
        if (own.docs.filter(doc => doc.data().status === "active" || doc.data().proposerId === uid).length >= 3) {
          fail("resource-exhausted", "At most three partners.");
        }
        const ref = pairs.doc();
        tx.set(ownAccount, { revision: (settings.data()?.revision || 0) + 1 }, { merge: true });
        tx.create(ref, { participantIds: [uid, peer], proposerId: uid, time, status: "pending",
          createdAt: timestamp, updatedAt: timestamp, paused: [] });
        tx.create(...notice(db, "buddy-invite-" + ref.id, { recipient: peer, sender: uid, pairId: ref.id,
          now: timestamp, kind: "buddy_invitation", title: "收到自律夥伴邀請" }));
        return { id: ref.id };
      });
    }

    const ref = pairs.doc(identifier(data.pairId));
    const result = await db.runTransaction(async tx => {
      const entry = (await tx.get(ref)).data();
      if (!entry?.participantIds.includes(uid)) fail("permission-denied", "Pair is unavailable.");
      const peer = entry.participantIds.find(member => member !== uid);
      if (data.action === "remove") {
        tx.delete(ref);
        return { remove: true };
      }
      const target = accounts.doc(peer);
      const [safety, fence, own, other] = await tx.getAll(safetyDocument(db, uid),
        db.collection("account_deletion_fences").doc(peer), ownAccount, target);
      if (fence.exists || hiddenBySafety(safety.data(), peer) || !(await hasFriendship(db, tx, uid, peer))) {
        fail("permission-denied", "Pair is unavailable.");
      }
      if (data.action === "accept" && entry.status === "pending" && entry.proposerId !== uid) {
        const [left, right] = await Promise.all([tx.get(byMember(uid)), tx.get(byMember(peer))]);
        if ([left, right].some(list => list.docs.filter(doc => doc.data().status === "active").length >= 3)) {
          fail("resource-exhausted", "At most three partners.");
        }
        tx.set(ownAccount, { revision: (own.data()?.revision || 0) + 1 }, { merge: true });
        tx.set(target, { revision: (other.data()?.revision || 0) + 1 }, { merge: true });
        tx.update(ref, { status: "active", acceptedAt: timestamp, updatedAt: timestamp,
          nextReminderAt: nextBuddyReminder(now, entry.time) });
        return {};
      }
      if (entry.status !== "active") fail("failed-precondition", "Accept the invitation first.");
      if (data.action === "propose") {
        tx.update(ref, { proposal: { by: uid, time: hourMinute(data.time) }, updatedAt: timestamp });
      } else if (data.action === "confirm" && entry.proposal && entry.proposal.by !== uid) {
        tx.update(ref, { time: entry.proposal.time, proposal: FieldValue.delete(),
          nextReminderAt: nextBuddyReminder(now, entry.proposal.time), updatedAt: timestamp });
      } else if (data.action === "pause" && typeof data.paused === "boolean") {
        tx.update(ref, { paused: data.paused ? FieldValue.arrayUnion(uid) : FieldValue.arrayRemove(uid), updatedAt: timestamp });
      } else if (data.action === "nudge") {
        const dayCount = other.data()?.nudgeDay === today ? other.data().nudgeCount || 0 : 0;
        if (entry.paused?.length || entry.lastNudges?.[uid] === today || dayCount >= (other.data()?.dailyLimit ?? 3)) {
          fail("failed-precondition", "This buddy is not receiving more nudges today.");
        }
        tx.update(ref, { lastNudges: { ...entry.lastNudges, [uid]: today }, updatedAt: timestamp });
        tx.set(target, { nudgeDay: today, nudgeCount: dayCount + 1 }, { merge: true });
        tx.create(...notice(db, "buddy-nudge-" + hash(ref.id, uid, today), {
          recipient: peer, sender: uid, pairId: ref.id, now: timestamp,
          kind: "buddy_nudge", title: "照自己的節奏，我陪你一起開始。",
        }));
      } else fail("failed-precondition", "That buddy action is unavailable.");
      return {};
    });
    if (result.remove) await eraseBuddyNotices(db, ref.id);
    return result;
  };
}

export function createBuddyReminder(db, clock = () => new Date()) {
  return async () => {
    const now = clock();
    const timestamp = now.toISOString();
    const due = await db.collection("buddy_pairs").where("nextReminderAt", "<=", timestamp).limit(200).get();
    for (const doc of due.docs) await db.runTransaction(async tx => {
      const pair = (await tx.get(doc.ref)).data();
      if (pair?.status !== "active" || !pair.nextReminderAt || pair.nextReminderAt > timestamp) return;
      const [a, b] = pair.participantIds;
      const [safety, left, right] = await tx.getAll(safetyDocument(db, a),
        db.collection("account_deletion_fences").doc(a), db.collection("account_deletion_fences").doc(b));
      const allowed = !(pair.paused?.length || hiddenBySafety(safety.data(), b) || left.exists || right.exists) &&
        await hasFriendship(db, tx, a, b);
      if (allowed && now.getTime() - Date.parse(pair.nextReminderAt) <= 10 * 60_000) {
        for (const [recipient, sender] of [[a, b], [b, a]]) {
          tx.create(...notice(db, "buddy-remind-" + hash(doc.id, recipient, pair.nextReminderAt), {
            recipient, sender, pairId: doc.id, now: timestamp, kind: "buddy_reminder", title: "夥伴在等你",
          }));
        }
      }
      tx.update(doc.ref, { nextReminderAt: nextBuddyReminder(now, pair.time) });
    });
  };
}
