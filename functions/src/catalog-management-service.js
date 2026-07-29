import { createHash } from "node:crypto";

import { HttpsError } from "firebase-functions/v2/https";

const STAFF_ROLES = new Set(["developer", "operator", "admin"]);
const CATALOG_ACTIONS = new Set(["publish", "update", "archive"]);
const CATALOG_TYPES = new Set([
  "permanent",
  "limited",
  "event_character",
  "avatar_series",
]);
const CATALOG_SCHEMA_VERSION = 1;
const FIRST_DYNAMIC_CATALOG_INDEX = 18;

function normalizedString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function requiredText(value, label, maxLength) {
  const result = normalizedString(value);
  if (!result || result.length > maxLength) {
    throw new HttpsError(
      "invalid-argument",
      `${label} is required and must be at most ${maxLength} characters.`,
    );
  }
  return result;
}

function optionalText(value, maxLength) {
  const result = normalizedString(value);
  if (result.length > maxLength) {
    throw new HttpsError(
      "invalid-argument",
      `Text values must be at most ${maxLength} characters.`,
    );
  }
  return result;
}

function nonNegativeInteger(value, label, maximum = 1_000_000_000) {
  const result = Number(value);
  if (!Number.isInteger(result) || result < 0 || result > maximum) {
    throw new HttpsError(
      "invalid-argument",
      `${label} must be a non-negative integer.`,
    );
  }
  return result;
}

function optionalEpochSeconds(value, label) {
  if (value === null || value === undefined || value === "") return null;
  return nonNegativeInteger(value, label, 9_999_999_999);
}

function catalogAsset(value, label) {
  const result = requiredText(value, label, 2_048);
  const isSecureRemoteAsset = /^https:\/\/[^\s]+$/i.test(result);
  const isLocalEmulatorAsset =
    /^http:\/\/(?:127\.0\.0\.1|localhost)(?::\d+)?\/[^\s]+$/i.test(result);
  if (!isSecureRemoteAsset && !isLocalEmulatorAsset) {
    throw new HttpsError(
      "invalid-argument",
      `${label} must use HTTPS (or a local emulator URL).`,
    );
  }
  return result;
}

function normalizeSchedule(type, payload) {
  let startTime = optionalEpochSeconds(
    payload.start_time ?? payload.start_at,
    "start_time",
  );
  let endTime = optionalEpochSeconds(
    payload.end_time ?? payload.end_at ?? payload.expires_at,
    "end_time",
  );
  if (type === "permanent") {
    startTime = null;
    endTime = null;
  } else if (
    (startTime === null) !== (endTime === null) ||
    (startTime !== null && endTime <= startTime)
  ) {
    throw new HttpsError(
      "invalid-argument",
      "Scheduled catalog items require a valid start and end time.",
    );
  }
  return {
    start_time: startTime,
    end_time: endTime,
    expires_at: endTime,
  };
}

