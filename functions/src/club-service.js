import { createHash } from "node:crypto";
import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";

const emblems = new Set(["sunrise","book","run","pencil","music","leaf","moon","globe"]);
const stickers = new Set(["cheer","study","sleep","thumbs-up","happy-tears","flex","coffee","heart","okay","wave","think","fire"]);
const reactions = new Set(["👍","🔥","💪","📚","😴","🎉"]);
const staff = new Set(["operator","admin","developer"]);
const hour = 3_600_000;
const day = 24 * hour;
const epoch = Date.parse("2020-01-06T00:00:00+08:00");
const hash = (...values) => createHash("sha256").update(JSON.stringify(values)).digest("hex");
const fail = (code, text) => { throw new HttpsError(code, text); };
function id(value) {
  if (typeof value !== "string" || !/^[^/]{1,180}$/.test(value)) fail("invalid-argument", "Invalid identity.");
  return value;
}
function text(value, maximum, required = true) {
  const trimmed = typeof value === "string" ? value.trim() : "";
  if (required && !trimmed || [...trimmed].length > maximum) fail("invalid-argument", "Invalid text length.");
  return trimmed;
}
export function clubPostTimes(previous, now) {
  const recent = previous.filter(stamp => stamp > now - hour);
  if (recent.length >= 10) fail("resource-exhausted", "At most 10 posts in the last hour.");
  return [...recent, now];
}
function challenge(now) {
  const number = Math.floor((now - epoch) / (7 * day));
  const [[type, title], start] = [[["focus","三天各專注一次"],["exercise","三天各運動一次"],["task","三天各完成一件委託"]][number % 3],
    new Date(epoch + number * 7 * day).toISOString()];
  return { id: start, startsAt: start, type, title, days: 3 };
}
function name(profile) {
  return String(profile.data()?.nickname || profile.data()?.displayName || "小鎮夥伴").slice(0, 40);
}
function memberProjection(roomId, uid, displayName, role, now) {
  return { schemaVersion: 1, roomId, memberId: uid, displayName, role, approvalStatus: "approved",
    presenceStatus: "offline", sessionSeconds: 0, metricValue: 0, metricUnit: "minutes", activeSessionId: null, updatedAt: now };
}

