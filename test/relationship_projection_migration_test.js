const test = require("node:test");
const assert = require("node:assert/strict");

async function planner() {
  return import("../scripts/migrate_relationship_memberships.js");
}

test("relationship migration backfills scoped roles and plans legacy cleanup", async () => {
  const { buildRelationshipMigrationPlan } = await planner();
  const now = "2026-07-29T00:00:00.000Z";
  const plan = buildRelationshipMigrationPlan({
    now,
    familyLinks: [
      {
        id: "family-link-12345678",
        data: {
          guardianId: "guardian",
          childId: "child",
          participantIds: ["guardian", "child"],
          status: "active",
          createdAt: "2026-07-01T00:00:00.000Z",
          updatedAt: "2026-07-02T00:00:00.000Z",
        },
      },
    ],
    groups: [
      {
        id: "GRP-ONE",
        data: {
          name: "自律同行團",
          ownerId: "guardian",
          memberIds: ["guardian", "child", "child"],
          status: "active",
          createdAt: "2026-07-03T00:00:00.000Z",
          updatedAt: "2026-07-04T00:00:00.000Z",
        },
      },
    ],
    users: [
      {
        id: "guardian",
        data: {
          userRole: "group",
          groupId: "GRP-ONE",
          groupName: "自律同行團",
          isGroupOwner: true,
          webToolsState: {
            guardianInvite: { relativeId: "child" },
            guardianInviteStatus: { status: "accepted" },
            futureLetter: { title: "保留我" },
          },
        },
      },
    ],
  });

  assert.equal(plan.issues.length, 0);
  assert.equal(plan.membershipUpserts.length, 4);
  assert.deepEqual(
    plan.membershipUpserts.map(item => [item.id, item.data.role]),
    [
      ["family--family-link-12345678--child", "child"],
      ["family--family-link-12345678--guardian", "guardian"],
      ["group--GRP-ONE--child", "member"],
      ["group--GRP-ONE--guardian", "manager"],
    ],
  );
  assert.deepEqual(plan.userProjectionCleanup, [
    {
      userId: "guardian",
      clearFields: [
        "groupId",
        "groupName",
        "isGroupOwner",
        "webToolsState.guardianInvite",
        "webToolsState.guardianInviteStatus",
      ],
      setFields: { userRole: "individual" },
    },
  ]);
});

test("relationship migration preserves original active audit timestamps", async () => {
  const { buildRelationshipMigrationPlan } = await planner();
  const plan = buildRelationshipMigrationPlan({
    now: "2026-07-29T00:00:00.000Z",
    groups: [
      {
        id: "GRP-AUDIT",
        data: {
          name: "稽核團",
          ownerId: "owner",
          memberIds: ["owner"],
          status: "active",
          createdAt: "2026-07-20T00:00:00.000Z",
        },
      },
    ],
    existingMemberships: [
      {
        id: "group--GRP-AUDIT--owner",
        data: {
          status: "active",
          createdAt: "2026-07-10T00:00:00.000Z",
          activeFrom: "2026-07-11T00:00:00.000Z",
        },
      },
    ],
  });

  const membership = plan.membershipUpserts[0];
  assert.equal(membership.data.createdAt, "2026-07-10T00:00:00.000Z");
  assert.equal(membership.data.activeFrom, "2026-07-11T00:00:00.000Z");
  assert.equal(membership.clearEndedFields, true);
});

test("relationship migration reports invalid parent data before apply", async () => {
  const { buildRelationshipMigrationPlan } = await planner();
  const plan = buildRelationshipMigrationPlan({
    groups: [
      {
        id: "GRP-BROKEN",
        data: {
          name: "缺少管理者的團體",
          ownerId: "owner",
          memberIds: ["member"],
          status: "active",
        },
      },
    ],
  });

  assert.equal(plan.membershipUpserts.length, 0);
  assert.deepEqual(plan.issues, [
    {
      scopeType: "group",
      scopeId: "GRP-BROKEN",
      reason: "invalid_group_parent",
    },
  ]);
});
