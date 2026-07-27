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
