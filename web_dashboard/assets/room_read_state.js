(function (root, factory) {
  const api = factory();
  if (typeof module === "object" && module.exports) module.exports = api;
  if (root) root.NudgeRoomReadState = api;
})(typeof window !== "undefined" ? window : null, function () {
  "use strict";
  function key(userId, roomId) {
    return `nudgeRoomRead:${encodeURIComponent(userId)}:${encodeURIComponent(roomId)}`;
  }
  function unreadCount(messages, lastReadId) {
    if (!lastReadId) return 0;
    const index = messages.findIndex(message => message.id === lastReadId);
    return index < 0 ? messages.length : index;
  }
  return { key, unreadCount };
});
