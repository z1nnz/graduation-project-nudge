(function (root, factory) {
  const api = factory();
  if (typeof module === "object" && module.exports) module.exports = api;
  else root.NudgeRoomLobbyCore = api;
})(globalThis, function () {
  "use strict";
  function hour(value) {
    return new Date(value).getUTCHours();
  }
  function recommend(rooms, activity) {
    const hours = Array(24).fill(0);
    for (const timestamp of activity) {
      const index = hour(timestamp);
      if (Number.isInteger(index)) hours[index]++;
    }
    const score = room => {
      const index = hour(room.updatedAt);
      if (!Number.isInteger(index)) return 0;
      return hours[index] * 2 + hours[(index + 1) % 24] + hours[(index + 23) % 24];
    };
    return [...rooms].sort((a, b) => score(b) - score(a) ||
      String(b.updatedAt || "").localeCompare(String(a.updatedAt || "")) ||
      a.name.localeCompare(b.name, "zh-Hant"));
  }
  return Object.freeze({ recommend });
});