export function createClubHandler(db, clock = () => new Date()) {
  const clubs = db.collection("clubs");
  const directory = db.collection("club_public");
  const users = db.collection("users");
  const posts = db.collection("club_posts");
  const roster = db.collection("club_members");
  const entries = db.collection("club_challenge_members");
  const votes = db.collection("club_reactions");
  const quotas = db.collection("club_post_quota");
  const audit = db.collection("audit_events");
  const fence = uid => db.collection("account_deletion_fences").doc(uid);
  const rosterId = (club, uid) => roster.doc(hash(club, uid));
  return async ({ auth, data = {} }) => {
    const uid = auth?.uid;
    if (!uid) fail("unauthenticated", "Sign-in is required.");
    const now = clock();
    const timestamp = now.toISOString();
    const profile = users.doc(uid);
    const isStaff = doc => doc.data()?.developerAccess === true || staff.has(doc.data()?.staffRole);

    if (data.action === "directory") {
      const [published, requests, staffDoc] = await Promise.all([directory.limit(150).get(),
        clubs.where("ownerId", "==", uid).get(), profile.get()]);
      const pending = isStaff(staffDoc) ? await clubs.where("status", "==", "pending").limit(100).get() : null;
      const view = doc => ({ id: doc.id, name: doc.data().name, introduction: doc.data().introduction,
        emblem: doc.data().emblem, status: doc.data().status });
      return { clubs: published.docs.map(view), requests: requests.docs.map(view), review: pending?.docs.map(view) || [] };
    }
    if (data.action === "apply") {
      const label = text(data.name, 60);
      const introduction = text(data.introduction, 400);
      if (!emblems.has(data.emblem)) fail("invalid-argument", "Choose a club emblem.");
      return db.runTransaction(async tx => {
        const pending = await tx.get(clubs.where("ownerId", "==", uid).where("status", "==", "pending").limit(1));
        if (!pending.empty) fail("already-exists", "You already have a pending application.");
        const club = clubs.doc();
        tx.create(club, { name: label, introduction, emblem: data.emblem, ownerId: uid, status: "pending", createdAt: timestamp });
        return { id: club.id };
      });
    }

    const club = clubs.doc(id(data.clubId));
    const member = rosterId(club.id, uid);
    const room = db.collection("rooms").doc("club-" + club.id);
    const roomName = db.collection("public_profiles").doc(uid);
    const gate = club.collection("safety_mutes").doc(uid);
    const thisWeek = challenge(now.getTime());
    const participation = entries.doc(hash(club.id, thisWeek.id, uid));

    return db.runTransaction(async tx => {
      const [metadata, myMembership] = await tx.getAll(club, member);
      const info = metadata.data();
      if (!info) fail("not-found", "Club is unavailable.");
      if (data.action === "review") {
        const ownerFence = await tx.get(fence(info.ownerId));
        if (!isStaff(await tx.get(profile)) || ownerFence.exists || info.status !== "pending" || !["approved","rejected"].includes(data.status)) {
          fail("permission-denied", "This application cannot be reviewed.");
        }
        tx.update(club, { status: data.status, reviewedAt: timestamp });
        if (data.status === "approved") {
          tx.create(directory.doc(club.id), { name: info.name, introduction: info.introduction, emblem: info.emblem, status: "approved" });
          tx.create(rosterId(club.id, info.ownerId), { clubId: club.id, userId: info.ownerId,
            public: false, joinedAt: timestamp });
        }
        tx.create(audit.doc(), { schemaVersion: 1, actorUserId: uid, actorPrincipalId: uid,
          action: "club.review", targetId: club.id, createdAt: timestamp, result: { status: data.status } });
        return {};
      }
      if (info.status !== "approved" || (await tx.get(fence(info.ownerId))).exists) fail("permission-denied", "Club is unavailable.");
      if (data.action === "join") {
        if (myMembership.exists) return {};
        const removed = await tx.get(club.collection("removed").doc(uid));
        if (removed.exists) fail("permission-denied", "Club membership is unavailable.");
        tx.create(member, { clubId: club.id, userId: uid, public: false, joinedAt: timestamp });
        return {};
      }
      if (data.action === "view" && !myMembership.exists) return { joined: false };
      if (!myMembership.exists) fail("permission-denied", "Club membership is required.");
      const manager = uid === info.ownerId;
      if (data.action === "view") {
        const [members, wall, challengeEntries, roomDoc] = await Promise.all([
          tx.get(roster.where("clubId", "==", club.id)),
          tx.get(posts.where("clubId", "==", club.id).orderBy("createdAt", "desc").limit(80)),
          tx.get(entries.where("clubId", "==", club.id).where("week", "==", thisWeek.id)),
          tx.get(room),
        ]);
        const visible = members.docs.filter(doc => manager || doc.data().public === true);
        const names = visible.length ? await tx.getAll(...visible.map(doc => db.collection("public_profiles").doc(doc.data().userId))) : [];
        const currentMembers = new Set(members.docs.map(doc => doc.data().userId));
        const participants = challengeEntries.docs.map(doc => doc.data().userId).filter(actor => currentMembers.has(actor));
        const completions = await Promise.all(participants.map(actor => tx.get(db.collection("activity_receipts")
          .where("actorUserId", "==", actor).where("verifiedAt", ">=", thisWeek.startsAt).orderBy("verifiedAt", "desc")).then(snap =>
          new Set(snap.docs.map(doc => doc.data()).filter(item => item.activityType === thisWeek.type &&
            item.acceptedMetric > 0 && !item.correctionOfReceiptId)
            .map(item => new Date(Date.parse(item.verifiedAt) + 8 * hour).toISOString().slice(0, 10))).size >= thisWeek.days)));
        return { joined: true, manager, public: myMembership.data().public, hasRoom: roomDoc.data()?.status === "active",
          challenge: { title: thisWeek.title, joined: participants.includes(uid), participants: participants.length, completed: completions.filter(Boolean).length },
          members: names.map((doc, index) => ({ id: doc.id, name: name(doc), public: visible[index].data().public })),
          posts: wall.docs.reverse().map(doc => {
            const { authorId, authorName, body, sticker, replyTo, totals, createdAt } = doc.data();
            return { id: doc.id, authorId, authorName, body, sticker, replyTo, totals, createdAt };
          }),
        };
      }
      if (data.action === "visibility" && typeof data.enabled === "boolean") {
        tx.update(member, { public: data.enabled });
        return {};
      }
      if (data.action === "challenge") {
        tx.set(participation, { clubId: club.id, week: thisWeek.id, userId: uid, joinedAt: timestamp });
        return {};
      }
      if (data.action === "leave") {
        if (manager) fail("failed-precondition", "The managing member cannot leave the club.");
        const roomInfo = await tx.get(room);
        tx.delete(member);
        if (roomInfo.exists) {
          tx.update(room, { memberIds: FieldValue.arrayRemove(uid), updatedAt: timestamp });
          tx.delete(room.collection("members").doc(uid));
        }
        return {};
      }
      if (data.action === "post" || data.action === "react") {
        const muted = (await tx.get(gate)).data()?.until?.toMillis() > now.getTime();
        if (muted) fail("permission-denied", "You are muted in this club.");
        if (data.action === "react") {
          if (!reactions.has(data.emoji) && data.emoji !== null) fail("invalid-argument", "Choose a reaction.");
          const post = posts.doc(id(data.postId));
          const vote = votes.doc(hash(post.id, uid));
          const [target, previous] = await tx.getAll(post, vote);
          const item = target.data();
          if (item?.clubId !== club.id) fail("not-found", "Post is unavailable.");
          const totals = { ...item.totals };
          const prior = previous.data()?.emoji;
          if (prior) totals[prior] = Math.max(0, (totals[prior] || 0) - 1);
          if (data.emoji && data.emoji !== prior) {
            totals[data.emoji] = (totals[data.emoji] || 0) + 1;
            tx.set(vote, { postId: post.id, clubId: club.id, userId: uid, emoji: data.emoji });
          } else tx.delete(vote);
          tx.update(post, { totals });
          return {};
        }
        const body = text(data.body, 300);
        if (data.sticker && !stickers.has(data.sticker)) fail("invalid-argument", "Unknown sticker.");
        const quota = quotas.doc(uid);
        const [throttle, account] = await tx.getAll(quota, roomName);
        const times = clubPostTimes(throttle.data()?.times || [], now.getTime());
        const parent = data.replyTo ? posts.doc(id(data.replyTo)) : null;
        if (parent && (await tx.get(parent)).data()?.clubId !== club.id) fail("not-found", "Post is unavailable.");
        tx.create(posts.doc(), { clubId: club.id, authorId: uid, authorName: name(account), body,
          sticker: data.sticker || null, replyTo: parent?.id || null, totals: {}, createdAt: timestamp });
        tx.set(quota, { userId: uid, times });
        return {};
      }
      if (data.action === "room") {
        const [existing, account, mute] = await tx.getAll(room, roomName, gate);
        const roomData = existing.data();
        if (!roomData) {
          if (!manager) fail("permission-denied", "Wait for the manager to open the room.");
          const displayName = name(account);
          tx.create(room, { schemaVersion: 2, id: room.id, name: info.name, description: "社團自律房",
            ownerId: uid, ownerName: displayName, memberIds: [uid], visibility: "private", status: "active",
            joinMode: "approval", roomType: "study", goalSourceType: "focusMinutes", dailyGoalValue: 25,
            goalUnitLabel: "分鐘", memberLimit: 50, voiceEnabled: data.voiceEnabled === true, clubScopeId: club.id,
            updatedAt: timestamp });
          tx.create(room.collection("members").doc(uid), memberProjection(room.id, uid, displayName, "owner", timestamp));
        } else {
          if (roomData.status !== "active") fail("failed-precondition", "Club room is closed.");
          if (!roomData.memberIds.includes(uid)) {
            if (roomData.memberIds.length >= roomData.memberLimit) fail("resource-exhausted", "The club room is full.");
            tx.update(room, { memberIds: FieldValue.arrayUnion(uid), updatedAt: timestamp });
            tx.set(room.collection("members").doc(uid), memberProjection(room.id, uid, name(account), "member", timestamp));
            if (mute.data()?.until?.toMillis() > now.getTime()) {
              tx.set(room.collection("safety_mutes").doc(uid), { userId: uid, until: mute.data().until });
            }
          }
        }
        return { roomId: room.id };
      }
      if (data.action !== "moderate" || !manager) fail("permission-denied", "Club manager access is required.");
      const reason = text(data.reason, 300);
      let target = id(data.targetId);
      if (data.operation === "deleteMessage") {
        const document = posts.doc(target);
        const item = (await tx.get(document)).data();
        if (item?.clubId !== club.id) fail("not-found", "Post is unavailable.");
        target = item.authorId;
        tx.delete(document);
      } else if (target !== uid && ["mute","remove"].includes(data.operation)) {
        const victim = rosterId(club.id, target);
        const [person, roomDoc] = await tx.getAll(victim, room);
        if (!person.exists) fail("not-found", "Member is unavailable.");
        if (data.operation === "mute" && [10,60,1440].includes(data.minutes)) {
          const until = Timestamp.fromMillis(now.getTime() + data.minutes * 60_000);
          tx.set(club.collection("safety_mutes").doc(target), { userId: target, until });
          if (roomDoc.exists) tx.set(room.collection("safety_mutes").doc(target), { userId: target, until });
        } else if (data.operation === "remove") {
          tx.delete(victim);
          tx.set(club.collection("removed").doc(target), { userId: target });
          if (roomDoc.exists) {
            tx.update(room, { memberIds: FieldValue.arrayRemove(target), updatedAt: timestamp });
            tx.delete(room.collection("members").doc(target));
          }
        } else fail("invalid-argument", "Invalid mute duration or removal.");
      } else fail("invalid-argument", "Invalid moderation target.");
      tx.create(audit.doc(), { schemaVersion: 1, actorUserId: uid, actorPrincipalId: uid,
        action: "safety." + data.operation, targetId: club.id, safetyTargetId: target,
        scopeType: "club", reason, createdAt: timestamp });
      return {};
    });
  };
}
