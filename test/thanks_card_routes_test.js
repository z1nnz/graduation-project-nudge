const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const { presentLetter } = require("../web_dashboard/assets/mailbox.js");

test("mailbox opens only the local thank-you card page with an encoded card id", () => {
  assert.equal(presentLetter({kind:"thanks_card",sourceId:"x?foo=#"}).href,"thanks-cards.html?card=x%3Ffoo%3D%23");
});
test("the room, focus break and cabin entry points include the thank-you action", () => {
  for (const [file, marker] of [["app.js","thanks-cards.html?to="],["focus_round.js","data-thanks-focus"],["friend_visits.js","data-thanks-cabin"]]) {
    assert.ok(fs.readFileSync("web_dashboard/assets/"+file,"utf8").includes(marker));
  }
});
