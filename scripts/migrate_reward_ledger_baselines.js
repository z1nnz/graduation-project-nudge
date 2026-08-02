import { createHash, randomUUID } from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

import admin from "firebase-admin";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const BASELINE_VERSION = 1;
const LEGACY_REWARD_FIELDS = [
  "rewardedTaskKeys",
  "monthlyDeadlineCoinEarned",
];
const REWARD_PROJECTION_FIELDS = [
  "disciplineCoins",
  "dailyCoinEarned",
  "avatarSeries",
  "avatarExperienceLedger",
  "avatarExperience",
  "avatarLevel",
  "unlockedAvatarItems",
  "rewardedTaskKeys",
  "monthlyDeadlineCoinEarned",
  "rewardLedgerBaselineVersion",
  "rewardLedgerBaselineId",
  "rewardLedgerBaselinedAt",
];

function record(document) {
  return { id: document.id, data: document.data() };
}

function nonNegativeInteger(value) {
  return Number.isSafeInteger(value) && value >= 0 ? value : null;
}

function baselineId(userId) {
  const digest = createHash("sha256").update(userId).digest("hex");
  return `baseline_${digest.slice(0, 40)}`;
}

function fingerprint(value) {
  function canonical(input) {
    if (Array.isArray(input)) return input.map(canonical);
    if (input && typeof input === "object") {
      return Object.fromEntries(
        Object.keys(input)
          .sort()
          .filter(key => input[key] !== undefined)
          .map(key => [key, canonical(input[key])]),
      );
    }
    return input;
  }
  return createHash("sha256")
    .update(JSON.stringify(canonical(value)))
    .digest("hex");
}

function projectionFingerprint(data) {
  return fingerprint(Object.fromEntries(
    REWARD_PROJECTION_FIELDS
      .filter(field => Object.hasOwn(data, field))
      .map(field => [field, data[field]]),
  ));
}

function rewardBeforeImage(data) {
  const fields = {};
  const absentFields = [];
  for (const field of REWARD_PROJECTION_FIELDS) {
    if (Object.hasOwn(data, field)) fields[field] = data[field];
    else absentFields.push(field);
  }
  return { fields, absentFields };
}

function normalizedStringList(value) {
  if (!Array.isArray(value)) return [];
  return [...new Set(value.filter(item => typeof item === "string" && item))];
}

function normalizedDailyCoins(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  return Object.fromEntries(
    Object.entries(value)
      .filter(([dateKey, amount]) =>
        /^\d{4}-\d{2}-\d{2}$/.test(dateKey) &&
        nonNegativeInteger(amount) !== null)
      .sort(([left], [right]) => left.localeCompare(right)),
  );
}

function normalizedExperienceLedger(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  return Object.fromEntries(
    Object.entries(value)
      .filter(([, bySeries]) =>
        bySeries && typeof bySeries === "object" && !Array.isArray(bySeries))
      .map(([dateKey, bySeries]) => [
        dateKey,
        Object.fromEntries(
          Object.entries(bySeries)
            .filter(([series, amount]) =>
              series.length > 0 &&
              series.length <= 128 &&
              nonNegativeInteger(amount) !== null)
            .sort(([left], [right]) => left.localeCompare(right)),
        ),
      ])
      .sort(([left], [right]) => left.localeCompare(right)),
  );
}

function experienceBySeries(ledger) {
  const result = {};
  for (const bySeries of Object.values(ledger)) {
    for (const [series, amount] of Object.entries(bySeries)) {
      result[series] = (result[series] ?? 0) + amount;
    }
  }
  return result;
}

