const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const root = path.resolve(__dirname, "..");
const read = relativePath => fs.readFileSync(path.join(root, relativePath), "utf8");
const roomReadState = require("../web_dashboard/assets/room_read_state.js");

test("room unread markers are isolated by account and room and count only newer messages", () => {
  assert.notEqual(roomReadState.key("alice", "room"), roomReadState.key("bob", "room"));
  assert.notEqual(roomReadState.key("alice", "room"), roomReadState.key("alice", "other"));
  const messages = [{ id: "newest" }, { id: "new" }, { id: "seen" }, { id: "old" }];
  assert.equal(roomReadState.unreadCount(messages, "seen"), 2);
  assert.equal(roomReadState.unreadCount(messages, "newest"), 0);
  assert.equal(roomReadState.unreadCount(messages, null), 0);
  assert.equal(roomReadState.unreadCount(messages, "expired"), 4);
});

test("web room chat shares existing room membership and message listeners", () => {
  const app = read("web_dashboard/assets/app.js");
  const rooms = read("web_dashboard/rooms.html");
  const chat = read("web_dashboard/room-chat.html");
  assert.match(rooms, /data-room-chat-link/);
  assert.doesNotMatch(rooms, /data-room-message-input/);
  assert.match(chat, /data-room-message-input/);
  assert.match(app, /activeWebRoomMember\?\.approvalStatus !== "approved"/);
  assert.match(app, /\.collection\("messages"\)/);
  assert.match(app, /stopWebRoomInteractionListeners\(\)/);
  assert.match(app, /room-chat\.html\?room=/);
});
