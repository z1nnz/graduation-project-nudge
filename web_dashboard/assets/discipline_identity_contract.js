(function disciplineIdentityContract(root, factory) {
  const contract = factory();
  if (typeof module === "object" && module.exports) {
    module.exports = contract;
  }
  if (root) root.NudgeDisciplineIdentityContract = contract;
})(typeof window !== "undefined" ? window : globalThis, function buildContract() {
  const personaKeys = new Set([
    "starting_seed",
    "comeback_builder",
    "steady_builder",
    "balanced_rhythm",
    "focus_sprinter",
    "pathfinder",
  ]);
  const recoveryStates = new Set([
    "starting",
    "gentle_return",
    "returning",
    "steady",
  ]);
  const activityKinds = new Set([
    "focus",
    "study",
    "exercise",
    "steps",
    "sleep",
    "task",
  ]);

  function record(value) {
    return value && typeof value === "object" && !Array.isArray(value);
  }

  function nonNegativeInteger(value) {
    return Number.isInteger(value) && value >= 0;
  }

  function validTimestamp(value) {
    return typeof value === "string" &&
      value.trim() &&
      !Number.isNaN(Date.parse(value));
  }

  function parseDisciplineIdentity(expectedUserId, data) {
    const window = data?.window;
    const persona = data?.persona;
    const recovery = data?.recovery;
    const metrics = data?.metrics;
    const kinds = metrics?.activityKinds;
    const lastActiveDay = metrics?.lastActiveDay;
    const uniqueKinds = Array.isArray(kinds) && new Set(kinds).size === kinds.length;
    if (
      !expectedUserId ||
      !record(data) ||
      data.schemaVersion !== 1 ||
      data.snapshotId !== expectedUserId ||
      data.userId !== expectedUserId ||
      data.visibility !== "private" ||
      !record(window) ||
      window.days !== 28 ||
      !validTimestamp(window.startedAt) ||
      !validTimestamp(window.endedAt) ||
      Date.parse(window.startedAt) > Date.parse(window.endedAt) ||
      !record(persona) ||
      !personaKeys.has(persona.key) ||
      typeof persona.title !== "string" ||
      !persona.title.trim() ||
      typeof persona.description !== "string" ||
      !persona.description.trim() ||
      !record(recovery) ||
      !recoveryStates.has(recovery.state) ||
      !Number.isInteger(recovery.recommendedFocusMinutes) ||
      recovery.recommendedFocusMinutes < 1 ||
      recovery.recommendedFocusMinutes > 120 ||
      typeof recovery.message !== "string" ||
      !recovery.message.trim() ||
      !record(metrics) ||
      !nonNegativeInteger(metrics.activeDays) ||
      metrics.activeDays > 28 ||
      !nonNegativeInteger(metrics.completedSessions) ||
      metrics.completedSessions < metrics.activeDays ||
      !nonNegativeInteger(metrics.focusMinutes) ||
      !nonNegativeInteger(metrics.exerciseMinutes) ||
      !uniqueKinds ||
      !kinds.every(kind => activityKinds.has(kind)) ||
      !(
        lastActiveDay === null ||
        (typeof lastActiveDay === "string" && /^\d{4}-\d{2}-\d{2}$/.test(lastActiveDay))
      ) ||
      (metrics.activeDays === 0 && lastActiveDay !== null) ||
      (metrics.activeDays > 0 && lastActiveDay === null) ||
      !validTimestamp(data.updatedAt) ||
      data.updatedAt !== window.endedAt
    ) {
      throw new Error("自律人格格式或帳號不一致");
    }
    return Object.freeze(data);
  }

  return { parseDisciplineIdentity };
});