export function buildRewardBaselineMigrationPlan({
  users = [],
  rewardEntries = [],
  now = new Date().toISOString(),
} = {}) {
  const generatedAt = new Date(now);
  if (Number.isNaN(generatedAt.getTime())) {
    throw new Error("Reward baseline migration requires a valid timestamp.");
  }
  const normalizedNow = generatedAt.toISOString();
  const entriesByActor = new Map();
  for (const entry of rewardEntries) {
    const actorUserId = entry.data?.actorUserId;
    if (typeof actorUserId !== "string" || !actorUserId) continue;
    const values = entriesByActor.get(actorUserId) ?? [];
    values.push(entry);
    entriesByActor.set(actorUserId, values);
  }

  const baselineCreates = [];
  const userUpdates = [];
  const issues = [];
  for (const user of users) {
    const data = user.data ?? {};
    const userId = typeof user.id === "string" ? user.id.trim() : "";
    const coins = nonNegativeInteger(data.disciplineCoins ?? 0);
    const unlocks = normalizedStringList(data.unlockedAvatarItems);
    if (!userId || coins === null || unlocks.length > 500) {
      issues.push({
        userId: userId || null,
        reason: coins === null
          ? "invalid_coin_projection"
          : unlocks.length > 500
            ? "unlock_projection_exceeds_limit"
            : "invalid_user_id",
      });
      continue;
    }
    const actorEntries = entriesByActor.get(userId) ?? [];
    const expectedBaselineId = baselineId(userId);
    const existingBaseline = actorEntries.find(entry =>
      entry.data?.entryType === "migration_baseline");

    const dailyCoinEarned = normalizedDailyCoins(data.dailyCoinEarned);
    const avatarExperienceLedger = normalizedExperienceLedger(
      data.avatarExperienceLedger,
    );
    let ledgerExperience = experienceBySeries(avatarExperienceLedger);
    const avatarSeries = typeof data.avatarSeries === "string" && data.avatarSeries
      ? data.avatarSeries
      : "default";
    const projectedExperience = nonNegativeInteger(data.avatarExperience ?? 0);
    if (projectedExperience === null) {
      issues.push({ userId, reason: "invalid_experience_projection" });
      continue;
    }
    const recordedCurrentSeries = ledgerExperience[avatarSeries] ?? 0;
    if (projectedExperience < recordedCurrentSeries) {
      issues.push({ userId, reason: "experience_projection_below_ledger" });
      continue;
    }
    const legacyExperienceGap = projectedExperience - recordedCurrentSeries;
    if (legacyExperienceGap > 0) {
      avatarExperienceLedger["1970-01-01"] = {
        ...(avatarExperienceLedger["1970-01-01"] ?? {}),
        [avatarSeries]:
          (avatarExperienceLedger["1970-01-01"]?.[avatarSeries] ?? 0) +
          legacyExperienceGap,
      };
      ledgerExperience = experienceBySeries(avatarExperienceLedger);
    }
    const formalCoinDelta = actorEntries
      .filter(entry => entry.data?.entryType !== "migration_baseline")
      .reduce((sum, entry) => {
        const delta = entry.data?.disciplineCoinsDelta;
        return Number.isSafeInteger(delta) ? sum + delta : sum;
      }, 0);
    const openingCoins = coins - formalCoinDelta;
    if (openingCoins < 0) {
      issues.push({ userId, reason: "formal_coin_delta_exceeds_projection" });
      continue;
    }
    const formalExperienceBySeries = {};
    for (const entry of actorEntries) {
      if (entry.data?.entryType === "migration_baseline") continue;
      const delta = entry.data?.characterExperienceDelta;
      const series = entry.data?.avatarSeries;
      if (
        Number.isSafeInteger(delta) &&
        delta >= 0 &&
        typeof series === "string" &&
        series
      ) {
        formalExperienceBySeries[series] =
          (formalExperienceBySeries[series] ?? 0) + delta;
      }
    }
    const openingExperienceBySeries = {};
    let invalidExperienceDelta = false;
    for (const [series, total] of Object.entries(ledgerExperience)) {
      const opening = total - (formalExperienceBySeries[series] ?? 0);
      if (opening < 0) {
        invalidExperienceDelta = true;
        break;
      }
      openingExperienceBySeries[series] = opening;
    }
    if (invalidExperienceDelta) {
      issues.push({
        userId,
        reason: "formal_experience_delta_exceeds_projection",
      });
      continue;
    }

    const formallyPurchasedItems = new Set(
      actorEntries
        .filter(entry =>
          entry.data?.entryType === "purchase" &&
          entry.data?.status === "applied" &&
          typeof entry.data?.itemKey === "string")
        .map(entry => entry.data.itemKey),
    );
    const openingUnlockedAvatarItems = unlocks.filter(
      itemKey => !formallyPurchasedItems.has(itemKey),
    );
    const planFingerprint = fingerprint({
      userId,
      policyVersion: `reward-baseline-v${BASELINE_VERSION}`,
      openingDisciplineCoins: openingCoins,
      openingExperienceBySeries,
      openingUnlockedAvatarItems,
    });
    if (
      existingBaseline &&
      (existingBaseline.id !== expectedBaselineId ||
        existingBaseline.data?.actorUserId !== userId ||
        existingBaseline.data?.policyVersion !==
          `reward-baseline-v${BASELINE_VERSION}` ||
        existingBaseline.data?.planFingerprint !== planFingerprint)
    ) {
      issues.push({ userId, reason: "baseline_content_mismatch" });
      continue;
    }

    if (!existingBaseline) {
      baselineCreates.push({
        id: expectedBaselineId,
        data: {
          schemaVersion: 1,
          rewardEntryId: expectedBaselineId,
          entryType: "migration_baseline",
          actorUserId: userId,
          policyVersion: `reward-baseline-v${BASELINE_VERSION}`,
          openingDisciplineCoins: openingCoins,
          openingExperienceBySeries,
          openingUnlockedAvatarItems,
          disciplineCoinsDelta: 0,
          characterExperienceDelta: 0,
          status: "applied",
          planFingerprint,
          createdAt: normalizedNow,
        },
      });
    }
    userUpdates.push({
      userId,
      expectedProjectionFingerprint: projectionFingerprint(data),
      setFields: {
        rewardLedgerBaselineVersion: BASELINE_VERSION,
        rewardLedgerBaselineId: expectedBaselineId,
        rewardLedgerBaselinedAt: normalizedNow,
        dailyCoinEarned,
        avatarExperienceLedger,
        unlockedAvatarItems: unlocks,
      },
      clearFields: LEGACY_REWARD_FIELDS.filter(field =>
        Object.hasOwn(data, field)),
    });
  }

  baselineCreates.sort((left, right) => left.id.localeCompare(right.id));
  userUpdates.sort((left, right) => left.userId.localeCompare(right.userId));
  return {
    generatedAt: normalizedNow,
    baselineCreates,
    userUpdates,
    issues,
    counts: {
      users: users.length,
      rewardEntries: rewardEntries.length,
      baselineCreates: baselineCreates.length,
      userUpdates: userUpdates.length,
      issues: issues.length,
    },
  };
}

