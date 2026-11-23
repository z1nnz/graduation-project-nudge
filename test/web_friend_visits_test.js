const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const read = relativePath => fs.readFileSync(path.join(root, relativePath), "utf8");
const visits = require("../web_dashboard/assets/friend_visits.js");

test("a visit is one fixed reaction per friend pair per day", () => {
  const now = new Date(2026, 10, 23, 9, 30);
  const built = visits.buildVisit({ hostId: "host", visitorId: "guest", sceneKey: "garden", reactionKey: "cheer", now });
  assert.equal(built.id, "host--guest--2026-11-23");
  assert.deepEqual(Object.keys(built.data).sort(), [
    "createdAt", "dateKey", "hostId", "reactionKey", "respondedAt", "responseKey", "sceneKey", "schemaVersion", "visitorId",
  ]);
  assert.equal(built.data.responseKey, null);
  assert.throws(() => visits.buildVisit({ hostId: "a", visitorId: "a", sceneKey: "garden", reactionKey: "cheer" }));
  assert.throws(() => visits.buildVisit({ hostId: "a", visitorId: "b", sceneKey: "garden", reactionKey: "free text" }));
  assert.throws(() => visits.buildVisit({ hostId: "a", visitorId: "b", sceneKey: undefined, reactionKey: "cheer" }));
});

test("visit settings are revocable and limited to fixed scenes", () => {
  const settings = visits.buildSettings({ userId: "u", allowVisits: false, sceneKey: "cabin" });
  assert.equal(settings.allowVisits, false);
  assert.throws(() => visits.buildSettings({ userId: "u", allowVisits: true, sceneKey: "bedroom" }));
});

test("visit cards expose only whitelisted, fixed labels", () => {
  const card = visits.presentVisit({
    id: "h--g--d", hostId: "me", visitorId: "g", sceneKey: "cabin", reactionKey: "wave", responseKey: null,
    dateKey: "2026-11-23", focusMinutes: 120, healthScore: 90,
  }, "me", { g: "阿禾" });
  assert.equal(card.incoming, true);
  assert.equal(card.canRespond, true);
  assert.equal(card.otherName, "阿禾");
  assert.doesNotMatch(JSON.stringify(card), /120|90|focus|health/);
});

test("friend-visits page has no hard-coded people, counts or fake rewards", () => {
  const html = read("web_dashboard/friend-visits.html");
  for (const forbidden of [/小安/, /小華/, /老闆/, /繁榮度/, /自律幣/, /data-count="5"/, /本週新增 2/]) {
    assert.doesNotMatch(html, forbidden);
  }
  assert.match(html, /data-visit-friends/);
  assert.match(html, /data-visit-allow/);
  assert.match(html, /data-town-return/);
  assert.ok(html.indexOf("friend_visits.js") < html.indexOf("assets/app.js"));
  const script = read("web_dashboard/assets/friend_visits.js");
  assert.doesNotMatch(script, /addCoins|grantXp|coins\s*[+:=]|\bxp\s*[+:=]|prosperity\s*[+:=]/i);
  assert.match(script, /const esc = value =>/);
  assert.match(script, /collection\("users"\)\.doc\(uid\)\.collection\("friends"\)/);
  assert.doesNotMatch(script, /collection\("users"\)\.doc\((friendId|hostId|other)\)/);
});

test("friend visit data joins privacy export, account deletion and Rules", () => {
  const exportService = read("functions/src/privacy-data-request-service.js");
  const deletion = read("functions/src/firestore-account-deletion-repository.js");
  const rules = read("firestore.rules");
  assert.match(exportService, /readSingleDocument\(firestore, "friend_visit_settings", userId\)/);
  assert.match(exportService, /readQuery\(firestore, "friend_visits", "hostId", "==", userId\)/);
  assert.match(exportService, /readQuery\(firestore, "friend_visits", "visitorId", "==", userId\)/);
  assert.match(deletion, /\["friend_visits", "hostId"\]/);
  assert.match(deletion, /\["friend_visits", "visitorId"\]/);
  assert.match(deletion, /"friend_visit_settings",/);
  assert.match(rules, /match \/friend_visit_settings\/\{userId\}/);
  assert.match(rules, /match \/friend_visits\/\{visitId\}/);
});
