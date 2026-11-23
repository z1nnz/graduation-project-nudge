const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const root = path.resolve(__dirname, "..");
const town = require("../web_dashboard/assets/town.js");

test("town movement stays within the walkable area and every place reaches an existing route", () => {
  assert.deepEqual(town.move({ x: 90, y: 100 }, "left"), { x: 90, y: 100 });
  assert.deepEqual(town.move({ x: 870, y: 525 }, "down"), { x: 870, y: 525 });
  assert.deepEqual(town.move({ x: 510, y: 385 }, "up"), { x: 510, y: 353 });
  for (const [key, place] of Object.entries(town.places)) {
    assert.equal(town.nearestPlace({ x: place.x, y: place.y }), key);
    assert.ok(fs.existsSync(path.join(root, "web_dashboard", place.href)), `${key} destination exists`);
  }
});

test("town keeps an accessible route list when script or movement is unavailable", () => {
  const html = fs.readFileSync(path.join(root, "web_dashboard/town.html"), "utf8");
  assert.match(html, /id="townDirectory"/);
  for (const place of Object.values(town.places)) assert.match(html, new RegExp(`href="${place.href}"`));
  assert.match(html, /data-town-viewport/);
  assert.match(html, /data-town-move="left"/);
  assert.match(fs.readFileSync(path.join(root, "web_dashboard/assets/town.css"), "utf8"), /prefers-reduced-motion/);
});
