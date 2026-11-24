import assert from "node:assert/strict";
import test from "node:test";
import { normalizePushInstallationRequest } from "../src/push-notification-service.js";
import { normalizeWebPushPreferences, webPushAllowed } from "../src/web-push-preferences.js";

const sample = {
  categories: { mentions: true, invitations: false, focusRounds: true, guildEvents: true, familyLetters: true },
  quiet: { enabled: true, start: "22:00", end: "07:00", zone: "Asia/Taipei" },
};
test("browser installation uses canonical token validation", () => {
  assert.equal(normalizePushInstallationRequest({
    action: "register", platform: "web", installationId: "browser-id",
    clientRequestId: "request-id", token: "a".repeat(64),
  }).platform, "web");
});
test("Web Push categories and quiet hours use the configured time zone", () => {
  const prefs = normalizeWebPushPreferences(sample);
  const at = time => new Date("2026-11-24T" + time + ":00Z");
  assert.equal(webPushAllowed(prefs, "room_chat_mention", at("13:59")), true);
  assert.equal(webPushAllowed(prefs, "room_chat_mention", at("14:00")), false);
  assert.equal(webPushAllowed(prefs, "room_chat_mention", at("22:59")), false);
  assert.equal(webPushAllowed(prefs, "room_chat_mention", at("23:00")), true);
  assert.equal(webPushAllowed(prefs, "group_invitation", at("03:00")), false);
  assert.equal(webPushAllowed(prefs, "unknown", at("03:00")), false);
  assert.throws(() => normalizeWebPushPreferences({ ...sample, quiet: { ...sample.quiet, end: "22:00" } }));
});
