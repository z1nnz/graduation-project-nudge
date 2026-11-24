const assert = require("node:assert/strict");
const test = require("node:test");
const { days, key, navigate } = require("../web_dashboard/assets/guild_calendar_core.js");

test("month and week navigation preserve boundaries and leap dates", () => {
  const anchor = new Date(2028, 1, 29);
  assert.equal(days(anchor, "month").length, 29);
  assert.equal(key(days(anchor, "month")[0]), "2028-02-01");
  assert.deepEqual(days(anchor, "week").map(key),
    ["2028-02-27", "2028-02-28", "2028-02-29", "2028-03-01", "2028-03-02", "2028-03-03", "2028-03-04"]);
  assert.equal(key(navigate(anchor, "month", 1)), "2028-03-01");
});
