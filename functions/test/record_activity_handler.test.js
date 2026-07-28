import assert from "node:assert/strict";
import test from "node:test";

import {
  ActivityLedgerService,
  InMemoryActivityLedgerStore,
} from "../src/activity-ledger-service.js";
import { createRecordActivityHandler } from "../src/record-activity-handler.js";

const evidence = {
  eventId: "event-web-focus-1",
  sourceRecordId: "web-focus-1",
  sessionId: "web-session-focus-1",
  activityCorrelationId: null,
  actorUserId: "user-1",
  roomIds: [],
  activityType: "focus",
  source: "web",
  eventType: "completed",
  metricValue: 30,
  metricUnit: "minutes",
  occurredAt: "2026-07-28T10:30:00.000Z",
};

test("the Cloud activity handler rejects unauthenticated submissions", async () => {
  const service = new ActivityLedgerService({
    store: new InMemoryActivityLedgerStore(),
  });
  const handler = createRecordActivityHandler({ service });

  await assert.rejects(
    handler({ auth: null, data: { evidence } }),
    /authenticated user is required/i,
  );
});

test("the Cloud activity handler binds evidence to the authenticated user", async () => {
  const service = new ActivityLedgerService({
    store: new InMemoryActivityLedgerStore(),
  });
  const handler = createRecordActivityHandler({ service });

  const result = await handler({
    auth: { uid: "user-1", token: {} },
    data: { evidence },
  });

  assert.equal(result.status, "settled");
  assert.equal(result.receipt.actorUserId, "user-1");
});
