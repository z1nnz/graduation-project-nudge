import assert from "node:assert/strict";
import test from "node:test";

import {
  buildFamilyRelationshipMemories,
  buildFamilyRelationshipOutcome,
  buildGroupRelationshipOutcome,
  createRefreshRelationshipOutcomeHandler,
} from "../src/relationship-outcome-service.js";

test("family outcome grows only from validated bond events", () => {
  const outcome = buildFamilyRelationshipOutcome({
    scopeId: "family-one",
    scopeName: "家庭連結 mily-one",
    participantIds: ["child", "guardian"],
    bondEvents: [
      { type: "acknowledgement", points: 3 },
      { type: "goalCompleted", points: 10 },
    ],
    goals: [{ status: "completed" }, { status: "accepted" }],
    encouragements: [
      { status: "acknowledged" },
      { status: "sent" },
    ],
    refreshedBy: "child",
    now: "2026-07-29T00:00:00.000Z",
  });

  assert.equal(outcome.growth.kind, "family_tree");
  assert.equal(outcome.growth.xp, 13);
  assert.equal(outcome.growth.level, 2);
  assert.equal(outcome.growth.currentLevelXp, 10);
  assert.deepEqual(outcome.growth.milestoneKeys, [
    "family_seed",
    "family_sprout",
  ]);
  assert.deepEqual(outcome.metrics, {
    acknowledgements: 1,
    completedGoals: 1,
    memoryCount: 2,
  });
  assert.equal(outcome.characterOutcome.kind, "family_companion");
});

test("family memories are deterministic projections of bond events", () => {
  const memories = buildFamilyRelationshipMemories({
    scopeId: "family-one",
    participantIds: ["guardian", "child"],
    bondEvents: [
      {
        id: "goal_goal-one",
        type: "goalCompleted",
        sourceId: "goal-one",
        actorId: "child",
        points: 10,
        createdAt: "2026-07-28T00:00:00.000Z",
      },
    ],
    now: "2026-07-29T00:00:00.000Z",
  });

  assert.equal(memories[0].id, "goal_completed--goal_goal-one");
  assert.equal(memories[0].data.memoryType, "goal_completed");
  assert.equal(memories[0].data.points, 10);
  assert.deepEqual(memories[0].data.participantIds, ["child", "guardian"]);
});

test("group outcome is relationship growth and never a personal reward", () => {
  const outcome = buildGroupRelationshipOutcome({
    scopeId: "GRP-ONE",
    scopeName: "自律同行團",
    participantIds: ["manager", "member"],
    sharedSummaries: [
      { memberId: "manager", status: "shared" },
      { memberId: "member", status: "shared" },
      { memberId: "removed-member", status: "shared" },
    ],
    currentChallengeId: "challenge-one",
    challengeParticipations: [
      {
        challengeId: "challenge-one",
        memberId: "manager",
        status: "joined",
      },
      {
        challengeId: "challenge-one",
        memberId: "member",
        status: "completed",
      },
      {
        challengeId: "challenge-one",
        memberId: "removed-member",
        status: "completed",
      },
      {
        challengeId: "previous-challenge",
        memberId: "member",
        status: "completed",
      },
    ],
    refreshedBy: "member",
    now: "2026-07-29T00:00:00.000Z",
  });

  assert.equal(outcome.growth.kind, "group_planet");
  assert.equal(outcome.growth.xp, 18);
  assert.equal(outcome.growth.level, 2);
  assert.equal(outcome.growth.currentLevelXp, 10);
  assert.deepEqual(outcome.metrics, {
    memberCount: 2,
    sharedMemberCount: 2,
    joinedChallengeCount: 2,
    completedChallengeCount: 1,
  });
  assert.equal(outcome.characterOutcome.kind, "group_companion");
  assert.equal("reward" in outcome, false);
  assert.equal("personalXp" in outcome, false);
});

test("refresh handler rejects unauthenticated callers before data access", async () => {
  const handler = createRefreshRelationshipOutcomeHandler({
    firestore: null,
  });
  await assert.rejects(
    () => handler({ auth: null, data: { scopeType: "family", scopeId: "x" } }),
    error => error.code === "unauthenticated",
  );
});
