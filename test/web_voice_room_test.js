const test = require("node:test");
const assert = require("node:assert/strict");
const { shouldOffer, heartbeatExpired, maxParticipants } = require("../web_dashboard/assets/voice_room_core.js");

test("exactly the lower UID sends the opening offer for a pair", () => {
  assert.equal(shouldOffer("a", "b"), true);
  assert.equal(shouldOffer("b", "a"), false);
  assert.equal(shouldOffer("a", "a"), false);
  assert.equal(shouldOffer(undefined, "b"), false);
  assert.equal(maxParticipants, 8);
});

test("a voice heartbeat is stale at the two minute boundary", () => {
  const stamp = { toMillis: () => 1000 };
  assert.equal(heartbeatExpired(stamp, 120999), false);
  assert.equal(heartbeatExpired(stamp, 121000), true);
  assert.equal(heartbeatExpired(null, 121000), true);
});
