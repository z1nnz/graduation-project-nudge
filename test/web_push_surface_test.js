const test = require("node:test");
const assert = require("node:assert/strict");
const core = require("../web_dashboard/assets/web_push_core.js");

test("Web Push routes to the authenticated town window with an encoded room ID", () => {
  const notice = core.notification({kind:"room_chat_mention",roomId:"room?code=1",notificationId:"abc"});
  const url = new URL(core.townUrl("https://example.test/assets-base/", notice.data.page));
  assert.equal(url.pathname, "/assets-base/town.html");
  assert.equal(decodeURIComponent(url.hash), "#open=room-chat.html?room=room%3Fcode%3D1");
  assert.equal(new URL(core.townUrl("https://example.test/", "//external.test")).origin, "https://example.test");
  assert.equal(core.notification({kind:"internal_or_unknown"}), null);
});
