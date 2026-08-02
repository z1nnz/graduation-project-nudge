(function relationshipOutcomeContract(root, factory) {
  const contract = factory();
  if (typeof module === "object" && module.exports) {
    module.exports = contract;
  }
  if (root) {
    root.NudgeRelationshipOutcomeContract = contract;
  }
})(typeof window !== "undefined" ? window : globalThis, function buildContract() {
  const expectedKinds = Object.freeze({
    family: Object.freeze({ growth: "family_tree", character: "family_companion" }),
    group: Object.freeze({ growth: "group_planet", character: "group_companion" }),
  });
  const memoryTypes = new Set(["goal_completed", "encouragement_ack"]);

  function record(value) {
    return value && typeof value === "object" && !Array.isArray(value);
  }

  function nonNegativeInteger(value) {
    return Number.isInteger(value) && value >= 0;
  }

  function parseOutcome(scopeType, scopeId, data) {
    const kinds = expectedKinds[scopeType];
    const expectedId = `${scopeType}--${scopeId}`;
    const growth = data?.growth;
    const metrics = data?.metrics;
    const character = data?.characterOutcome;
    if (
      !kinds ||
      !record(data) ||
      data.schemaVersion !== 1 ||
      data.outcomeId !== expectedId ||
      data.scopeType !== scopeType ||
      data.scopeId !== scopeId ||
      typeof data.scopeName !== "string" ||
      !data.scopeName.trim() ||
      !["active", "ended"].includes(data.status) ||
      !record(growth) ||
      growth.kind !== kinds.growth ||
      !nonNegativeInteger(growth.xp) ||
      !Number.isInteger(growth.level) ||
      growth.level < 1 ||
      !nonNegativeInteger(growth.currentLevelXp) ||
      !(
        growth.nextLevelXp === null ||
        (Number.isInteger(growth.nextLevelXp) &&
          growth.nextLevelXp > growth.currentLevelXp)
      ) ||
      !Array.isArray(growth.milestoneKeys) ||
      growth.milestoneKeys.length === 0 ||
      !record(metrics) ||
      !Object.values(metrics).every(nonNegativeInteger) ||
      !record(character) ||
      character.kind !== kinds.character ||
      character.stage !== growth.level ||
      typeof character.title !== "string" ||
      !character.title.trim() ||
      typeof character.description !== "string" ||
      !character.description.trim() ||
      typeof data.updatedAt !== "string" ||
      !data.updatedAt.trim()
    ) {
      throw new Error("關係成果格式或情境不一致");
    }
    return Object.freeze(data);
  }

  function parseFamilyMemory(scopeId, id, data) {
    if (
      !record(data) ||
      data.schemaVersion !== 1 ||
      !id ||
      data.memoryId !== id ||
      data.scopeType !== "family" ||
      data.scopeId !== scopeId ||
      !memoryTypes.has(data.memoryType) ||
      typeof data.sourceId !== "string" ||
      !data.sourceId.trim() ||
      typeof data.actorId !== "string" ||
      !data.actorId.trim() ||
      typeof data.title !== "string" ||
      !data.title.trim() ||
      !nonNegativeInteger(data.points) ||
      typeof data.happenedAt !== "string" ||
      !data.happenedAt.trim()
    ) {
      throw new Error("家庭共同回憶格式或情境不一致");
    }
    return Object.freeze({ id, ...data });
  }

  function filterFamilyMemories(scopeId, rows) {
    return (Array.isArray(rows) ? rows : []).flatMap(row => {
      try {
        const id = String(row?.id || row?.memoryId || "").trim();
        return [parseFamilyMemory(scopeId, id, row)];
      } catch (_) {
        return [];
      }
    });
  }

  return { parseOutcome, parseFamilyMemory, filterFamilyMemories };
});
