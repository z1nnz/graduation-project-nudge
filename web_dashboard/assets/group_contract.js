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
    challengeId,
    type,
    days,
    reward,
    now = new Date().toISOString(),
  }) {
    requireManager(group, publisherId);
    return {
      schemaVersion: 2,
      challengeId: requireText(challengeId, "挑戰識別碼"),
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

  function requireActiveChallenge(group, challenge) {
    if (
      !challenge ||
      challenge.schemaVersion !== 2 ||
      challenge.groupId !== group.id ||
      challenge.status !== "active"
    ) {
      throw new Error("請使用目前團體已發布的新版有效挑戰");
    }
    return requireText(challenge.challengeId, "挑戰識別碼");
  }

  function buildGroupChallengeParticipation({
    group,
    challenge,
    memberId,
    now = new Date().toISOString(),
  }) {
    if (!isGroupMember(group, memberId)) {
      throw new Error("只有目前團體成員可以參與挑戰");
    }
    const challengeId = requireActiveChallenge(group, challenge);
    const totalDays = requireDays(challenge.days, "挑戰");
    return {
      schemaVersion: 1,
      groupId: group.id,
      challengeId,
      memberId,
      status: "joined",
      completedDays: 0,
      totalDays,
      joinedAt: now,
      updatedAt: now,
    };
  }

  function updateGroupChallengeParticipation({
    group,
    challenge,
    existing,
    memberId,
    completedDays,
    now = new Date().toISOString(),
  }) {
    if (!isGroupMember(group, memberId)) {
      throw new Error("只有目前團體成員可以更新挑戰進度");
    }
    const challengeId = requireActiveChallenge(group, challenge);
    const totalDays = requireDays(challenge.days, "挑戰");
    const normalizedDays = Number(completedDays);
    if (
      !existing ||
      existing.groupId !== group.id ||
      existing.challengeId !== challengeId ||
      existing.memberId !== memberId
    ) {
      throw new Error("挑戰參與紀錄與目前成員或挑戰不一致");
    }
    if (
      !Number.isInteger(normalizedDays) ||
      normalizedDays < 0 ||
      normalizedDays > totalDays
    ) {
      throw new Error("完成天數必須介於 0 到挑戰總天數");
    }
    if (existing.status === "completed" && normalizedDays < totalDays) {
      throw new Error("已完成的挑戰不可回退進度");
    }
    const completed = normalizedDays === totalDays;
    return {
      schemaVersion: 1,
      groupId: group.id,
      challengeId,
      memberId,
      status: completed ? "completed" : "joined",
      completedDays: normalizedDays,
      totalDays,
      joinedAt: existing.joinedAt || now,
      updatedAt: now,
      ...(completed ? { completedAt: existing.completedAt || now } : {}),
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

  function buildMemberRemoval({
    group,
    managerId,
    memberId,
    now = new Date().toISOString(),
  }) {
    requireManager(group, managerId);
    if (memberId === group.ownerId) {
      throw new Error("團體管理者不可移除自己，請先轉移管理權");
    }
    if (!isGroupMember(group, memberId)) {
      throw new Error("指定使用者不是目前團體成員");
    }
    return {
      memberIds: group.memberIds.filter(id => id !== memberId),
      lastMembershipChange: {
        type: "member_removed",
        memberId,
        by: managerId,
        at: now,
      },
      updatedAt: now,
    };
  }

  function buildOwnershipTransfer({
    group,
    managerId,
    nextManagerId,
    now = new Date().toISOString(),
  }) {
    requireManager(group, managerId);
    if (nextManagerId === managerId) {
      throw new Error("指定成員已經是團體管理者");
    }
    if (!isGroupMember(group, nextManagerId)) {
      throw new Error("管理權只能轉移給目前團體成員");
    }
    return {
      ownerId: nextManagerId,
      lastMembershipChange: {
        type: "ownership_transferred",
        fromMemberId: managerId,
        toMemberId: nextManagerId,
        by: managerId,
        at: now,
      },
      updatedAt: now,
    };
  }

  function buildGroupResultSummary({
    group,
    memberId,
    displayName,
    disciplineScore,
    completedTasks,
    totalTasks,
    focusMinutes,
    steps,
    sleepHours,
    now = new Date().toISOString(),
  }) {
    if (!isGroupMember(group, memberId)) {
      throw new Error("只有目前團體成員可以分享成果摘要");
    }
    const normalizedDisplayName = requireText(
      displayName,
      "團體顯示名稱",
    );
    if (normalizedDisplayName.length > 40) {
      throw new Error("團體顯示名稱不可超過 40 字");
    }
    const metrics = {
      disciplineScore: Number(disciplineScore),
      completedTasks: Number(completedTasks),
      totalTasks: Number(totalTasks),
      focusMinutes: Number(focusMinutes),
      steps: Number(steps),
      sleepHours: Number(sleepHours),
    };
    if (
      !Number.isInteger(metrics.disciplineScore) ||
      !Number.isInteger(metrics.completedTasks) ||
      !Number.isInteger(metrics.totalTasks) ||
      !Number.isInteger(metrics.focusMinutes) ||
      !Number.isInteger(metrics.steps) ||
      metrics.disciplineScore < 0 ||
      metrics.disciplineScore > 100 ||
      metrics.completedTasks < 0 ||
      metrics.totalTasks < metrics.completedTasks ||
      metrics.totalTasks > 10000 ||
      metrics.focusMinutes < 0 ||
      metrics.focusMinutes > 1440 ||
      metrics.steps < 0 ||
      metrics.steps > 1000000 ||
      !Number.isFinite(metrics.sleepHours) ||
      metrics.sleepHours < 0 ||
      metrics.sleepHours > 24
    ) {
      throw new Error("團體成果摘要包含無效數值");
    }
    return {
      schemaVersion: 1,
      groupId: group.id,
      memberId,
      displayName: normalizedDisplayName,
      status: "shared",
      summary: metrics,
      updatedAt: now,
    };
  }

  return {
    isGroupMember,
    isGroupManager,
    buildGroupChallenge,
    buildGroupChallengeParticipation,
    updateGroupChallengeParticipation,
    buildGroupStudySchedule,
    buildGroupTemplate,
    buildMemberRemoval,
    buildOwnershipTransfer,
    buildGroupResultSummary,
  };
});
