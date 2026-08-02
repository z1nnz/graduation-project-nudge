import { createHash } from "node:crypto";

import { HttpsError } from "firebase-functions/v2/https";

const PROFILE_INTEGER_FIELDS = [
  "skinToneIndex",
  "faceShapeIndex",
  "hairStyleIndex",
  "hairColorIndex",
  "eyeStyleIndex",
  "eyebrowStyleIndex",
  "mouthStyleIndex",
  "outfitStyleIndex",
  "outfitColorIndex",
  "accessoryIndex",
  "backgroundColorIndex",
  "avatarIconIndex",
];
const BACKGROUND_THEMES = [
  "softGlow",
  "nightStudy",
  "sakuraWalk",
  "galaxySleep",
  "gymEnergy",
];
const BUILT_IN_SERIES = [
  "星辰旅人",
  "星詠魔導",
  "焰心鬥士",
  "玫瑰學院",
  "月影忍者",
  "森語女神",
];
const PAID_BUILT_IN_STARTERS = new Set([12, 15]);
const AVATAR_LEVEL_CURVE_A = 5.454899668809663;
const AVATAR_LEVEL_CURVE_B = 186.63549581141635;

function hash(value) {
  return createHash("sha256").update(value).digest("hex");
}

function boundedText(value, maximum) {
  const normalized = typeof value === "string" ? value.trim() : "";
  return normalized && normalized.length <= maximum ? normalized : null;
}

function normalizeProfile(raw) {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) {
    throw new HttpsError("invalid-argument", "An avatar profile is required.");
  }
  const profile = {};
  for (const field of PROFILE_INTEGER_FIELDS) {
    const value = Number(raw[field]);
    if (!Number.isSafeInteger(value) || value < 0 || value > 1_000_000) {
      throw new HttpsError("invalid-argument", "The avatar profile is invalid.");
    }
    profile[field] = value;
  }
  profile.useCustomImage = raw.useCustomImage === true;
  profile.customImagePath = raw.customImagePath == null
    ? null
    : boundedText(raw.customImagePath, 2_048);
  if (raw.customImagePath != null && !profile.customImagePath) {
    throw new HttpsError("invalid-argument", "The avatar image path is invalid.");
  }
  return profile;
}

function normalizeInput(raw) {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) {
    throw new HttpsError("invalid-argument", "An equipment command is required.");
  }
  const profile = normalizeProfile(raw.avatarProfile);
  const backgroundTheme = boundedText(raw.backgroundTheme, 40);
  const faceCatalogItemId = raw.faceCatalogItemId == null
    ? null
    : boundedText(raw.faceCatalogItemId, 128);
  const iconCatalogItemId = raw.iconCatalogItemId == null
    ? null
    : boundedText(raw.iconCatalogItemId, 128);
  const clientRequestId = boundedText(raw.clientRequestId, 128);
  const sourceSurface = boundedText(raw.sourceSurface, 20);
  if (
    !backgroundTheme ||
    !BACKGROUND_THEMES.includes(backgroundTheme) ||
    (raw.faceCatalogItemId != null && !faceCatalogItemId) ||
    (raw.iconCatalogItemId != null && !iconCatalogItemId) ||
    !clientRequestId ||
    !/^[A-Za-z0-9][A-Za-z0-9._:-]*$/.test(clientRequestId) ||
    !["app", "web"].includes(sourceSurface)
  ) {
    throw new HttpsError("invalid-argument", "The equipment command is invalid.");
  }
  return {
    profile,
    backgroundTheme,
    faceCatalogItemId,
    iconCatalogItemId,
    clientRequestId,
    sourceSurface,
  };
}

function completeStages(item) {
  const stages = Array.isArray(item?.character_stages)
    ? item.character_stages
    : [];
  return item?.type === "avatar_series" &&
    stages.length === 3 &&
    stages.every((stage, index) =>
      Number(stage?.stage) === index + 1 &&
      Number.isSafeInteger(Number(stage?.catalog_index)) &&
      Number.isSafeInteger(Number(stage?.required_level)) &&
      Number.isSafeInteger(Number(stage?.required_experience)))
    ? stages
    : null;
}

