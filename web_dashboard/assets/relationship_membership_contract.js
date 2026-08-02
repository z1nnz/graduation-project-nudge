(function attachRelationshipMembershipContract(root, factory) {
  const api = factory();
  if (typeof module === "object" && module.exports) {
    module.exports = api;
  } else {
    root.NudgeRelationshipMembershipContract = api;
  }
})(typeof globalThis !== "undefined" ? globalThis : this, function createApi() {
  "use strict";

  const scopes = new Set(["family", "group"]);
  const rolesByScope = Object.freeze({
    family: new Set(["guardian", "child"]),
    group: new Set(["manager", "member"]),
  });

  function documentId(scopeType, scopeId, userId) {
    const values = [scopeType, scopeId, userId].map(value =>
      String(value || "").trim(),
    );
    if (
      !scopes.has(values[0]) ||
      values.some(value => !value || value.includes("/"))
    ) {
      throw new Error("Membership 識別碼不完整");
    }
    return `${values[0]}--${values[1]}--${values[2]}`;
  }

  function parse(id, data, expectedUserId) {
    if (!data || typeof data !== "object" || Array.isArray(data)) {
      throw new Error("Membership 資料格式錯誤");
    }
    const scopeType = String(data.scopeType || "");
    const scopeId = String(data.scopeId || "").trim();
    const scopeName = String(data.scopeName || "").trim();
    const userId = String(data.userId || "").trim();
    const role = String(data.role || "");
    const status = String(data.status || "");
    if (
      data.schemaVersion !== 1 ||
      data.membershipId !== id ||
      documentId(scopeType, scopeId, userId) !== id ||
      (expectedUserId && userId !== expectedUserId) ||
      !scopeName ||
      !rolesByScope[scopeType]?.has(role) ||
      !["active", "ended"].includes(status)
    ) {
      throw new Error("Membership 身分或角色不一致");
    }
    return Object.freeze({
      id,
      scopeType,
      scopeId,
      scopeName,
      userId,
      role,
      status,
    });
  }

  function activeFor(memberships, scopeType, scopeId, userId) {
    return (Array.isArray(memberships) ? memberships : []).find(
      membership =>
        membership.scopeType === scopeType &&
        membership.scopeId === scopeId &&
        membership.userId === userId &&
        membership.status === "active",
    ) || null;
  }

  function filterParents(parents, memberships, scopeType, userId) {
    return (Array.isArray(parents) ? parents : []).filter(parent =>
      activeFor(memberships, scopeType, parent.id, userId),
    );
  }

  return { documentId, parse, activeFor, filterParents };
});
