(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.NudgeArcadeMoreCore = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';
  // Rules for the two new park games (J6), no DOM:
  //  - Firefly lanterns: catch fireflies while they glow; quick catches chain
  //    a combo; 45 seconds.
  //  - Constellation: watch the stars light up in order, then tap them back;
  //    one more star each round; two slips end the night.

  // ---------- firefly lanterns ----------
  const FIREFLY = Object.freeze({ W: 320, H: 180, MS: 45000, COUNT: 7, RADIUS: 12, COMBO_MS: 1200, GLOW_MS: 1300, DARK_MS: 900 });

  function rng(seed) {
    let s = seed >>> 0 || 1;
    return () => {
      s ^= s << 13; s >>>= 0;
      s ^= s >> 17;
      s ^= s << 5; s >>>= 0;
      return s / 4294967296;
    };
  }

  function newFireflies(seed = 1) {
    const r = rng(seed);
    return {
      t: 0, score: 0, caught: 0, combo: 0, best: 0, lastCatch: -1e9, done: false, rand: r,
      flies: Array.from({ length: FIREFLY.COUNT }, (_, i) => spawn(r, i)),
    };
  }
  function spawn(r, i) {
    return { id: i, ax: 30 + r() * 260, ay: 30 + r() * 110, phase: r() * 6.28, speed: 0.4 + r() * 0.6, offset: Math.floor(r() * (FIREFLY.GLOW_MS + FIREFLY.DARK_MS)) };
  }
  /** Where a firefly is and whether it glows at time t (ms). */
  function flyAt(f, t) {
    const a = f.phase + (t / 1000) * f.speed;
    const cycle = (t + f.offset) % (FIREFLY.GLOW_MS + FIREFLY.DARK_MS);
    return { x: f.ax + Math.sin(a) * 24, y: f.ay + Math.sin(a * 1.7) * 14, lit: cycle < FIREFLY.GLOW_MS };
  }
  function stepFireflies(s, dtMs) {
    if (s.done) return s;
    s.t += dtMs;
    if (s.t >= FIREFLY.MS) s.done = true;
    return s;
  }
  /** Try to catch at (x, y); returns { s, event: 'catch'|'dark'|'miss', points }. */
  function catchAt(s, x, y) {
    if (s.done) return { s, event: 'miss', points: 0 };
    let hit = null, dark = false;
    for (const f of s.flies) {
      const p = flyAt(f, s.t);
      if (Math.hypot(p.x - x, p.y - y) <= FIREFLY.RADIUS) {
        if (p.lit) { hit = f; break; }
        dark = true;
      }
    }
    if (!hit) {
      s.combo = 0;
      return { s, event: dark ? 'dark' : 'miss', points: 0 };
    }
    s.combo = s.t - s.lastCatch <= FIREFLY.COMBO_MS ? s.combo + 1 : 1;
    s.best = Math.max(s.best, s.combo);
    s.lastCatch = s.t;
    const points = 10 + Math.min(5, s.combo - 1) * 2;
    s.score += points;
    s.caught += 1;
    const i = s.flies.indexOf(hit);
    s.flies[i] = spawn(s.rand, hit.id);
    return { s, event: 'catch', points };
  }
  function fireflyGrade(score) {
    return score >= 300 ? 'S' : score >= 200 ? 'A' : score >= 120 ? 'B' : 'C';
  }

  // ---------- constellation ----------
  const CONST = Object.freeze({ W: 320, H: 180, START: 3, MAX: 10, SLIPS: 2, SHOW_MS: 600, MS: 90000 });

  function newConstellation(seed = 7) {
    const s = { rand: rng(seed), round: 0, stars: [], order: [], pos: 0, score: 0, slips: 0, phase: 'show', showT: 0, t: 0, done: false };
    return nextRound(s);
  }
  function nextRound(s) {
    s.round += 1;
    const n = Math.min(CONST.MAX, CONST.START + s.round - 1);
    s.stars = [];
    let guard = 0;
    while (s.stars.length < n && guard++ < 500) {
      const p = { x: 24 + s.rand() * 272, y: 22 + s.rand() * 136 };
      if (s.stars.every(q => Math.hypot(q.x - p.x, q.y - p.y) > 30)) s.stars.push(p);
    }
    s.order = s.stars.map((_, i) => i);
    for (let i = s.order.length - 1; i > 0; i--) {
      const j = Math.floor(s.rand() * (i + 1));
      [s.order[i], s.order[j]] = [s.order[j], s.order[i]];
    }
    s.pos = 0;
    s.phase = 'show';
    s.showT = 0;
    return s;
  }
  /** Index of the star lit while the order is shown, or -1. */
  function showing(s) {
    if (s.phase !== 'show') return -1;
    const k = Math.floor(s.showT / CONST.SHOW_MS);
    return k < s.order.length ? s.order[k] : -1;
  }
  function stepConstellation(s, dtMs) {
    if (s.done) return s;
    s.t += dtMs;
    if (s.t >= CONST.MS) { s.done = true; return s; }
    if (s.phase === 'show') {
      s.showT += dtMs;
      if (s.showT >= CONST.SHOW_MS * (s.order.length + 0.5)) s.phase = 'input';
    }
    return s;
  }
  /** Pick star [i]; returns { s, event: 'link'|'complete'|'slip'|'over'|'wait' }. */
  function pick(s, i) {
    if (s.done || s.phase !== 'input') return { s, event: 'wait' };
    if (s.order[s.pos] === i) {
      s.pos += 1;
      s.score += 1;
      if (s.pos >= s.order.length) {
        s.score += s.order.length;
        nextRound(s);
        return { s, event: 'complete' };
      }
      return { s, event: 'link' };
    }
    s.slips += 1;
    if (s.slips >= CONST.SLIPS) { s.done = true; return { s, event: 'over' }; }
    s.pos = 0;
    s.phase = 'show';
    s.showT = 0;
    return { s, event: 'slip' };
  }
  /** Nearest star to (x, y) within reach, or -1. */
  function starAt(s, x, y, reach = 14) {
    let best = -1, d = reach;
    s.stars.forEach((p, i) => { const k = Math.hypot(p.x - x, p.y - y); if (k <= d) { d = k; best = i; } });
    return best;
  }
  function constellationGrade(score) {
    return score >= 45 ? 'S' : score >= 28 ? 'A' : score >= 14 ? 'B' : 'C';
  }

  return {
    FIREFLY, CONST, rng, newFireflies, flyAt, stepFireflies, catchAt, fireflyGrade,
    newConstellation, nextRound, showing, stepConstellation, pick, starAt, constellationGrade,
  };
});
