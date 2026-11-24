const { test } = require("node:test");
const assert = require("node:assert/strict");
const { readFileSync } = require("node:fs");
const page = readFileSync("web_dashboard/rooms.html", "utf8");
const moduleSource = readFileSync("web_dashboard/assets/study_hall.js", "utf8");
test("H2 objects use their existing feature entry points and respect reduced motion", () => {
  for (const selector of ["id=\"focusRoundTitle\" tabindex=\"-1\""]) assert.ok(page.includes(selector), selector);
  for (const behavior of ["roomClock()","motion.matches ? 0 : 360","if (!focusPanel.hidden)","state.available && room.roomType === \"study\""]) assert.ok(moduleSource.includes(behavior), behavior);
});
