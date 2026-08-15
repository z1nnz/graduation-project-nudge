import { HttpsError } from "firebase-functions/v2/https";

const WINDOW_DAYS = 28;
const MAX_SESSIONS = 500;
const SUPPORTED_ACTIVITY_TYPES = new Set([
  "focus",
  "study",
  "exercise",
  "steps",
  "sleep",
  "task",
]);

const PERSONAS = {
  starting_seed: {
    title: "起步種子",
    description: "還在建立第一段可觀察的自律節奏，先從一個容易完成的小行動開始。",
  },
  comeback_builder: {
    title: "復原建築師",
    description: "中斷後仍願意重新開始，回歸本身就是正在累積的能力。",
  },
  steady_builder: {
    title: "穩定築路者",
    description: "近四週持續留下行動紀錄，正在把自律變成可重複的節奏。",
  },
  balanced_rhythm: {
    title: "平衡節奏家",
    description: "在多種活動間建立節奏，讓自律不只依賴單一方法。",
  },
  focus_sprinter: {
    title: "專注衝刺者",
    description: "主要透過專注與共讀推進目標，擅長把時間切成清楚的行動區段。",
  },
  pathfinder: {
    title: "節奏探索者",
    description: "正在測試適合自己的行動方式，每次完成都會讓下一步更清楚。",
  },
};

function validDate(value) {
  const date = value instanceof Date ? value : new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
}

export function disciplineDayKey(value) {
  const date = validDate(value);
  if (!date) throw new TypeError("A valid date is required.");
  const shifted = new Date(date.getTime() + 3 * 60 * 60 * 1000);
  return shifted.toISOString().slice(0, 10);
}

function disciplineDayStart(value) {
  const date = validDate(value);
  if (!date) throw new TypeError("A valid date is required.");
  const shifted = new Date(date.getTime() + 3 * 60 * 60 * 1000);
  shifted.setUTCHours(0, 0, 0, 0);
  return new Date(shifted.getTime() - 3 * 60 * 60 * 1000);
}

function windowStart(now) {
  return new Date(
    disciplineDayStart(now).getTime() -
      (WINDOW_DAYS - 1) * 24 * 60 * 60 * 1000,
  );
}

function previousDayKey(now) {
  return disciplineDayKey(
    new Date(disciplineDayStart(now).getTime() - 1),
  );
}

function normalizeSessions({ userId, sessions, now }) {
  const startedAt = windowStart(now).getTime();
  const endedAt = now.getTime();
  return sessions.flatMap(session => {
    const completedAt = validDate(session?.endedAt);
    const metricValue = Number(session?.metricValue);
    if (
      session?.actorUserId !== userId ||
      session?.status !== "completed" ||
      !SUPPORTED_ACTIVITY_TYPES.has(session?.activityType) ||
      !completedAt ||
      completedAt.getTime() < startedAt ||
      completedAt.getTime() > endedAt ||
      !Number.isFinite(metricValue) ||
      metricValue <= 0
    ) {
      return [];
    }
    return [{
      activityType: session.activityType,
      dayKey: disciplineDayKey(completedAt),
      metricValue,
      metricUnit: String(session.metricUnit ?? ""),
    }];
  });
}

function resolveRecovery({ activeDayKeys, now }) {
  if (activeDayKeys.length === 0) {
    return {
      state: "starting",
      recommendedFocusMinutes: 10,
      message: "先完成 10 分鐘，建立第一個可以回看的行動證據。",
    };
  }
  const currentDay = disciplineDayKey(now);
  const hasToday = activeDayKeys.includes(currentDay);
  const hasYesterday = activeDayKeys.includes(previousDayKey(now));
  if (hasToday && !hasYesterday) {
    return {
      state: "returning",
      recommendedFocusMinutes: 15,
      message: "你已重新接上節奏；今天再完成一個小段落就足夠。",
    };
  }
  if (hasToday) {
    return {
      state: "steady",
      recommendedFocusMinutes: 25,
      message: "目前節奏穩定，依自己的負荷選擇下一個行動。",
    };
  }
  return {
    state: "gentle_return",
    recommendedFocusMinutes: 10,
    message: "紀錄沒有消失；用 10 分鐘回來，不需要補做錯過的份量。",
  };
}

