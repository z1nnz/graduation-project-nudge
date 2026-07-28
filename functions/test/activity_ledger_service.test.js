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
  assert.equal(first.receipt.rewardIssued, true);
  assert.equal(first.receipt.characterExperienceIssued, true);
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

  assert.equal(zero.receipt.rewardIssued, false);
  assert.equal(zero.receipt.characterExperienceIssued, false);
  assert.equal(custom.receipt.rewardIssued, false);
  assert.equal(custom.receipt.characterExperienceIssued, false);
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
