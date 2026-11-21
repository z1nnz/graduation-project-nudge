(function (root, factory) {
  const api = factory();
  if (typeof module === "object" && module.exports) {
    module.exports = api;
  } else {
    root.NudgeRelationshipCapabilities = api;
  }
})(typeof globalThis !== "undefined" ? globalThis : this, function () {
  const GROUP_ROLES = new Set(["group", "enterprise", "tutor", "school"]);
  const RELATIONSHIP_CONTEXTS = new Set(["personal", "family", "group"]);

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
    const requestedContext = String(input.activeContext || "")
      .trim()
      .toLowerCase();
    const contextExplicit = RELATIONSHIP_CONTEXTS.has(requestedContext);
    const activeContext = contextExplicit
      ? requestedContext
      : isGuardian || isChild
        ? "family"
        : hasGroup || hasDeclaredGroupRole
          ? "group"
          : "personal";
    let role = "personal";

    if (activeContext === "family" && isGuardian) {
      role = "guardian";
    } else if (activeContext === "family" && isChild) {
      role = "child";
    } else if (activeContext === "group" && (hasGroup || hasDeclaredGroupRole)) {
      role = input.isGroupOwner ? "groupManager" : "groupMember";
    }

    const isPreview = Boolean(input.isPreview);
    const canUseFamilyContext = !contextExplicit || activeContext === "family";
    const canUseGroupContext = !contextExplicit || activeContext === "group";
    const canManageGroup = isGroupOwner && canUseGroupContext;

    return Object.freeze({
      role,
      activeContext,
      contextExplicit,
      isGuardian,
      isChild,
      isPreview,
      isAuthenticated: Boolean(input.isAuthenticated) && !isPreview,
      familyLinked,
      hasGroup,
      canViewGuardianHub: isGuardian && familyLinked && canUseFamilyContext,
      canManageOwnFamilyLink: isChild && familyLinked && canUseFamilyContext,
      canManageGroup,
      canParticipateInGroup: hasGroup && canUseGroupContext,
      showsPersonalTools: role !== "guardian",
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
    const isFamilyPage = fileName.startsWith("guardian");
    const isGroupPage = fileName.startsWith("groups");

    if (
      capabilities.contextExplicit &&
      isFamilyPage &&
      capabilities.activeContext !== "family"
    ) {
      return "dashboard.html";
    }
    if (
      capabilities.contextExplicit &&
      isGroupPage &&
      capabilities.activeContext !== "group"
    ) {
      return "dashboard.html";
    }

    if (
      isFamilyPage &&
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
