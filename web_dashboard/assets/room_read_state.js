// Room chat read state shared by the room hub and the dedicated chat page.
// The canonical marker is the member-owned Cloud document
// room_read_markers/{roomId}--{userId}; it stores only the newest message the
// member has seen, so App and Web on any device agree on unread counts.
(function (root, factory) {
  const api = factory();
  if (typeof module === "object" && module.exports) module.exports = api;
  if (root) root.NudgeRoomReadState = api;
})(typeof window !== "undefined" ? window : null, function () {
  "use strict";

  const UNREAD_CAP = 60;

  function markerId(roomId, userId) {
    if (!roomId || !userId) return null;
    return `${roomId}--${userId}`;
  }

  // Messages are ordered newest first. Own messages never count as unread.
  // With no marker yet, nothing is unread: a member joining a room does not
  // inherit its whole history as notifications.
  function unreadCount(messages, marker, userId) {
    if (!marker || !marker.lastReadCreatedAt) return 0;
    let count = 0;
    for (const message of messages) {
      if (String(message.createdAt || "") <= marker.lastReadCreatedAt) break;
      if (message.senderId !== userId) count += 1;
    }
    return Math.min(count, UNREAD_CAP);
  }

  function badgeText(count) {
    if (!count) return "";
    return count >= UNREAD_CAP ? `${UNREAD_CAP}+ 則新訊息` : `${count} 則新訊息`;
  }

  // Returns the marker document to write, or null when it would not move the
  // marker forward (prevents redundant writes and backwards moves).
  function nextMarker({ roomId, userId, newestMessage, current, now = new Date() }) {
    if (!roomId || !userId || !newestMessage?.id || !newestMessage.createdAt) return null;
    if (current?.lastReadCreatedAt && current.lastReadCreatedAt >= newestMessage.createdAt) {
      return null;
    }
    return {
      schemaVersion: 1,
      roomId,
      userId,
      lastReadMessageId: newestMessage.id,
      lastReadCreatedAt: newestMessage.createdAt,
      updatedAt: now.toISOString(),
    };
  }

  // Fixed encouragement actions: no free text, so they need no moderation and
  // carry no private data. Stored as ordinary room "sticker" messages.
  const encouragements = Object.freeze([
    Object.freeze({ key: "cheer", text: "👏 一起加油" }),
    Object.freeze({ key: "with_you", text: "🌱 我也在這裡" }),
    Object.freeze({ key: "rest_ok", text: "☕ 休息一下也很好" }),
    Object.freeze({ key: "done", text: "🔥 我完成一小段了" }),
  ]);

  return Object.freeze({
    UNREAD_CAP,
    markerId,
    unreadCount,
    badgeText,
    nextMarker,
    encouragements,
  });
});
