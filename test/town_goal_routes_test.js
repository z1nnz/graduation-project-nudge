const test = require("node:test");
const assert = require("node:assert/strict");
const { presentLetter } = require("../web_dashboard/assets/mailbox.js");

test("the celebration letter opens the plaza lighthouse page", () => {
  assert.equal(presentLetter({kind:"town_goal_celebration"}).href,"town-goals.html");
});
