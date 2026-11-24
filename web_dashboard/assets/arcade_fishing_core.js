(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  root.NudgeArcadeFishingCore = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';
  // Starlight fishing: hold to cast, keep holding while the bobber drifts,
  // let go within the "！" window when a fish bites. Rarer fish show the
  // "！" for a shorter time. The collection is local only.

  const BASE_WINDOW_MS = 600;
  const RARITIES = Object.freeze([
    Object.freeze({ id: 'common', name: '普通', weight: 50, windowMs: 600 }),
    Object.freeze({ id: 'uncommon', name: '少見', weight: 25, windowMs: 520 }),
    Object.freeze({ id: 'rare', name: '稀有', weight: 15, windowMs: 440 }),
    Object.freeze({ id: 'shiny', name: '閃亮', weight: 7, windowMs: 360 }),
    Object.freeze({ id: 'legendary', name: '傳說', weight: 3, windowMs: 280 }),
  ]);

  // Order matches the sprite strip assets/arcade/fish.png (48x48 each).
  const FISH = Object.freeze([
    { id: 'pebble-minnow', name: '小石鰷', rarity: 'common', note: '湖邊最常見，喜歡月光下的淺灘。' },
    { id: 'reed-perch', name: '蘆葦鱸', rarity: 'common', note: '躲在蘆葦旁，咬餌很乾脆。' },
    { id: 'lantern-carp', name: '提燈鯉', rarity: 'uncommon', note: '鰭尾像小燈籠，夜裡微微發亮。' },
    { id: 'violet-trout', name: '紫霞鱒', rarity: 'uncommon', note: '黃昏時身上會映出紫色。' },
    { id: 'bell-koi', name: '鐘聲錦鯉', rarity: 'rare', note: '聽到鐘塔的聲音就會浮上來。' },
    { id: 'moss-turtlefish', name: '青苔龜魚', rarity: 'rare', note: '背上長著一小塊苔，慢吞吞的。' },
    { id: 'starscale', name: '星鱗魚', rarity: 'shiny', note: '鱗片像撒了星砂，一閃一閃。' },
    { id: 'aurora-eel', name: '極光鰻', rarity: 'shiny', note: '游過的水面會留下彩色光痕。' },
    { id: 'moon-whale', name: '月影小鯨', rarity: 'legendary', note: '傳說只在月亮最圓的夜裡出現。' },
    { id: 'golden-dragonet', name: '金星龍魚', rarity: 'legendary', note: '鎮上沒有人真的見過牠。' },
  ].map(f => Object.freeze(f)));

  const rarityOf = id => RARITIES.find(r => r.id === id) || null;
  const fishById = id => FISH.find(f => f.id === id) || null;

  function chance(rarityId) {
    const total = RARITIES.reduce((sum, r) => sum + r.weight, 0);
    const r = rarityOf(rarityId);
    return r ? r.weight / total : 0;
  }

  /** Pick a rarity with weights, then a fish of that rarity. rng() -> [0,1). */
  function rollFish(rng = Math.random) {
    const total = RARITIES.reduce((sum, r) => sum + r.weight, 0);
    let pick = clamp01(rng()) * total;
    let rarity = RARITIES[RARITIES.length - 1];
    for (const r of RARITIES) {
      if (pick < r.weight) { rarity = r; break; }
      pick -= r.weight;
    }
    const pool = FISH.filter(f => f.rarity === rarity.id);
    const fish = pool[Math.min(pool.length - 1, Math.floor(clamp01(rng()) * pool.length))];
    return { fish, rarity };
  }

  /** How long the bobber drifts before a bite, 1.5–4.5 s. */
  function biteDelayMs(rng = Math.random) {
    return Math.round(1500 + clamp01(rng()) * 3000);
  }

  /** Window for a rarity; never longer than the 0.6 s base. */
  function windowFor(rarityId) {
    const r = rarityOf(rarityId);
    return Math.min(BASE_WINDOW_MS, r ? r.windowMs : BASE_WINDOW_MS);
  }

  /**
   * Judge a release. biteAt = when "！" appeared (null if not yet).
   * Returns 'early' (let go before the bite), 'caught' or 'late'.
   */
  function judgeRelease(releaseAt, biteAt, windowMs) {
    if (biteAt == null || releaseAt < biteAt) return 'early';
    return releaseAt - biteAt <= windowMs ? 'caught' : 'late';
  }

  /** True once the bite window has closed with the line still held. */
  function escaped(nowMs, biteAt, windowMs) {
    return biteAt != null && nowMs - biteAt > windowMs;
  }

  /** Cast distance 0.35–1 from how long the button was held (full at 0.8 s). */
  function castPower(holdMs) {
    return 0.35 + 0.65 * Math.min(1, Math.max(0, Number(holdMs) || 0) / 800);
  }

  /** Add a catch to the local collection (returns a new object). */
  function addToDex(dex, fishId, nowMs) {
    if (!fishById(fishId)) return { ...(dex || {}) };
    const prev = dex && dex[fishId];
    return {
      ...(dex || {}),
      [fishId]: { count: (prev?.count || 0) + 1, firstAt: prev?.firstAt || nowMs },
    };
  }

  /** Parse a stored collection, keeping only known fish with sane counts. */
  function readDex(raw) {
    let value;
    try { value = JSON.parse(raw || '{}'); } catch { return {}; }
    const out = {};
    if (!value || typeof value !== 'object') return out;
    for (const f of FISH) {
      const e = value[f.id];
      if (e && Number.isInteger(e.count) && e.count > 0 && Number.isFinite(e.firstAt)) {
        out[f.id] = { count: e.count, firstAt: e.firstAt };
      }
    }
    return out;
  }

  function clamp01(v) {
    const n = Number(v);
    if (!Number.isFinite(n) || n < 0) return 0;
    return n >= 1 ? 0.999999 : n;
  }

  return Object.freeze({
    BASE_WINDOW_MS, RARITIES, FISH, rarityOf, fishById, chance, rollFish,
    biteDelayMs, windowFor, judgeRelease, escaped, castPower, addToDex, readDex,
  });
});