async function initializeAdmin() {
  if (admin.apps.length > 0) return admin.apps[0];
  const serviceAccountPath = path.join(
    __dirname,
    "..",
    "firebase-service-account.json",
  );
  if (fs.existsSync(serviceAccountPath)) {
    const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, "utf8"));
    return admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
  }
  return admin.initializeApp({
    credential: admin.credential.applicationDefault(),
  });
}

async function readPlan(db, now = new Date().toISOString()) {
  const [userSnapshot, rewardSnapshot] = await Promise.all([
    db.collection("users").get(),
    db.collection("reward_ledger_entries").get(),
  ]);
  return buildRewardBaselineMigrationPlan({
    users: userSnapshot.docs.map(record),
    rewardEntries: rewardSnapshot.docs.map(record),
    now,
  });
}

async function acquireCutoverFence(db) {
  const fenceRef = db.collection("system_state").doc("reward_ledger_cutover");
  const proposedRunRef = db.collection("migration_runs").doc();
  const proposedCutoffAt = new Date().toISOString();
  const ownerToken = randomUUID();
  return db.runTransaction(async transaction => {
    const fenceSnapshot = await transaction.get(fenceRef);
    if (fenceSnapshot.exists && fenceSnapshot.data().writesPaused === true) {
      const fence = fenceSnapshot.data();
      if (
        typeof fence.runId !== "string" ||
        !fence.runId ||
        typeof fence.cutoffAt !== "string" ||
        Number.isNaN(new Date(fence.cutoffAt).getTime())
      ) {
        throw new Error("既有 Reward cutover fence 無法安全續跑。");
      }
      if (fence.operation === "rollback") {
        throw new Error("Reward cutover 正在回滾，不能切換回 apply。");
      }
      const runRef = db.collection("migration_runs").doc(fence.runId);
      transaction.update(fenceRef, {
        ownerToken,
        operation: "apply",
        updatedAt: proposedCutoffAt,
      });
      transaction.set(runRef, {
        status: "running",
        resumedAt: proposedCutoffAt,
      }, { merge: true });
      return {
        fenceRef,
        runRef,
        cutoffAt: new Date(fence.cutoffAt).toISOString(),
        ownerToken,
      };
    }
    transaction.set(fenceRef, {
      writesPaused: true,
      runId: proposedRunRef.id,
      ownerToken,
      operation: "apply",
      cutoffAt: proposedCutoffAt,
      updatedAt: proposedCutoffAt,
    });
    transaction.create(proposedRunRef, {
      type: "reward_ledger_baseline_cutover",
      status: "running",
      startedAt: proposedCutoffAt,
    });
    return {
      fenceRef,
      runRef: proposedRunRef,
      cutoffAt: proposedCutoffAt,
      ownerToken,
    };
  });
}

