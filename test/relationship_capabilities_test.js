const test = require("node:test");
const assert = require("node:assert/strict");

const {
  resolveRelationshipCapabilities,
  resolveRoleGateRedirect,
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

test("family insight pages require a linked guardian capability", () => {
  assert.equal(
    resolveRoleGateRedirect("guardian-report.html", {
      rawRole: "child",
      familyLinked: true,
    }),
    "guardian-link.html",
  );
  assert.equal(
    resolveRoleGateRedirect("guardian.html", {
      rawRole: "guardian",
      familyLinked: false,
    }),
    "guardian-link.html",
  );
  assert.equal(
    resolveRoleGateRedirect("guardian-report.html", {
      rawRole: "guardian",
      familyLinked: true,
    }),
    null,
  );
});

test("group management pages require a manager capability", () => {
  assert.equal(
    resolveRoleGateRedirect("groups-challenge.html", {
      rawRole: "group",
      isGroupOwner: false,
      hasGroup: true,
    }),
    "groups.html",
  );
  assert.equal(
    resolveRoleGateRedirect("groups-templates.html", {
      rawRole: "personal",
    }),
    "groups-link.html",
  );
  assert.equal(
    resolveRoleGateRedirect("groups-study-schedule.html", {
      rawRole: "school",
      isGroupOwner: true,
      hasGroup: true,
    }),
    null,
  );
});
