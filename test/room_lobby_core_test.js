const assert = require("node:assert/strict");
const test = require("node:test");
const { recommend } = require("../web_dashboard/assets/room_lobby_core.js");

test("recommended rooms use the member's cloud activity hour and the adjacent hours", () => {
  const rooms = [
    { name: "Seldom", updatedAt: "2026-11-24T13:00:00Z" },
    { name: "Midnight", updatedAt: "2026-11-22T00:00:00Z" },
    { name: "Favorite", updatedAt: "2026-11-20T23:00:00Z" },
  ];
  const activity = ["2026-11-22T23:00:00Z", "2026-11-23T23:00:00Z", "invalid"];
  assert.deepEqual(recommend(rooms, activity).map(room => room.name), ["Favorite", "Midnight", "Seldom"]);
  assert.deepEqual(recommend(rooms, []), rooms);
  assert.equal(rooms[0].name, "Seldom");
});
