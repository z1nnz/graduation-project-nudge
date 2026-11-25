import { Timestamp } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";

const TTL_MS = 300_000;
const TOWN_MIN_INTERVAL_MS = 700;
const buildings = new Set([
  "cabin", "board", "tower", "family", "guild", "library",
  "store", "park", "observatory", "garden", "plaza",
]);
// The town shares only fixed choices: no free text ever reaches friends.
const facings = new Set(["south", "north", "east", "west"]);
const emotes = new Set(["wave", "cheer", "sit", "sleep", "heart", "study"]);
const phrases = new Set(["hi", "study", "great", "rest", "bye", "go"]);

function fraction(value) {
  return typeof value === "number" && Number.isFinite(value) && value >= 0 && value <= 1;
}

function validTown(data) {
  return fraction(data.x) && fraction(data.y) && facings.has(data.facing)
    && (data.emote == null || emotes.has(data.emote))
    && (data.say == null || phrases.has(data.say));
}

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
      (action === "town" && validTown(data)) ||
      (action === "leave" && Number.isSafeInteger(data.version) && data.version > 0);
    if (!valid) throw new HttpsError("invalid-argument", "Invalid presence command.");

    const setting = firestore.collection("presence_settings").doc(uid);
    const presence = firestore.collection("presence").doc(uid);
    const fence = firestore.collection("account_deletion_fences").doc(uid);
    const user = firestore.collection("users").doc(uid);
    return firestore.runTransaction(async transaction => {
      const refs = action === "town" ? [setting, presence, fence, user] : [setting, presence, fence];
      const [preferences, active, deletion, account] = await transaction.getAll(...refs);
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
      const clock = now();
      if (action === "town" && active.data()?.building === "town" && clock - previousVersion < TOWN_MIN_INTERVAL_MS) {
        return { version: previousVersion, throttled: true };
      }
      const version = Math.max(clock, previousVersion + 1);
      const record = {
        uid,
        building: action === "town" ? "town" : data.building,
        page: action === "town" ? "town" : data.building,
        updatedAt: Timestamp.fromMillis(version),
        expiresAt: Timestamp.fromMillis(version + TTL_MS),
      };
      if (action === "town") {
        const face = Number(account?.data()?.avatarProfile?.faceShapeIndex);
        record.town = {
          x: Math.round(data.x * 1000) / 1000,
          y: Math.round(data.y * 1000) / 1000,
          facing: data.facing,
          emote: data.emote ?? null,
          say: data.say ?? null,
          face: Number.isSafeInteger(face) && face >= 0 && face < 100 ? face : 0,
        };
      }
      transaction.set(presence, record);
      return { version };
    });
  };
}
