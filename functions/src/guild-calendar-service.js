import { createHash } from "node:crypto";
import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";

const minute = 60_000;
const hour = 60 * minute;
const day = 24 * hour;
const actions = new Set(["study", "book", "exam"]);
const statuses = new Set(["going", "declined"]);
const hash = (...parts) => createHash("sha256").update(JSON.stringify(parts)).digest("hex");
const eventRoomId = eventId => "guild-event-" + eventId;

function fail(code, message) {
  throw new HttpsError(code, message);
}

function validId(value) {
  if (typeof value !== "string" || !/^[^/]{1,180}$/.test(value)) fail("invalid-argument", "Invalid group or event.");
  return value;
}

function trim(value, max) {
  const clean = typeof value === "string" ? value.trim() : "";
  if (!clean || clean.length > max) fail("invalid-argument", "Invalid text length.");
  return clean;
}

export function eventSettings(input, now) {
  const start = Date.parse(input.startsAt);
  const end = Date.parse(input.endsAt);
  if (!Number.isFinite(start) || !Number.isFinite(end) || start <= now ||
      start > now + 366 * day || end - start < 15 * minute || end - start > 12 * hour ||
      !actions.has(input.kind) || typeof input.voiceEnabled !== "boolean") {
    fail("invalid-argument", "Invalid event time or type.");
  }
  return {
    title: trim(input.title, 80), kind: input.kind, voiceEnabled: input.voiceEnabled,
    startsAt: new Date(start).toISOString(), endsAt: new Date(end).toISOString(),
    activateAt: new Date(start).toISOString(), remindAt: new Date(start - 30 * minute).toISOString(),
    closeAt: new Date(end + hour).toISOString(),
  };
}

function activeGroup(group, uid) {
  return group?.status === "active" && group.memberIds?.includes(uid);
}

function roomSettings(eventId, event, group, ownerName, now) {
  return {
    schemaVersion: 2, id: eventRoomId(eventId), name: event.title, description: "團體共同自習",
    ownerId: group.ownerId, ownerName, memberIds: [group.ownerId], visibility: "private",
    status: "active", joinMode: "approval", roomType: "study", goalSourceType: "focusMinutes",
    dailyGoalValue: 25, goalUnitLabel: "分鐘", memberLimit: 50, voiceEnabled: event.voiceEnabled,
    guildGroupId: event.groupId, guildClosesAt: Timestamp.fromDate(new Date(event.closeAt)),
    guildClosePendingAt: Timestamp.fromDate(new Date(event.closeAt)), updatedAt: now,
  };
}

function memberSettings(roomId, uid, name, role, now) {
  return {
    schemaVersion: 1, roomId, memberId: uid, displayName: name, role, approvalStatus: "approved",
    presenceStatus: "offline", sessionSeconds: 0, metricValue: 0, metricUnit: "minutes",
    activeSessionId: null, updatedAt: now,
  };
}

function displayName(user) {
  return String(user.data()?.displayName || "自律房成員").trim().slice(0, 40) || "自律房成員";
}

