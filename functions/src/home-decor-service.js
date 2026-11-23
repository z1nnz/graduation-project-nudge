import { createHash } from "node:crypto";
import { createRequire } from "node:module";

import { HttpsError } from "firebase-functions/v2/https";

const catalog = createRequire(import.meta.url)("./home-decor-catalog.json");
const SLOT_ORDER = catalog.slots.map(slot => slot.slot);
const VARIANTS = new Map(
  catalog.slots.map(slot => [slot.slot, new Set(slot.variants.map(v => v.index))]),
);

function hash(value) {
  return createHash("sha256").update(value).digest("hex");
}

function normalizeInput(raw) {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) {
    throw new HttpsError("invalid-argument", "A home decor arrangement is required.");
  }
  const arrangement = raw.arrangement;
  const clientRequestId = typeof raw.clientRequestId === "string"
    ? raw.clientRequestId.trim()
    : "";
  if (
    !arrangement ||
    typeof arrangement !== "object" ||
    Array.isArray(arrangement) ||
    Object.keys(arrangement).length !== SLOT_ORDER.length ||
    !SLOT_ORDER.every(slot =>
      Number.isSafeInteger(arrangement[slot]) &&
      VARIANTS.get(slot).has(arrangement[slot])) ||
    !/^[A-Za-z0-9][A-Za-z0-9._:-]{7,127}$/.test(clientRequestId) ||
    !["app", "web"].includes(raw.sourceSurface)
  ) {
    throw new HttpsError("invalid-argument", "The home decor arrangement is invalid.");
  }
  return {
    arrangement: Object.fromEntries(SLOT_ORDER.map(slot => [slot, arrangement[slot]])),
    clientRequestId,
    sourceSurface: raw.sourceSurface,
  };
}

export function createArrangeHomeDecorHandler({ firestore, clock }) {
  return async request => {
    const userId = request.auth?.uid;
    if (!userId) {
      throw new HttpsError("unauthenticated", "Authentication is required.");
    }
    const input = normalizeInput(request.data);
    const requestFingerprint = hash(JSON.stringify(input));
    const rewardEntryId = `decor_${hash(`${userId}:${input.clientRequestId}`).slice(0, 40)}`;
    const entryRef = firestore.collection("reward_ledger_entries").doc(rewardEntryId);
    const userRef = firestore.collection("users").doc(userId);

    return firestore.runTransaction(async transaction => {
      const [cutover, existing, userSnapshot] = await Promise.all([
        transaction.get(firestore.collection("system_state").doc("reward_ledger_cutover")),
        transaction.get(entryRef),
        transaction.get(userRef),
      ]);
      if (cutover.exists && cutover.data().writesPaused === true) {
        throw new HttpsError(
          "unavailable",
          "Home decor changes are temporarily paused for a ledger cutover.",
        );
      }
      if (existing.exists) {
        const entry = existing.data();
        if (entry.actorUserId !== userId || entry.requestFingerprint !== requestFingerprint) {
          throw new HttpsError(
            "already-exists",
            "The home decor request ID was already used for another command.",
          );
        }
        return { ...entry.result, replayed: true };
      }
      if (!userSnapshot.exists) {
        throw new HttpsError("failed-precondition", "The user profile is missing.");
      }
      const unlocked = new Set(
        Array.isArray(userSnapshot.data().unlockedAvatarItems)
          ? userSnapshot.data().unlockedAvatarItems
          : [],
      );
      SLOT_ORDER.forEach((slot, order) => {
        const index = input.arrangement[slot];
        if (index !== 0 && !unlocked.has(`homeDecor:${order * 100 + index}`)) {
          throw new HttpsError(
            "failed-precondition",
            "Only owned home decor variants can be arranged.",
          );
        }
      });
      const nowDate = new Date(clock());
      if (Number.isNaN(nowDate.getTime())) {
        throw new HttpsError("internal", "The reward service clock is invalid.");
      }
      const result = { rewardEntryId, homeDecor: input.arrangement, replayed: false };
      transaction.create(entryRef, {
        schemaVersion: 1,
        rewardEntryId,
        entryType: "decorArrangement",
        actorUserId: userId,
        disciplineCoinsDelta: 0,
        characterExperienceDelta: 0,
        policyVersion: "decor-v1",
        clientRequestId: input.clientRequestId,
        requestFingerprint,
        sourceSurface: input.sourceSurface,
        status: "applied",
        result,
        createdAt: nowDate.toISOString(),
      });
      transaction.update(userRef, { homeDecor: input.arrangement });
      return result;
    });
  };
}
