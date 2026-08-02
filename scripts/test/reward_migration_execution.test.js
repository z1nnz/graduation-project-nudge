import assert from "node:assert/strict";
import test from "node:test";

import admin from "firebase-admin";

import {
  rollbackActiveRewardCutover,
  runRewardBaselineMigration,
} from "../migrate_reward_ledger_baselines.js";

const emulatorAvailable = Boolean(process.env.FIRESTORE_EMULATOR_HOST);

test("reward baseline apply and rollback keep an owned cutover fence", {
  skip: !emulatorAvailable,
}, async t => {
  const app = admin.initializeApp({ projectId: "nudge-reward-migration-test" });
  t.after(async () => app.delete());
  const db = admin.firestore();

  await db.collection("users").doc("apply-user").set({
    disciplineCoins: 120,
    avatarSeries: "forest",
    avatarExperience: 70,
    avatarExperienceLedger: {
      "2026-07-28": { forest: 50 },
    },
    dailyCoinEarned: { "2026-07-28": 3 },
    unlockedAvatarItems: ["faceShape:18"],
    rewardedTaskKeys: ["legacy"],
  });
  await db.collection("reward_ledger_entries").doc("activity-before").set({
    actorUserId: "apply-user",
    entryType: "activity",
    disciplineCoinsDelta: 3,
    characterExperienceDelta: 10,
    avatarSeries: "forest",
  });

  await runRewardBaselineMigration({ apply: true });

  const appliedFence = (
    await db.collection("system_state").doc("reward_ledger_cutover").get()
  ).data();
  assert.equal(appliedFence.writesPaused, false);
  assert.equal(appliedFence.ownerToken, null);
  assert.equal(appliedFence.operation, null);
  const appliedUser = (await db.collection("users").doc("apply-user").get())
    .data();
  assert.equal(appliedUser.rewardLedgerBaselineVersion, 1);
  assert.equal(Object.hasOwn(appliedUser, "rewardedTaskKeys"), false);
  assert.equal(
    appliedUser.avatarExperienceLedger["1970-01-01"].forest,
    20,
  );
  const baselines = await db.collection("reward_ledger_entries")
    .where("actorUserId", "==", "apply-user")
    .where("entryType", "==", "migration_baseline")
    .get();
  assert.equal(baselines.size, 1);
  assert.equal(baselines.docs[0].data().openingDisciplineCoins, 117);

  const rollbackRunId = "rollback-run";
  await db.collection("users").doc("rollback-user").set({
    disciplineCoins: 5,
    rewardLedgerBaselineVersion: 1,
  });
  await db.collection("reward_ledger_entries").doc("rollback-baseline").set({
    actorUserId: "rollback-user",
    entryType: "migration_baseline",
  });
  await db.collection("reward_migration_before_images")
    .doc("rollback-before")
    .set({
      actorUserId: "rollback-user",
      migrationRunId: rollbackRunId,
      fields: { disciplineCoins: 99 },
      absentFields: ["rewardLedgerBaselineVersion"],
      baselineId: "rollback-baseline",
      baselineCreatedByRun: true,
    });
  await db.collection("migration_runs").doc(rollbackRunId).set({
    status: "failed",
  });
  await db.collection("system_state").doc("reward_ledger_cutover").set({
    writesPaused: true,
    runId: rollbackRunId,
    ownerToken: "stale-owner",
    operation: "apply",
    cutoffAt: "2026-08-02T00:00:00.000Z",
  });

  await rollbackActiveRewardCutover();

  const restoredUser = (
    await db.collection("users").doc("rollback-user").get()
  ).data();
  assert.equal(restoredUser.disciplineCoins, 99);
  assert.equal(Object.hasOwn(restoredUser, "rewardLedgerBaselineVersion"), false);
  assert.equal(
    (await db.collection("reward_ledger_entries")
      .doc("rollback-baseline").get()).exists,
    false,
  );
  assert.equal(
    (await db.collection("reward_migration_before_images")
      .doc("rollback-before").get()).exists,
    false,
  );
  const rolledBackFence = (
    await db.collection("system_state").doc("reward_ledger_cutover").get()
  ).data();
  assert.equal(rolledBackFence.writesPaused, false);
  assert.equal(rolledBackFence.ownerToken, null);
  assert.equal(rolledBackFence.operation, null);
});
