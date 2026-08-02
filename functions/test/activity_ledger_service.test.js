import assert from "node:assert/strict";
import test from "node:test";

import {
  ActivityLedgerService,
  InMemoryActivityLedgerStore,
} from "../src/activity-ledger-service.js";

const completedFocusEvidence = {
  eventId: "event-focus-1",
  sourceRecordId: "app-focus-1",
  sessionId: "session-focus-1",
  activityCorrelationId: "focus-2026-07-28",
  actorUserId: "user-1",
  roomIds: ["room-study"],
  activityType: "focus",
  source: "app",
  eventType: "completed",
  metricValue: 25,
  metricUnit: "minutes",
  occurredAt: "2026-07-28T09:25:00.000Z",
};

const completedTaskEvidence = {
  eventId: "event-task-completed-1",
  sourceRecordId: "app-task-completed-1",
  sessionId: "task:user-1:6aac647c1ff1ff95:2026-07-28",
  activityCorrelationId: "task:user-1:6aac647c1ff1ff95:2026-07-28",
  taskId: "daily-review",
  actorUserId: "user-1",
  roomIds: [],
  activityType: "task",
  source: "app",
  eventType: "metricSynced",
  metricValue: 1,
  metricUnit: "completion",
  occurredAt: "2026-07-28T09:25:00.000Z",
};

function taskStore() {
  return new InMemoryActivityLedgerStore({
    userTasks: {
      "user-1": [{ id: "daily-review", done: false, isDone: false }],
    },
  });
}

test("App task completion can be corrected from Web without a reward", async () => {
  const store = taskStore();
  const service = new ActivityLedgerService({
    store,
    clock: () => new Date("2026-07-28T09:30:00.000Z"),
  });

  const completed = await service.record(
    { kind: "user", userId: "user-1" },
    completedTaskEvidence,
  );
  const corrected = await service.record(
    { kind: "user", userId: "user-1" },
    {
      ...completedTaskEvidence,
      eventId: "event-task-incomplete-1",
      sourceRecordId: "web-task-incomplete-1",
      source: "web",
      metricValue: 0,
      occurredAt: "2026-07-28T09:29:00.000Z",
    },
  );

  assert.equal(completed.status, "settled");
  assert.equal(completed.receipt.acceptedMetric, 1);
  assert.equal(completed.receipt.rewardEligible, false);
  assert.equal(completed.receipt.rewardIssued, false);
  assert.equal(corrected.receipt.acceptedMetric, 0);
  assert.equal(
    corrected.receipt.correctionOfReceiptId,
    completed.receipt.receiptId,
  );
  assert.equal(corrected.receipt.rewardEligible, false);
  assert.equal(corrected.receipt.rewardIssued, false);
  assert.equal(corrected.session.status, "active");
  assert.equal(corrected.session.metricValue, 0);
  assert.equal(store.receiptCount, 2);
  assert.equal((await store.getTaskProjection("user-1", "daily-review")).done, false);
});

test("task evidence is a binary metric synchronization", async () => {
  const service = new ActivityLedgerService({
    store: new InMemoryActivityLedgerStore(),
  });
  const principal = { kind: "user", userId: "user-1" };

  await assert.rejects(
    service.record(principal, {
      ...completedTaskEvidence,
      eventType: "completed",
    }),
    error =>
      error.name === "ActivityLedgerValidationError" &&
      error.message.toLowerCase().includes("task"),
  );
  await assert.rejects(
    service.record(principal, {
      ...completedTaskEvidence,
      eventId: "event-task-fractional",
      sourceRecordId: "app-task-fractional",
      metricValue: 0.5,
    }),
    error =>
      error.name === "ActivityLedgerValidationError" &&
      error.message.toLowerCase().includes("task"),
  );
});

test("task evidence settles only when its canonical task projection exists", async () => {
  const service = new ActivityLedgerService({
    store: new InMemoryActivityLedgerStore(),
  });

  await assert.rejects(
    service.record(
      { kind: "user", userId: "user-1" },
      completedTaskEvidence,
    ),
    error =>
      error.name === "ActivityLedgerValidationError" &&
      error.message.toLowerCase().includes("canonical task"),
  );
});

