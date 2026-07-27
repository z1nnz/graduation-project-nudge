const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

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
  assert.equal(member.showsPersonalTools, true);
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

test("canonical family identity overrides a stale profile role", () => {
  const guardian = resolveRelationshipCapabilities({
    rawRole: "personal",
    familyLinked: true,
    isFamilyGuardian: true,
    isFamilyChild: false,
  });
  const child = resolveRelationshipCapabilities({
    rawRole: "guardian",
    familyLinked: true,
    isFamilyGuardian: false,
    isFamilyChild: true,
  });

  assert.equal(guardian.role, "guardian");
  assert.equal(guardian.canViewGuardianHub, true);
  assert.equal(child.role, "child");
  assert.equal(child.canManageOwnFamilyLink, true);
  assert.equal(child.canViewGuardianHub, false);
});

test("family and canonical group capabilities can coexist", () => {
  const childMember = resolveRelationshipCapabilities({
    rawRole: "child",
    familyLinked: true,
    isFamilyChild: true,
    hasGroup: true,
    isGroupOwner: false,
  });
  const personalManager = resolveRelationshipCapabilities({
    rawRole: "personal",
    hasGroup: true,
    isGroupOwner: true,
  });

  assert.equal(childMember.isChild, true);
  assert.equal(childMember.canManageOwnFamilyLink, true);
  assert.equal(childMember.canParticipateInGroup, true);
  assert.equal(childMember.canManageGroup, false);

  assert.equal(personalManager.role, "groupManager");
  assert.equal(personalManager.canManageGroup, true);
  assert.equal(personalManager.showsPersonalTools, true);
});

test("App surfaces composable relationship tools and separates growth tracks", () => {
  const projectRoot = path.resolve(__dirname, "..");
  const homePage = fs.readFileSync(
    path.join(projectRoot, "lib/screens/home_page.dart"),
    "utf8",
  );
  const characterPage = fs.readFileSync(
    path.join(projectRoot, "lib/screens/character_page.dart"),
    "utf8",
  );
  const appState = fs.readFileSync(
    path.join(projectRoot, "lib/state/app_state.dart"),
    "utf8",
  );
  const webApp = fs.readFileSync(
    path.join(projectRoot, "web_dashboard/assets/app.js"),
    "utf8",
  );
  const webProfile = fs.readFileSync(
    path.join(projectRoot, "web_dashboard/profile.html"),
    "utf8",
  );
  const quickActions = homePage.slice(
    homePage.indexOf("// Filter quick action cards based on active role"),
    homePage.indexOf("return GridView.count"),
  );

  assert.match(quickActions, /if \(capabilities\.canParticipateInGroup\)/);
  assert.doesNotMatch(
    quickActions,
    /else if \(capabilities\.isGroupExperience\)/,
  );
  assert.match(characterPage, /個人角色進化/);
  assert.match(characterPage, /家庭羈絆/);
  assert.match(characterPage, /團體貢獻/);
  assert.match(characterPage, /不會直接增加角色 EXP/);
  assert.match(webApp, /updateNavigationRecommendation\(capabilities\)/);
  assert.doesNotMatch(
    webApp,
    /updateNavigationRecommendation\(userRole\)/,
  );
  assert.match(webApp, /團體成員身分/);
  assert.match(
    webApp,
    /function buildRelationshipCapabilityInput\(data = \{\}\)/,
  );
  assert.equal(
    (webApp.match(/buildRelationshipCapabilityInput\(data\)/g) || []).length,
    2,
  );
  assert.match(
    appState,
    /\.where\(\s*'memberIds',\s*arrayContains: userId\s*\)/,
  );
  assert.match(
    webApp,
    /\.where\("memberIds", "array-contains", userId\)/,
  );
  assert.match(
    appState,
    /'avatarExperienceLedger': _avatarExperienceLedger/,
  );
  assert.match(webProfile, /id="profileGrowthTracks"/);
  assert.match(webProfile, /個人角色進化/);
  assert.match(webProfile, /家庭羈絆/);
  assert.match(webProfile, /團體貢獻/);
});
