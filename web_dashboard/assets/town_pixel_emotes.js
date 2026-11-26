(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  root.NudgeTownPixelEmotes = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';
  // #200 H2: pixel-animated emotes instead of emoji. Each emote is an 8x8
  // bitmap ('.' clear, letters = palette) with a 4-frame motion at 8 fps.
  const PALETTE = { k: '#3a1d0c', y: '#ffd77a', o: '#f2a33a', p: '#f26b8a', r: '#c94f4f', w: '#fff6e2', b: '#6aa5e6', g: '#7cc46a', s: '#d8c3a5' };
  const BITMAPS = Object.freeze({
    wave: ['..k.k...', '.kykyk..', '.kyyyyk.', 'kyyyyyk.', 'kyyyyyk.', '.kyyyk..', '..kkk...', '........'],
    heart: ['........', '.kk.kk..', 'kppkppk.', 'kpppppk.', '.kpppk..', '..kpk...', '...k....', '........'],
    study: ['........', 'kkkkkkkk', 'kwwkkwwk', 'kwwkkwwk', 'kwwkkwwk', 'kbbkkbbk', 'kkkkkkkk', '........'],
    sleep: ['kkkk....', '..k.....', '.k..kkk.', 'kkkk..k.', '.....k..', '....kkk.', '........', '........'],
    cheer: ['...y....', '.y.y.y..', '..yyy...', 'yyyoyyy.', '..yyy...', '.y.y.y..', '...y....', '........'],
    sit: ['........', '.kkkkk..', '.kssskk.', '.kssssk.', 'kkkkkkk.', 'k.....k.', 'k.....k.', '........'],
  });
  const MOTION = Object.freeze({
    wave: f => ({ dx: [0, 1, 0, -1][f], dy: 0, scale: 1 }),
    heart: f => ({ dx: 0, dy: [0, -1, -2, -1][f], scale: [1, 1.1, 1.2, 1.1][f] }),
    study: f => ({ dx: 0, dy: [0, 0, -1, 0][f], scale: 1 }),
    sleep: f => ({ dx: [0, 1, 1, 0][f], dy: [0, -1, -2, -3][f], scale: 1 }),
    cheer: f => ({ dx: 0, dy: [0, -2, 0, -1][f], scale: [1, 1.15, 1, 1.05][f] }),
    sit: () => ({ dx: 0, dy: 0, scale: 1 }),
  });

  function frameAt(now, reducedMotion) { return reducedMotion ? 0 : Math.floor(now / 125) % 4; }

  /** Pixel rectangles (in emote cells) for an emote at a frame. */
  function cells(key, frame) {
    const bitmap = BITMAPS[key];
    if (!bitmap) return [];
    const m = MOTION[key](frame);
    const out = [];
    bitmap.forEach((row, y) => [...row].forEach((ch, x) => {
      if (ch !== '.') out.push({ x: x + m.dx, y: y + m.dy, color: PALETTE[ch], scale: m.scale });
    }));
    return out;
  }

  /** Draw an emote centred above (x, y) on a 2D context. */
  function draw(ctx, key, x, y, size, now, reducedMotion) {
    const list = cells(key, frameAt(now, reducedMotion));
    if (!list.length) return false;
    const unit = Math.max(2, Math.round((size / 8) * (list[0].scale || 1)));
    const left = Math.round(x - unit * 4), top = Math.round(y - unit * 8);
    ctx.fillStyle = 'rgba(255,250,240,0.92)';
    ctx.fillRect(left - unit, top - unit, unit * 10, unit * 10);
    for (const c of list) {
      ctx.fillStyle = c.color;
      ctx.fillRect(left + c.x * unit, top + c.y * unit, unit, unit);
    }
    return true;
  }

  return Object.freeze({ BITMAPS, PALETTE, cells, frameAt, draw });
});
