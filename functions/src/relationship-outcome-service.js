import { HttpsError } from "firebase-functions/v2/https";

const FAMILY_STAGES = [
  {
    level: 1,
    minimumXp: 0,
    milestoneKey: "family_seed",
    title: "陪伴種子",
    description: "家庭連結已建立，等待第一段雙向回應。",
  },
  {
    level: 2,
    minimumXp: 10,
    milestoneKey: "family_sprout",
    title: "同行嫩芽",
    description: "共同目標與回應已長成穩定的陪伴節奏。",
  },
  {
    level: 3,
    minimumXp: 30,
    milestoneKey: "family_tree",
    title: "回憶之樹",
    description: "持續的雙向互動已形成可回顧的家庭成果。",
  },
];

const GROUP_STAGES = [
  {
    level: 1,
    minimumXp: 0,
    milestoneKey: "group_core",
    title: "同行核心",
    description: "團體成員已聚集，準備建立共同節奏。",
  },
  {
    level: 2,
    minimumXp: 10,
    milestoneKey: "group_orbit",
    title: "協作軌道",
    description: "成員開始主動分享與參與共同挑戰。",
  },
  {
    level: 3,
    minimumXp: 30,
    milestoneKey: "group_planet",
    title: "共進星球",
    description: "團體持續累積由成員自己完成的共同成果。",
  },
];

function normalizedString(value, fallback = "") {
  const text = typeof value === "string" ? value.trim() : "";
  return text || fallback;
}

function nonNegativeInteger(value) {
  const number = Number(value);
  return Number.isFinite(number) && number > 0 ? Math.floor(number) : 0;
}

function resolveStage(stages, xp) {
  return stages.reduce(
    (resolved, stage) => (xp >= stage.minimumXp ? stage : resolved),
    stages[0],
  );
}

function nextStageXp(stages, level) {
  return stages.find(stage => stage.level > level)?.minimumXp ?? null;
}

function milestoneKeys(stages, level) {
  return stages
    .filter(stage => stage.level <= level)
    .map(stage => stage.milestoneKey);
}

function outcomeId(scopeType, scopeId) {
  return `${scopeType}--${scopeId}`;
}

export function buildFamilyRelationshipOutcome({
  scopeId,
  scopeName,
  participantIds,
  status = "active",
  bondEvents = [],
  goals = [],
  encouragements = [],
  refreshedBy,
  now,
}) {
  const growthXp = bondEvents.reduce(
    (sum, event) => sum + nonNegativeInteger(event.points),
    0,
  );
  const stage = resolveStage(FAMILY_STAGES, growthXp);
  const completedGoals = goals.filter(goal => goal.status === "completed").length;
  const acknowledgements = encouragements.filter(
    encouragement => encouragement.status === "acknowledged",
  ).length;
  return {
    schemaVersion: 1,
    outcomeId: outcomeId("family", scopeId),
    scopeType: "family",
    scopeId,
    scopeName,
    participantIds: [...new Set(participantIds)].sort(),
    status,
    growth: {
      kind: "family_tree",
      xp: growthXp,
      level: stage.level,
      currentLevelXp: stage.minimumXp,
      nextLevelXp: nextStageXp(FAMILY_STAGES, stage.level),
      milestoneKeys: milestoneKeys(FAMILY_STAGES, stage.level),
    },
    metrics: {
      acknowledgements,
      completedGoals,
      memoryCount: bondEvents.length,
    },
    characterOutcome: {
      kind: "family_companion",
      stage: stage.level,
      title: stage.title,
      description: stage.description,
    },
    refreshedBy,
    updatedAt: now,
  };
}

export function buildGroupRelationshipOutcome({
  scopeId,
  scopeName,
  participantIds,
  status = "active",
  sharedSummaries = [],
  currentChallengeId = null,
  challengeParticipations = [],
  refreshedBy,
  now,
}) {
  const currentMembers = new Set(participantIds);
  const currentParticipations = currentChallengeId
    ? challengeParticipations.filter(
        participation => participation.challengeId === currentChallengeId,
      )
    : [];
  const memberCount = currentMembers.size;
  const sharedMemberCount = new Set(
    sharedSummaries
      .filter(
        summary =>
          summary.status === "shared" &&
          currentMembers.has(summary.memberId),
      )
      .map(summary => summary.memberId)
  ).size;
  const joinedChallengeCount = new Set(
    currentParticipations
      .map(participation => participation.memberId)
      .filter(memberId => currentMembers.has(memberId)),
  ).size;
  const completedChallengeCount = new Set(
    currentParticipations
      .filter(
        participation =>
          participation.status === "completed" &&
          currentMembers.has(participation.memberId),
      )
      .map(participation => participation.memberId)
  ).size;
  const growthXp =
    memberCount +
    sharedMemberCount * 2 +
    joinedChallengeCount * 2 +
    completedChallengeCount * 8;
  const stage = resolveStage(GROUP_STAGES, growthXp);
  return {
    schemaVersion: 1,
    outcomeId: outcomeId("group", scopeId),
    scopeType: "group",
    scopeId,
    scopeName,
    participantIds: [...new Set(participantIds)].sort(),
    status,
    growth: {
      kind: "group_planet",
      xp: growthXp,
      level: stage.level,
      currentLevelXp: stage.minimumXp,
      nextLevelXp: nextStageXp(GROUP_STAGES, stage.level),
      milestoneKeys: milestoneKeys(GROUP_STAGES, stage.level),
    },
    metrics: {
      memberCount,
      sharedMemberCount,
      joinedChallengeCount,
      completedChallengeCount,
    },
    characterOutcome: {
      kind: "group_companion",
      stage: stage.level,
      title: stage.title,
      description: stage.description,
    },
    refreshedBy,
    updatedAt: now,
  };
}

