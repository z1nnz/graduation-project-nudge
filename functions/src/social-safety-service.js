import { createHash } from "node:crypto";
import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";

const reasons = new Set(["harassment", "hate", "spam", "privacy", "other"]);
const types = new Set(["roomMessage", "guestbook", "roomName", "nickname"]);
const muteMinutes = new Set([10, 60, 1440]);
const staffRoles = new Set(["developer", "operator", "admin"]);
const hash = (...parts) => createHash("sha256").update(JSON.stringify(parts)).digest("hex");

function fail(code, message) { throw new HttpsError(code, message); }
function identifier(value) {
  if (typeof value !== "string" || !/^[^/]{1,180}$/.test(value)) fail("invalid-argument", "Invalid identity.");
  return value;
}
function text(value, max, required = false) {
  const result = typeof value === "string" ? value.trim() : "";
  if (result.length > max || required && !result) fail("invalid-argument", "Invalid text length.");
  return result;
}
export function hiddenBySafety(data, peer) {
  return (data?.blocked || []).includes(peer) || (data?.blockedBy || []).includes(peer);
}
export function safetyDocument(db, uid) {
  return db.collection("social_safety").doc(uid);
}
function role(user) {
  return user?.developerAccess === true || staffRoles.has(user?.staffRole);
}
function approved(room, membership, uid) {
  return room?.status === "active" && room.memberIds.includes(uid) &&
    membership?.data()?.approvalStatus === "approved";
}
function publicName(doc) {
  const data = doc.data();
  return String(data?.displayName || data?.nickname || "小鎮居民").slice(0, 80);
}

async function moderationSnapshot(db, tx, uid, input) {
  const target = identifier(input.targetId);
  if (input.type === "roomMessage" || input.type === "roomName") {
    const room = db.collection("rooms").doc(input.type === "roomName" ? target : identifier(input.roomId));
    const [metadata, membership] = await tx.getAll(room, room.collection("members").doc(uid));
    const data = metadata.data();
    if (!data || !approved(data, membership, uid) && !(input.type === "roomName" && data.visibility === "public" && data.status === "active")) {
      fail("permission-denied", "Room is unavailable.");
    }
    if (input.type === "roomName") return { senderId: data.ownerId, evidence: data.name };
    const message = room.collection("messages").doc(target);
    const entry = (await tx.get(message)).data();
    const preferences = (await tx.get(safetyDocument(db, uid))).data();
    if (!entry || hiddenBySafety(preferences, entry.senderId)) fail("permission-denied", "Message is unavailable.");
    return {
      senderId: entry.senderId, evidence: entry.text, messageType: entry.type,
      legacy: message.collection("chat_reports").doc(uid),
    };
  }
  if (input.type === "guestbook") {
    const entry = (await tx.get(db.collection("friend_visits").doc(target))).data();
    if (!entry || entry.hostId !== uid || entry.removed === true) fail("permission-denied", "Guestbook entry is unavailable.");
    return { senderId: entry.visitorId, evidence: String(entry.noteKey || entry.reactionKey || "") };
  }
  const profile = await tx.get(db.collection("public_profiles").doc(target));
  if (!profile.exists) fail("not-found", "Profile is unavailable.");
  return { senderId: target, evidence: publicName(profile) };
}

