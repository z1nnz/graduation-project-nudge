(function attachRoomActivitySessionContract(root) {
  const statuses = ["active", "paused", "completed", "cancelled"];
  const activityKinds = ["focus", "sleep", "exercise", "steps", "custom"];
  const sources = ["app", "web", "health", "device"];

  function requireText(value, label) {
    const text = String(value || "").trim();
    if (!text) throw new Error(`${label} is required`);
    return text;
  }

  function requireMetric(value, label, { positive = false } = {}) {
    const metric = Number(value);
    if (!Number.isFinite(metric) || metric < 0 || (positive && metric <= 0)) {
      throw new Error(`${label} is invalid`);
    }
    return metric;
  }

  function start(input) {
    if (!activityKinds.includes(input.activityKind)) {
      throw new Error("Unsupported room activity kind");
    }
    if (!sources.includes(input.source)) {
      throw new Error("Unsupported room activity source");
    }
    const now = new Date(input.now);
    if (Number.isNaN(now.getTime())) throw new Error("Invalid start time");
    return {
      schemaVersion: 1,
      sessionId: requireText(input.sessionId, "sessionId"),
      roomId: requireText(input.roomId, "roomId"),
      actorId: requireText(input.actorId, "actorId"),
      activityKind: input.activityKind,
      metricUnit: requireText(input.metricUnit, "metricUnit"),
      targetValue: requireMetric(input.targetValue, "targetValue", {
        positive: true,
      }),
      metricValue: 0,
      source: input.source,
      status: "active",
      startedAt: now.toISOString(),
      updatedAt: now.toISOString(),
      endedAt: null,
    };
  }

  function transition(session, input) {
    if (!session || session.actorId !== input.actorId) {
      throw new Error("Only the session actor controls its lifecycle");
    }
    if (!statuses.includes(input.nextStatus)) {
      throw new Error("Unsupported room session status");
    }
    if (["completed", "cancelled"].includes(session.status)) {
      throw new Error("A terminal room session cannot transition");
    }
    const allowed =
      session.status === "active"
        ? ["paused", "completed", "cancelled"]
        : ["active", "completed", "cancelled"];
    if (!allowed.includes(input.nextStatus)) {
      throw new Error("Invalid room session transition");
    }
    const metricValue = requireMetric(input.metricValue, "metricValue");
    if (metricValue < Number(session.metricValue || 0)) {
      throw new Error("Room session progress cannot decrease");
    }
    const now = new Date(input.now);
    if (Number.isNaN(now.getTime())) throw new Error("Invalid transition time");
    const ended = ["completed", "cancelled"].includes(input.nextStatus);
    return {
      ...session,
      metricValue,
      status: input.nextStatus,
      updatedAt: now.toISOString(),
      endedAt: ended ? now.toISOString() : null,
    };
  }

  const contract = { start, transition, statuses, activityKinds, sources };
  root.NudgeRoomActivitySessionContract = contract;
  if (typeof module !== "undefined" && module.exports) {
    module.exports = contract;
  }
})(typeof window !== "undefined" ? window : globalThis);