export function buildFamilyRelationshipMemories({
  scopeId,
  participantIds,
  bondEvents,
  now,
}) {
  return bondEvents.slice(0, 100).map(event => {
    const sourceId = normalizedString(event.id || event.sourceId);
    const type =
      event.type === "goalCompleted" ? "goal_completed" : "encouragement_ack";
    return {
      id: `${type}--${sourceId}`,
      data: {
        schemaVersion: 1,
        memoryId: `${type}--${sourceId}`,
        scopeType: "family",
        scopeId,
        participantIds: [...new Set(participantIds)].sort(),
        memoryType: type,
        sourceId,
        actorId: normalizedString(event.actorId),
        title:
          type === "goal_completed"
            ? "一起完成了一個共同目標"
            : "收到並回應了一張家庭鼓勵卡",
        points: nonNegativeInteger(event.points),
        happenedAt: normalizedString(event.createdAt, now),
        createdAt: now,
      },
    };
  });
}

function snapshotRows(snapshot) {
  return snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
}

function requireInput(data) {
  const scopeType = normalizedString(data?.scopeType);
  const scopeId = normalizedString(data?.scopeId);
  if (!["family", "group"].includes(scopeType) || !scopeId) {
    throw new HttpsError(
      "invalid-argument",
      "scopeType and scopeId must identify a family or group.",
    );
  }
  if (scopeId.includes("/") || scopeId.length > 256) {
    throw new HttpsError("invalid-argument", "scopeId is invalid.");
  }
  return { scopeType, scopeId };
}

async function refreshFamily({ firestore, userId, scopeId, now }) {
  const linkRef = firestore.collection("family_links").doc(scopeId);
  const [linkSnapshot, bondSnapshot, goalSnapshot, encouragementSnapshot] =
    await Promise.all([
      linkRef.get(),
      linkRef.collection("bond_events").get(),
      linkRef.collection("goals").get(),
      linkRef.collection("encouragements").get(),
    ]);
  if (!linkSnapshot.exists) {
    throw new HttpsError("not-found", "Family relationship not found.");
  }
  const link = linkSnapshot.data();
  const participantIds = Array.isArray(link.participantIds)
    ? link.participantIds
    : [];
  if (!participantIds.includes(userId)) {
    throw new HttpsError(
      "permission-denied",
      "The caller is not a family participant.",
    );
  }
  const bondEvents = snapshotRows(bondSnapshot).sort((a, b) =>
    String(b.createdAt || "").localeCompare(String(a.createdAt || "")),
  );
  const outcome = buildFamilyRelationshipOutcome({
    scopeId,
    scopeName: `家庭連結 ${scopeId.slice(-8)}`,
    participantIds,
    status: link.status === "ended" ? "ended" : "active",
    bondEvents,
    goals: snapshotRows(goalSnapshot),
    encouragements: snapshotRows(encouragementSnapshot),
    refreshedBy: userId,
    now,
  });
  const memories = buildFamilyRelationshipMemories({
    scopeId,
    participantIds,
    bondEvents,
    now,
  });
  const outcomeRef = firestore
    .collection("relationship_outcomes")
    .doc(outcome.outcomeId);
  const batch = firestore.batch();
  batch.set(outcomeRef, outcome);
  for (const memory of memories) {
    batch.set(outcomeRef.collection("memories").doc(memory.id), memory.data);
  }
  await batch.commit();
  return { outcome, memories: memories.map(memory => memory.data) };
}

async function refreshGroup({ firestore, userId, scopeId, now }) {
  const groupRef = firestore.collection("groups").doc(scopeId);
  const [
    groupSnapshot,
    summarySnapshot,
    challengeSnapshot,
    participationSnapshot,
  ] =
    await Promise.all([
      groupRef.get(),
      groupRef.collection("member_summaries").get(),
      groupRef.collection("challenges").doc("current").get(),
      groupRef
        .collection("challenges")
        .doc("current")
        .collection("participants")
        .get(),
    ]);
  if (!groupSnapshot.exists) {
    throw new HttpsError("not-found", "Group relationship not found.");
  }
  const group = groupSnapshot.data();
  const participantIds = Array.isArray(group.memberIds) ? group.memberIds : [];
  if (!participantIds.includes(userId) || group.status !== "active") {
    throw new HttpsError(
      "permission-denied",
      "The caller is not an active group member.",
    );
  }
  const outcome = buildGroupRelationshipOutcome({
    scopeId,
    scopeName: normalizedString(group.name, "未命名團體"),
    participantIds,
    status: "active",
    sharedSummaries: snapshotRows(summarySnapshot),
    currentChallengeId: challengeSnapshot.exists
      ? normalizedString(challengeSnapshot.data().challengeId)
      : null,
    challengeParticipations: snapshotRows(participationSnapshot),
    refreshedBy: userId,
    now,
  });
  await firestore
    .collection("relationship_outcomes")
    .doc(outcome.outcomeId)
    .set(outcome);
  return { outcome, memories: [] };
}

export function createRefreshRelationshipOutcomeHandler({
  firestore,
  clock = () => new Date(),
}) {
  return async request => {
    const userId = request.auth?.uid;
    if (!userId) {
      throw new HttpsError(
        "unauthenticated",
        "Authentication is required to refresh a relationship outcome.",
      );
    }
    const { scopeType, scopeId } = requireInput(request.data);
    const input = {
      firestore,
      userId,
      scopeId,
      now: clock().toISOString(),
    };
    return scopeType === "family"
      ? refreshFamily(input)
      : refreshGroup(input);
  };
}
