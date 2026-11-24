(function (root, factory) {
  const api = factory();
  if (typeof module === "object" && module.exports) module.exports = api;
  else root.NudgeGuildCalendarCore = api;
})(globalThis, function () {
  "use strict";
  function dateAt(date, offset) {
    return new Date(date.getFullYear(), date.getMonth(), date.getDate() + offset);
  }
  function key(date) {
    return [date.getFullYear(), date.getMonth() + 1, date.getDate()].map((part, index) =>
      index === 0 ? String(part) : String(part).padStart(2, "0")).join("-");
  }
  function days(anchor, view) {
    const first = view === "week" ? dateAt(anchor, -anchor.getDay()) :
      new Date(anchor.getFullYear(), anchor.getMonth(), 1);
    const size = view === "week" ? 7 : new Date(first.getFullYear(), first.getMonth() + 1, 0).getDate();
    return Array.from({ length: size }, (_, index) => dateAt(first, index));
  }
  function navigate(anchor, view, direction) {
    return view === "week" ? dateAt(anchor, direction * 7) :
      new Date(anchor.getFullYear(), anchor.getMonth() + direction, 1);
  }
  return Object.freeze({ dateAt, days, key, navigate });
});
