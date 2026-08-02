import { createHash } from "node:crypto";

import { HttpsError } from "firebase-functions/v2/https";

const BUILT_IN_PRICES = new Map([
  ["faceShape:12", 120],
  ["faceShape:15", 120],
  ["appBackground:1", 35],
  ["appBackground:2", 45],
  ["appBackground:3", 55],
  ["appBackground:4", 40],
]);
const PURCHASE_POLICY_VERSION = "purchase-v1";
const MAX_UNLOCKED_ITEMS = 500;

function hash(value) {
  return createHash("sha256").update(value).digest("hex");
}

function text(value, maximum) {
  const normalized = typeof value === "string" ? value.trim() : "";
  return normalized && normalized.length <= maximum ? normalized : null;
}

function normalizeInput(raw) {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) {
    throw new HttpsError("invalid-argument", "A purchase command is required.");
  }
  const category = text(raw.category, 40);
  const index = Number(raw.index);
  const catalogItemId = raw.catalogItemId == null
    ? null
    : text(raw.catalogItemId, 128);
  const clientRequestId = text(raw.clientRequestId, 128);
  const sourceSurface = text(raw.sourceSurface, 20);
  if (
    !["faceShape", "appBackground"].includes(category) ||
    !Number.isSafeInteger(index) ||
    index < 0 ||
    index > 1_000_000 ||
    (raw.catalogItemId != null && !catalogItemId) ||
    !clientRequestId ||
    !/^[A-Za-z0-9][A-Za-z0-9._:-]*$/.test(clientRequestId) ||
    !["app", "web"].includes(sourceSurface)
  ) {
    throw new HttpsError("invalid-argument", "The purchase command is invalid.");
  }
  return { category, index, catalogItemId, clientRequestId, sourceSurface };
}

function activeCatalogItem(item, nowEpochSeconds) {
  if (item?.status !== "published") return false;
  const start = item.start_time ?? null;
  const end = item.end_time ?? item.expires_at ?? null;
  return (start == null || Number(start) <= nowEpochSeconds) &&
    (end == null || Number(end) > nowEpochSeconds);
}

async function resolvePrice(transaction, firestore, input, nowEpochSeconds) {
  const itemKey = `${input.category}:${input.index}`;
  if (BUILT_IN_PRICES.has(itemKey)) {
    if (input.catalogItemId !== null) {
      throw new HttpsError(
        "invalid-argument",
        "Built-in purchases cannot claim a catalog document.",
      );
    }
    return BUILT_IN_PRICES.get(itemKey);
  }
  if (input.category !== "faceShape" || !input.catalogItemId) {
    throw new HttpsError(
      "failed-precondition",
      "Only an initial published character stage can be purchased.",
    );
  }
  const snapshot = await transaction.get(
    firestore.collection("shop_items").doc(input.catalogItemId),
  );
  const item = snapshot.exists ? snapshot.data() : null;
  if (!activeCatalogItem(item, nowEpochSeconds)) {
    throw new HttpsError("not-found", "The catalog item is not available.");
  }
  const stages = Array.isArray(item.character_stages)
    ? item.character_stages
    : [];
  const isCompleteEvolutionChain =
    item.type === "avatar_series" &&
    stages.length === 3 &&
    stages.every((value, position) =>
      Number(value?.stage) === position + 1 &&
      Number.isSafeInteger(Number(value?.catalog_index)) &&
      (position === 0
        ? value?.shop_eligible === true
        : value?.shop_eligible === false && Number(value?.coin_price) === 0));
  if (!isCompleteEvolutionChain) {
    throw new HttpsError(
      "failed-precondition",
      "The catalog document is not a complete published evolution chain.",
    );
  }
  const stage = stages.find(value => Number(value?.catalog_index) === input.index);
  if (
    Number(stage?.stage) !== 1 ||
    stage?.shop_eligible !== true ||
    !Number.isSafeInteger(Number(stage?.coin_price)) ||
    Number(stage.coin_price) <= 0 ||
    Number(stage.coin_price) !== Number(item.price)
  ) {
    throw new HttpsError(
      "failed-precondition",
      "Only the priced initial stage of a complete evolution chain is purchasable.",
    );
  }
  return Number(stage.coin_price);
}