test("task evidence is personal and requires one daily correlation", async () => {
  const service = new ActivityLedgerService({
    store: new InMemoryActivityLedgerStore({
      roomMemberships: [
        {
          roomId: "room-study",
          userId: "user-1",
          status: "active",
          sharingConsented: true,
        },
      ],
    }),
  });
  const principal = { kind: "user", userId: "user-1" };

  await assert.rejects(
    service.record(principal, {
      ...completedTaskEvidence,
      roomIds: ["room-study"],
    }),
    error =>
      error.name === "ActivityLedgerValidationError" &&
      error.message.toLowerCase().includes("task"),
  );
  await assert.rejects(
    service.record(principal, {
      ...completedTaskEvidence,
      eventId: "event-task-uncorrelated",
      sourceRecordId: "app-task-uncorrelated",
      activityCorrelationId: null,
    }),
    error =>
      error.name === "ActivityLedgerValidationError" &&
      error.message.toLowerCase().includes("task"),
  );
  for (const invalidEvidence of [
    {
      sessionId: "task:user-1:6aac647c1ff1ff95:2026-07-27",
      activityCorrelationId: "task:user-1:6aac647c1ff1ff95:2026-07-27",
    },
    {
      sessionId: "task:user-1:not-a-hash:2026-07-28",
      activityCorrelationId: "task:user-1:not-a-hash:2026-07-28",
    },
    { sessionId: "another-session" },
    { taskId: "another-task" },
  ]) {
    await assert.rejects(
      service.record(principal, {
        ...completedTaskEvidence,
        eventId: `event-task-invalid-${JSON.stringify(invalidEvidence)}`,
        sourceRecordId: `source-task-invalid-${JSON.stringify(invalidEvidence)}`,
        ...invalidEvidence,
      }),
      error =>
        error.name === "ActivityLedgerValidationError" &&
        error.message.toLowerCase().includes("task"),
    );
  }
});

test("an older task event is audited without overwriting newer task state", async () => {
  const store = taskStore();
  const service = new ActivityLedgerService({
    store,
    clock: () => new Date("2026-07-28T09:30:00.000Z"),
  });
  await service.record(
    { kind: "user", userId: "user-1" },
    {
      ...completedTaskEvidence,
      eventId: "event-task-newer-reopened",
      sourceRecordId: "web-task-newer-reopened",
      source: "web",
      metricValue: 0,
      occurredAt: "2026-07-28T09:29:00.000Z",
    },
  );

  const stale = await service.record(
    { kind: "user", userId: "user-1" },
    completedTaskEvidence,
  );
  assert.equal(stale.status, "superseded");
  assert.equal(stale.receipt.acceptedMetric, 0);
  assert.equal(stale.session.metricValue, 0);
  assert.equal((await store.getTaskProjection("user-1", "daily-review")).done, false);
  assert.equal(store.receiptCount, 1);

  const replay = await service.record(
    { kind: "user", userId: "user-1" },
    completedTaskEvidence,
  );
  assert.equal(replay.status, "superseded");
  assert.equal(replay.wasDuplicate, true);
});

test("a completed activity settles once across service restarts", async () => {
  const store = new InMemoryActivityLedgerStore({
    roomMemberships: [
      {
        roomId: "room-study",
        userId: "user-1",
        status: "active",
        sharingConsented: true,
      },
    ],
  });
  const firstService = new ActivityLedgerService({
    store,
    clock: () => new Date("2026-07-28T09:25:01.000Z"),
  });

  const first = await firstService.record(
    { kind: "user", userId: "user-1" },
    completedFocusEvidence,
  );
  const restartedService = new ActivityLedgerService({
    store,
    clock: () => new Date("2026-07-28T09:26:00.000Z"),
  });
  const replay = await restartedService.record(
    { kind: "user", userId: "user-1" },
    completedFocusEvidence,
  );

  assert.equal(first.status, "settled");
  assert.equal(first.receipt.rewardEligible, true);
  assert.equal(first.receipt.rewardIssued, false);
  assert.equal(first.receipt.characterExperienceEligible, true);
  assert.equal(first.receipt.characterExperienceIssued, false);
  assert.equal(first.contributions.length, 1);
  assert.equal(first.contributions[0].roomId, "room-study");
  assert.equal(replay.receipt.receiptId, first.receipt.receiptId);
  assert.equal(replay.wasDuplicate, true);
  assert.equal(store.receiptCount, 1);
});

