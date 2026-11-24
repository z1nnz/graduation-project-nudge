import { createHash } from "node:crypto";
import { HttpsError } from "firebase-functions/v2/https";

import { hiddenBySafety, safetyDocument } from "./social-safety-service.js";

const COOLDOWN_MS = 10 * 60 * 1000;

function peerId(value) {
  if (typeof value !== "string" || !value.length || value.length > 128 || /[\/]/.test(value)) {
    throw new HttpsError("invalid-argument", "Select an eligible friend.");
  }
  return value;
}

/**
 * A friend sends a "hug": the recipient's app passes it to their desk device,
 * which breathes pink for a few seconds. Mutual friends only, at most one hug
 * per pair every 10 minutes, and blocked or deleting accounts never receive.
 */
export function createDeviceHugHandler(firestore, clock = () => new Date()) {
  const users = firestore.collection("users");
  const hugs = firestore.collection("device_hugs");
  const notices = firestore.collection("user_notifications");
  const fences = firestore.collection("account_deletion_fences");

  return async request => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Sign-in is required.");
    const to = peerId(request.data?.toUserId);
    if (to === uid) throw new HttpsError("invalid-argument", "Select an eligible friend.");
    const now = clock();
    const pairRef = hugs.doc(uid + "--" + to);

    return firestore.runTransaction(async transaction => {
      const [fromFriend, toFriend, senderFence, recipientFence, safety, pair] = await transaction.getAll(
        users.doc(uid).collection("friends").doc(to),
        users.doc(to).collection("friends").doc(uid),
        fences.doc(uid), fences.doc(to), safetyDocument(firestore, uid), pairRef,
      );
      if (!fromFriend.exists || !toFriend.exists || senderFence.exists || recipientFence.exists ||
          hiddenBySafety(safety.data(), to)) {
        throw new HttpsError("permission-denied", "This friend cannot receive hugs.");
      }
      const last = Date.parse(pair.data()?.lastAt ?? "");
      if (Number.isFinite(last) && now.getTime() - last < COOLDOWN_MS) {
        throw new HttpsError("resource-exhausted", "Wait a little before the next hug.");
      }
      const createdAt = now.toISOString();
      const id = "device-hug--" + createHash("sha256").update(pairRef.id + "--" + createdAt).digest("hex");
      transaction.set(pairRef, { fromUserId: uid, toUserId: to, lastAt: createdAt });
      transaction.create(notices.doc(id), {
        schemaVersion: 1, notificationId: id, recipientUserId: to,
        actorUserId: uid, actorPrincipalId: uid,
        category: "social", kind: "device_hug", sourceType: "device_hug", sourceId: pairRef.id,
        title: "好友送你一個擁抱", body: "桌上的夥伴亮起了粉紅色的光。",
        route: "friends", status: "unread", createdAt, updatedAt: createdAt,
      });
      return { sent: true };
    });
  };
}
