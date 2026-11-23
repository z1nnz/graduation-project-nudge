const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const read = relativePath => fs.readFileSync(path.join(root, relativePath), "utf8");
const scene = require("../web_dashboard/assets/room_scene.js");

function member(memberId, overrides = {}) {
  return {
    memberId,
    displayName: memberId,
    role: "member",
    approvalStatus: "approved",
    presenceStatus: "resting",
    metricValue: 42.5,
    sessionSeconds: 3600,
    activeSessionId: `session-${memberId}`,
    ...overrides,
  };
}

test("scene seats expose only display name, role and a bounded posture", () => {
  const model = scene.buildScene({
    viewerId: "alice",
    memberLimit: 4,
    members: [
      member("owner", { role: "owner", presenceStatus: "studying" }),
      member("alice"),
      member("pending-pat", { approvalStatus: "pending" }),
    ],
  });
  assert.equal(model.viewerApproved, true);
  assert.equal(model.approvedCount, 2);
  assert.equal(model.focusingCount, 1);
  assert.equal(model.emptySeats, 2);
  assert.deepEqual(model.seats.map(seat => seat.memberId), ["alice", "owner"]);
  for (const seat of model.seats) {
    assert.deepEqual(Object.keys(seat).sort(), [
      "displayName", "glyph", "isOwner", "isViewer", "memberId", "postureKey", "postureLabel",
    ]);
    assert.doesNotMatch(JSON.stringify(seat), /42\.5|3600|session-/);
  }
  assert.ok(!model.seats.some(seat => seat.memberId === "pending-pat"));
});

test("pending, removed and signed-out viewers receive no seats", () => {
  const members = [member("owner", { role: "owner" }), member("bob", { approvalStatus: "pending" })];
  for (const viewerId of ["bob", "removed-carol", null]) {
    const model = scene.buildScene({ members, viewerId, memberLimit: 6 });
    assert.equal(model.viewerApproved, false);
    assert.equal(model.seats.length, 0);
    assert.equal(model.approvedCount, 0);
  }
});

test("unknown presence collapses to the away posture instead of leaking raw values", () => {
  assert.equal(scene.postureFor("studying").key, "focusing");
  assert.equal(scene.postureFor("resting").key, "seated");
  assert.equal(scene.postureFor("offline").key, "away");
  assert.equal(scene.postureFor("<img src=x>").key, "away");
});

test("presence follows only the viewer's own accepted activity transition", () => {
  assert.equal(scene.presenceAfterTransition("active"), "studying");
  for (const status of ["paused", "completed", "cancelled"]) {
    assert.equal(scene.presenceAfterTransition(status), "resting");
  }
  assert.equal(scene.presenceAfterTransition("unknown"), null);
});

test("leaving requires ending the own session and owner transfer when others remain", () => {
  const room = { id: "r", ownerId: "owner", memberIds: ["owner", "alice"] };
  assert.deepEqual(scene.leaveDecision({ room, viewerId: "alice" }), { allowed: true, mode: "leave" });
  assert.equal(scene.leaveDecision({ room, viewerId: "alice", sessionStatus: "active" }).reason, "session_running");
  assert.equal(scene.leaveDecision({ room, viewerId: "alice", sessionStatus: "paused" }).reason, "session_running");
  assert.equal(scene.leaveDecision({ room, viewerId: "owner" }).reason, "owner_must_transfer");
  assert.deepEqual(
    scene.leaveDecision({ room: { ...room, memberIds: ["owner"] }, viewerId: "owner" }),
    { allowed: true, mode: "close" },
  );
  assert.equal(scene.leaveDecision({ room, viewerId: null }).allowed, false);
});

test("rooms page renders the scene from the shared membership listener", () => {
  const html = read("web_dashboard/rooms.html");
  const app = read("web_dashboard/assets/app.js");
  assert.match(html, /data-room-stage\b/);
  assert.match(html, /data-room-seat-toggle/);
  assert.match(html, /data-room-leave/);
  assert.match(html, /data-world-return/);
  assert.match(html, /assets\/room_scene\.js\?v=\d+/);
  assert.ok(html.indexOf("room_scene.js") < html.indexOf("assets/app.js"));

  const sceneRender = app.slice(
    app.indexOf("function renderWebRoomScene"),
    app.indexOf("async function setOwnWebRoomPresence"),
  );
  assert.match(sceneRender, /NudgeRoomScene\.buildScene/);
  assert.match(sceneRender, /escapeHtml\(seat\.isViewer \? "我" : seat\.displayName\)/);
  assert.doesNotMatch(sceneRender, /metricValue|sessionSeconds|activeSessionId/);

  const presence = app.slice(
    app.indexOf("async function setOwnWebRoomPresence"),
    app.indexOf("async function publishOwnWebRoomPresenceBestEffort"),
  );
  assert.match(presence, /\.doc\(userId\)/);
  assert.match(presence, /update\(\{ presenceStatus, updatedAt/);
});

test("leaving, logout and lost access drop every room listener", () => {
  const app = read("web_dashboard/assets/app.js");
  const leave = app.slice(
    app.indexOf("async function leaveWebRoom"),
    app.indexOf("function resetWebRoomState"),
  );
  assert.ok(leave.indexOf('buildWebRoomEvent("leave"') < leave.indexOf("batch.delete"));
  assert.match(leave, /resetWebRoomState\(\)/);
  const reset = app.slice(
    app.indexOf("function resetWebRoomState"),
    app.indexOf("async function runWebRoomCommand"),
  );
  assert.match(reset, /stopWebRoomDetailListeners\(\)/);
  assert.match(reset, /activeWebRoomMembers = \[\]/);

  const logoutStart = app.indexOf("clearWebSession();",app.indexOf("const handleUser"));
  const logout = app.slice(logoutStart, logoutStart + 240);
  assert.match(logout, /webRoomsSub\(\)/);
  assert.match(logout, /resetWebRoomState\(\)/);

  const selection = app.slice(app.indexOf("function selectWebRoom"), app.indexOf("function listenToWebRooms"));
  assert.match(selection, /Room membership sync failed[\s\S]*resetWebRoomState\(\)/);
});

test("room commands are guarded against double submission", () => {
  const app = read("web_dashboard/assets/app.js");
  const runner = app.slice(
    app.indexOf("async function runWebRoomCommand"),
    app.indexOf("function bindWebRoomSceneControls"),
  );
  assert.match(runner, /if \(webRoomCommandPending\) return;/);
  assert.match(runner, /finally \{\s*webRoomCommandPending = false;/);
  assert.match(app, /runWebRoomCommand\(startWebRoomSession/);
});