export function createSocialSafetyHandler(db, clock = () => new Date()) {
  const audit = db.collection("audit_events");
  const reports = db.collection("safety_reports");
  const users = db.collection("users");
  return async ({ auth, data }) => {
    const uid = auth?.uid;
    if (!uid) fail("unauthenticated", "Sign-in is required.");
    const input = data || {};
    const local = safetyDocument(db, uid);
    const instant = clock();
    const now = instant.toISOString();
    if (input.action === "settings") {
      const [settings, user] = await Promise.all([local.get(), users.doc(uid).get()]);
      const ids = settings.data()?.blocked || [];
      const profiles = ids.length ? await db.getAll(...ids.map(id => db.collection("public_profiles").doc(id))) : [];
      return { allowVoice: settings.data()?.allowVoice !== false, blocked: profiles.map(doc => ({ id: doc.id, name: publicName(doc) })), staff: role(user.data()) };
    }
    if (input.action === "reports" || input.action === "staffReports") {
      const staff = input.action === "staffReports";
      if (staff && !role((await users.doc(uid).get()).data())) fail("permission-denied", "Staff role is required.");
      const general = staff ? reports.where("status", "==", "pending") : reports.where("userId", "==", uid);
      const legacy = staff ? db.collectionGroup("chat_reports").where("status", "==", "pending") :
        db.collectionGroup("chat_reports").where("userId", "==", uid);
      const [entries, chat, actions] = await Promise.all([
        general.limit(80).get(), legacy.limit(80).get(),
        staff ? Promise.resolve(null) : audit.where("safetyTargetId", "==", uid).limit(80).get(),
      ]);
      const list = [...entries.docs, ...chat.docs].map(doc => {
        const report = doc.data();
        return { id: doc.ref.path, type: report.targetType || "roomMessage",
          reason: report.reason || "other", details: report.details || "", status: report.status,
          evidence: staff ? report.evidence || report.text || "" : undefined,
        };
      });
      return { reports: list, actions: actions?.docs.map(doc => ({
        reason: doc.data().reason, action: doc.data().action, createdAt: doc.data().createdAt,
      })) || [] };
    }
    return db.runTransaction(async tx => {
      if (input.action === "block" || input.action === "unblock") {
        const target = identifier(input.targetId);
        if (target === uid) fail("invalid-argument", "Cannot block yourself.");
        const ref = safetyDocument(db, target);
        const [self, profile, fence] = await tx.getAll(local, users.doc(target), db.collection("account_deletion_fences").doc(target));
        const blocked = self.data()?.blocked || [];
        if (input.action === "block" && (!profile.exists || fence.exists)) fail("not-found", "Account is unavailable.");
        if (input.action === "block" && blocked.length >= 200 && !blocked.includes(target)) {
          fail("resource-exhausted", "Block list is full.");
        }
        if (input.action === "unblock" && !blocked.includes(target)) return {};
        const change = input.action === "block" ? FieldValue.arrayUnion : FieldValue.arrayRemove;
        tx.set(local, { userId: uid, blocked: change(target) }, { merge: true });
        if (!fence.exists && profile.exists) tx.set(ref, { userId: target, blockedBy: change(uid) }, { merge: true });
        return {};
      }
      if (input.action === "roomMessages" || input.action === "roomEvents") {
        const room = db.collection("rooms").doc(identifier(input.roomId));
        const [metadata, member, settings] = await tx.getAll(room, room.collection("members").doc(uid), local);
        const info = metadata.data();
        if (!approved(info, member, uid)) fail("permission-denied", "Approved room membership is required.");
        const chat = input.action === "roomMessages";
        const entries = await tx.get(room.collection(chat ? "messages" : "events")
          .orderBy("createdAt", "desc").limit(200));
        return { messages: entries.docs
          .filter(doc => !hiddenBySafety(settings.data(), doc.data()[chat ? "senderId" : "actorId"]))
          .slice(0, chat ? 60 : 40).map(doc => ({ ...doc.data(), id: doc.id })) };
      }
      if (input.action === "familyView" || input.action === "setChildProtection") {
        const link = (await tx.get(db.collection("family_links").doc(identifier(input.linkId)))).data();
        if (link?.status !== "active" || !link.participantIds?.includes(uid)) {
          fail("permission-denied", "Active family membership is required.");
        }
        if ((await tx.get(db.collection("account_deletion_fences").doc(link.childId))).exists) {
          fail("permission-denied", "Active family membership is required.");
        }
        const child = safetyDocument(db, link.childId);
        if (input.action === "setChildProtection") {
          if (link.childId !== uid || input.confirm !== true ||
              typeof input.allowVoice !== "boolean" || typeof input.allowStrangerMentions !== "boolean") {
            fail("permission-denied", "Only the child can confirm these settings.");
          }
          tx.set(child, { userId: uid, allowVoice: input.allowVoice,
            allowStrangerMentions: input.allowStrangerMentions }, { merge: true });
          return {};
        }
        const settings = (await tx.get(child)).data();
        return { isChild: link.childId === uid, allowVoice: settings?.allowVoice !== false,
          allowStrangerMentions: settings?.allowStrangerMentions !== false };
      }
      if (input.action === "report") {
        if (!types.has(input.type) || !reasons.has(input.reason)) fail("invalid-argument", "Choose a report type and reason.");
        const { legacy, senderId, evidence, messageType } = await moderationSnapshot(db, tx, uid, input);
        if (uid === senderId) fail("invalid-argument", "Select another member’s content.");
        const ref = legacy || reports.doc(hash(uid, input.type, input.targetId));
        if ((await tx.get(ref)).exists) return {};
        tx.create(ref, {
          userId: uid, senderId, targetType: input.type, targetId: input.targetId,
          reason: input.reason, details: text(input.details, 500), status: "pending",
          ...(legacy ? { text: evidence, type: messageType } : { evidence }),
          createdAt: Timestamp.fromDate(instant),
        });
        return {};
      }
      if (input.action === "review") {
        const actor = (await tx.get(users.doc(uid))).data();
        if (!role(actor)) fail("permission-denied", "Staff role is required.");
        const path = input.reportId;
        if (typeof path !== "string" || !/^(?:safety_reports\/[^/]+|rooms\/[^/]+\/messages\/[^/]+\/chat_reports\/[^/]+)$/.test(path) ||
            !["reviewed", "dismissed"].includes(input.status)) fail("invalid-argument", "Invalid report decision.");
        const ref = db.doc(path);
        if ((await tx.get(ref)).data()?.status !== "pending") fail("failed-precondition", "Report is not pending.");
        tx.update(ref, { status: input.status });
        tx.create(audit.doc(), { schemaVersion: 1, actorUserId: uid, actorPrincipalId: uid, action: "safety.report.review",
          targetId: path, result: { status: input.status }, createdAt: now });
        return {};
      }
      if (input.action !== "moderate" && input.action !== "members") fail("invalid-argument", "Unknown safety action.");
      const roomScope = input.scope === "room";
      if (!roomScope && input.scope !== "group") fail("invalid-argument", "Unknown moderation scope.");
      const scope = db.collection(roomScope ? "rooms" : "groups").doc(identifier(input.scopeId));
      const scopeData = (await tx.get(scope)).data();
      if (scopeData?.ownerId !== uid || scopeData.status !== "active") fail("permission-denied", "Manager role is required.");
      if (input.action === "members") {
        const ids = scopeData.memberIds.filter(id => id !== uid).slice(0, 100);
        const docs = ids.length ? await tx.getAll(...ids.map(id => db.collection("public_profiles").doc(id))) : [];
        return { members: docs.map(doc => ({ id: doc.id, name: publicName(doc) })) };
      }
      const reason = text(input.reason, 300, true);
      if (!["mute", "remove", "deleteMessage"].includes(input.operation)) fail("invalid-argument", "Unknown moderation operation.");
      let targetId = identifier(input.targetId);
      if (input.operation === "deleteMessage") {
        const ref = roomScope ? scope.collection("messages").doc(targetId) : db.collection("guild_notices").doc(targetId);
        const content = (await tx.get(ref)).data();
        if (!content || !roomScope && content.groupId !== scope.id) fail("not-found", "Message is unavailable.");
        targetId = roomScope ? content.senderId : content.authorId;
        if (roomScope) {
          tx.update(ref, { text: "訊息已移除", type: "text", mentionUid: FieldValue.delete(),
            replyTo: FieldValue.delete(), moderated: true });
        } else {
          tx.delete(ref);
        }
      } else {
        if (targetId === uid || !scopeData.memberIds.includes(targetId)) fail("invalid-argument", "Select another member.");
        if (input.operation === "mute") {
          if (!muteMinutes.has(input.minutes)) fail("invalid-argument", "Invalid mute duration.");
          const until = Timestamp.fromMillis(instant.getTime() + 60_000 * input.minutes);
          tx.set(scope.collection("safety_mutes").doc(targetId), { userId: targetId, until });
        } else {
          if (roomScope) {
            tx.delete(scope.collection("members").doc(targetId));
          } else {
            const projection = db.collection("relationship_memberships").doc("group--" + scope.id + "--" + targetId);
            const membership = await tx.get(projection);
            if (membership.exists) tx.update(projection, { status: "ended", activeUntil: now, endedBy: uid, updatedAt: now });
            tx.delete(scope.collection("member_summaries").doc(targetId));
            tx.delete(scope.collection("challenges").doc("current").collection("participants").doc(targetId));
          }
          tx.update(scope, { memberIds: FieldValue.arrayRemove(targetId), updatedAt: now });
        }
      }
      tx.create(audit.doc(), {
        schemaVersion: 1, actorUserId: uid, actorPrincipalId: uid, action: "safety." + input.operation,
        targetId: scope.id, safetyTargetId: targetId, scopeType: input.scope, reason, createdAt: now,
      });
      return {};
    });
  };
}
