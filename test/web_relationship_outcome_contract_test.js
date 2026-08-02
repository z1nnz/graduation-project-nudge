const test = require("node:test");
const assert = require("node:assert/strict");

const contract = require(
  "../web_dashboard/assets/relationship_outcome_contract.js"
);

function groupOutcome(overrides = {}) {
  return {
    schemaVersion: 1,
    outcomeId: "group--group-1",
    scopeType: "group",
    scopeId: "group-1",
    scopeName: "晨光讀書會",
    status: "active",
    growth: {
      kind: "group_planet",
      xp: 12,
      level: 2,
      currentLevelXp: 10,
      nextLevelXp: 30,
      milestoneKeys: ["group_core", "group_orbit"],
    },
    metrics: { memberCount: 2, sharedMemberCount: 1 },
    characterOutcome: {
      kind: "group_companion",
      stage: 2,
      title: "協作軌道",
      description: "成員開始主動分享與參與共同挑戰。",
    },
    updatedAt: "2026-07-29T00:00:00.000Z",
    ...overrides,
  };
}

test("Web relationship outcome parser binds identity, growth and character", () => {
  const parsed = contract.parseOutcome("group", "group-1", groupOutcome());
  assert.equal(parsed.characterOutcome.stage, 2);
  assert.throws(
    () => contract.parseOutcome("family", "group-1", groupOutcome()),
    /格式或情境不一致/,
  );
  assert.throws(
    () => contract.parseOutcome(
      "group",
      "group-1",
      groupOutcome({
        characterOutcome: {
          kind: "group_companion",
          stage: 1,
          title: "錯誤階段",
          description: "不應顯示",
        },
      }),
    ),
    /格式或情境不一致/,
  );
});

test("Web family memories discard legacy or cross-family projections", () => {
  const valid = {
    id: "goal_completed--goal-1",
    schemaVersion: 1,
    memoryId: "goal_completed--goal-1",
    scopeType: "family",
    scopeId: "family-1",
    memoryType: "goal_completed",
    sourceId: "goal-1",
    actorId: "child-1",
    title: "一起完成了一個共同目標",
    points: 10,
    happenedAt: "2026-07-29T00:00:00.000Z",
  };
  const parsed = contract.filterFamilyMemories("family-1", [
    valid,
    { ...valid, id: "wrong-id" },
    { ...valid, scopeId: "family-2" },
  ]);
  assert.deepEqual(parsed.map(memory => memory.id), [valid.id]);
});
