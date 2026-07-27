const test = require("node:test");
const assert = require("node:assert/strict");
const path = require("node:path");
const { pathToFileURL } = require("node:url");

const moduleUrl = pathToFileURL(
  path.resolve(__dirname, "../scripts/backfill_public_profiles.js"),
).href;

test("public profile backfill strips private and local-only user fields", async () => {
  const { buildPublicProfile } = await import(moduleUrl);
  const payload = buildPublicProfile(
    "member-1",
    {
      username: "NDG_MEMBER",
      nickname: "小樹",
      signature: "穩定前進",
      userRole: "child",
      focusSeconds: 90000,
      planetCount: 3,
      avatarProfile: {
        faceShapeIndex: 2,
        avatarIconIndex: 5,
        customImagePath: "/Users/example/private/avatar.png",
      },
      tasks: [{ title: "私人任務" }],
      dailySummaries: [{ sleepHours: 7.5, steps: 8000 }],
      groupId: "PRIVATE-GROUP",
    },
    new Date("2026-07-27T00:00:00.000Z"),
  );

  assert.equal(payload.familyRole, "child");
  assert.equal(payload.avatarProfile.faceShapeIndex, 2);
  assert.equal(payload.avatarProfile.avatarIconIndex, 5);
  assert.equal(payload.updatedAt, "2026-07-27T00:00:00.000Z");
  assert.ok(!("tasks" in payload));
  assert.ok(!("dailySummaries" in payload));
  assert.ok(!("focusSeconds" in payload));
  assert.ok(!("isStudying" in payload));
  assert.ok(!("groupId" in payload));
  assert.ok(!("customImagePath" in payload.avatarProfile));
});