test("event idempotency is namespaced by actor and source", async () => {
  const store = new InMemoryActivityLedgerStore();
  const service = new ActivityLedgerService({ store });

  const first = await service.record(
    { kind: "user", userId: "user-1" },
    completedFocusEvidence,
  );
  const second = await service.record(
    { kind: "user", userId: "user-2" },
    {
      ...completedFocusEvidence,
      sourceRecordId: "app-focus-user-2",
      sessionId: "session-focus-user-2",
      activityCorrelationId: "focus-user-2",
      actorUserId: "user-2",
    },
  );

  assert.notEqual(second.receipt.receiptId, first.receipt.receiptId);
  assert.equal(store.receiptCount, 2);
});

test("one source record cannot mint another receipt under a new event ID", async () => {
  const store = new InMemoryActivityLedgerStore();
  const service = new ActivityLedgerService({
    store,
    clock: () => new Date("2026-07-28T09:25:01.000Z"),
  });

  const first = await service.record(
    { kind: "user", userId: "user-1" },
    completedFocusEvidence,
  );
  const replay = await service.record(
    { kind: "user", userId: "user-1" },
    {
      ...completedFocusEvidence,
      eventId: "event-focus-recreated",
    },
  );

  assert.equal(replay.receipt.receiptId, first.receipt.receiptId);
  assert.equal(replay.wasDuplicate, true);
  assert.equal(store.receiptCount, 1);
});

test("a source record cannot be reclassified into another rewarded activity", async () => {
  const store = new InMemoryActivityLedgerStore();
  const service = new ActivityLedgerService({ store });

  await service.record(
    { kind: "user", userId: "user-1" },
    completedFocusEvidence,
  );

  await assert.rejects(
    service.record(
      { kind: "user", userId: "user-1" },
      {
        ...completedFocusEvidence,
        eventId: "event-reclassified",
        activityCorrelationId: "exercise-2026-07-28",
        activityType: "exercise",
      },
    ),
    error =>
      error.name === "ActivityLedgerValidationError" &&
      error.message.includes("source record"),
  );
  assert.equal(store.receiptCount, 1);
});

test("app and health evidence with one correlation settle one reward", async () => {
  const store = new InMemoryActivityLedgerStore();
  const service = new ActivityLedgerService({
    store,
    clock: () => new Date("2026-07-28T09:25:01.000Z"),
  });

  const appResult = await service.record(
    { kind: "user", userId: "user-1" },
    completedFocusEvidence,
  );
  const healthResult = await service.record(
    { kind: "health_adapter", adapterId: "health-connect" },
    {
      ...completedFocusEvidence,
      eventId: "event-focus-health",
      sourceRecordId: "health-focus-1",
      sessionId: "health-session-focus-1",
      source: "health",
    },
  );

  assert.equal(healthResult.receipt.receiptId, appResult.receipt.receiptId);
  assert.equal(healthResult.wasDuplicate, true);
  assert.equal(store.receiptCount, 1);
});

test("user ingestion rejects spoofed device evidence and invalid dimensions", async () => {
  const service = new ActivityLedgerService({
    store: new InMemoryActivityLedgerStore(),
  });
  const principal = { kind: "user", userId: "user-1" };

  await assert.rejects(
    service.record(principal, {
      ...completedFocusEvidence,
      source: "device",
    }),
    error =>
      error.name === "ActivityLedgerAuthorizationError" &&
      error.message.includes("device"),
  );
  await assert.rejects(
    service.record(principal, {
      ...completedFocusEvidence,
      source: "health",
    }),
    error =>
      error.name === "ActivityLedgerAuthorizationError" &&
      error.message.includes("health"),
  );
  await assert.rejects(
    service.record(principal, {
      ...completedFocusEvidence,
      activityType: "gaming",
    }),
    error =>
      error.name === "ActivityLedgerValidationError" &&
      error.message.includes("activity type"),
  );
  await assert.rejects(
    service.record(principal, {
      ...completedFocusEvidence,
      roomIds: ["room-study", { roomId: "room-injected" }],
    }),
    error =>
      error.name === "ActivityLedgerValidationError" &&
      error.message.includes("Room IDs"),
  );
  await assert.rejects(
    service.record(principal, {
      ...completedFocusEvidence,
      metricValue: 2000,
    }),
    error =>
      error.name === "ActivityLedgerValidationError" &&
      error.message.includes("range"),
  );
  await assert.rejects(
    service.record(principal, {
      ...completedFocusEvidence,
      occurredAt: "2030-01-01T00:00:00.000Z",
    }),
    error =>
      error.name === "ActivityLedgerValidationError" &&
      error.message.includes("future"),
  );
});

