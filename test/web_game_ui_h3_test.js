const { test } = require("node:test");
const assert = require("node:assert/strict");
const { readFileSync } = require("node:fs");
const page = readFileSync("web_dashboard/town-goals.html", "utf8");
const moduleSource = readFileSync("web_dashboard/assets/social_plaza_ground.js", "utf8");
test("H3 objects use their existing feature entry points and respect reduced motion", () => {
  for (const selector of ["data-plaza-panel=\"goal\"","data-plaza-panel=\"board\"","data-plaza-panel=\"post\"","data-plaza-panel=\"friends\""]) assert.ok(page.includes(selector), selector);
  for (const behavior of ["panel.showModal()","motion.matches || document.hidden || !visible",".focus()"]) assert.ok(moduleSource.includes(behavior), behavior);
});