export function createPurchaseRewardItemHandler({ firestore, clock }) {
  return async request => {
    const userId = request.auth?.uid;
    if (!userId) {
      throw new HttpsError("unauthenticated", "Authentication is required.");
    }
    const input = normalizeInput(request.data);
    const fingerprint = hash(JSON.stringify(input));
    const rewardEntryId = `purchase_${hash(
      `${userId}:${input.clientRequestId}`,
    ).slice(0, 40)}`;
    const rewardRef = firestore
      .collection("reward_ledger_entries")
      .doc(rewardEntryId);
    const userRef = firestore.collection("users").doc(userId);

    return firestore.runTransaction(async transaction => {
      const cutoverSnapshot = await transaction.get(
        firestore.collection("system_state").doc("reward_ledger_cutover"),
      );
      if (cutoverSnapshot.exists && cutoverSnapshot.data().writesPaused === true) {
        throw new HttpsError(
          "unavailable",
          "Reward purchases are temporarily paused for a ledger cutover.",
        );
      }
      const existing = await transaction.get(rewardRef);
      if (existing.exists) {
        const entry = existing.data();
        if (
          entry.actorUserId !== userId ||
          entry.requestFingerprint !== fingerprint
        ) {
          throw new HttpsError(
            "already-exists",
            "The purchase request ID was already used for another command.",
          );
        }
        return { ...entry.result, replayed: true };
      }
      const userSnapshot = await transaction.get(userRef);
      if (!userSnapshot.exists) {
        throw new HttpsError("failed-precondition", "The user profile is missing.");
      }
      const nowDate = new Date(clock());
      if (Number.isNaN(nowDate.getTime())) {
        throw new HttpsError("internal", "The reward service clock is invalid.");
      }
      const now = nowDate.toISOString();
      const price = await resolvePrice(
        transaction,
        firestore,
        input,
        Math.floor(nowDate.getTime() / 1_000),
      );
      const itemKey = `${input.category}:${input.index}`;
      const user = userSnapshot.data();
      const unlocked = Array.isArray(user.unlockedAvatarItems)
        ? [...new Set(user.unlockedAvatarItems.filter(value => typeof value === "string"))]
        : [];
      if (unlocked.length > MAX_UNLOCKED_ITEMS) {
        throw new HttpsError(
          "failed-precondition",
          "The reward unlock projection exceeds the supported limit.",
        );
      }
      const currentCoins = user.disciplineCoins ?? 0;
      if (!Number.isSafeInteger(currentCoins) || currentCoins < 0) {
        throw new HttpsError(
          "failed-precondition",
          "The reward balance projection is invalid.",
        );
      }
      const alreadyUnlocked = unlocked.includes(itemKey);
      if (!alreadyUnlocked && unlocked.length >= MAX_UNLOCKED_ITEMS) {
        throw new HttpsError(
          "failed-precondition",
          "The reward unlock projection has reached the supported limit.",
        );
      }
      if (!alreadyUnlocked && currentCoins < price) {
        throw new HttpsError(
          "failed-precondition",
          "The discipline coin balance is insufficient.",
        );
      }
      const disciplineCoins = alreadyUnlocked ? currentCoins : currentCoins - price;
      if (!alreadyUnlocked) unlocked.push(itemKey);
      const result = {
        rewardEntryId,
        itemKey,
        disciplineCoins,
        unlockedAvatarItems: unlocked,
        alreadyUnlocked,
        replayed: false,
      };
      transaction.create(rewardRef, {
        schemaVersion: 1,
        rewardEntryId,
        entryType: "purchase",
        actorUserId: userId,
        itemKey,
        catalogItemId: input.catalogItemId,
        disciplineCoinsDelta: alreadyUnlocked ? 0 : -price,
        characterExperienceDelta: 0,
        policyVersion: PURCHASE_POLICY_VERSION,
        clientRequestId: input.clientRequestId,
        requestFingerprint: fingerprint,
        sourceSurface: input.sourceSurface,
        status: alreadyUnlocked ? "alreadyOwned" : "applied",
        result,
        createdAt: now,
      });
      transaction.update(userRef, {
        disciplineCoins,
        unlockedAvatarItems: unlocked,
      });
      return result;
    });
  };
}
