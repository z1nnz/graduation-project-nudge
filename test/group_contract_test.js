const test = require("node:test");
const assert = require("node:assert/strict");
const contract = require("../web_dashboard/assets/group_contract.js");

const group = {
  id: "GRP-TEST",
  name: "自律同行團",
  ownerId: "manager-1",
  memberIds: ["manager-1", "member-1"],
  status: "active",
};

test("canonical group derives manager and member roles", () => {
  assert.equal(contract.isGroupManager(group, "manager-1"), true);
  assert.equal(contract.isGroupMember(group, "member-1"), true);
  assert.equal(contract.isGroupManager(group, "member-1"), false);
  assert.equal(contract.isGroupMember(group, "stranger"), false);
});

test("group challenge publication carries canonical ownership", () => {
  const payload = contract.buildGroupChallenge({
    group,
    publisherId: "manager-1",
    type: "步數挑戰",
    days: 7,
    reward: "限定徽章",
    now: "2026-07-27T00:00:00.000Z",
  });

  assert.equal(payload.groupId, "GRP-TEST");
  assert.equal(payload.groupName, "自律同行團");
  assert.equal(payload.publishedBy, "manager-1");
  assert.equal(payload.status, "active");
});

test("group publication rejects a non-manager", () => {
  assert.throws(() => contract.buildGroupTemplate({
    group,
    publisherId: "member-1",
    type: "期末考",
    days: 14,
    effort: "複習錯題",
    strategy: "每天自主安排",
    now: "2026-07-27T00:00:00.000Z",
  }));
});

test("manager can remove a member or transfer ownership", () => {
  const removal = contract.buildMemberRemoval({
    group,
    managerId: "manager-1",
    memberId: "member-1",
    now: "2026-07-27T00:00:00.000Z",
  });
  assert.deepEqual(removal.memberIds, ["manager-1"]);
  assert.equal(removal.lastMembershipChange.type, "member_removed");

  const transfer = contract.buildOwnershipTransfer({
    group,
    managerId: "manager-1",
    nextManagerId: "member-1",
    now: "2026-07-27T00:00:00.000Z",
  });
  assert.equal(transfer.ownerId, "member-1");
  assert.equal(transfer.lastMembershipChange.toMemberId, "member-1");
});

test("member result summary is explicit and validated", () => {
  const payload = contract.buildGroupResultSummary({
    group,
    memberId: "member-1",
    displayName: "小樹",
    disciplineScore: 82,
    completedTasks: 4,
    totalTasks: 5,
    focusMinutes: 60,
    steps: 8000,
    sleepHours: 7.5,
    now: "2026-07-27T00:00:00.000Z",
  });
  assert.equal(payload.status, "shared");
  assert.equal(payload.summary.completedTasks, 4);
  assert.equal(payload.summary.sleepHours, 7.5);
  assert.throws(() => contract.buildGroupResultSummary({
    group,
    memberId: "stranger",
    displayName: "陌生人",
    disciplineScore: 0,
    completedTasks: 0,
    totalTasks: 0,
    focusMinutes: 0,
    steps: 0,
    sleepHours: 0,
  }));
});