function ownsCutover(fence, runId, ownerToken, operation) {
  return fence?.writesPaused === true &&
    fence.runId === runId &&
    fence.ownerToken === ownerToken &&
    fence.operation === operation;
}

async function applyUserCutover(
  db,
  fenceRef,
  runRef,
  ownerToken,
  operation,
  baselineOperation,
) {
  const userRef = db.collection("users").doc(operation.userId);
  const baselineRef = db
    .collection("reward_ledger_entries")
    .doc(operation.setFields.rewardLedgerBaselineId);
  const beforeRef = db.collection("reward_migration_before_images").doc(
    `${runRef.id}--${fingerprint(operation.userId).slice(0, 32)}`,
  );
  await db.runTransaction(async transaction => {
    const [fenceSnapshot, userSnapshot, baselineSnapshot, beforeSnapshot] =
      await Promise.all([
        transaction.get(fenceRef),
        transaction.get(userRef),
        transaction.get(baselineRef),
        transaction.get(beforeRef),
      ]);
    if (
      !fenceSnapshot.exists ||
      !ownsCutover(
        fenceSnapshot.data(),
        runRef.id,
        ownerToken,
        "apply",
      )
    ) {
      throw new Error("Reward cutover apply ownership changed.");
    }
    if (!userSnapshot.exists) {
      throw new Error(`Reward cutover user missing: ${operation.userId}`);
    }
    const current = userSnapshot.data();
    if (
      !beforeSnapshot.exists &&
      projectionFingerprint(current) !== operation.expectedProjectionFingerprint
    ) {
      throw new Error(`Reward projection changed after fence: ${operation.userId}`);
    }
    if (baselineOperation) {
      if (baselineSnapshot.exists) {
        if (
          baselineSnapshot.data().planFingerprint !==
          baselineOperation.data.planFingerprint
        ) {
          throw new Error(`Reward baseline mismatch: ${operation.userId}`);
        }
      } else {
        transaction.create(baselineRef, baselineOperation.data);
      }
    } else if (!baselineSnapshot.exists) {
      throw new Error(`Reward baseline disappeared: ${operation.userId}`);
    }
    if (!beforeSnapshot.exists) {
      transaction.create(beforeRef, {
        userId: operation.userId,
        actorUserId: operation.userId,
        migrationRunId: runRef.id,
        ...rewardBeforeImage(current),
        baselineId: baselineRef.id,
        baselineCreatedByRun: Boolean(baselineOperation && !baselineSnapshot.exists),
        capturedAt: new Date().toISOString(),
      });
    }
    const update = { ...operation.setFields };
    for (const field of operation.clearFields) {
      update[field] = admin.firestore.FieldValue.delete();
    }
    transaction.update(userRef, update);
    transaction.update(fenceRef, { updatedAt: new Date().toISOString() });
  });
}

