const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const read = relativePath =>
  fs.readFileSync(path.join(root, relativePath), "utf8");

test("web exposes a real member-controlled activity room hub", () => {
  const html = read("web_dashboard/rooms.html");
  const app = read("web_dashboard/assets/app.js");
  const roomCommands = app.slice(
    app.indexOf("async function startWebRoomSession"),
    app.indexOf("function stopFamilyInteractionListeners"),
  );
  const roomSelection = app.slice(
    app.indexOf("function selectWebRoom"),
    app.indexOf("function listenToWebRooms"),
  );

  assert.match(html, /data-room-list/);
  assert.match(html, /data-room-session-panel/);
  assert.match(html, /data-room-message-list/);
  assert.match(html, /data-room-event-list/);
  assert.match(html, /data-room-message-input/);
  assert.match(html, /由你自己開始、暫停與完成/);
  assert.match(app, /function listenToWebRooms/);
  assert.match(app, /function startWebRoomSession/);
  assert.match(app, /function transitionWebRoomSession/);
  assert.match(app, /recordWebRoomLedgerTransition/);
  assert.match(app, /recordWebRoomEventBestEffort/);
  assert.match(
    app,
    /Room activity was accepted by Cloud, but its activity-feed event was not written/,
  );
  assert.match(app, /roomSession:\s*session/);
  assert.doesNotMatch(
    roomCommands,
    /batch\.set\(\s*roomRef\.collection\("activity_sessions"\)/,
  );
  assert.doesNotMatch(
    roomCommands,
    /activeSessionId\s*:/,
  );
  assert.match(app, /function listenToWebRoomInteractions/);
  assert.match(app, /function sendWebRoomMessage/);
  assert.match(app, /function buildWebRoomEvent/);
  assert.match(app, /member\.presenceStatus/);
  assert.match(app, /batch\.set\(roomRef\.collection\("events"\)/);
  assert.match(
    app,
    /db\.collection\("activity_sessions"\)\s*\.where\("actorUserId",\s*"==",\s*userId\)/,
  );
  assert.doesNotMatch(
    app,
    /collection\("rooms"\)\.doc\(roomId\)[\s\S]{0,120}collection\("activity_sessions"\)/,
  );
  assert.doesNotMatch(
    roomSelection,
    /if \(roomUsesTrustedHealthAdapter\(activeWebRoom\)\)/,
  );
  assert.match(app, /\.collection\("messages"\)/);
  assert.match(app, /\.collection\("events"\)/);
  assert.doesNotMatch(html, /房主開始|管理者開始|統一開始/);
});

test("app discovery no longer ships fabricated public rooms", () => {
  const listPage = read("lib/screens/study_room_list_page.dart");

  assert.doesNotMatch(
    listPage,
    /public_focus_library|public_sleep_reset|public_exam_pass/,
  );
  assert.match(listPage, /discoverableStudyRooms/);
  assert.doesNotMatch(listPage, /final combined = \[\.\.\.publicRooms, \.\.\.rooms\]/);

  const livePage = read("lib/screens/study_room_live_page.dart");
  assert.doesNotMatch(livePage, /_syncExternalActivity/);
  assert.doesNotMatch(livePage, /RoomActivitySource\.health/);
  assert.match(livePage, /MaterialPageRoute\(builder: \(_\) => const HealthPage\(\)\)/);
  assert.match(livePage, /活動帳本/);
});

test("App room commands preserve the running session when Cloud rejects", () => {
  const livePage = read("lib/screens/study_room_live_page.dart");
  const pause = livePage.slice(
    livePage.indexOf("Future<void> _pauseSession"),
    livePage.indexOf("Future<void> _completeSession"),
  );
  const complete = livePage.slice(
    livePage.indexOf("Future<void> _completeSession"),
    livePage.indexOf("Future<void> _stopSession"),
  );
  const stop = livePage.slice(
    livePage.indexOf("Future<void> _stopSession"),
    livePage.indexOf("Future<void> _commitSessionAsResting"),
  );

  assert.match(livePage, /void _restartSessionTimer/);
  for (const command of [pause, complete, stop]) {
    assert.match(command, /catch \(error\)[\s\S]*_restartSessionTimer/);
    assert.doesNotMatch(
      command.match(/catch \(error\)[\s\S]*?return;/)?.[0] || "",
      /_isRunning = false/,
    );
  }
  assert.match(
    livePage,
    /await appState\.transitionRoomActivitySession[\s\S]*addSecureFocusSeconds/,
  );
});

test("Health last-sync time advances only after Cloud accepts the Ledger batch", () => {
  const healthPage = read("lib/screens/health_page.dart");
  const sync = healthPage.slice(
    healthPage.indexOf("Future<void> syncHealthData"),
    healthPage.indexOf("void showConnectInfoDialog"),
  );
  assert.ok(sync.indexOf("if (!accepted)") >= 0);
  assert.ok(
    sync.indexOf("lastSyncTime = formatNow()") > sync.indexOf("if (!accepted)"),
  );
});
