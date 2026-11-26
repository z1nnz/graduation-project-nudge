const test = require("node:test"),
  assert = require("node:assert/strict"),
  core = require("../web_dashboard/assets/library_scene_core.js");
test("library Monday weeks use Taipei 05:00 rather than calendar midnight", () => {
  const a = core.shelf(
    [
      {
        id: "a",
        type: "focus",
        value: 25,
        endedAt: "2026-11-22T20:59:59.999Z",
      },
      {
        id: "b",
        type: "focus",
        value: 50,
        endedAt: "2026-11-22T21:00:00.000Z",
      },
    ],
    "2026-11-23T08:00:00.000Z",
    2,
  );
  assert.equal(a.books[0].focus, 25);
  assert.equal(a.books[1].focus, 50);
  assert.equal(a.books[1].start, "2026-11-23");
});
test("books retain empty weeks, deduplicate receipts and never carry private fields into display models", () => {
  const row = {
    id: "a",
    type: "focus",
    value: 60,
    endedAt: "2026-11-23T08:00:00.000Z",
    userId: "PRIVATE",
    email: "SECRET",
  };
  const s = core.shelf([row, row], "2026-11-24T08:00:00.000Z", 2);
  assert.equal(s.books[0].empty, true);
  assert.equal(s.books[1].focus, 60);
  assert.doesNotMatch(JSON.stringify(s), /PRIVATE|SECRET/);
  assert.ok(s.books[1].thickness > s.books[0].thickness);
});
test("each metric preserves its original unit and actual values, future and withdrawn actions excluded upstream", () => {
  const rows = [
    ["focus", 25],
    ["sleep", 7.5],
    ["steps", 2500],
    ["task", 1],
  ].map(([type, value], i) => ({
    id: String(i),
    type,
    value,
    endedAt: "2026-11-23T08:00:00.000Z",
  }));
  rows.push({
    id: "future",
    type: "focus",
    value: 50,
    endedAt: "2026-11-25T08:00:00.000Z",
  });
  const b = core.shelf(rows, "2026-11-24T08:00:00.000Z", 1).books[0];
  assert.deepEqual([b.focus, b.sleep, b.steps, b.tasks], [25, 7.5, 2500, 1]);
  assert.equal(b.days.length, 7);
});