test("an activity lifecycle is persisted and only terminal events settle", async () => {
  const store = new InMemoryActivityLedgerStore();
  const service = new ActivityLedgerService({
    store,
    clock: () => new Date("2026-07-28T09:25:01.000Z"),
  });
  const base = {
    ...completedFocusEvidence,
    eventId: "event-focus-start",
    sourceRecordId: "app-focus-start",
    eventType: "started",
    metricValue: 0,
    occurredAt: "2026-07-28T09:00:00.000Z",
  };

  const started = await service.record(
    { kind: "user", userId: "user-1" },
    base,
  );
  const paused = await service.record(
    { kind: "user", userId: "user-1" },
    {
      ...base,
      eventId: "event-focus-pause",
      sourceRecordId: "app-focus-pause",
      eventType: "paused",
      metricValue: 10,
      occurredAt: "2026-07-28T09:10:00.000Z",
    },
  );
  const resumed = await service.record(
    { kind: "user", userId: "user-1" },
    {
      ...base,
      eventId: "event-focus-resume",
      sourceRecordId: "app-focus-resume",
      eventType: "resumed",
      metricValue: 10,
      occurredAt: "2026-07-28T09:12:00.000Z",
    },
  );
  const completed = await service.record(
    { kind: "user", userId: "user-1" },
    completedFocusEvidence,
  );

  assert.equal(started.status, "accepted");
  assert.equal(started.receipt, null);
  assert.equal(paused.status, "accepted");
  assert.equal(resumed.status, "accepted");
  assert.equal(completed.status, "settled");
  assert.equal(completed.session.status, "completed");
  assert.equal(completed.session.metricValue, 25);
  assert.equal(store.receiptCount, 1);
});

test("only an approved membership active at occurrence time contributes", async () => {
  const store = new InMemoryActivityLedgerStore({
    roomMemberships: [
      {
        roomId: "room-study",
        userId: "user-1",
        approvalStatus: "approved",
        sharingConsented: true,
        activeFrom: "2026-07-28T08:00:00.000Z",
        activeUntil: "2026-07-28T10:00:00.000Z",
      },
    ],
  });
  const service = new ActivityLedgerService({ store });

  const result = await service.record(
    { kind: "user", userId: "user-1" },
    completedFocusEvidence,
  );

  assert.deepEqual(
    result.contributions.map(item => item.roomId),
    ["room-study"],
  );
});

test("membership and room status must both allow the contribution", async () => {
  const store = new InMemoryActivityLedgerStore({
    roomMemberships: [
      {
        roomId: "room-pending",
        userId: "user-1",
        status: "active",
        approvalStatus: "pending",
        roomStatus: "active",
      },
      {
        roomId: "room-closed",
        userId: "user-1",
        approvalStatus: "approved",
        roomStatus: "closed",
      },
    ],
  });
  const result = await new ActivityLedgerService({ store }).record(
    { kind: "user", userId: "user-1" },
    {
      ...completedFocusEvidence,
      roomIds: ["room-pending", "room-closed"],
    },
  );

  assert.deepEqual(result.contributions, []);
});

test("rooms requiring sharing consent fail closed", async () => {
  const store = new InMemoryActivityLedgerStore({
    roomMemberships: [
      {
        roomId: "room-missing-consent",
        userId: "user-1",
        approvalStatus: "approved",
        roomStatus: "active",
        sharingConsentRequired: true,
      },
      {
        roomId: "room-denied-consent",
        userId: "user-1",
        approvalStatus: "approved",
        roomStatus: "active",
        sharingConsentRequired: true,
        sharingConsented: false,
      },
      {
        roomId: "room-approved-consent",
        userId: "user-1",
        approvalStatus: "approved",
        roomStatus: "active",
        sharingConsentRequired: true,
        sharingConsented: true,
      },
    ],
  });
  const result = await new ActivityLedgerService({ store }).record(
    { kind: "user", userId: "user-1" },
    {
      ...completedFocusEvidence,
      roomIds: [
        "room-missing-consent",
        "room-denied-consent",
        "room-approved-consent",
      ],
    },
  );

  assert.deepEqual(
    result.contributions.map(item => item.roomId),
    ["room-approved-consent"],
  );
});

