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
    const familyLinked = Boolean(input.familyLinked);
    const hasCanonicalFamilyRole =
      familyLinked &&
      (Boolean(input.isFamilyGuardian) || Boolean(input.isFamilyChild));
    const isGuardian = hasCanonicalFamilyRole
      ? Boolean(input.isFamilyGuardian)
      : rawRole === "guardian";
    const isChild = hasCanonicalFamilyRole
      ? Boolean(input.isFamilyChild)
      : rawRole === "child";
    const hasDeclaredGroupRole = GROUP_ROLES.has(rawRole);
    const hasGroup = Boolean(input.hasGroup);
    const isGroupOwner = hasGroup && Boolean(input.isGroupOwner);
    let role = "personal";

    if (isGuardian) {
      role = "guardian";
    } else if (isChild) {
      role = "child";
    } else if (hasGroup || hasDeclaredGroupRole) {
      role = input.isGroupOwner ? "groupManager" : "groupMember";
    }

    const isPreview = Boolean(input.isPreview);
    const canManageGroup = isGroupOwner;

    return Object.freeze({
      role,
      isGuardian,
      isChild,
      isPreview,
      isAuthenticated: Boolean(input.isAuthenticated) && !isPreview,
      familyLinked,
      hasGroup,
      canViewGuardianHub: isGuardian && familyLinked,
      canManageOwnFamilyLink: isChild && familyLinked,
      canManageGroup,
      canParticipateInGroup: hasGroup,
      showsPersonalTools: !isGuardian,
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