function normalizeAvatarStages(payload, price) {
  const stages = payload.character_stages;
  if (!Array.isArray(stages) || stages.length !== 3) {
    throw new HttpsError(
      "invalid-argument",
      "An avatar series must contain exactly three evolution stages.",
    );
  }

  let previousLevel = -1;
  let previousExperience = -1;
  return stages.map((stage, index) => {
    if (stage === null || typeof stage !== "object" || Array.isArray(stage)) {
      throw new HttpsError(
        "invalid-argument",
        `Avatar stage ${index + 1} is invalid.`,
      );
    }
    const stageNumber = index + 1;
    if (Number(stage.stage) !== stageNumber) {
      throw new HttpsError(
        "invalid-argument",
        "Avatar stages must be ordered from stage 1 through stage 3.",
      );
    }
    const requiredLevel = nonNegativeInteger(
      stage.required_level,
      `stage ${stageNumber} required_level`,
    );
    const requiredExperience = nonNegativeInteger(
      stage.required_experience,
      `stage ${stageNumber} required_experience`,
    );
    if (
      (stageNumber === 1 &&
        (requiredLevel !== 1 || requiredExperience !== 0)) ||
      (stageNumber > 1 &&
        (requiredLevel <= previousLevel ||
          requiredExperience <= previousExperience))
    ) {
      throw new HttpsError(
        "invalid-argument",
        "Avatar evolution requirements must start at level 1 / 0 XP and strictly increase.",
      );
    }
    previousLevel = requiredLevel;
    previousExperience = requiredExperience;
    return {
      stage: stageNumber,
      catalog_index: 0,
      name: requiredText(stage.name, `stage ${stageNumber} name`, 120),
      description: requiredText(
        stage.description,
        `stage ${stageNumber} description`,
        1_000,
      ),
      character_asset: catalogAsset(
        stage.character_asset,
        `stage ${stageNumber} character_asset`,
      ),
      icon_asset: catalogAsset(
        stage.icon_asset,
        `stage ${stageNumber} icon_asset`,
      ),
      required_level: requiredLevel,
      required_experience: requiredExperience,
      shop_eligible: stageNumber === 1,
      coin_price: stageNumber === 1 ? price : 0,
      evolves_from_stage: stageNumber === 1 ? null : stageNumber - 1,
    };
  });
}

export function normalizeCatalogPayload(payload) {
  if (payload === null || typeof payload !== "object" || Array.isArray(payload)) {
    throw new HttpsError("invalid-argument", "A catalog payload is required.");
  }
  const type = normalizedString(payload.type);
  if (!CATALOG_TYPES.has(type)) {
    throw new HttpsError("invalid-argument", "Catalog item type is invalid.");
  }
  const name = requiredText(payload.name, "Catalog item name", 120);
  const description = requiredText(
    payload.description ?? payload.codex_description,
    "Catalog item description",
    2_000,
  );
  const price = nonNegativeInteger(payload.price, "price");
  const schedule = normalizeSchedule(type, payload);

  const result = {
    schema_version: CATALOG_SCHEMA_VERSION,
    type,
    status: "published",
    name,
    description,
    price,
    ...schedule,
  };

  if (type !== "avatar_series") {
    return {
      ...result,
      image_path: catalogAsset(payload.image_path, "image_path"),
    };
  }

  const seriesKey = requiredText(payload.series_key, "series_key", 80)
    .toLowerCase();
  if (!/^[a-z0-9][a-z0-9_-]*$/.test(seriesKey)) {
    throw new HttpsError(
      "invalid-argument",
      "series_key may only contain letters, numbers, underscores, and hyphens.",
    );
  }
  const seriesName = requiredText(
    payload.series_name ?? name,
    "series_name",
    120,
  );
  const theme = optionalText(
    payload.series_theme ?? payload.theme,
    120,
  );
  const codexDescription = requiredText(
    payload.codex_description ?? description,
    "codex_description",
    2_000,
  );
  const stages = normalizeAvatarStages(payload, price);
  return {
    ...result,
    series_key: seriesKey,
    series_name: seriesName,
    series_theme: theme,
    theme,
    codex_description: codexDescription,
    series: {
      key: seriesKey,
      name: seriesName,
      theme,
      codex_description: codexDescription,
    },
    catalog_index_base: 0,
    image_path: stages[0].character_asset,
    icon_path: stages[0].icon_asset,
    character_stages: stages,
  };
}

