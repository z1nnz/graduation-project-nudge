const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const read = relativePath => fs.readFileSync(path.join(root, relativePath), "utf8");
const mailbox = require("../web_dashboard/assets/mailbox.js");

test("pending invitations route to the handling centre, resolved ones to the scene", () => {
  const invite = { id: "n1", kind: "family_invitation", sourceType: "family_request", route: "guardian", status: "unread", title: "新的家庭連結邀請" };
  const pending = mailbox.presentLetter(invite, "pending");
  assert.equal(pending.href, "guardian.html");
  assert.equal(pending.requestStatusLabel, "等待你回覆");
  assert.equal(pending.unread, true);
  const accepted = mailbox.presentLetter(invite, "accepted");
  assert.equal(accepted.href, "family-courtyard.html");
  assert.equal(accepted.requestStatusLabel, "已接受");
  const groupResult = mailbox.presentLetter({ id: "n2", kind: "group_invitation_declined", sourceType: "group_request", route: "groups", status: "read" }, "declined");
  assert.equal(groupResult.href, "group-hall.html");
  assert.equal(groupResult.unread, false);
});

test("letters cannot carry external links or unknown routes", () => {
  const letter = mailbox.presentLetter({ id: "x", route: "https://evil.example", title: "<b>hi</b>", kind: "x" }, null);
  assert.equal(letter.href, null);
  assert.equal(letter.actionLabel, "");
});

test("unread count and request lookups use canonical sources", () => {
  assert.equal(mailbox.unreadCount([{ status: "unread" }, { status: "read" }, { status: "unread" }]), 2);
  assert.equal(mailbox.requestCollection({ sourceType: "family_request" }), "guardian_requests");
  assert.equal(mailbox.requestCollection({ sourceType: "group_request" }), "group_requests");
  assert.equal(mailbox.requestCollection({ sourceType: "other" }), null);
});

test("mailbox reads shared notifications and marks read only via the audited callable", () => {
  const html = read("web_dashboard/mailbox.html");
  const script = read("web_dashboard/assets/mailbox.js");
  assert.match(html, /data-page="mailbox"/);
  assert.match(html, /data-mailbox-letters/);
  assert.match(html, /data-town-return/);
  assert.match(html, /推播尚未在實機驗收/);
  assert.ok(html.indexOf("mailbox.js") < html.indexOf("assets/app.js"));
  assert.match(script, /collection\("user_notifications"\)\s*\.where\("recipientUserId", "==", uid\)/);
  assert.match(script, /httpsCallable\("markNotificationRead"\)/);
  assert.doesNotMatch(script, /collection\("user_notifications"\)\.doc\([^)]*\)\.(set|update|delete)/);
  assert.doesNotMatch(script, /\.update\(\{\s*status:/);
  assert.ok(require("../web_dashboard/assets/social_scene.js").SCENES.plaza.rooms.some(([href]) => href === "mailbox.html"));
});
