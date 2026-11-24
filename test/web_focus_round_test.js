const test = require("node:test");
const assert = require("node:assert/strict");
const round = require("../web_dashboard/assets/focus_round_core.js");

test("a shared round has one focus deadline and one break deadline", () => {
  const startAt = { toMillis: () => 0 };
  const record = round.newRound("member", startAt);
  assert.deepEqual(record, { startedBy: "member", startAt, durationMin: 25, breakMin: 5 });
  assert.deepEqual(round.snapshot(record, 0), { phase: "focus", remaining: 1500 });
  assert.deepEqual(round.snapshot(record, 1499999), { phase: "focus", remaining: 1 });
  assert.deepEqual(round.snapshot(record, 1500000), { phase: "break", remaining: 300 });
  assert.deepEqual(round.snapshot(record, 1800000), { phase: "idle", remaining: 0 });
  assert.deepEqual(round.snapshot(undefined, 0), { phase: "idle", remaining: 0 });
});