test("a replay cannot use a later occurrence time to backfill a room", async () => {
  const store = new InMemoryActivityLedgerStore({
    roomMemberships: [
      {
        roomId: "room-later",
        userId: "user-1",
        approvalStatus: "approved",
        roomStatus: "active",
        activeFrom: "2026-07-28T09:30:00.000Z",
      },
    ],
  });
  const service = new ActivityLedgerService({ store });
  await service.record(
    { kind: "user", userId: "user-1" },
    {
      ...completedFocusEvidence,
      roomIds: [],
    },
  );
  const replay = await service.record(
    { kind: "health_adapter", adapterId: "health-connect" },
    {
      ...completedFocusEvidence,
      eventId: "event-health-after-join",
      sourceRecordId: "health-after-join",
      sessionId: "health-after-join",
      source: "health",
      roomIds: ["room-later"],
      occurredAt: "2026-07-28T09:45:00.000Z",
    },
  );

  assert.deepEqual(replay.contributions, []);
});

test("zero and unverified custom activities settle without reward issuance", async () => {
  const service = new ActivityLedgerService({
    store: new InMemoryActivityLedgerStore(),
  });
  const zero = await service.record(
    { kind: "user", userId: "user-1" },
    {
      ...completedFocusEvidence,
      metricValue: 0,
    },
  );
  const custom = await service.record(
    { kind: "user", userId: "user-1" },
    {
      ...completedFocusEvidence,
      eventId: "event-custom",
      sourceRecordId: "source-custom",
      sessionId: "session-custom",
      activityCorrelationId: "custom-correlation",
      activityType: "custom",
      metricUnit: "check-ins",
      metricValue: 1,
    },
  );

  assert.equal(zero.receipt.rewardEligible, false);
  assert.equal(zero.receipt.rewardIssued, false);
  assert.equal(zero.receipt.characterExperienceEligible, false);
  assert.equal(zero.receipt.characterExperienceIssued, false);
  assert.equal(custom.receipt.rewardEligible, false);
  assert.equal(custom.receipt.rewardIssued, false);
  assert.equal(custom.receipt.characterExperienceEligible, false);
  assert.equal(custom.receipt.characterExperienceIssued, false);
});

test("discarding a session is terminal and never settles a receipt", async () => {
  const store = new InMemoryActivityLedgerStore();
  const service = new ActivityLedgerService({ store });
  const started = await service.record(
    { kind: "user", userId: "user-1" },
    {
      ...completedFocusEvidence,
      eventId: "event-discard-start",
      sourceRecordId: "source-discard-start",
      sessionId: "session-discard",
      activityCorrelationId: "discard-correlation",
      eventType: "started",
      metricValue: 0,
    },
  );
  const discarded = await service.record(
    { kind: "user", userId: "user-1" },
    {
      ...completedFocusEvidence,
      eventId: "event-discard",
      sourceRecordId: "source-discard",
      sessionId: "session-discard",
      activityCorrelationId: "discard-correlation",
      eventType: "discarded",
      metricValue: 5,
    },
  );

  assert.equal(started.session.status, "active");
  assert.equal(discarded.session.status, "discarded");
  assert.equal(discarded.receipt, null);
  assert.equal(store.receiptCount, 0);
  await assert.rejects(
    service.record(
      { kind: "user", userId: "user-1" },
      {
        ...completedFocusEvidence,
        eventId: "event-after-discard",
        sourceRecordId: "source-after-discard",
        sessionId: "session-discard",
        activityCorrelationId: "discard-correlation",
      },
    ),
    /discarded activity session cannot change state/i,
  );
});

test("activity identifiers are canonicalized before idempotency", async () => {
  const service = new ActivityLedgerService({
    store: new InMemoryActivityLedgerStore(),
  });
  const result = await service.record(
    { kind: "user", userId: "user-1" },
    {
      ...completedFocusEvidence,
      eventId: " event-canonical ",
      sourceRecordId: " source-canonical ",
      sessionId: " session-canonical ",
      activityCorrelationId: " correlation-canonical ",
    },
  );

  assert.equal(result.acknowledgedEventId, "event-canonical");
  assert.equal(result.acknowledgedSourceRecordId, "source-canonical");
  assert.equal(result.canonicalSessionId, "correlation-canonical");
});