export function createGuildCalendarHandler(db, clock = () => new Date()) {
  const events = db.collection("guild_events");
  const attendance = db.collection("guild_event_attendance");
  const notices = db.collection("guild_notices");
  const reads = db.collection("guild_notice_reads");
  return async request => {
    const uid = request.auth?.uid;
    if (!uid) fail("unauthenticated", "Sign-in is required.");
    const data = request.data || {};
    const groupId = validId(data.groupId);
    const now = clock().toISOString();
    const groupRef = db.collection("groups").doc(groupId);
    return db.runTransaction(async tx => {
      const group = (await tx.get(groupRef)).data();
      if (!activeGroup(group, uid)) fail("permission-denied", "Group membership is required.");
      const manager = group.ownerId === uid;
      if (data.action === "list") {
        const cutoff = new Date(Date.parse(now) - 93 * day).toISOString();
        const [upcoming, pinned, mine, seen] = await Promise.all([
          tx.get(events.where("groupId", "==", groupId).where("startsAt", ">=", cutoff).orderBy("startsAt").limit(150)),
          tx.get(notices.where("groupId", "==", groupId)),
          tx.get(attendance.where("userId", "==", uid).where("groupId", "==", groupId)),
          tx.get(reads.where("userId", "==", uid).where("groupId", "==", groupId)),
        ]);
        const rsvp = new Map(mine.docs.map(doc => [doc.data().eventId, doc.data().status]));
        const marked = new Set(seen.docs.map(doc => doc.data().noticeId));
        const pinnedViews = await Promise.all(pinned.docs.map(async doc => {
          const data = doc.data();
          let count;
          if (manager) {
            const acknowledgements = await tx.get(reads.where("noticeId", "==", doc.id));
            count = acknowledgements.docs.filter(mark => group.memberIds.includes(mark.data().userId)).length;
          }
          return { id: doc.id, body: data.body, createdAt: data.createdAt, acknowledged: marked.has(doc.id), count };
        }));
        return {
          now, manager, notices: pinnedViews,
          events: upcoming.docs.map(doc => {
            const event = doc.data();
            return { id: doc.id, title: event.title, kind: event.kind, startsAt: event.startsAt,
              endsAt: event.endsAt, status: rsvp.get(doc.id) || null,
              joinable: rsvp.get(doc.id) === "going" && now >= event.startsAt && now < event.endsAt };
          }),
        };
      }
      if (data.action === "create") {
        if (!manager) fail("permission-denied", "Only the manager can publish an event.");
        tx.create(events.doc(), { ...eventSettings(data, Date.parse(now)), groupId, authorId: uid, createdAt: now });
        return {};
      }
      if (data.action === "pin") {
        if (!manager) fail("permission-denied", "Only the manager can pin a notice.");
        if ((await tx.get(notices.where("groupId", "==", groupId).limit(3))).size >= 3) {
          fail("resource-exhausted", "The board has three notices.");
        }
        tx.create(notices.doc(), { groupId, authorId: uid, body: trim(data.body, 300), createdAt: now });
        return {};
      }
      if (data.action === "ack" || data.action === "unpin") {
        const ref = notices.doc(validId(data.noticeId));
        if ((await tx.get(ref)).data()?.groupId !== groupId) fail("not-found", "Notice is unavailable.");
        if (data.action === "unpin") {
          if (!manager) fail("permission-denied", "Only the manager can unpin a notice.");
          const acknowledgements = await tx.get(reads.where("noticeId", "==", ref.id));
          acknowledgements.docs.forEach(doc => tx.delete(doc.ref));
          tx.delete(ref);
        } else {
          tx.set(reads.doc(hash(ref.id, uid)), { noticeId: ref.id, groupId, userId: uid, updatedAt: now });
        }
        return {};
      }
      const eventId = validId(data.eventId);
      const event = (await tx.get(events.doc(eventId))).data();
      if (event?.groupId !== groupId) fail("not-found", "Event is unavailable.");
      const rsvp = attendance.doc(hash(eventId, uid));
      if (data.action === "rsvp") {
        if (!statuses.has(data.status)) fail("invalid-argument", "Invalid attendance choice.");
        if (now >= event.endsAt) fail("failed-precondition", "The event has ended.");
        tx.set(rsvp, { groupId, eventId, userId: uid, status: data.status, updatedAt: now });
        return {};
      }
      if (data.action !== "join") fail("invalid-argument", "Unknown calendar action.");
      if (now < event.startsAt || now >= event.endsAt || (await tx.get(rsvp)).data()?.status !== "going") {
        fail("failed-precondition", "Confirm attendance and wait for the event to start.");
      }
      const room = db.collection("rooms").doc(eventRoomId(eventId));
      const users = db.collection("users");
      const roomDoc = await tx.get(room);
      const fence = await tx.get(db.collection("account_deletion_fences").doc(group.ownerId));
      if (fence.exists) fail("failed-precondition", "The event room is unavailable.");
      const [owner, user] = uid === group.ownerId
        ? await tx.getAll(users.doc(uid)).then(([doc]) => [doc, doc])
        : await tx.getAll(users.doc(group.ownerId), users.doc(uid));
      const metadata = roomDoc.data() || roomSettings(eventId, event, group, displayName(owner), now);
      if (metadata.status !== "active" || metadata.ownerId !== group.ownerId ||
          !metadata.memberIds.includes(uid) && metadata.memberIds.length >= metadata.memberLimit) {
        fail("failed-precondition", "The event room is unavailable.");
      }
      if (!roomDoc.exists) {
        tx.create(room, { ...metadata, memberIds: [...new Set([...metadata.memberIds, uid])] });
        tx.create(room.collection("members").doc(group.ownerId),
          memberSettings(room.id, group.ownerId, displayName(owner), "owner", now));
      } else if (!metadata.memberIds.includes(uid)) {
        tx.update(room, { memberIds: [...metadata.memberIds, uid], updatedAt: now });
      }
      if (uid !== group.ownerId && !metadata.memberIds.includes(uid)) {
        tx.set(room.collection("members").doc(uid), memberSettings(room.id, uid, displayName(user), "member", now));
      }
      return { roomId: room.id };
    });
  };
}

