const { test } = require("node:test");
const assert = require("node:assert/strict");
const { readFileSync } = require("node:fs");
const page = readFileSync("web_dashboard/group-hall.html", "utf8");
const moduleSource = readFileSync("web_dashboard/assets/community_ground.js", "utf8");
test("H4 objects use their existing feature entry points and respect reduced motion", () => {
  for (const selector of ["data-community-open=\"calendar\"","data-community-open=\"challenge\"","data-community-open=\"office\""]) assert.ok(page.includes(selector), selector);
  for (const behavior of ["manager.hidden || calendar.hidden","panel.parentElement.closest(\"[hidden]\")","motion.matches || document.hidden || !visible"]) assert.ok(moduleSource.includes(behavior), behavior);
});
