const test = require("node:test");
const assert = require("node:assert/strict");
const core = require("../web_dashboard/assets/presence_core.js");
const routes = require("../web_dashboard/assets/town_routes.js");

test("presence maps facilities to buildings without storing page or URL details", () => {
  assert.equal(core.buildingForPath(routes, "room-chat.html?room=private"), "tower");
  assert.equal(core.buildingForPath(routes, "personal.html"), "library");
  assert.equal(core.buildingForPath(routes, "operations-room-review.html"), null);
  assert.equal(core.buildingForPath(routes, "login.html"), null);
  assert.equal(core.buildingForPath(routes, "town.html"), null);
});

test("presence only shows a permitted building before expiry", () => {
  const data = { uid: "alice", building: "tower", page: "tower", expiresAt: { toMillis: () => 300000 } };
  assert.deepEqual(core.visiblePresence(data, routes.BUILDINGS, 299999), {
    uid: "alice", building: "tower", expiresAt: 300000,
  });
  assert.equal(core.visiblePresence(data, routes.BUILDINGS, 300000), null);
  assert.equal(core.visiblePresence({ ...data, page: "private-room" }, routes.BUILDINGS, 0), null);
  assert.equal(core.visiblePresence({ ...data, building: "__proto__" }, routes.BUILDINGS, 0), null);
});
