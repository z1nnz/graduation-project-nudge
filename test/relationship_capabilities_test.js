const test = require("node:test");
const assert = require("node:assert/strict");

const {
  resolveRelationshipCapabilities,
} = require("../web_dashboard/assets/relationship_capabilities.js");

test("guardian and child receive different family capabilities", () => {
  const guardian = resolveRelationshipCapabilities({
    rawRole: "guardian",
    familyLinked: true,
  });
  const child = resolveRelationshipCapabilities({
    rawRole: "child",
    familyLinked: true,
  });

  assert.equal(guardian.role, "guardian");
  assert.equal(guardian.canViewGuardianHub, true);
  assert.equal(guardian.canManageOwnFamilyLink, false);
  assert.equal(child.role, "child");
  assert.equal(child.canViewGuardianHub, false);
  assert.equal(child.canManageOwnFamilyLink, true);
});

test("group manager and member receive different management capabilities", () => {
  const manager = resolveRelationshipCapabilities({
    rawRole: "school",
    isGroupOwner: true,
    hasGroup: true,
  });
  const member = resolveRelationshipCapabilities({
    rawRole: "group",
    isGroupOwner: false,
    hasGroup: true,
  });

  assert.equal(manager.role, "groupManager");
  assert.equal(manager.canManageGroup, true);
  assert.equal(manager.groupSurfaceTitle, "團體管理控制台");
  assert.equal(member.role, "groupMember");
  assert.equal(member.canManageGroup, false);
  assert.equal(member.canParticipateInGroup, true);
  assert.equal(member.groupSurfaceTitle, "團體任務與共同進度");
});

test("preview mode is explicit and does not imply a real signed-in session", () => {
  const preview = resolveRelationshipCapabilities({
    rawRole: "guardian",
    familyLinked: true,
    isPreview: true,
  });

  assert.equal(preview.isPreview, true);
  assert.equal(preview.isAuthenticated, false);
  assert.equal(preview.canViewGuardianHub, true);
});
