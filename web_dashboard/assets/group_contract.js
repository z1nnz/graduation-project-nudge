(function initGroupContract(root, factory) {
  const api = factory();
  if (typeof module === "object" && module.exports) {
    module.exports = api;
  }
  if (root) root.NudgeGroupContract = api;
})(typeof window !== "undefined" ? window : globalThis, function createGroupContract() {
  function isGroupMember(group, userId) {
    return Boolean(
      group &&
      group.status === "active" &&
      Array.isArray(group.memberIds) &&
      group.memberIds.includes(userId),
    );
  }

  function isGroupManager(group, userId) {
    return isGroupMember(group, userId) && group.ownerId === userId;
  }

  function requireManager(group, publisherId) {
    if (!isGroupManager(group, publisherId)) {
      throw new Error("只有目前團體的管理者可以發布團體內容");
    }
  }

  function requireText(value, label) {
    const normalized = String(value || "").trim();
    if (!normalized) throw new Error(`${label}不可空白`);
    return normalized;
  }

  function requireDays(days, label) {
    const normalized = Number(days);
    if (!Number.isInteger(normalized) || normalized < 1 || normalized > 365) {
      throw new Error(`${label}天數必須介於 1 到 365 天`);
    }
    return normalized;
  }

  function buildGroupChallenge({
    group,
    publisherId,
    type,
    days,
    reward,
    now = new Date().toISOString(),
  }) {
    requireManager(group, publisherId);
    return {
      schemaVersion: 1,
      groupId: group.id,
      groupName: group.name,
      type: requireText(type, "挑戰類型"),
      days: requireDays(days, "挑戰"),
      reward: requireText(reward, "挑戰獎勵"),
      status: "active",
      publishedBy: publisherId,
      updatedAt: now,
    };
  }

  function buildGroupStudySchedule({
    group,
    publisherId,
    title,
    meta,
    now = new Date().toISOString(),
  }) {
    requireManager(group, publisherId);
    return {
      schemaVersion: 1,
      groupId: group.id,
      title: requireText(title, "時段名稱"),
      meta: requireText(meta, "時段說明"),
      status: "scheduled",
      publishedBy: publisherId,
      createdAt: now,
    };
  }

  function buildGroupTemplate({
    group,
    publisherId,
    type,
    days,
    effort,
    strategy,
    now = new Date().toISOString(),
  }) {
    requireManager(group, publisherId);
    return {
      schemaVersion: 1,
      groupId: group.id,
      type: requireText(type, "模板類型"),
      days: requireDays(days, "模板"),
      effort: requireText(effort, "核心任務"),
      strategy: requireText(strategy, "準備策略"),
      status: "active",
      publishedBy: publisherId,
      updatedAt: now,
    };
  }

  return {
    isGroupMember,
    isGroupManager,
    buildGroupChallenge,
    buildGroupStudySchedule,
    buildGroupTemplate,
  };
});