async function updateOwnedRun(
  db,
  fenceRef,
  runRef,
  ownerToken,
  operation,
  values,
) {
  await db.runTransaction(async transaction => {
    const fenceSnapshot = await transaction.get(fenceRef);
    if (
      !fenceSnapshot.exists ||
      !ownsCutover(
        fenceSnapshot.data(),
        runRef.id,
        ownerToken,
        operation,
      )
    ) {
      throw new Error(`Reward cutover ${operation} ownership changed.`);
    }
    transaction.set(runRef, values, { merge: true });
  });
}

async function recordOwnedFailure(
  db,
  fenceRef,
  runRef,
  ownerToken,
  operation,
  error,
) {
  await db.runTransaction(async transaction => {
    const fenceSnapshot = await transaction.get(fenceRef);
    if (
      !fenceSnapshot.exists ||
      !ownsCutover(
        fenceSnapshot.data(),
        runRef.id,
        ownerToken,
        operation,
      )
    ) {
      return;
    }
    transaction.set(runRef, {
      status: operation === "rollback" ? "rollback_failed" : "failed",
      error: String(error?.message || error).slice(0, 500),
      failedAt: new Date().toISOString(),
    }, { merge: true });
  });
}

export async function runRewardBaselineMigration({ apply }) {
  await initializeAdmin();
  const db = admin.firestore();
  if (!apply) {
    const plan = await readPlan(db);
    console.log("DRY RUN reward baseline migration");
    console.log(JSON.stringify(plan.counts, null, 2));
    if (plan.issues.length > 0) {
      console.log("Issues:");
      console.log(JSON.stringify(plan.issues, null, 2));
    }
    console.log(
      "未寫入資料。確認 issues 為 0 後執行：npm run migrate:rewards:apply",
    );
    return plan;
  }
  const { fenceRef, runRef, cutoffAt, ownerToken } =
    await acquireCutoverFence(db);
  try {
    const plan = await readPlan(db, cutoffAt);
    console.log("APPLY reward baseline migration");
    console.log(JSON.stringify(plan.counts, null, 2));
    if (plan.issues.length > 0) {
      console.log("Issues:");
      console.log(JSON.stringify(plan.issues, null, 2));
      throw new Error("存在無效獎勵投影；Reward fence 保持關閉等待修正。");
    }
    await updateOwnedRun(
      db,
      fenceRef,
      runRef,
      ownerToken,
      "apply",
      { status: "running", counts: plan.counts },
    );
    const baselineByUser = new Map(
      plan.baselineCreates.map(operation => [operation.data.actorUserId, operation]),
    );
    let projectionWrites = 0;
    for (const operation of plan.userUpdates) {
      await applyUserCutover(
        db,
        fenceRef,
        runRef,
        ownerToken,
        operation,
        baselineByUser.get(operation.userId) ?? null,
      );
      projectionWrites += 1;
    }
    const baselineWrites = plan.baselineCreates.length;
    await db.runTransaction(async transaction => {
      const fenceSnapshot = await transaction.get(fenceRef);
      if (
        !fenceSnapshot.exists ||
        !ownsCutover(
          fenceSnapshot.data(),
          runRef.id,
          ownerToken,
          "apply",
        )
      ) {
        throw new Error("Reward cutover fence ownership changed.");
      }
      transaction.update(fenceRef, {
        writesPaused: false,
        ownerToken: null,
        operation: null,
        completedAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      });
      transaction.set(runRef, {
        status: "completed",
        baselineWrites,
        projectionWrites,
        completedAt: new Date().toISOString(),
      }, { merge: true });
    });
    console.log(`完成：${baselineWrites} 筆基線、${projectionWrites} 筆投影切換。`);
    return plan;
  } catch (error) {
    await recordOwnedFailure(
      db,
      fenceRef,
      runRef,
      ownerToken,
      "apply",
      error,
    );
    throw error;
  }
}

