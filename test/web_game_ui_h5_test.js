const { test } = require("node:test");
const assert = require("node:assert/strict");
const { readFileSync } = require("node:fs");
const page = readFileSync("web_dashboard/mailbox.html", "utf8");
const moduleSource = readFileSync("web_dashboard/assets/post_office_scene.js", "utf8");
test("H5 objects use their existing feature entry points and respect reduced motion", () => {
  for (const selector of ["href=\"#mailboxDrawer\"","data-mailbox-drawer"]) assert.ok(page.includes(selector), selector);
  for (const behavior of ["destination.open = true","motion.matches || document.hidden || !visible"]) assert.ok(moduleSource.includes(behavior), behavior);
});
