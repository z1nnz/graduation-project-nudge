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

  assert.match(html, /data-room-list/);
  assert.match(html, /data-room-session-panel/);
  assert.match(html, /由你自己開始、暫停與完成/);
  assert.match(app, /function listenToWebRooms/);
  assert.match(app, /function startWebRoomSession/);
  assert.match(app, /function transitionWebRoomSession/);
  assert.match(app, /\.collection\("activity_sessions"\)/);
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
  assert.match(livePage, /_syncExternalActivity/);
  assert.match(livePage, /RoomActivitySource\.health/);
});
