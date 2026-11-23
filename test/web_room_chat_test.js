const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const read = relativePath => fs.readFileSync(path.join(root, relativePath), "utf8");
const readState = require("../web_dashboard/assets/room_read_state.js");

const messages = [
  { id: "m5", senderId: "bob", createdAt: "2026-11-23T10:05:00.000Z" },
  { id: "m4", senderId: "alice", createdAt: "2026-11-23T10:04:00.000Z" },
  { id: "m3", senderId: "bob", createdAt: "2026-11-23T10:03:00.000Z" },
  { id: "m2", senderId: "bob", createdAt: "2026-11-23T10:02:00.000Z" },
];

test("unread counts only peers' messages newer than the Cloud marker", () => {
  const marker = { lastReadMessageId: "m2", lastReadCreatedAt: "2026-11-23T10:02:00.000Z" };
  assert.equal(readState.unreadCount(messages, marker, "alice"), 2);
  assert.equal(readState.unreadCount(messages, marker, "bob"), 1);
  assert.equal(readState.unreadCount(messages, null, "alice"), 0);
  assert.equal(readState.unreadCount(messages, { lastReadCreatedAt: "2026-11-23T10:05:00.000Z" }, "alice"), 0);
  const many = Array.from({ length: 80 }, (_, index) => ({
    id: `m${index}`, senderId: "bob", createdAt: `2026-11-24T00:00:${String(80 - index).padStart(2, "0")}.000Z`,
  }));
  assert.equal(readState.unreadCount(many, marker, "alice"), readState.UNREAD_CAP);
  assert.equal(readState.badgeText(readState.UNREAD_CAP), "60+ 則新訊息");
  assert.equal(readState.badgeText(0), "");
});

test("the read marker only moves forward and is keyed by room and member", () => {
  assert.equal(readState.markerId("room", "alice"), "room--alice");
  assert.notEqual(readState.markerId("room", "alice"), readState.markerId("room", "bob"));
  assert.equal(readState.markerId("room", null), null);
  const next = readState.nextMarker({
    roomId: "room", userId: "alice", newestMessage: messages[0], now: new Date("2026-11-23T11:00:00Z"),
  });
  assert.deepEqual(Object.keys(next).sort(), [
    "lastReadCreatedAt", "lastReadMessageId", "roomId", "schemaVersion", "updatedAt", "userId",
  ]);
  assert.equal(next.lastReadMessageId, "m5");
  assert.equal(readState.nextMarker({ roomId: "room", userId: "alice", newestMessage: messages[1], current: next }), null);
  assert.equal(readState.nextMarker({ roomId: "room", userId: "alice", newestMessage: undefined }), null);
});

test("encouragements are a fixed set without free text", () => {
  assert.ok(readState.encouragements.length >= 3);
  for (const item of readState.encouragements) {
    assert.match(item.key, /^[a-z_]+$/);
    assert.ok(item.text.length <= 40);
  }
  assert.ok(Object.isFrozen(readState.encouragements));
});

test("chat page and room hub share one message listener and the Cloud marker", () => {
  const app = read("web_dashboard/assets/app.js");
  const chat = read("web_dashboard/room-chat.html");
  const rooms = read("web_dashboard/rooms.html");
  assert.match(chat, /data-page="room-chat"/);
  assert.match(chat, /data-room-message-input/);
  assert.match(chat, /data-room-encouragements/);
  assert.match(chat, /data-room-resonance-enabled/);
  assert.match(chat, /role="log"/);
  assert.match(chat, /aria-live="polite"/);
  assert.match(rooms, /data-room-unread/);
  assert.match(rooms, /data-room-chat-link/);
  for (const html of [chat, rooms]) {
    assert.ok(html.indexOf("room_read_state.js") < html.indexOf("assets/app.js"));
  }
  assert.match(app, /\["rooms", "room-chat"\]\.includes\(document\.body\.dataset\.page\)/);
  assert.match(app, /collection\("room_read_markers"\)/);
  assert.doesNotMatch(app, /localStorage\.setItem\(key, messageId\)|nudgeRoomRead:/);

  const mark = app.slice(
    app.indexOf("async function markWebRoomMessagesRead"),
    app.indexOf("const webRoomResonanceCueLabels"),
  );
  assert.match(mark, /isWebRoomChatPage\(\)/);
  assert.match(mark, /visibilityState === "hidden"/);
  assert.match(mark, /approvalStatus !== "approved"/);

  const stop = app.slice(
    app.indexOf("function stopWebRoomInteractionListeners"),
    app.indexOf("function renderWebRoomScene"),
  );
  assert.match(stop, /webRoomReadMarkerSub\(\)/);
  assert.match(stop, /activeWebRoomMessages = \[\]/);
});

test("message sends are single-flight and ids carry client entropy", () => {
  const app = read("web_dashboard/assets/app.js");
  const once = app.slice(app.indexOf("async function sendWebRoomMessageOnce"));
  assert.match(once, /if \(webRoomChatSending\) return;/);
  assert.match(once, /finally \{\s*webRoomChatSending = false;/);
  assert.match(app, /message_\$\{userId\}_\$\{Date\.now\(\)\}_\$\{webClientSuffix\(\)\}/);
  assert.match(app, /event\.isComposing/);
});

test("read markers are exported and deleted with the account", () => {
  const exportService = read("functions/src/privacy-data-request-service.js");
  const deletion = read("functions/src/firestore-account-deletion-repository.js");
  const rules = read("firestore.rules");
  assert.match(exportService, /readQuery\(firestore, "room_read_markers", "userId", "==", userId\)/);
  assert.match(exportService, /room_read_markers: roomReadMarkers\.documents/);
  assert.match(deletion, /\["room_read_markers", "userId"\]/);
  assert.match(rules, /match \/room_read_markers\/\{markerId\}/);
});
