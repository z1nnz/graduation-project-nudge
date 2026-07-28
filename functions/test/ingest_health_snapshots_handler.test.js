import assert from "node:assert/strict";
import test from "node:test";

import {
  ActivityLedgerService,
  InMemoryActivityLedgerStore,
} from "../src/activity-ledger-service.js";
import { createIngestHealthSnapshotsHandler } from "../src/ingest-health-snapshots-handler.js";

function snapshot(overrides = {}) {
  return {
    activityType: "steps",
    metricValue: 4321,
    metricUnit: "steps",
    localDate: "2026-07-28",
    periodStart: "2026-07-27T16:00:00.000Z",
    periodEnd: "2026-07-28T09:00:00.000Z",
    observedAt: "2026-07-28T09:00:00.000Z",
    dataOrigins: ["android"],
    roomIds: [],
    ...overrides,
  };
}

test("health snapshot ingestion requires an authenticated user", async () => {
  const handler = createIngestHealthSnapshotsHandler({
    service: new ActivityLedgerService({
      store: new InMemoryActivityLedgerStore(),
    }),
  });

  await assert.rejects(
    handler({
      auth: null,
      data: { provider: "healthConnect", snapshots: [snapshot()] },
    }),
    /authenticated user is required/i,
  );
});

test("health snapshot ingestion binds actor and deduplicates a replay", async () => {
  const store = new InMemoryActivityLedgerStore();
  const handler = createIngestHealthSnapshotsHandler({
    service: new ActivityLedgerService({
      store,
      clock: () => new Date("2026-07-28T09:01:00.000Z"),
    }),
    clock: () => new Date("2026-07-28T09:01:00.000Z"),
  });
  const request = {
    auth: { uid: "user-1", token: {} },
    data: { provider: "healthConnect", snapshots: [snapshot()] },
  };

  const first = await handler(request);
  const replay = await handler(request);

  assert.equal(first.accepted, 1);
  assert.equal(first.results[0].receipt.actorUserId, "user-1");
  assert.equal(first.results[0].receipt.rewardEligible, false);
  assert.equal(replay.results[0].wasDuplicate, true);
  assert.equal(
    replay.results[0].receipt.receiptId,
    first.results[0].receipt.receiptId,
  );
  assert.equal(store.receiptCount, 1);
});

test("health snapshot ingestion rejects malformed provider contracts", async () => {
  const handler = createIngestHealthSnapshotsHandler({
    service: new ActivityLedgerService({
      store: new InMemoryActivityLedgerStore(),
    }),
    clock: () => new Date("2026-07-28T09:01:00.000Z"),
  });

  await assert.rejects(
    handler({
      auth: { uid: "user-1", token: {} },
      data: {
        provider: "unknown-health-source",
        snapshots: [snapshot()],
      },
    }),
    /provider/i,
  );
  await assert.rejects(
    handler({
      auth: { uid: "user-1", token: {} },
      data: {
        provider: "healthConnect",
        snapshots: [snapshot({ metricUnit: "minutes" })],
      },
    }),
    /metric unit/i,
  );
});