async function resolveStage(transaction, firestore, index, catalogItemId) {
  if (index >= 0 && index < 18) {
    if (catalogItemId !== null) {
      throw new HttpsError(
        "invalid-argument",
        "Built-in avatar stages cannot claim a catalog document.",
      );
    }
    const seriesOffset = Math.floor(index / 3);
    const stage = (index % 3) + 1;
    return {
      index,
      series: BUILT_IN_SERIES[seriesOffset],
      stage,
      requiredLevel: stage === 1 ? 1 : stage === 2 ? 30 : 60,
      requiredExperience: stage === 1 ? 0 : stage === 2 ? 10_000 : 30_000,
      firstStageIndex: seriesOffset * 3,
      firstStageIsFree: !PAID_BUILT_IN_STARTERS.has(seriesOffset * 3),
    };
  }
  if (!catalogItemId) {
    throw new HttpsError(
      "failed-precondition",
      "Dynamic avatar equipment requires its catalog document.",
    );
  }
  const snapshot = await transaction.get(
    firestore.collection("shop_items").doc(catalogItemId),
  );
  const item = snapshot.exists ? snapshot.data() : null;
  const stages = completeStages(item);
  if (!stages) {
    throw new HttpsError(
      "failed-precondition",
      "The avatar catalog document is not a complete evolution chain.",
    );
  }
  const stage = stages.find(value => Number(value.catalog_index) === index);
  if (!stage) {
    throw new HttpsError(
      "failed-precondition",
      "The avatar stage does not belong to the claimed catalog document.",
    );
  }
  const series = item.series?.name ?? item.series_name ?? item.name;
  if (typeof series !== "string" || !series.trim() || series.length > 128) {
    throw new HttpsError("failed-precondition", "The avatar series is invalid.");
  }
  return {
    index,
    series: series.trim(),
    stage: Number(stage.stage),
    requiredLevel: Number(stage.required_level),
    requiredExperience: Number(stage.required_experience),
    firstStageIndex: Number(stages[0].catalog_index),
    firstStageIsFree: Number(stages[0].coin_price) === 0,
  };
}

function experienceForSeries(user, series) {
  const ledger = user.avatarExperienceLedger;
  if (!ledger || typeof ledger !== "object" || Array.isArray(ledger)) return 0;
  return Object.values(ledger).reduce((sum, bySeries) => {
    if (!bySeries || typeof bySeries !== "object" || Array.isArray(bySeries)) {
      return sum;
    }
    const value = bySeries[series];
    return Number.isSafeInteger(value) && value >= 0 ? sum + value : sum;
  }, 0);
}

function levelForExperience(experience) {
  let level = 1;
  for (let candidate = 2; candidate <= 60; candidate += 1) {
    const offset = candidate - 1;
    const required = Math.round(
      AVATAR_LEVEL_CURVE_A * offset * offset + AVATAR_LEVEL_CURVE_B * offset,
    );
    if (experience < required) break;
    level = candidate;
  }
  return level;
}

function assertStageUnlocked(user, stage) {
  const unlocked = Array.isArray(user.unlockedAvatarItems)
    ? user.unlockedAvatarItems
    : [];
  const ownsStarter =
    stage.firstStageIsFree ||
    unlocked.includes(`faceShape:${stage.firstStageIndex}`);
  const experience = experienceForSeries(user, stage.series);
  if (
    !ownsStarter ||
    (stage.stage > 1 &&
      (experience < stage.requiredExperience ||
        levelForExperience(experience) < stage.requiredLevel))
  ) {
    throw new HttpsError(
      "failed-precondition",
      "The avatar stage is not owned or has not reached its evolution requirement.",
    );
  }
}

