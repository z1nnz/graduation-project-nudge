(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  root.NudgeFestivalCore = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';
  // #200 H3: town-wide festivals. Pure date maths and the "fireworks once"
  // rule; drawing lives in town_festival.js and festival_scene.js. Festivals
  // never grant coins, XP or rewards.

  const FESTIVALS = Object.freeze([
    Object.freeze({ key: 'lantern', name: '燈籠節', from: [1, 20], to: [2, 20], decor: ['lantern_string'], far: 'lanterns', petals: false,
      npc: 'chestnut', lines: ['燈籠節到了！每一盞燈都是大家今天前進的一小步。', '慢慢走，燈會一直亮著。'],
      melody: [0, 4, 7, 9, 7, 4, 2, 4] }),
    Object.freeze({ key: 'cherry', name: '櫻花季', from: [3, 15], to: [4, 15], decor: ['cherry_tree'], far: 'clouds', petals: 'petal',
      npc: 'sprout', lines: ['櫻花開了，和花一樣，慢慢來也會盛開。', '花瓣落在哪裡，哪裡就是今天的好地方。'],
      melody: [0, 2, 4, 7, 9, 7, 4, 2] }),
    Object.freeze({ key: 'starlight', name: '星光夜', from: [7, 1], to: [8, 31], decor: ['star_garland'], far: 'stars', petals: false,
      npc: 'stella', lines: ['星光夜！抬頭看看，每顆星都在陪你。', '今天的努力，會在夜空裡發亮。'],
      melody: [7, 9, 12, 9, 7, 4, 7, 9] }),
    Object.freeze({ key: 'snowman', name: '雪人週', from: [12, 15], to: [1, 10], decor: ['snowman'], far: 'clouds', petals: 'snow',
      npc: 'letty', lines: ['雪人週來了！堆個雪人，暖暖地休息一下。', '冷冷的天，記得照顧好自己。'],
      melody: [4, 2, 0, 2, 4, 4, 4, 2] }),
  ]);

  function taipeiDate(date) {
    const d = new Date(date.getTime() + 8 * 3600000);
    return { month: d.getUTCMonth() + 1, day: d.getUTCDate(), year: d.getUTCFullYear() };
  }

  function inRange(month, day, from, to) {
    const v = month * 100 + day, a = from[0] * 100 + from[1], b = to[0] * 100 + to[1];
    return a <= b ? v >= a && v <= b : v >= a || v <= b; // ranges may wrap the new year
  }

  /** The festival running on this date (Asia/Taipei), or null. ?festival=key previews one. */
  function festivalAt(date, preview) {
    if (preview) return FESTIVALS.find(f => f.key === preview) || null;
    const { month, day } = taipeiDate(date);
    return FESTIVALS.find(f => inRange(month, day, f.from, f.to)) || null;
  }

  /** Week key (Monday-based, Taipei) used to show the town-goal fireworks once. */
  function weekKey(date) {
    const d = new Date(date.getTime() + 8 * 3600000);
    const day = (d.getUTCDay() + 6) % 7;
    const monday = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate() - day));
    return monday.toISOString().slice(0, 10);
  }

  const STORE = 'nudge_town_fireworks_v1';
  /** Record that this week's town goal was reached (from the cloud total). */
  function markGoalReached(storage, key) {
    try { const s = JSON.parse(storage.getItem(STORE) || '{}'); if (!s[key]) { s[key] = 'due'; storage.setItem(STORE, JSON.stringify(s)); } } catch { /* private mode */ }
  }
  /** True once per week after the goal is reached; then marks it shown. */
  function takeFireworks(storage, key) {
    try {
      const s = JSON.parse(storage.getItem(STORE) || '{}');
      if (s[key] !== 'due') return false;
      s[key] = 'shown';
      storage.setItem(STORE, JSON.stringify(s));
      return true;
    } catch { return false; }
  }

  /** Firework particles for a burst at progress t (0..1), deterministic per seed. */
  function fireworkParticles(seed, t, count = 18) {
    const out = [];
    for (let i = 0; i < count; i++) {
      const angle = (i / count) * Math.PI * 2 + seed;
      const r = Math.min(1, t * 1.6);
      out.push({ x: Math.cos(angle) * r, y: Math.sin(angle) * r + t * t * 0.4, alpha: Math.max(0, 1 - t) });
    }
    return out;
  }

  return Object.freeze({ FESTIVALS, festivalAt, weekKey, markGoalReached, takeFireworks, fireworkParticles, inRange });
});
