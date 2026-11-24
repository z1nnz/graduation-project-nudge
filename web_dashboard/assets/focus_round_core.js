(function (root) {
  "use strict";
  const durationMin = 25;
  const breakMin = 5;
  const minute = 60_000;

  function snapshot(round, now) {
    const start = round?.startAt?.toMillis?.();
    if (!Number.isFinite(start)) return { phase: "idle", remaining: 0 };
    const focusEnd = start + durationMin * minute;
    const breakEnd = focusEnd + breakMin * minute;
    if (now < focusEnd) return { phase: "focus", remaining: Math.ceil((focusEnd - now) / 1_000) };
    if (now < breakEnd) return { phase: "break", remaining: Math.ceil((breakEnd - now) / 1_000) };
    return { phase: "idle", remaining: 0 };
  }

  function newRound(userId, startAt) {
    return { startedBy: userId, startAt, durationMin, breakMin };
  }

  const api = Object.freeze({ snapshot, newRound });
  if (typeof module === "object" && module.exports) module.exports = api;
  else root.NudgeFocusRoundCore = api;
})(globalThis);
