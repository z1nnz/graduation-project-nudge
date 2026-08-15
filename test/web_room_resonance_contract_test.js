const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const contract = require(
  "../web_dashboard/assets/room_resonance_contract.js",
);
const read = relativePath =>
  fs.readFileSync(path.join(root, relativePath), "utf8");

function signal(overrides = {}) {
  return {
    schemaVersion: 1,
    signalId: "room-study--alice",
    roomId: "room-study",
    ownerUserId: "alice",
    generationId: "resonance-publish-001",
    cueKey: "gentle_restart",
    status: "active",
    visibility: "room_members_only",
    acknowledgementCount: 0,
    createdAt: "2026-08-15T10:00:00.000Z",
    updatedAt: "2026-08-15T10:00:00.000Z",
    expiresAt: "2026-08-16T10:00:00.000Z",
    withdrawnAt: null,
    ...overrides,
  };
}

test("Web accepts only private bounded room resonance", () => {
  const parsed = contract.parseSignal("room-study", signal());
  assert.equal(parsed.cueKey, "gentle_restart");
  assert.equal(
    contract.isVisible(parsed, new Date("2026-08-15T12:00:00.000Z")),
    true,
  );
  assert.throws(() =>
    contract.parseSignal("room-study", signal({ visibility: "public" }))
  );
  assert.throws(() =>
    contract.parseSignal("other-room", signal())
  );
});

test("Web room exposes opt-in resonance without precise activity sharing", () => {
  const html = read("web_dashboard/rooms.html");
  const app = read("web_dashboard/assets/app.js");
  assert.match(html, /data-room-resonance-enabled/);
  assert.match(html, /看不到精確健康、專注數值或 Ledger 明細/);
  assert.match(html, /room_resonance_contract\.js/);
  assert.match(app, /httpsCallable\("manageRoomResonance"\)/);
  assert.match(app, /collection\("room_resonance_signals"\)/);
  assert.match(app, /collection\("room_resonance_preferences"\)/);
  assert.match(app, /set_preference/);
  assert.match(app, /acknowledge/);
  assert.doesNotMatch(app, /resonance[\s\S]{0,80}metricValue/);
});
