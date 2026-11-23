(function (root) {
  'use strict';
  // Pure rules for the Lv 10 starlight garden. No DOM, no writes: the garden
  // only reflects the signed-in user's own Cloud-confirmed activity.

  const MIN_LEVEL = 10;
  const BEDS = Object.freeze([
    Object.freeze({ id: 'focus', name: '專注花圃', plant: '星光鈴蘭', types: Object.freeze(['focus', 'study']) }),
    Object.freeze({ id: 'move', name: '運動花圃', plant: '跳跳向日葵', types: Object.freeze(['exercise', 'steps']) }),
    Object.freeze({ id: 'rest', name: '睡眠花圃', plant: '月光薰衣草', types: Object.freeze(['sleep']) }),
    Object.freeze({ id: 'custom', name: '自訂花圃', plant: '小小野花', types: Object.freeze(['custom']) }),
  ]);

  function level(value) {
    const n = Math.floor(Number(value));
    return Number.isFinite(n) && n >= 1 ? n : 1;
  }

  /** Whether the garden is open for this level, with the text to show. */
  function access(avatarLevel) {
    const current = level(avatarLevel);
    if (current >= MIN_LEVEL) return { unlocked: true, level: current, reason: '' };
    return {
      unlocked: false,
      level: current,
      reason: `角色 Lv ${MIN_LEVEL} 才能進入星光花園，你目前是 Lv ${current}，還差 ${MIN_LEVEL - current} 級。`,
    };
  }

  const api = { MIN_LEVEL, BEDS, access, level };
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.NudgeGardenCore = api;
})(typeof globalThis !== 'undefined' ? globalThis : this);
