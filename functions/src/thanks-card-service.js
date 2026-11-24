import { createHash } from "node:crypto";
import { HttpsError } from "firebase-functions/v2/https";
import { hiddenBySafety, safetyDocument } from "./social-safety-service.js";

const patterns = new Set(["stars", "flowers", "coffee", "books", "moon", "sun", "rainbow", "mountain", "lantern", "heart", "leaf", "music"]);
const dateFormat = new Intl.DateTimeFormat("en-CA", { timeZone: "Asia/Taipei", dateStyle: "short" });
const hash = (...parts) => createHash("sha256").update(JSON.stringify(parts)).digest("hex");
const fail = (code, message) => { throw new HttpsError(code, message); };
function identity(value) {
  if (typeof value !== "string" || !/^[^/]{1,180}$/.test(value)) fail("invalid-argument", "Invalid recipient.");
  return value;
}
export function cardContent(input) {
  const text = typeof input.text === "string" ? input.text.trim() : "";
  if (!patterns.has(input.pattern) || !text || [...text].length > 60) fail("invalid-argument", "Choose a design and write 1–60 characters.");
  return { text, pattern: input.pattern };
}

async function allowedPair(db, tx, sender, peer, roomId) {
  if (roomId) {
    const room = db.collection("rooms").doc(identity(roomId));
    const [metadata, own, other] = await tx.getAll(room, room.collection("members").doc(sender),
      room.collection("members").doc(peer));
    const info = metadata.data();
    if (info?.guildGroupId) {
      const group = (await tx.get(db.collection("groups").doc(info.guildGroupId))).data();
      if (group?.status !== "active" || ![sender, peer].every(uid => group.memberIds?.includes(uid))) return false;
    }
    return info?.status === "active" && [sender, peer].every(uid => info.memberIds?.includes(uid)) &&
      own.data()?.approvalStatus === "approved" && other.data()?.approvalStatus === "approved";
  }
  const users = db.collection("users");
  const links = await tx.getAll(users.doc(sender).collection("friends").doc(peer), users.doc(peer).collection("friends").doc(sender));
  return links.every(snapshot => snapshot.exists);
}

export function createThanksCardHandler(db, clock = () => new Date()) {
  const cards = db.collection("thanks_cards");
  const receipts = db.collection("thanks_card_receipts");
  const budgets = db.collection("thanks_card_budgets");
  const notices = db.collection("user_notifications");
  const users = db.collection("users");
  return async ({ auth, data = {} }) => {
    const uid = auth?.uid;
    if (!uid) fail("unauthenticated", "Sign-in is required.");
    const instant = clock();
    const now = instant.toISOString();
    const day = dateFormat.format(instant);
    if (data.action === "list") {
      const inbox = await cards.where("recipientId", "==", uid).get();
      return { cards: inbox.docs.map(doc => ({ ...doc.data(), id: doc.id })).sort((a, b) => b.createdAt.localeCompare(a.createdAt)) };
    }
    if (data.action === "send") {
      const peer = identity(data.recipientId);
      if (peer === uid) fail("invalid-argument", "Choose another resident.");
      const content = cardContent(data);
      const receipt = receipts.doc(hash(uid, peer, day));
      const budget = budgets.doc(hash(uid, day));
      const card = cards.doc(receipt.id);
      return db.runTransaction(async tx => {
        const [seen, current, localSafety, fence, user, profile] = await tx.getAll(receipt, budget,
          safetyDocument(db, uid), db.collection("account_deletion_fences").doc(peer), users.doc(peer),
          db.collection("public_profiles").doc(uid));
        if (!user.exists || fence.exists || hiddenBySafety(localSafety.data(), peer) ||
            !(await allowedPair(db, tx, uid, peer, data.roomId))) fail("permission-denied", "This recipient is unavailable.");
        if (seen.exists) fail("already-exists", "A card was already sent to this recipient today.");
        const count = current.data()?.count || 0;
        if (count >= 10) fail("resource-exhausted", "Daily card limit reached.");
        const senderName = String(profile.data()?.nickname || profile.data()?.displayName || "小鎮夥伴").slice(0, 40);
        tx.create(receipt, { senderId: uid, recipientId: peer, day });
        tx.set(budget, { userId: uid, day, count: count + 1 });
        tx.create(card, { ...content, senderId: uid, senderName, recipientId: peer,
          month: day.slice(0, 7), createdAt: now, saved: false });
        const notification = notices.doc("thanks-" + card.id);
        tx.create(notification, {
          schemaVersion: 1, notificationId: notification.id, recipientUserId: peer,
          actorUserId: uid, actorPrincipalId: uid, category: "social", kind: "thanks_card",
          sourceType: "thanks_card", sourceId: card.id, route: "thanks-cards",
          title: "收到一張感謝卡", body: content.text, status: "unread", createdAt: now, updatedAt: now,
        });
        return { id: card.id };
      });
    }
    const selected = cards.doc(identity(data.cardId));
    return db.runTransaction(async tx => {
      if ((await tx.get(selected)).data()?.recipientId !== uid) fail("permission-denied", "Card is unavailable.");
      if (data.action === "save") tx.update(selected, { saved: true });
      else if (data.action === "delete") {
        tx.delete(selected);
        tx.delete(notices.doc("thanks-" + selected.id));
      } else fail("invalid-argument", "Unknown action.");
      return {};
    });
  };
}
