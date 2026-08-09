const test = require("node:test");
const assert = require("node:assert/strict");

const {
  buildRoomActivityEvidence,
  buildStandaloneFocusEvidence,
  buildTaskCompletionEvidence,
  createActivityLedgerOutbox,
} = require("../web_dashboard/assets/activity_ledger_client.js");

function memoryStorage(initial = {}) {
  const values = new Map(Object.entries(initial));
  return {
    getItem(key) {
      return values.has(key) ? values.get(key) : null;
    },
    setItem(key, value) {
      values.set(key, String(value));
    },
  };
}

test("room session transitions map to the Cloud Activity Ledger contract", () => {
  const evidence = buildRoomActivityEvidence({
    session: {
      sessionId: "web-session-1",
      roomId: "room-focus",
      activityKind: "focus",
      metricValue: 25,
      metricUnit: "minutes",
      updatedAt: "2026-07-28T10:25:00.000Z",
    },
    nextStatus: "completed",
  });

  assert.deepEqual(evidence, {
    eventId: "web-session-1_completed_2026-07-28T10:25:00.000Z",
    sourceRecordId: "web-session-1_completed_2026-07-28T10:25:00.000Z",
    sessionId: "web-session-1",
    activityCorrelationId: "web-session-1",
    roomIds: ["room-focus"],
    activityType: "focus",
    source: "web",
    eventType: "completed",
    metricValue: 25,
    metricUnit: "minutes",
    occurredAt: "2026-07-28T10:25:00.000Z",
  });
});

test("cancelled room sessions become discarded Ledger events", () => {
  const evidence = buildRoomActivityEvidence({
    session: {
      sessionId: "web-session-2",
      roomId: "room-custom",
      activityKind: "custom",
      metricValue: 4,
      metricUnit: "minutes",
      updatedAt: "2026-07-28T11:00:00.000Z",
    },
    nextStatus: "cancelled",
  });

  assert.equal(evidence.eventType, "discarded");
});

test("standalone Web focus emits one stable lifecycle without room authority", () => {
  const evidence = buildStandaloneFocusEvidence({
    sessionId: "personal-focus-1",
    eventType: "paused",
    elapsedSeconds: 90,
    occurredAt: "2026-07-28T11:30:00.000Z",
  });

  assert.deepEqual(evidence, {
    eventId: "personal-focus-1_paused_2026-07-28T11:30:00.000Z",
    sourceRecordId: "personal-focus-1_paused_2026-07-28T11:30:00.000Z",
    sessionId: "personal-focus-1",
    activityCorrelationId: null,
    roomIds: [],
    activityType: "focus",
    source: "web",
    eventType: "paused",
    metricValue: 1.5,
    metricUnit: "minutes",
    occurredAt: "2026-07-28T11:30:00.000Z",
  });
});

test("Web task state changes share the App daily Ledger correlation", () => {
  const completed = buildTaskCompletionEvidence({
    userId: "user-1",
    taskId: "daily-review",
    activityDateKey: "2026-07-28",
    completed: true,
    occurredAt: "2026-07-28T09:25:00.000Z",
  });
  const reopened = buildTaskCompletionEvidence({
    userId: "user-1",
    taskId: "daily-review",
    activityDateKey: "2026-07-28",
    completed: false,
    occurredAt: "2026-07-28T09:29:00.000Z",
  });

  assert.equal(
    completed.activityCorrelationId,
    "task:user-1:6aac647c1ff1ff95:2026-07-28",
  );
  assert.equal(reopened.activityCorrelationId, completed.activityCorrelationId);
  assert.notEqual(reopened.eventId, completed.eventId);
  assert.equal(completed.activityType, "task");
  assert.equal(completed.source, "web");
  assert.equal(completed.eventType, "metricSynced");
  assert.equal(completed.metricValue, 1);
  assert.equal(reopened.metricValue, 0);
  assert.equal(completed.metricUnit, "completion");
  assert.deepEqual(completed.roomIds, []);
});

test("Web task Ledger identifiers stay within the Cloud contract limit", () => {
  const evidence = buildTaskCompletionEvidence({
    userId: "user-1",
    taskId: "x".repeat(256),
    activityDateKey: "2026-07-28",
    completed: true,
    occurredAt: "2026-07-28T09:25:00.000Z",
  });

  assert.ok(evidence.activityCorrelationId.length <= 256);
  assert.ok(evidence.sessionId.length <= 256);
  assert.ok(evidence.eventId.length <= 256);
  assert.ok(evidence.sourceRecordId.length <= 256);
  assert.throws(() => buildTaskCompletionEvidence({
    userId: "user-1",
    taskId: "x".repeat(257),
    activityDateKey: "2026-07-28",
    completed: true,
    occurredAt: "2026-07-28T09:25:00.000Z",
  }), /invalid/i);
});