function resolvePersona({ sessions, activeDayKeys, recovery }) {
  if (sessions.length === 0) return "starting_seed";
  if (recovery.state === "returning") return "comeback_builder";
  if (activeDayKeys.length >= 5) return "steady_builder";
  const activityKinds = new Set(sessions.map(session => session.activityType));
  if (activityKinds.size >= 3) return "balanced_rhythm";
  const focusSessions = sessions.filter(session =>
    ["focus", "study"].includes(session.activityType)
  ).length;
  if (focusSessions / sessions.length >= 0.6) return "focus_sprinter";
  return "pathfinder";
}

function sumMinutes(sessions, activityTypes) {
  return Math.floor(sessions.reduce((sum, session) => {
    return activityTypes.has(session.activityType) &&
        session.metricUnit === "minutes"
      ? sum + session.metricValue
      : sum;
  }, 0));
}

export function buildDisciplineIdentitySnapshot({ userId, sessions, now }) {
  const normalizedUserId = typeof userId === "string" ? userId.trim() : "";
  const currentTime = validDate(now);
  if (!normalizedUserId || normalizedUserId.includes("/") || !currentTime) {
    throw new TypeError("A valid user and clock are required.");
  }
  const normalizedSessions = normalizeSessions({
    userId: normalizedUserId,
    sessions: Array.isArray(sessions) ? sessions : [],
    now: currentTime,
  });
  const activeDayKeys = [
    ...new Set(normalizedSessions.map(session => session.dayKey)),
  ].sort();
  const recovery = resolveRecovery({ activeDayKeys, now: currentTime });
  const personaKey = resolvePersona({
    sessions: normalizedSessions,
    activeDayKeys,
    recovery,
  });
  const persona = PERSONAS[personaKey];
  const activityKinds = [
    ...new Set(normalizedSessions.map(session => session.activityType)),
  ].sort();
  return {
    schemaVersion: 1,
    snapshotId: normalizedUserId,
    userId: normalizedUserId,
    visibility: "private",
    window: {
      days: WINDOW_DAYS,
      startedAt: windowStart(currentTime).toISOString(),
      endedAt: currentTime.toISOString(),
    },
    persona: {
      key: personaKey,
      title: persona.title,
      description: persona.description,
    },
    recovery,
    metrics: {
      activeDays: activeDayKeys.length,
      completedSessions: normalizedSessions.length,
      focusMinutes: sumMinutes(
        normalizedSessions,
        new Set(["focus", "study"]),
      ),
      exerciseMinutes: sumMinutes(
        normalizedSessions,
        new Set(["exercise"]),
      ),
      activityKinds,
      lastActiveDay: activeDayKeys.at(-1) ?? null,
    },
    updatedAt: currentTime.toISOString(),
  };
}

export class FirestoreDisciplineIdentityRepository {
  constructor({ firestore }) {
    this.firestore = firestore;
  }

  async listCompletedSessions(userId, windowStartedAt) {
    const snapshot = await this.firestore
      .collection("activity_sessions")
      .where("actorUserId", "==", userId)
      .where("status", "==", "completed")
      .where("endedAt", ">=", windowStartedAt)
      .orderBy("endedAt", "desc")
      .limit(MAX_SESSIONS + 1)
      .get();
    return snapshot.docs.map(document => ({
      documentId: document.id,
      ...document.data(),
    }));
  }

  async saveSnapshot(snapshot) {
    await this.firestore
      .collection("discipline_identity_snapshots")
      .doc(snapshot.userId)
      .set(snapshot, { merge: false });
  }
}

export function createRefreshDisciplineIdentityHandler({
  repository,
  clock = () => new Date(),
}) {
  return async request => {
    const userId = request.auth?.uid;
    if (!userId) {
      throw new HttpsError(
        "unauthenticated",
        "Authentication is required to refresh a discipline identity.",
      );
    }
    const now = clock();
    const sessions = await repository.listCompletedSessions(
      userId,
      windowStart(now).toISOString(),
    );
    if (!Array.isArray(sessions) || sessions.length > MAX_SESSIONS) {
      throw new HttpsError(
        "resource-exhausted",
        "The 28-day activity window exceeds the supported snapshot size.",
      );
    }
    const snapshot = buildDisciplineIdentitySnapshot({
      userId,
      sessions,
      now,
    });
    await repository.saveSnapshot(snapshot);
    return { snapshot };
  };
}