function assertBackgroundUnlocked(user, backgroundTheme) {
  const index = BACKGROUND_THEMES.indexOf(backgroundTheme);
  const unlocked = Array.isArray(user.unlockedAvatarItems)
    ? user.unlockedAvatarItems
    : [];
  if (index !== 0 && !unlocked.includes(`appBackground:${index}`)) {
    throw new HttpsError(
      "failed-precondition",
      "The background theme is not owned.",
    );
  }
}

function publicAvatar(profile) {
  return Object.fromEntries(
    PROFILE_INTEGER_FIELDS.map(field => [field, profile[field]]),
  );
}

export function createEquipRewardAvatarHandler({ firestore, clock }) {
  return async request => {
    const userId = request.auth?.uid;
    if (!userId) {
      throw new HttpsError("unauthenticated", "Authentication is required.");
    }
    const input = normalizeInput(request.data);
    const requestFingerprint = hash(JSON.stringify(input));
    const rewardEntryId = `equipment_${hash(
      `${userId}:${input.clientRequestId}`,
    ).slice(0, 40)}`;
    const entryRef = firestore.collection("reward_ledger_entries").doc(rewardEntryId);
    const userRef = firestore.collection("users").doc(userId);
    const publicRef = firestore.collection("public_profiles").doc(userId);

    return firestore.runTransaction(async transaction => {
      const [cutoverSnapshot, existing, userSnapshot, publicSnapshot] =
        await Promise.all([
          transaction.get(
            firestore.collection("system_state").doc("reward_ledger_cutover"),
          ),
          transaction.get(entryRef),
          transaction.get(userRef),
          transaction.get(publicRef),
        ]);
      if (cutoverSnapshot.exists && cutoverSnapshot.data().writesPaused === true) {
        throw new HttpsError(
          "unavailable",
          "Avatar equipment is temporarily paused for a ledger cutover.",
        );
      }
      if (existing.exists) {
        const entry = existing.data();
        if (
          entry.actorUserId !== userId ||
          entry.requestFingerprint !== requestFingerprint
        ) {
          throw new HttpsError(
            "already-exists",
            "The equipment request ID was already used for another command.",
          );
        }
        return { ...entry.result, replayed: true };
      }
      if (!userSnapshot.exists) {
        throw new HttpsError("failed-precondition", "The user profile is missing.");
      }
      const nowDate = new Date(clock());
      if (Number.isNaN(nowDate.getTime())) {
        throw new HttpsError("internal", "The reward service clock is invalid.");
      }
      const faceStage = await resolveStage(
        transaction,
        firestore,
        input.profile.faceShapeIndex,
        input.faceCatalogItemId,
      );
      const iconStage = await resolveStage(
        transaction,
        firestore,
        input.profile.avatarIconIndex,
        input.iconCatalogItemId,
      );
      const user = userSnapshot.data();
      assertStageUnlocked(user, faceStage);
      assertStageUnlocked(user, iconStage);
      assertBackgroundUnlocked(user, input.backgroundTheme);
      const result = {
        rewardEntryId,
        avatarProfile: input.profile,
        avatarSeries: faceStage.series,
        backgroundTheme: input.backgroundTheme,
        replayed: false,
      };
      transaction.create(entryRef, {
        schemaVersion: 1,
        rewardEntryId,
        entryType: "equipment",
        actorUserId: userId,
        disciplineCoinsDelta: 0,
        characterExperienceDelta: 0,
        policyVersion: "equipment-v1",
        clientRequestId: input.clientRequestId,
        requestFingerprint,
        sourceSurface: input.sourceSurface,
        status: "applied",
        result,
        createdAt: nowDate.toISOString(),
      });
      transaction.update(userRef, {
        avatarProfile: input.profile,
        avatarSeries: faceStage.series,
        backgroundTheme: input.backgroundTheme,
      });
      if (publicSnapshot.exists) {
        transaction.update(publicRef, { avatarProfile: publicAvatar(input.profile) });
      }
      return result;
    });
  };
}