test("outbox binds evidence to the authenticated Web actor", async () => {
  const storage = memoryStorage();
  const calls = [];
  const outbox = createActivityLedgerOutbox({
    storage,
    getActorId: () => "alice",
    call: async payload => calls.push(payload),
  });
  const evidence = buildStandaloneFocusEvidence({
    sessionId: "personal-focus-actor-bound",
    eventType: "started",
    elapsedSeconds: 0,
    occurredAt: "2026-07-28T11:45:00.000Z",
  });

  await outbox.enqueue({ ...evidence, actorUserId: "mallory" });
  await outbox.flush();

  assert.equal(calls.length, 1);
  assert.equal(calls[0].evidence.actorUserId, "alice");
});

test("outbox survives retryable callable failure and drains after restart", async () => {
  const storage = memoryStorage();
  const evidence = buildRoomActivityEvidence({
    session: {
      sessionId: "web-session-3",
      roomId: "room-focus",
      activityKind: "focus",
      metricValue: 10,
      metricUnit: "minutes",
      updatedAt: "2026-07-28T12:00:00.000Z",
    },
    nextStatus: "paused",
  });
  let calls = 0;
  const first = createActivityLedgerOutbox({
    storage,
    getActorId: () => "alice",
    call: async () => {
      calls += 1;
      const error = new Error("offline");
      error.code = "functions/unavailable";
      throw error;
    },
  });

  await first.enqueue(evidence);
  const blocked = await first.flush();

  assert.equal(blocked.retryBlocked, true);
  assert.equal(first.pendingCount(), 1);

  const received = [];
  const restarted = createActivityLedgerOutbox({
    storage,
    getActorId: () => "alice",
    call: async payload => {
      received.push(payload);
      return { status: "accepted" };
    },
  });
  const drained = await restarted.flush();

  assert.equal(calls, 1);
  assert.equal(drained.succeeded, 1);
  assert.equal(restarted.pendingCount(), 0);
  assert.deepEqual(received, [{
    evidence: {
      ...evidence,
      actorUserId: "alice",
    },
  }]);
});

test("outbox deduplicates stable event IDs and dead-letters invalid evidence", async () => {
  const storage = memoryStorage();
  const evidence = buildRoomActivityEvidence({
    session: {
      sessionId: "web-session-4",
      roomId: "room-focus",
      activityKind: "focus",
      metricValue: 25,
      metricUnit: "minutes",
      updatedAt: "2026-07-28T13:00:00.000Z",
    },
    nextStatus: "completed",
  });
  const outbox = createActivityLedgerOutbox({
    storage,
    getActorId: () => "alice",
    call: async () => {
      const error = new Error("invalid");
      error.code = "functions/invalid-argument";
      throw error;
    },
  });

  await outbox.enqueue(evidence);
  await outbox.enqueue(evidence);
  assert.equal(outbox.pendingCount(), 1);

  const report = await outbox.flush();

  assert.equal(report.permanentlyRejected, 1);
  assert.equal(outbox.pendingCount(), 0);
  assert.equal(outbox.deadLetterCount(), 1);
});

test("outbox never submits another account's queued Web activity", async () => {
  const storage = memoryStorage();
  let actorId = "alice";
  const calls = [];
  const outbox = createActivityLedgerOutbox({
    storage,
    getActorId: () => actorId,
    call: async payload => calls.push(payload),
  });
  const evidence = buildStandaloneFocusEvidence({
    sessionId: "personal-focus-owner-bound",
    eventType: "started",
    elapsedSeconds: 0,
    occurredAt: "2026-07-28T14:00:00.000Z",
  });
  await outbox.enqueue(evidence);

  actorId = "bob";
  const blocked = await outbox.flush();

  assert.equal(blocked.retryBlocked, false);
  assert.equal(outbox.pendingCount(), 1);
  assert.deepEqual(calls, []);
});

test("a Web account switch during flush retains the prior actor event", async () => {
  const storage = memoryStorage();
  let actorId = "alice";
  const outbox = createActivityLedgerOutbox({
    storage,
    getActorId: () => actorId,
    call: async () => {
      actorId = "bob";
      const error = new Error("account switched");
      error.code = "functions/permission-denied";
      throw error;
    },
  });
  await outbox.enqueue(buildStandaloneFocusEvidence({
    sessionId: "personal-focus-account-switch",
    eventType: "started",
    elapsedSeconds: 0,
    occurredAt: "2026-07-28T14:30:00.000Z",
  }));

  const report = await outbox.flush();

  assert.equal(report.permanentlyRejected, 0);
  assert.equal(outbox.pendingCount(), 1);
});

test("a Web account switch after success removes the submitted actor event", async () => {
  const storage = memoryStorage();
  let actorId = "alice";
  const outbox = createActivityLedgerOutbox({
    storage,
    getActorId: () => actorId,
    call: async () => {
      actorId = "bob";
      return { status: "accepted" };
    },
  });
  await outbox.enqueue(buildStandaloneFocusEvidence({
    sessionId: "personal-focus-successful-account-switch",
    eventType: "started",
    elapsedSeconds: 0,
    occurredAt: "2026-07-28T14:35:00.000Z",
  }));

  const report = await outbox.flush();

  assert.equal(report.succeeded, 1);
  assert.equal(outbox.pendingCount(), 0);
});
