(function attachActivityLedgerClient(root, factory) {
  const api = factory();
  if (typeof module !== "undefined" && module.exports) {
    module.exports = api;
  }
  if (root) {
    root.NudgeActivityLedgerClient = api;
  }
})(typeof globalThis !== "undefined" ? globalThis : this, function createApi() {
  "use strict";

  const pendingKey = "nudge_web_activity_ledger_outbox_v1";
  const deadLetterKey = "nudge_web_activity_ledger_dead_letters_v1";
  const allowedActivityTypes = new Set([
    "focus",
    "study",
    "exercise",
    "steps",
    "sleep",
    "custom",
  ]);

  function parseList(storage, key) {
    try {
      const value = JSON.parse(storage.getItem(key) || "[]");
      return Array.isArray(value) ? value : [];
    } catch (_) {
      return [];
    }
  }

  function writeList(storage, key, value) {
    storage.setItem(key, JSON.stringify(value));
  }

  function eventTypeForTransition(previousStatus, nextStatus) {
    if (nextStatus === "paused") return "paused";
    if (nextStatus === "completed") return "completed";
    if (nextStatus === "cancelled") return "discarded";
    if (nextStatus === "active" && previousStatus === "paused") return "resumed";
    if (nextStatus === "active" && !previousStatus) return "started";
    throw new Error("Unsupported room activity transition.");
  }

  function buildRoomActivityEvidence({
    session,
    previousStatus = null,
    nextStatus,
  }) {
    if (!session || typeof session !== "object") {
      throw new Error("A room activity session is required.");
    }
    const sessionId = String(session.sessionId || "").trim();
    const roomId = String(session.roomId || "").trim();
    const activityType = String(session.activityKind || "").trim();
    const metricUnit = String(session.metricUnit || "").trim();
    const occurredAt = new Date(session.updatedAt);
    const metricValue = Number(session.metricValue);
    if (
      !sessionId ||
      !roomId ||
      !allowedActivityTypes.has(activityType) ||
      !metricUnit ||
      !Number.isFinite(metricValue) ||
      metricValue < 0 ||
      Number.isNaN(occurredAt.getTime())
    ) {
      throw new Error("Room activity evidence is invalid.");
    }
    const eventType = eventTypeForTransition(previousStatus, nextStatus);
    const normalizedOccurredAt = occurredAt.toISOString();
    const stableId = `${sessionId}_${eventType}_${normalizedOccurredAt}`;
    return {
      eventId: stableId,
      sourceRecordId: stableId,
      sessionId,
      activityCorrelationId: sessionId,
      roomIds: [roomId],
      activityType,
      source: String(session.source || "web").trim(),
      eventType,
      metricValue,
      metricUnit,
      occurredAt: normalizedOccurredAt,
    };
  }

  function buildStandaloneFocusEvidence({
    sessionId,
    eventType,
    elapsedSeconds,
    occurredAt,
  }) {
    const normalizedSessionId = String(sessionId || "").trim();
    const normalizedEventType = String(eventType || "").trim();
    const seconds = Number(elapsedSeconds);
    const occurrence = new Date(occurredAt);
    if (
      !normalizedSessionId ||
      !["started", "paused", "resumed", "completed", "discarded"].includes(
        normalizedEventType,
      ) ||
      !Number.isFinite(seconds) ||
      seconds < 0 ||
      Number.isNaN(occurrence.getTime())
    ) {
      throw new Error("Standalone focus evidence is invalid.");
    }
    const normalizedOccurredAt = occurrence.toISOString();
    const stableId =
      `${normalizedSessionId}_${normalizedEventType}_${normalizedOccurredAt}`;
    return {
      eventId: stableId,
      sourceRecordId: stableId,
      sessionId: normalizedSessionId,
      activityCorrelationId: null,
      roomIds: [],
      activityType: "focus",
      source: "web",
      eventType: normalizedEventType,
      metricValue: seconds / 60,
      metricUnit: "minutes",
      occurredAt: normalizedOccurredAt,
    };
  }

  function stableTaskKey(value) {
    let hash = 14695981039346656037n;
    const prime = 1099511628211n;
    for (let index = 0; index < value.length; index += 1) {
      hash ^= BigInt(value.charCodeAt(index));
      hash = BigInt.asUintN(64, hash * prime);
    }
    return hash.toString(16).padStart(16, "0");
  }

  function buildTaskCompletionEvidence({
    userId,
    taskId,
    activityDateKey,
    completed,
    occurredAt,
  }) {
    const normalizedUserId = String(userId || "").trim();
    const normalizedTaskId = String(taskId || "").trim();
    const normalizedDateKey = String(activityDateKey || "").trim();
    const occurrence = new Date(occurredAt);
    if (
      !normalizedUserId ||
      !normalizedTaskId ||
      normalizedTaskId.length > 256 ||
      !/^\d{4}-\d{2}-\d{2}$/.test(normalizedDateKey) ||
      typeof completed !== "boolean" ||
      Number.isNaN(occurrence.getTime())
    ) {
      throw new Error("Task activity evidence is invalid.");
    }
    const normalizedOccurredAt = occurrence.toISOString();
    const correlationId =
      `task:${normalizedUserId}:${stableTaskKey(normalizedTaskId)}:${normalizedDateKey}`;
    const stableId =
      `${correlationId}:${completed ? "1" : "0"}:${normalizedOccurredAt}`;
    return {
      eventId: stableId,
      sourceRecordId: stableId,
      sessionId: correlationId,
      activityCorrelationId: correlationId,
      actorUserId: normalizedUserId,
      taskId: normalizedTaskId,
      roomIds: [],
      activityType: "task",
      source: "web",
      eventType: "metricSynced",
      metricValue: completed ? 1 : 0,
      metricUnit: "completion",
      occurredAt: normalizedOccurredAt,
    };
  }

  function normalizedErrorCode(error) {
    return String(error?.code || "")
      .replace(/^functions\//, "")
      .toLowerCase();
  }

  function isPermanent(error) {
    return [
      "invalid-argument",
      "failed-precondition",
      "permission-denied",
    ].includes(normalizedErrorCode(error));
  }

  function createActivityLedgerOutbox({
    storage,
    call,
    getActorId,
    clock = () => new Date(),
  }) {
    if (!storage || typeof storage.getItem !== "function") {
      throw new Error("Activity Ledger outbox requires storage.");
    }
    if (typeof call !== "function") {
      throw new Error("Activity Ledger outbox requires a callable transport.");
    }
    if (typeof getActorId !== "function") {
      throw new Error("Activity Ledger outbox requires an actor identity.");
    }
    let activeFlush = null;

    function pendingEntries() {
      return parseList(storage, pendingKey);
    }

    function deadLetters() {
      return parseList(storage, deadLetterKey);
    }

    async function enqueue(evidence) {
      if (!evidence?.eventId) {
        throw new Error("Activity evidence requires an event ID.");
      }
      const actorUserId = String(getActorId() || "").trim();
      if (!actorUserId) {
        throw new Error("Sign in before recording Web activity.");
      }
      const actorBoundEvidence = {
        ...evidence,
        actorUserId,
      };
      const entries = pendingEntries();
      const existing = entries.find(
        entry =>
          entry.actorUserId === actorUserId &&
          entry.evidence?.eventId === actorBoundEvidence.eventId,
      );
      if (existing) {
        if (
          JSON.stringify(existing.evidence) !== JSON.stringify(actorBoundEvidence)
        ) {
          throw new Error("An event ID cannot be reused for different evidence.");
        }
        return;
      }
      entries.push({
        actorUserId,
        evidence: actorBoundEvidence,
        queuedAt: clock().toISOString(),
        attempts: 0,
        lastError: null,
      });
      writeList(storage, pendingKey, entries);
    }

    function removePending(actorUserId, eventId) {
      writeList(
        storage,
        pendingKey,
        pendingEntries().filter(
          entry =>
            entry.actorUserId !== actorUserId ||
            entry.evidence?.eventId !== eventId,
        ),
      );
    }

    function retainFailure(entry, error) {
      const current = pendingEntries();
      const index = current.findIndex(
        item =>
          item.actorUserId === entry.actorUserId &&
          item.evidence?.eventId === entry.evidence.eventId,
      );
      if (index < 0) return;
      current[index] = {
        ...current[index],
        attempts: Number(current[index].attempts || 0) + 1,
        lastError: String(error?.message || error),
      };
      writeList(storage, pendingKey, current);
    }

    function deadLetter(entry, error) {
      const rejected = deadLetters();
      rejected.push({
        ...entry,
        attempts: Number(entry.attempts || 0) + 1,
        lastError: String(error?.message || error),
        failedAt: clock().toISOString(),
      });
      writeList(storage, deadLetterKey, rejected.slice(-100));
      removePending(entry.actorUserId, entry.evidence.eventId);
    }

    async function flushInternal() {
      let succeeded = 0;
      let permanentlyRejected = 0;
      while (true) {
        const pending = pendingEntries();
        if (!pending.length) {
          return { succeeded, permanentlyRejected, retryBlocked: false };
        }
        const actorUserId = String(getActorId() || "").trim();
        if (!actorUserId) {
          return { succeeded, permanentlyRejected, retryBlocked: true };
        }
        const entry = pending.find(item => item.actorUserId === actorUserId);
        if (!entry) {
          return { succeeded, permanentlyRejected, retryBlocked: false };
        }
        try {
          await call({ evidence: entry.evidence });
          removePending(entry.actorUserId, entry.evidence.eventId);
          succeeded += 1;
        } catch (error) {
          const currentActorUserId = String(getActorId() || "").trim();
          if (currentActorUserId !== entry.actorUserId) {
            retainFailure(entry, error);
            return { succeeded, permanentlyRejected, retryBlocked: false };
          }
          if (isPermanent(error)) {
            deadLetter(entry, error);
            permanentlyRejected += 1;
            continue;
          }
          retainFailure(entry, error);
          return { succeeded, permanentlyRejected, retryBlocked: true };
        }
      }
    }

    function flush() {
      if (activeFlush) return activeFlush;
      activeFlush = flushInternal().finally(() => {
        activeFlush = null;
      });
      return activeFlush;
    }

    return {
      enqueue,
      flush,
      pendingCount: () => pendingEntries().length,
      deadLetterCount: () => deadLetters().length,
    };
  }

  return {
    buildRoomActivityEvidence,
    buildStandaloneFocusEvidence,
    buildTaskCompletionEvidence,
    createActivityLedgerOutbox,
  };
});
