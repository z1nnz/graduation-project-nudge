import { createHash, randomBytes } from "node:crypto";
import { HttpsError } from "firebase-functions/v2/https";

const roomTypes = Object.freeze({
  study: ["focusMinutes", "分鐘", "minutes"],
  exercise: ["exerciseMinutes", "分鐘", "minutes"],
  sleep: ["sleepHours", "小時", "hours"],
  steps: ["steps", "步", "steps"],
  custom: ["manual", "次", "count"],
});
const themes = new Set(["library", "attic", "forest", "seaside"]);
const tokenPattern = /^[A-Za-z0-9_-]{24}$/;
const day = 86_400_000;

function invalid(message) {
  throw new HttpsError("invalid-argument", message);
}

function text(value, limit, required = false) {
  if (typeof value !== "string") invalid("Invalid text.");
  const clean = value.trim();
  if (clean.length > limit || required && !clean) invalid("Invalid text length.");
  return clean;
}

function id(value) {
  if (typeof value !== "string" || !/^[^/]{1,180}$/.test(value)) invalid("Invalid room.");
  return value;
}

const digest = raw => createHash("sha256").update(raw).digest("hex");

export function normalizeLobbyRoom(data) {
  if (!Object.hasOwn(roomTypes, data.roomType) || !themes.has(data.theme) ||
      !Number.isFinite(data.dailyGoalValue) || data.dailyGoalValue <= 0 || data.dailyGoalValue > 100000 ||
      !Number.isInteger(data.memberLimit) || data.memberLimit < 2 || data.memberLimit > 8 ||
      typeof data.approval !== "boolean" || typeof data.voiceEnabled !== "boolean" ||
      !["public", "private"].includes(data.visibility) || !Array.isArray(data.tags) || data.tags.length > 5) {
    invalid("Invalid room settings.");
  }
  const question = text(data.question, 140);
  if (question && !data.approval) invalid("A question requires approval.");
  const [goalSourceType, goalUnitLabel] = roomTypes[data.roomType];
  return {
    schemaVersion: 2,
    name: text(data.name, 80, true),
    description: text(data.description, 500),
    tags: [...new Set(data.tags.map(tag => text(tag, 20, true)))],
    roomType: data.roomType, theme: data.theme, dailyGoalValue: data.dailyGoalValue,
    memberLimit: data.memberLimit, voiceEnabled: data.voiceEnabled, visibility: data.visibility,
    joinMode: data.approval ? "approval" : "instant", goalSourceType, goalUnitLabel,
    joinQuestion: question, lobbyManaged: true, status: "active",
  };
}

function memberDoc(room, uid, name, role, approvalStatus, now) {
  return {
    schemaVersion: 1, roomId: room.id, memberId: uid, displayName: name,
    role, approvalStatus, presenceStatus: "offline", sessionSeconds: 0, metricValue: 0,
    metricUnit: room.goalSourceType === "sleepHours" ? "hours" : room.goalSourceType === "steps" ? "steps" : "minutes", activeSessionId: null, updatedAt: now,
  };
}

function roomSummary(room, uid) {
  return {
    id: room.id, name: room.name, description: room.description, owner: room.ownerId === uid,
    joined: room.memberIds.includes(uid), roomType: room.roomType, theme: room.theme || "library",
    count: room.memberIds.length, limit: room.memberLimit, updatedAt: room.updatedAt, approval: room.joinMode === "approval",
    question: room.joinQuestion || "", voice: room.voiceEnabled === true, tags: room.tags || [],
  };
}