export function createGuildEventSchedule(db, clock = () => new Date()) {
  const events = db.collection("guild_events");
  return async () => {
    const now = clock().toISOString();
    const closedRooms = await db.collection("rooms")
      .where("guildClosePendingAt", "<=", Timestamp.fromDate(new Date(now))).limit(200).get();
    for (const entry of closedRooms.docs) {
      await db.runTransaction(async tx => {
        const current = await tx.get(entry.ref);
        if (!current.exists || !current.data().guildClosePendingAt) return;
        tx.update(entry.ref, { status: "closed", voiceEnabled: false, updatedAt: now,
          guildClosePendingAt: FieldValue.delete() });
      });
    }
    for (const kind of ["remindAt", "activateAt"]) {
      const entries = await events.where(kind, "<=", now).limit(100).get();
      for (const entry of entries.docs) {
        await db.runTransaction(async tx => {
          const event = (await tx.get(entry.ref)).data();
          if (!event?.[kind] || event[kind] > now) return;
          const room = db.collection("rooms").doc(eventRoomId(entry.id));
          const groupRef = db.collection("groups").doc(event.groupId);
          const group = (await tx.get(groupRef)).data();
          if (kind === "remindAt" && group?.status === "active" && now < event.startsAt) {
            const signup = await tx.get(db.collection("guild_event_attendance").where("eventId", "==", entry.id));
            const declined = new Set(signup.docs.filter(doc => doc.data().status === "declined").map(doc => doc.data().userId));
            const recipients = group.memberIds.filter(uid => !declined.has(uid)).slice(0, 450);
            const fences = recipients.length ? await tx.getAll(...recipients.map(uid => db.collection("account_deletion_fences").doc(uid))) : [];
            recipients.forEach((uid, index) => {
              if (fences[index].exists) return;
              const id = "guild-reminder-" + hash(entry.id, uid);
              tx.create(db.collection("user_notifications").doc(id), {
                schemaVersion: 1, notificationId: id, recipientUserId: uid,
                actorUserId: group.ownerId, actorPrincipalId: group.ownerId,
                category: "social", kind: "guild_event_reminder", sourceType: "guild_event",
                sourceId: entry.id, groupId: event.groupId, route: "groups",
                title: "團體活動即將開始", body: event.title, status: "unread", createdAt: now, updatedAt: now,
              });
            });
          }
          if (kind === "activateAt" && group?.status === "active" && now < event.endsAt) {
            const [existing, user, fence] = await tx.getAll(room, db.collection("users").doc(group.ownerId),
              db.collection("account_deletion_fences").doc(group.ownerId));
            if (!existing.exists && !fence.exists) {
              const name = displayName(user);
              tx.create(room, roomSettings(entry.id, event, group, name, now));
              tx.create(room.collection("members").doc(group.ownerId),
                memberSettings(room.id, group.ownerId, name, "owner", now));
            }
          }
          tx.update(entry.ref, { [kind]: FieldValue.delete() });
        });
      }
    }
  };
}
