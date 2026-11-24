const test = require("node:test");
const assert = require("node:assert/strict");
const mailbox = require("../web_dashboard/assets/mailbox.js");
const push = require("../web_dashboard/assets/web_push_core.js");

test("buddy mail and reminder push open the buddy page", () => {
  assert.equal(mailbox.presentLetter({kind:"buddy_invitation"}).href,"buddies.html");
  assert.equal(mailbox.presentLetter({kind:"buddy_nudge"}).href,"buddies.html");
  const reminder = push.notification({kind:"buddy_reminder"});
  assert.equal(reminder.data.page,"buddies.html");
  assert.equal(push.townUrl("https://example.test/",reminder.data.page),"https://example.test/town.html#open=buddies.html");
});