export function createRoomLobbyHandler(db, clock = () => new Date()) {
  const rooms = db.collection("rooms");
  const invites = db.collection("room_lobby_codes");
  const currentInvites = db.collection("room_lobby_active_codes");
  return async request => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Sign-in is required.");
    const data = request.data || {};
    const instant = clock();
    const now = instant.toISOString();
    const profile = () => db.collection("users").doc(uid);
    const ownName = snapshot => String(snapshot.data()?.displayName || "自律房成員").trim().slice(0, 40) || "自律房成員";
    if (data.action === "list") {
      const [publicRooms, ownRooms, activity] = await Promise.all([
        rooms.where("visibility", "==", "public").where("status", "==", "active").limit(200).get(),
        rooms.where("memberIds", "array-contains", uid).get(),
        db.collection("activity_sessions").where("actorUserId", "==", uid)
          .where("status", "==", "completed").orderBy("endedAt", "desc").limit(80).get(),
      ]);
      const visible = new Map([...publicRooms.docs, ...ownRooms.docs]
        .filter(doc => doc.data().status === "active")
        .map(doc => [doc.id, roomSummary(doc.data(), uid)]));
      return { rooms: [...visible.values()], activity: activity.docs.map(doc => doc.data().startedAt).filter(Boolean) };
    }
    if (data.action === "create") {
      const fields = normalizeLobbyRoom(data);
      const ref = rooms.doc();
      const ownerName = ownName(await profile().get());
      const room = { ...fields, id: ref.id, ownerId: uid, ownerName, memberIds: [uid], updatedAt: now };
      const batch = db.batch();
      batch.create(ref, room);
      batch.create(ref.collection("members").doc(uid), memberDoc(room, uid, ownerName, "owner", "approved", now));
      await batch.commit();
      return { roomId: ref.id };
    }
    const token = data.token;
    if (token !== undefined && (typeof token !== "string" || !tokenPattern.test(token))) invalid("Invalid invitation.");
    const inviteRef = token === undefined ? null : invites.doc(digest(token));
    return db.runTransaction(async tx => {
      const invite = inviteRef ? (await tx.get(inviteRef)).data() : null;
      if (inviteRef && (!invite || invite.expiresAt <= now)) {
        throw new HttpsError("not-found", "Invitation is unavailable.");
      }
      const ref = rooms.doc(invite ? invite.roomId : id(data.roomId));
      const room = (await tx.get(ref)).data();
      if (!room || room.status !== "active" || invite && room.ownerId !== invite.ownerId) {
        throw new HttpsError("not-found", "Room is unavailable.");
      }
      if (data.action === "applications") {
        if (room.ownerId !== uid) throw new HttpsError("permission-denied", "Only the owner can review answers.");
        const pending = await tx.get(ref.collection("members").where("approvalStatus", "==", "pending"));
        if (!pending.size) return { answers: [] };
        const answers = await tx.getAll(...pending.docs.map(doc =>
          db.collection("room_lobby_answers").doc(digest(ref.id + "/" + doc.id))));
        return { answers: answers.flatMap((doc, index) => doc.exists ? [{
          name: pending.docs[index].data().displayName, answer: doc.data().answer,
        }] : []) };
      }

      if (data.action === "invite" || data.action === "revoke") {
        if (room.ownerId !== uid || room.visibility === "private" && !room.lobbyManaged) {
          throw new HttpsError("permission-denied", "Only the room owner can manage supported invitations.");
        }
        const current = currentInvites.doc(ref.id);
        const prior = (await tx.get(current)).data();
        if (prior) tx.delete(invites.doc(prior.codeId));
        if (data.action === "revoke") {
          tx.delete(current);
          return {};
        }
        const code = randomBytes(18).toString("base64url");
        const codeId = digest(code);
        const expiresAt = new Date(instant.getTime() + 7 * day).toISOString();
        tx.create(invites.doc(codeId), { roomId: ref.id, ownerId: uid, expiresAt });
        tx.set(current, { codeId, ownerId: uid });
        return { code, expiresAt };
      }
      if (!invite && room.visibility !== "public" && !room.memberIds.includes(uid)) {
        throw new HttpsError("permission-denied", "Room requires an invitation.");
      }
      if (data.action === "preview") return roomSummary(room, uid);
      if (data.action !== "join") invalid("Unknown room action.");
      const member = ref.collection("members").doc(uid);
      const [membership, user] = await tx.getAll(member, profile());
      if (room.memberIds.includes(uid) && membership.exists) return { roomId: ref.id, approvalStatus: membership.data().approvalStatus };
      if (room.memberIds.length >= room.memberLimit) throw new HttpsError("resource-exhausted", "Room is full.");
      const answer = text(data.answer ?? "", 200, Boolean(room.joinQuestion));
      const displayName = ownName(user);
      const approvalStatus = room.joinMode === "approval" ? "pending" : "approved";
      tx.update(ref, { memberIds: [...new Set([...room.memberIds, uid])], updatedAt: now });
      tx.set(member, memberDoc(room, uid, displayName, "member", approvalStatus, now));
      if (room.joinQuestion) {
        tx.set(db.collection("room_lobby_answers").doc(digest(ref.id + "/" + uid)), {
          roomId: ref.id, memberId: uid, question: room.joinQuestion, answer, updatedAt: now,
        });
      }
      const event = ref.collection("events").doc();
      tx.create(event, {
        id: event.id, roomId: ref.id, actorId: uid, actorName: displayName, type: "join",
        text: invite ? "使用房間邀請碼申請加入。" : "透過專注塔大廳申請加入。", createdAt: now,
      });
      return { roomId: ref.id, approvalStatus };
    });
  };
}