export function normalizeCatalogCommand(data) {
  const action = normalizedString(data?.action);
  const itemId = normalizedString(data?.itemId);
  const clientRequestId = normalizedString(data?.clientRequestId);
  const sourceSurface = normalizedString(data?.sourceSurface);
  if (!CATALOG_ACTIONS.has(action)) {
    throw new HttpsError("invalid-argument", "Catalog action is invalid.");
  }
  if (!/^[A-Za-z0-9_-]{8,128}$/.test(itemId)) {
    throw new HttpsError("invalid-argument", "A valid catalog itemId is required.");
  }
  if (!/^[A-Za-z0-9_-]{8,128}$/.test(clientRequestId)) {
    throw new HttpsError(
      "invalid-argument",
      "A stable catalog clientRequestId is required.",
    );
  }
  if (sourceSurface !== "admin_web") {
    throw new HttpsError(
      "invalid-argument",
      "Catalog commands must originate from the admin Web surface.",
    );
  }
  return {
    action,
    itemId,
    clientRequestId,
    sourceSurface,
    payload: action === "archive" ? null : normalizeCatalogPayload(data.payload),
  };
}

function fingerprintCatalogCommand(input) {
  return createHash("sha256")
    .update(JSON.stringify(input))
    .digest("hex");
}

function isStaffProfile(profile) {
  return profile?.developerAccess === true ||
    STAFF_ROLES.has(normalizedString(profile?.staffRole));
}

function maximumCatalogIndex(snapshot) {
  let maximum = FIRST_DYNAMIC_CATALOG_INDEX - 1;
  snapshot?.forEach?.(document => {
    const item = document.data();
    const base = Number(item.catalog_index_base);
    if (Number.isInteger(base)) maximum = Math.max(maximum, base);
    if (Array.isArray(item.character_stages)) {
      for (const stage of item.character_stages) {
        const index = Number(stage?.catalog_index);
        if (Number.isInteger(index)) maximum = Math.max(maximum, index);
      }
    }
  });
  return maximum;
}

function hasConflictingSeriesKey(snapshot, itemId, seriesKey) {
  return snapshot?.docs?.some(document => {
    if (document.id === itemId) return false;
    const item = document.data();
    const nestedSeries =
      item.series && typeof item.series === "object" && !Array.isArray(item.series)
        ? item.series
        : {};
    return normalizedString(item.series_key || nestedSeries.key).toLowerCase() ===
      seriesKey;
  }) ?? false;
}

function withCatalogIndexes(payload, base) {
  return {
    ...payload,
    catalog_index_base: base,
    character_stages: payload.character_stages.map((stage, index) => ({
      ...stage,
      catalog_index: base + index,
    })),
  };
}

function catalogAuditEvent({
  auditEventId,
  userId,
  staffRole,
  input,
  fingerprint,
  result,
  now,
}) {
  return {
    schemaVersion: 1,
    auditEventId,
    category: "catalog",
    action: `catalog.item.${input.action}`,
    actorUserId: userId,
    actorRole: staffRole,
    targetType: "shop_item",
    targetId: input.itemId,
    sourceSurface: input.sourceSurface,
    clientRequestId: input.clientRequestId,
    requestFingerprint: fingerprint,
    result,
    createdAt: now,
  };
}

