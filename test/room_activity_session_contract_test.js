const test = require("node:test");
const assert = require("node:assert/strict");
const contract = require("../web_dashboard/assets/room_activity_session_contract.js");

const startedAt = "2026-07-27T09:00:00.000Z";

test("web room session contract follows member-controlled transitions", () => {
  const started = contract.start({
    sessionId: "session-alice-focus",
    roomId: "room-study",
    actorId: "alice",
    activityKind: "focus",
    metricUnit: "minutes",
    targetValue: 25,
    source: "web",
    now: startedAt,
  });
  const paused = contract.transition(started, {
    actorId: "alice",
    nextStatus: "paused",
    metricValue: 10,
    now: "2026-07-27T09:10:00.000Z",
  });
  const completed = contract.transition(paused, {
    actorId: "alice",
    nextStatus: "completed",
    metricValue: 25,
    now: "2026-07-27T09:28:00.000Z",
  });

  assert.equal(started.status, "active");
  assert.equal(paused.status, "paused");
  assert.equal(completed.status, "completed");
  assert.equal(completed.endedAt, "2026-07-27T09:28:00.000Z");
});

test("web contract rejects owner control and terminal replay", () => {
  const started = contract.start({
    sessionId: "session-alice-steps",
    roomId: "room-steps",
    actorId: "alice",
    activityKind: "steps",
    metricUnit: "steps",
    targetValue: 8000,
    source: "health",
    now: startedAt,
  });
  assert.throws(() =>
    contract.transition(started, {
      actorId: "room-owner",
      nextStatus: "completed",
      metricValue: 8000,
      now: "2026-07-27T18:00:00.000Z",
    }),
  );

  const completed = contract.transition(started, {
    actorId: "alice",
    nextStatus: "completed",
    metricValue: 8000,
    now: "2026-07-27T18:00:00.000Z",
  });
  assert.throws(() =>
    contract.transition(completed, {
      actorId: "alice",
      nextStatus: "active",
      metricValue: 8000,
      now: "2026-07-27T18:01:00.000Z",
    }),
  );
});
