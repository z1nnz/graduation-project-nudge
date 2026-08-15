import test from "node:test";
import assert from "node:assert/strict";

import {
  buildDisciplineIdentitySnapshot,
  createRefreshDisciplineIdentityHandler,
  disciplineDayKey,
} from "../src/discipline-identity-service.js";

function completedSession({
  actorUserId = "user-1",
  activityType = "focus",
  endedAt,
  metricValue = 25,
  metricUnit = "minutes",
}) {
  return {
    actorUserId,
    activityType,
    status: "completed",
    startedAt: endedAt,
    endedAt,
    metricValue,
    metricUnit,
  };
}

test("discipline day follows the Taipei 05:00 boundary", () => {
  assert.equal(
    disciplineDayKey(new Date("2026-08-14T20:59:59.000Z")),
    "2026-08-14",
  );
  assert.equal(
    disciplineDayKey(new Date("2026-08-14T21:00:00.000Z")),
    "2026-08-15",
  );
});

test("an empty ledger produces a private starting snapshot", () => {
  const snapshot = buildDisciplineIdentitySnapshot({
    userId: "user-1",
    sessions: [],
    now: new Date("2026-08-15T10:00:00.000Z"),
  });

  assert.equal(snapshot.snapshotId, "user-1");
  assert.equal(snapshot.persona.key, "starting_seed");
  assert.equal(snapshot.recovery.state, "starting");
  assert.equal(snapshot.recovery.recommendedFocusMinutes, 10);
  assert.equal(snapshot.metrics.activeDays, 0);
  assert.equal(snapshot.visibility, "private");
});

test("five active days form a steady builder identity", () => {
  const sessions = [10, 11, 12, 13, 14].map(day =>
    completedSession({ endedAt: `2026-08-${day}T10:00:00.000Z` })
  );
  const snapshot = buildDisciplineIdentitySnapshot({
    userId: "user-1",
    sessions,
    now: new Date("2026-08-15T10:00:00.000Z"),
  });

  assert.equal(snapshot.persona.key, "steady_builder");
  assert.equal(snapshot.metrics.activeDays, 5);
  assert.equal(snapshot.metrics.completedSessions, 5);
  assert.equal(snapshot.metrics.focusMinutes, 125);
  assert.equal(snapshot.recovery.state, "gentle_return");
});

test("returning after a gap becomes a comeback builder without erasing history", () => {
  const snapshot = buildDisciplineIdentitySnapshot({
    userId: "user-1",
    sessions: [
      completedSession({ endedAt: "2026-08-10T10:00:00.000Z" }),
      completedSession({
        activityType: "exercise",
        endedAt: "2026-08-15T09:30:00.000Z",
        metricValue: 15,
      }),
    ],
    now: new Date("2026-08-15T10:00:00.000Z"),
  });

  assert.equal(snapshot.persona.key, "comeback_builder");
  assert.equal(snapshot.recovery.state, "returning");
  assert.equal(snapshot.recovery.recommendedFocusMinutes, 15);
  assert.equal(snapshot.metrics.activeDays, 2);
  assert.equal(snapshot.metrics.lastActiveDay, "2026-08-15");
});

test("snapshot rejects unrelated and non-completed ledger records", () => {
  const snapshot = buildDisciplineIdentitySnapshot({
    userId: "user-1",
    sessions: [
      completedSession({
        actorUserId: "other-user",
        endedAt: "2026-08-15T09:00:00.000Z",
      }),
      {
        ...completedSession({ endedAt: "2026-08-15T09:00:00.000Z" }),
        status: "discarded",
      },
      completedSession({
        endedAt: "2026-08-15T09:00:00.000Z",
        metricValue: -1,
      }),
      completedSession({ endedAt: "2026-06-01T09:00:00.000Z" }),
    ],
    now: new Date("2026-08-15T10:00:00.000Z"),
  });

  assert.equal(snapshot.metrics.completedSessions, 0);
  assert.equal(snapshot.persona.key, "starting_seed");
});

test("authenticated refresh reads canonical sessions and saves one snapshot", async () => {
  const saved = [];
  const repository = {
    async listCompletedSessions(userId, windowStartedAt) {
      assert.equal(userId, "user-1");
      assert.equal(windowStartedAt, "2026-07-18T21:00:00.000Z");
      return [
        completedSession({ endedAt: "2026-08-15T09:00:00.000Z" }),
      ];
    },
    async saveSnapshot(snapshot) {
      saved.push(snapshot);
    },
  };
  const handler = createRefreshDisciplineIdentityHandler({
    repository,
    clock: () => new Date("2026-08-15T10:00:00.000Z"),
  });

  const result = await handler({ auth: { uid: "user-1" } });

  assert.equal(result.snapshot.userId, "user-1");
  assert.equal(result.snapshot.recovery.state, "returning");
  assert.equal(saved.length, 1);
  assert.deepEqual(saved[0], result.snapshot);
});

test("refresh requires authentication", async () => {
  const handler = createRefreshDisciplineIdentityHandler({
    repository: {
      listCompletedSessions: async () => [],
      saveSnapshot: async () => {},
    },
  });

  await assert.rejects(
    () => handler({}),
    error => error.code === "unauthenticated",
  );
});

test("refresh fails closed instead of publishing a truncated identity", async () => {
  const handler = createRefreshDisciplineIdentityHandler({
    repository: {
      listCompletedSessions: async () => Array.from({ length: 501 }, () =>
        completedSession({ endedAt: "2026-08-15T09:00:00.000Z" })
      ),
      saveSnapshot: async () => assert.fail("must not save a partial snapshot"),
    },
    clock: () => new Date("2026-08-15T10:00:00.000Z"),
  });

  await assert.rejects(
    () => handler({ auth: { uid: "user-1" } }),
    error => error.code === "resource-exhausted",
  );
});
