const test = require("node:test");
const assert = require("node:assert/strict");

async function migrationModule() {
  return import("../scripts/migrate_reward_ledger_baselines.js");
}

test("reward migration creates one deterministic opening baseline", async () => {
  const { buildRewardBaselineMigrationPlan } = await migrationModule();
  const input = {
    users: [{
      id: "user-1",
      data: {
        disciplineCoins: 120,
        avatarSeries: "forest",
        avatarExperience: 70,
        avatarExperienceLedger: {
          "2026-07-28": { forest: 50 },
        },
        dailyCoinEarned: { "2026-07-28": 3, invalid: 999 },
        unlockedAvatarItems: ["faceShape:18", "faceShape:18"],
        rewardedTaskKeys: ["legacy"],
        monthlyDeadlineCoinEarned: { "2026-07": 2 },
      },
    }],
    rewardEntries: [{
      id: "activity-entry",
      data: {
        actorUserId: "user-1",
        entryType: "activity",
        disciplineCoinsDelta: 3,
        characterExperienceDelta: 10,
        avatarSeries: "forest",
      },
    }, {
      id: "purchase-entry",
      data: {
        actorUserId: "user-1",
        entryType: "purchase",
        status: "applied",
        itemKey: "faceShape:18",
        disciplineCoinsDelta: 0,
        characterExperienceDelta: 0,
      },
    }],
    now: "2026-08-02T12:00:00.000Z",
  };

  const plan = buildRewardBaselineMigrationPlan(input);

  assert.equal(plan.issues.length, 0);
  assert.equal(plan.baselineCreates.length, 1);
  assert.equal(plan.baselineCreates[0].data.openingDisciplineCoins, 117);
  assert.deepEqual(plan.baselineCreates[0].data.openingExperienceBySeries, {
    forest: 60,
  });
  assert.deepEqual(
    plan.baselineCreates[0].data.openingUnlockedAvatarItems,
    [],
  );
  assert.deepEqual(plan.userUpdates[0].setFields.dailyCoinEarned, {
    "2026-07-28": 3,
  });
  assert.equal(
    plan.userUpdates[0].setFields.avatarExperienceLedger["1970-01-01"].forest,
    20,
  );
  assert.deepEqual(plan.userUpdates[0].clearFields, [
    "rewardedTaskKeys",
    "monthlyDeadlineCoinEarned",
  ]);

  const replay = buildRewardBaselineMigrationPlan({
    ...input,
    rewardEntries: [
      ...input.rewardEntries,
      {
        id: plan.baselineCreates[0].id,
        data: {
          ...plan.baselineCreates[0].data,
          entryType: "migration_baseline",
        },
      },
    ],
  });
  assert.equal(replay.baselineCreates.length, 0);

  const tampered = buildRewardBaselineMigrationPlan({
    ...input,
    rewardEntries: [
      ...input.rewardEntries,
      {
        id: plan.baselineCreates[0].id,
        data: {
          ...plan.baselineCreates[0].data,
          planFingerprint: "tampered",
        },
      },
    ],
  });
  assert.equal(tampered.issues[0].reason, "baseline_content_mismatch");
});

test("reward migration reports unsafe projections before apply", async () => {
  const { buildRewardBaselineMigrationPlan } = await migrationModule();
  const plan = buildRewardBaselineMigrationPlan({
    users: [{
      id: "user-bad",
      data: { disciplineCoins: "100", unlockedAvatarItems: [] },
    }],
  });

  assert.deepEqual(plan.issues, [
    { userId: "user-bad", reason: "invalid_coin_projection" },
  ]);
  assert.equal(plan.baselineCreates.length, 0);
  assert.equal(plan.userUpdates.length, 0);
});
