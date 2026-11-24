import assert from "node:assert/strict";
import test from "node:test";
import { familyReviewDate, gardenStages, createFamilyGardenHandler } from "../src/family-garden-service.js";

test("the weekly review switches at 18:00 Taiwan time on Sunday", () => {
  assert.equal(familyReviewDate(new Date("2026-11-22T09:59:59Z")), "2026-11-15");
  assert.equal(familyReviewDate(new Date("2026-11-22T10:00:00Z")), "2026-11-22");
  assert.equal(familyReviewDate(new Date("2026-11-23T00:00:00Z")), "2026-11-22");
});

test("the garden exposes only capped stages for completed consented activity", () => {
  const sessions = [
    ...Array.from({ length: 5 }, () => ({ status: "completed", activityKind: "focus", metricValue: 25 })),
    { status: "completed", activityKind: "exercise", metricValue: 40 },
    { status: "active", activityKind: "exercise", metricValue: 40 },
    { status: "completed", activityKind: "sleep", metricValue: 8, startedAt: "2026-11-21T14:00:00Z", endedAt: "2026-11-21T22:00:00Z" },
    { status: "completed", activityKind: "sleep", metricValue: 8, startedAt: "2026-11-21T15:00:00Z", endedAt: "2026-11-21T22:00:00Z" },
  ];
  assert.deepEqual(gardenStages(sessions, { summary: true, healthTrends: true }),
    { sunflower: 3, sapling: 1, moonflower: 1 });
  assert.deepEqual(gardenStages(sessions, { summary: true, healthTrends: false }),
    { sunflower: 3, sapling: 0, moonflower: 0 });
  assert.deepEqual(gardenStages(sessions, {}), { sunflower: 0, sapling: 0, moonflower: 0 });
});

test("no family operation can use an unauthenticated request", async () => {
  const call = createFamilyGardenHandler(null);
  await assert.rejects(call({ data: { action: "view", linkId: "family" } }),
    { code: "unauthenticated" });
});