export async function rollbackActiveRewardCutover() {
  await initializeAdmin();
  const db = admin.firestore();
  const fenceRef = db.collection("system_state").doc("reward_ledger_cutover");
  const ownerToken = randomUUID();
  const { runRef, runId } = await db.runTransaction(async transaction => {
    const fenceSnapshot = await transaction.get(fenceRef);
    const fence = fenceSnapshot.exists ? fenceSnapshot.data() : null;
    if (
      fence?.writesPaused !== true ||
      typeof fence.runId !== "string" ||
      !fence.runId
    ) {
      throw new Error("目前沒有可回滾的 active Reward cutover fence。");
    }
    const activeRunRef = db.collection("migration_runs").doc(fence.runId);
    const claimedAt = new Date().toISOString();
    transaction.update(fenceRef, {
      ownerToken,
      operation: "rollback",
      updatedAt: claimedAt,
    });
    transaction.set(activeRunRef, {
      status: "rolling_back",
      rollbackStartedAt: claimedAt,
    }, { merge: true });
    return { runRef: activeRunRef, runId: fence.runId };
  });
  const beforeSnapshot = await db
    .collection("reward_migration_before_images")
    .where("migrationRunId", "==", runId)
    .get();
  let restored = 0;
  try {
    for (const beforeDocument of beforeSnapshot.docs) {
      await db.runTransaction(async transaction => {
        const beforeRef = beforeDocument.ref;
        const [latestFence, latestBefore] = await Promise.all([
          transaction.get(fenceRef),
          transaction.get(beforeRef),
        ]);
        if (
          !latestFence.exists ||
          !ownsCutover(
            latestFence.data(),
            runId,
            ownerToken,
            "rollback",
          )
        ) {
          throw new Error(
            "Reward cutover rollback ownership changed.",
          );
        }
        if (!latestBefore.exists) return;
        const before = latestBefore.data();
        const userRef = db.collection("users").doc(before.actorUserId);
        const userSnapshot = await transaction.get(userRef);
        if (!userSnapshot.exists) {
          throw new Error(`Rollback user missing: ${before.actorUserId}`);
        }
        const restore = { ...(before.fields ?? {}) };
        for (const field of before.absentFields ?? []) {
          restore[field] = admin.firestore.FieldValue.delete();
        }
        transaction.update(userRef, restore);
        if (before.baselineCreatedByRun === true) {
          transaction.delete(
            db.collection("reward_ledger_entries").doc(before.baselineId),
          );
        }
        transaction.delete(beforeRef);
        transaction.update(fenceRef, { updatedAt: new Date().toISOString() });
      });
      restored += 1;
    }
    await db.runTransaction(async transaction => {
      const latestFence = await transaction.get(fenceRef);
      if (
        !latestFence.exists ||
        !ownsCutover(
          latestFence.data(),
          runId,
          ownerToken,
          "rollback",
        )
      ) {
        throw new Error("Reward cutover fence ownership changed during rollback.");
      }
      const completedAt = new Date().toISOString();
      transaction.update(fenceRef, {
        writesPaused: false,
        ownerToken: null,
        operation: null,
        rolledBackAt: completedAt,
        updatedAt: completedAt,
      });
      transaction.set(runRef, {
        status: "rolled_back",
        restoredUsers: restored,
        rolledBackAt: completedAt,
      }, { merge: true });
    });
    console.log(`Reward cutover 已回滾 ${restored} 位使用者並解除 fence。`);
  } catch (error) {
    await recordOwnedFailure(
      db,
      fenceRef,
      runRef,
      ownerToken,
      "rollback",
      error,
    );
    throw error;
  }
}

const isDirectRun =
  process.argv[1] &&
  import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href;

if (isDirectRun) {
  const action = process.argv.includes("--rollback")
    ? rollbackActiveRewardCutover()
    : runRewardBaselineMigration({
        apply: process.argv.includes("--apply"),
      });
  action.catch(error => {
    console.error(error.message);
    process.exitCode = 1;
  });
}
