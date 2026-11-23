(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  root.NudgeTownGameCore = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';
  function catchObject(score, combo, kind) {
    if (kind === 'star') {
      const nextCombo = combo + 1;
      const bonus = nextCombo % 5 === 0 ? 1 : 0;
      return { score: score + 1 + bonus, combo: nextCombo, bonus };
    }
    if (kind === 'cloud') return { score: Math.max(0, score - 2), combo: 0, bonus: 0 };
    throw new Error('Unknown game object');
  }
  function resumeDeadline(end, pausedAt, now) {
    return end + Math.max(0, now - pausedAt);
  }
  function spawnRates(elapsedSeconds) {
    const stage = Math.max(0, Math.min(1, elapsedSeconds / 90));
    return { stars: 1.6 + stage, clouds: 0.5 + stage * 0.4 };
  }
  return { catchObject, resumeDeadline, spawnRates };
});
