import { Timestamp } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";

const TTL_MS = 300_000;
const buildings = new Set([
  "cabin", "board", "tower", "family", "guild", "library",
  "store", "park", "observatory", "garden", "plaza",
]);

export function createManageFriendPresenceHandler(firestore, now = Date.now) {
  return async ({ auth, data }) => {
    const uid = auth?.uid;
    if (!uid || auth.token?.firebase?.sign_in_provider === "anonymous") {
      throw new HttpsError("unauthenticated", "Sign-in is required.");
    }
    const action = data?.action;
    const valid =
      (action === "consent" && typeof data.enabled === "boolean") ||
      (action === "heartbeat" && buildings.has(data.building)) ||
      (action === "leave" && Number.isSafeInteger(data.version) && data.version > 0);
    if (!valid) throw new HttpsError("invalid-argument", "Invalid presence command.");

    const setting = firestore.collection("presence_settings").doc(uid);
    const presence = firestore.collection("presence").doc(uid);
    const fence = firestore.collection("account_deletion_fences").doc(uid);
    return firestore.runTransaction(async transaction => {
      const [preferences, active, deletion] = await transaction.getAll(setting, presence, fence);
      if (deletion.exists) throw new HttpsError("failed-precondition", "Account deletion is in progress.");
      if (action === "consent") {
        transaction.set(setting, { enabled: data.enabled });
        if (!data.enabled) transaction.delete(presence);
        return { enabled: data.enabled };
      }
      const previousVersion = active.data()?.updatedAt?.toMillis() ?? 0;
      if (action === "leave") {
        if (active.exists && data.version === previousVersion) transaction.delete(presence);
        return {};
      }
      if (preferences.data()?.enabled !== true) {
        throw new HttpsError("permission-denied", "Presence sharing is off.");
      }
      const version = Math.max(now(), previousVersion + 1);
      transaction.set(presence, {
        uid, building: data.building, page: data.building,
        updatedAt: Timestamp.fromMillis(version),
        expiresAt: Timestamp.fromMillis(version + TTL_MS),
      });
      return { version };
    });
  };
}
