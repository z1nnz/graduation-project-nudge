(function (root, factory) {
  const api = factory();
  if (typeof module === "object" && module.exports) {
    module.exports = api;
  } else {
    root.NudgeRelationshipCapabilities = api;
  }
})(typeof globalThis !== "undefined" ? globalThis : this, function () {
  const GROUP_ROLES = new Set(["group", "enterprise", "tutor", "school"]);

  function resolveRelationshipCapabilities(input = {}) {
    const rawRole = String(input.rawRole || "personal").trim().toLowerCase();
    let role = "personal";

    if (rawRole === "guardian") {
      role = "guardian";
    } else if (rawRole === "child") {
      role = "child";
    } else if (GROUP_ROLES.has(rawRole)) {
      role = input.isGroupOwner ? "groupManager" : "groupMember";
    }

    const familyLinked = Boolean(input.familyLinked);
    const hasGroup = Boolean(input.hasGroup);
    const isPreview = Boolean(input.isPreview);
    const canManageGroup = role === "groupManager" && hasGroup;

    return Object.freeze({
      role,
      isPreview,
      isAuthenticated: Boolean(input.isAuthenticated) && !isPreview,
      familyLinked,
      hasGroup,
      canViewGuardianHub: role === "guardian" && familyLinked,
      canManageOwnFamilyLink: role === "child",
      canManageGroup,
      canParticipateInGroup:
        (role === "groupManager" || role === "groupMember") && hasGroup,
      groupSurfaceTitle: canManageGroup
        ? "團體管理控制台"
        : "團體任務與共同進度",
    });
  }

  function resolveRoleGateRedirect(path, input = {}) {
    const fileName = String(path || "")
      .split("?")[0]
      .split("/")
      .pop();
    const capabilities = resolveRelationshipCapabilities(input);

    if (
      fileName.startsWith("guardian") &&
      fileName !== "guardian-link.html" &&
      !capabilities.canViewGuardianHub
    ) {
      return "guardian-link.html";
    }

    const managerOnlyPages = new Set([
      "groups-challenge.html",
      "groups-study-schedule.html",
      "groups-templates.html",
      "groups-creation.html",
    ]);
    if (
      managerOnlyPages.has(fileName) &&
      !capabilities.canManageGroup
    ) {
      return capabilities.canParticipateInGroup
        ? "groups.html"
        : "groups-link.html";
    }

    return null;
  }

  return {
    resolveRelationshipCapabilities,
    resolveRoleGateRedirect,
  };
});
