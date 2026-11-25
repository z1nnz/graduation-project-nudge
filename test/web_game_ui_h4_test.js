const { test } = require("node:test");
const assert = require("node:assert/strict");
const { readFileSync } = require("node:fs");
const { guildMuralProgress } = require('../web_dashboard/assets/family_group_scenes.js');
const page = readFileSync("web_dashboard/group-hall.html", "utf8");
const moduleSource = readFileSync("web_dashboard/assets/community_ground.js", "utf8");
test("H4 objects use their existing feature entry points and respect reduced motion", () => {
  for (const selector of ["data-community-open=\"calendar\"","data-community-open=\"challenge\"","data-community-open=\"office\""]) assert.ok(page.includes(selector), selector);
  for (const behavior of ["manager.hidden || calendar.hidden","panel.parentElement.closest(\"[hidden]\")","motion.matches || document.hidden || !visible"]) assert.ok(moduleSource.includes(behavior), behavior);
});

test("the challenge mural exposes only the current aggregate", () => {
  const challenge = { challengeId: "current", status: "active", days: 4 };
  const rows = [
    { challengeId: "current", status: "joined", completedDays: 1, memberId: "person-a" },
    { challengeId: "current", status: "completed", completedDays: 4, memberId: "person-b" },
    { challengeId: "previous", status: "completed", completedDays: 4, memberId: "person-c" },
  ];
  assert.deepEqual(guildMuralProgress(challenge, rows), { done: 5, target: 8 });
  assert.deepEqual(guildMuralProgress({ ...challenge, status: "closed" }, rows), { done: 0, target: 0 });
});