test("one receipt can add a later eligible room without another reward", async () => {
  const store = new InMemoryActivityLedgerStore({
    roomMemberships: [
      {
        roomId: "room-a",
        userId: "user-1",
        approvalStatus: "approved",
      },
      {
        roomId: "room-b",
        userId: "user-1",
        approvalStatus: "approved",
      },
    ],
  });
  const service = new ActivityLedgerService({ store });
  const first = await service.record(
    { kind: "user", userId: "user-1" },
    {
      ...completedFocusEvidence,
      roomIds: ["room-a"],
    },
  );
  const second = await service.record(
    { kind: "health_adapter", adapterId: "health-connect" },
    {
      ...completedFocusEvidence,
      eventId: "event-focus-health-room-b",
      sourceRecordId: "health-focus-room-b",
      sessionId: "health-session-room-b",
      source: "health",
      roomIds: ["room-b"],
    },
  );
  const replay = await service.record(
    { kind: "user", userId: "user-1" },
    {
      ...completedFocusEvidence,
      roomIds: ["room-a"],
    },
  );

  assert.equal(second.receipt.receiptId, first.receipt.receiptId);
  assert.deepEqual(
    second.contributions.map(item => item.roomId).sort(),
    ["room-a", "room-b"],
  );
  assert.deepEqual(
    replay.contributions.map(item => item.roomId).sort(),
    ["room-a", "room-b"],
  );
  assert.equal(second.wasDuplicate, true);
  assert.equal(store.receiptCount, 1);
});

test("health snapshots correct one logical daily metric before finalization", async () => {
  const store = new InMemoryActivityLedgerStore();
  const service = new ActivityLedgerService({
    store,
    clock: () => new Date("2026-07-28T12:00:00.000Z"),
  });
  const principal = {
    kind: "health_adapter",
    adapterId: "mobile-health-connect",
    allowedActorUserId: "user-1",
  };
  const firstEvidence = {
    eventId: "health-steps-snapshot-1",
    sourceRecordId: "health-steps-source-1",
    sessionId: "health-steps-2026-07-28",
    activityCorrelationId: "health-steps-2026-07-28",
    actorUserId: "user-1",
    roomIds: [],
    activityType: "steps",
    source: "health",
    eventType: "metricSynced",
    metricValue: 1200,
    metricUnit: "steps",
    occurredAt: "2026-07-28T10:00:00.000Z",
    healthContext: {
      provider: "healthConnect",
      localDate: "2026-07-28",
      periodStart: "2026-07-27T16:00:00.000Z",
      periodEnd: "2026-07-28T10:00:00.000Z",
      dataOrigins: ["android"],
    },
  };

  const first = await service.record(principal, firstEvidence);
  const corrected = await service.record(principal, {
    ...firstEvidence,
    eventId: "health-steps-snapshot-2",
    sourceRecordId: "health-steps-source-2",
    metricValue: 1800,
    occurredAt: "2026-07-28T11:00:00.000Z",
    healthContext: {
      ...firstEvidence.healthContext,
      periodEnd: "2026-07-28T11:00:00.000Z",
    },
  });
  const finalized = await service.record(principal, {
    ...firstEvidence,
    eventId: "health-steps-final",
    sourceRecordId: "health-steps-final",
    eventType: "completed",
    metricValue: 1800,
    occurredAt: "2026-07-28T11:30:00.000Z",
    healthContext: {
      ...firstEvidence.healthContext,
      periodEnd: "2026-07-28T11:30:00.000Z",
    },
  });

  assert.equal(first.status, "settled");
  assert.equal(first.session.status, "active");
  assert.equal(first.receipt.rewardEligible, false);
  assert.equal(corrected.receipt.acceptedMetric, 1800);
  assert.equal(
    corrected.receipt.correctionOfReceiptId,
    first.receipt.receiptId,
  );
  assert.equal(corrected.receipt.rewardEligible, false);
  assert.equal(finalized.session.status, "completed");
  assert.equal(
    finalized.receipt.correctionOfReceiptId,
    corrected.receipt.receiptId,
  );
  assert.equal(finalized.receipt.rewardEligible, true);
  assert.equal(store.receiptCount, 3);
});

test("a mobile health adapter is bound to its authenticated actor", async () => {
  const service = new ActivityLedgerService({
    store: new InMemoryActivityLedgerStore(),
  });

  await assert.rejects(
    service.record(
      {
        kind: "health_adapter",
        adapterId: "mobile-health-connect",
        allowedActorUserId: "user-1",
      },
      {
        ...completedFocusEvidence,
        actorUserId: "user-2",
        source: "health",
      },
    ),
    error =>
      error.name === "ActivityLedgerAuthorizationError" &&
      error.message.includes("assigned actor"),
  );
});
