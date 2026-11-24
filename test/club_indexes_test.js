const assert = require("node:assert/strict");
const test = require("node:test");
const config = require("../firestore.indexes.json");

test("club composite is top-level and field overrides contain only index modes", () => {
  const club = config.indexes.filter(index => index.collectionGroup === "club_posts");
  assert.equal(club.length, 1);
  assert.deepEqual(club[0].fields, [
    { fieldPath: "clubId", order: "ASCENDING" },
    { fieldPath: "createdAt", order: "DESCENDING" },
  ]);
  config.fieldOverrides.forEach(override => (override.indexes || []).forEach(mode => {
    assert.equal(Object.hasOwn(mode, "collectionGroup"), false);
    assert.equal(Object.hasOwn(mode, "fields"), false);
  }));
});
