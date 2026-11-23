const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const read = relativePath => fs.readFileSync(path.join(root, relativePath), "utf8");
const scenes = require("../web_dashboard/assets/family_group_scenes.js");

const allOff = { summary: false, weeklyReport: false, taskCategories: false, healthTrends: false };

test("weekly report export contains only currently consented fields", () => {
  const summary = { childId: "c", summary: "穩定", weeklyReport: "5 天", taskCategories: ["讀書"], healthTrends: "睡眠穩定", secret: "x" };
  assert.deepEqual(scenes.consentedReport(summary, { ...allOff, weeklyReport: true }), { weeklyReport: "5 天" });
  assert.deepEqual(scenes.consentedReport(summary, allOff), {});
  assert.deepEqual(scenes.consentedReport(null, { ...allOff, summary: true }), {});
  assert.equal(scenes.hasAnyConsent(allOff), false);
});

test("revoking consent also strips the revoked field from the summary write", () => {
  const scopes = scenes.nextConsentScopes({ ...allOff, summary: true, healthTrends: true }, "healthTrends", false);
  assert.deepEqual(scopes, { ...allOff, summary: true });
  const next = scenes.summaryAfterConsent({
    currentSummary: { summary: "穩定", healthTrends: "睡眠穩定" }, scopes, childId: "c", now: new Date("2026-11-23T00:00:00Z"),
  });
  assert.deepEqual(next, { schemaVersion: 1, childId: "c", updatedAt: "2026-11-23T00:00:00.000Z", summary: "穩定" });
  assert.throws(() => scenes.nextConsentScopes(allOff, "precise_location", true));
});

test("bond events are idempotent per encouragement or goal", () => {
  assert.equal(scenes.bondEventId("acknowledgement", "e1"), "encouragement_e1");
  assert.equal(scenes.bondEventId("goalCompleted", "g1"), "goal_g1");
});

test("group results count only member-shared summaries", () => {
  const digest = scenes.groupResultDigest([
    { status: "shared", summary: { disciplineScore: 80, completedTasks: 3 } },
    { status: "shared", summary: { disciplineScore: 60, completedTasks: 1 } },
    { status: "withdrawn", summary: { disciplineScore: 0, completedTasks: 99 } },
  ]);
  assert.deepEqual(digest, { sharedCount: 2, averageScore: 70, completedTasks: 4 });
  assert.equal(scenes.groupResultDigest([]).averageScore, null);
});

test("members join and check in to a challenge themselves, never past its length", () => {
  const challenge = { challengeId: "c1", days: 2 };
  const joined = scenes.nextParticipation({ current: null, challenge, memberId: "m", groupId: "g", now: new Date("2026-11-23T00:00:00Z") });
  assert.equal(joined.status, "joined");
  assert.equal(joined.completedDays, 0);
  const day1 = scenes.nextParticipation({ current: joined, challenge, memberId: "m", groupId: "g" });
  assert.equal(day1.completedDays, 1);
  assert.equal(day1.completedAt, undefined);
  const day2 = scenes.nextParticipation({ current: day1, challenge, memberId: "m", groupId: "g" });
  assert.equal(day2.status, "completed");
  assert.equal(scenes.nextParticipation({ current: day2, challenge, memberId: "m", groupId: "g" }), null);
  const rejoined = scenes.nextParticipation({ current: day2, challenge: { challengeId: "c2", days: 3 }, memberId: "m", groupId: "g" });
  assert.equal(rejoined.completedDays, 0);
});

test("courtyard and hall pages are wired to the scene module without touching app.js", () => {
  const family = read("web_dashboard/family-courtyard.html");
  const group = read("web_dashboard/group-hall.html");
  for (const html of [family, group]) {
    assert.match(html, /data-social-scene/);
    assert.match(html, /data-town-return|data-world-return/);
    assert.ok(html.indexOf("family_group_scenes.js") < html.indexOf("assets/app.js"));
  }
  assert.match(family, /data-page="family-courtyard"/);
  assert.match(group, /data-page="group-hall"/);
  const facilities = require("../web_dashboard/assets/social_scene.js").SCENES;
  assert.ok(facilities.family.rooms.some(([href]) => href === "family-courtyard.html"));
  assert.ok(facilities.guild.rooms.some(([href]) => href === "group-hall.html"));
  const script = read("web_dashboard/assets/family_group_scenes.js");
  assert.doesNotMatch(script, /collection\("users"\)/);
  assert.doesNotMatch(script, /addCoins|grantXp|avatarXp|coins\s*[:+=]/i);
  assert.match(script, /refreshRelationshipOutcome/);
});