export function createManageCatalogItemHandler({ firestore, clock }) {
  return async request => {
    const userId = request.auth?.uid;
    if (!userId) {
      throw new HttpsError(
        "unauthenticated",
        "Authentication is required to manage the catalog.",
      );
    }
    const input = normalizeCatalogCommand(request.data);
    const fingerprint = fingerprintCatalogCommand(input);
    const itemRef = firestore.collection("shop_items").doc(input.itemId);
    const userRef = firestore.collection("users").doc(userId);
    const counterRef = firestore
      .collection("catalog_counters")
      .doc("avatar_series");
    const avatarSeriesQuery = firestore
      .collection("shop_items")
      .where("type", "==", "avatar_series");
    const auditRef = firestore
      .collection("audit_events")
      .doc(`catalog-command--${userId}--${input.clientRequestId}`);
    const nowDate = clock();
    const now = nowDate.toISOString();
    const nowEpochSeconds = Math.floor(nowDate.getTime() / 1_000);

    return firestore.runTransaction(async transaction => {
      const staffSnapshot = await transaction.get(userRef);
      if (!staffSnapshot.exists || !isStaffProfile(staffSnapshot.data())) {
        throw new HttpsError(
          "permission-denied",
          "This account does not have catalog management permission.",
        );
      }
      const staffRole =
        normalizedString(staffSnapshot.data().staffRole) ||
        (staffSnapshot.data().developerAccess === true ? "developer" : "staff");

      const existingAudit = await transaction.get(auditRef);
      if (existingAudit.exists) {
        const audit = existingAudit.data();
        if (
          audit.actorUserId !== userId ||
          audit.requestFingerprint !== fingerprint
        ) {
          throw new HttpsError(
            "already-exists",
            "The catalog clientRequestId was already used for another command.",
          );
        }
        return {
          replayed: true,
          itemId: input.itemId,
          item: audit.result.item,
          auditEventId: auditRef.id,
        };
      }

      const itemSnapshot = await transaction.get(itemRef);
      const existingItem = itemSnapshot.exists ? itemSnapshot.data() : null;
      if (input.action === "publish" && itemSnapshot.exists) {
        throw new HttpsError("already-exists", "The catalog item already exists.");
      }
      if (input.action !== "publish" && !itemSnapshot.exists) {
        throw new HttpsError("not-found", "The catalog item was not found.");
      }

      let item;
      if (input.action === "archive") {
        item = {
          ...existingItem,
          status: "archived",
          updated_at: nowEpochSeconds,
        };
        transaction.update(itemRef, {
          status: item.status,
          updated_at: item.updated_at,
        });
      } else {
        if (
          input.action === "update" &&
          existingItem.type !== input.payload.type
        ) {
          throw new HttpsError(
            "failed-precondition",
            "A catalog item type cannot be changed after publication.",
          );
        }
        let payload = input.payload;
        if (payload.type === "avatar_series") {
          const avatarSeriesSnapshot = await transaction.get(avatarSeriesQuery);
          if (
            hasConflictingSeriesKey(
              avatarSeriesSnapshot,
              input.itemId,
              payload.series_key,
            )
          ) {
            throw new HttpsError(
              "already-exists",
              "The avatar series_key is already in use.",
            );
          }
          let base;
          if (input.action === "update") {
            base = Number(existingItem.catalog_index_base);
            if (!Number.isInteger(base) || base < FIRST_DYNAMIC_CATALOG_INDEX) {
              throw new HttpsError(
                "failed-precondition",
                "The existing avatar series has an invalid catalog index.",
              );
            }
          } else {
            const counterSnapshot = await transaction.get(counterRef);
            const storedNextIndex = Number(
              counterSnapshot.exists
                ? counterSnapshot.data().next_index
                : FIRST_DYNAMIC_CATALOG_INDEX,
            );
            const discoveredNextIndex =
              maximumCatalogIndex(avatarSeriesSnapshot) + 1;
            base = Math.max(
              FIRST_DYNAMIC_CATALOG_INDEX,
              Number.isInteger(storedNextIndex)
                ? storedNextIndex
                : FIRST_DYNAMIC_CATALOG_INDEX,
              discoveredNextIndex,
            );
            transaction.set(
              counterRef,
              {
                next_index: base + 3,
                updated_at: nowEpochSeconds,
              },
              { merge: true },
            );
          }
          payload = withCatalogIndexes(payload, base);
        }
        item = {
          ...payload,
          id: input.itemId,
          created_at:
            input.action === "update"
              ? existingItem.created_at ?? nowEpochSeconds
              : nowEpochSeconds,
          updated_at: nowEpochSeconds,
        };
        transaction.set(itemRef, item);
      }

      const result = {
        status: item.status,
        type: item.type,
        item,
      };
      transaction.create(
        auditRef,
        catalogAuditEvent({
          auditEventId: auditRef.id,
          userId,
          staffRole,
          input,
          fingerprint,
          result,
          now,
        }),
      );
      return {
        replayed: false,
        itemId: input.itemId,
        item,
        auditEventId: auditRef.id,
      };
    });
  };
}
