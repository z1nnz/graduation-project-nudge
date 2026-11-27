(function (root) {
  'use strict';
  // Level scenery for every arcade game (J6): the game screen sits inside a
  // full-width, three-layer pixel scene that matches its ride —
  //   stars: night over the Ferris wheel (the wheel turns),
  //   fishing: a moonlit lake (ripples, a bobbing boat, swaying reeds),
  //   rhythm: the clock tower (hands move, notes float up),
  //   memory: the carousel (it spins, bunting sways, balloons rise),
  //   fireflies / constellation: the meadow hills.
  // Far = live sky (world_life.js), mid = the ride, near = falling motes.
  // One rAF loop at 12 fps; paused for hidden tabs; reduced motion = still.
  const doc = root.document;
  const game = doc?.getElementById('arcadeGame');
  const stage = doc?.getElementById('gameStage');
  if (!game || !stage) return;
  const life = root.NudgeWorldLife;
  const reduced = () => root.matchMedia('(prefers-reduced-motion: reduce)').matches;
  const PX = 3;

  const THEMES = {
    stars: { near: 'dust', hills: 0.8 },
    fishing: { near: 'fireflies', hills: 0.55 },
    rhythm: { near: 'dust', hills: 0.82 },
    memory: { near: 'petals', hills: 0.82 },
    fireflies: { near: 'fireflies', hills: 0.7 },
    constellation: { near: 'snow', hills: 0.78 },
  };
  const scene = doc.createElement('div');
  scene.className = 'al-scene';
  scene.setAttribute('aria-hidden', 'true');
  const layers = ['far', 'mid', 'near'].map(k => { const c = doc.createElement('canvas'); c.className = `al-${k}`; scene.append(c); return c; });
  game.prepend(scene);
  game.classList.add('al-on');

  const current = () => doc.querySelector('.arcade-view:not([hidden])')?.dataset.view || '';
  function fit(c) {
    const w = Math.max(32, Math.ceil(scene.clientWidth / PX)), h = Math.max(32, Math.ceil(scene.clientHeight / PX));
    if (c.width !== w || c.height !== h) { c.width = w; c.height = h; }
    const g = c.getContext('2d');
    if (g) g.imageSmoothingEnabled = false;
    return [g, w, h];
  }
  const rect = (g, x, y, w, h, c) => { g.fillStyle = c; g.fillRect(Math.round(x), Math.round(y), Math.round(w), Math.round(h)); };

  const MID = {
    stars(g, w, h, f) {
      const cx = w * 0.82, cy = h * 0.5, r = Math.min(w, h) * 0.32;
      rect(g, cx - 2, cy, 4, h - cy, '#2b2050');
      rect(g, cx - r * 0.6, h - 6, r * 1.2, 6, '#2b2050');
      for (let i = 0; i < 12; i++) {
        const a = (i / 12) * Math.PI * 2 + (f / 240);
        const x = cx + Math.cos(a) * r, y = cy + Math.sin(a) * r;
        for (let s = 0; s < r; s += 2) rect(g, cx + Math.cos(a) * s, cy + Math.sin(a) * s, 1, 1, '#4a3a7a');
        rect(g, x - 3, y - 2, 6, 5, i % 3 ? '#d8452e' : '#ffc54d');
        rect(g, x - 1, y - 4, 2, 2, '#2b2050');
      }
    },
    fishing(g, w, h, f) {
      const water = h * 0.58;
      rect(g, 0, water, w, h - water, '#203a6a');
      for (let i = 0; i < 40; i++) {
        const y = water + 4 + (i * 7) % (h - water - 4);
        const x = ((i * 53 + f * (0.3 + (i % 3) * 0.2)) % (w + 20)) - 10;
        rect(g, x, y, 6 + (i % 4) * 2, 1, i % 5 ? '#3c5a96' : '#f6f0d8');
      }
      const bob = Math.round(Math.sin(f / 10) * 1.5);
      rect(g, w * 0.7, water - 6 + bob, 26, 6, '#8a5a34');
      rect(g, w * 0.7 + 12, water - 18 + bob, 1, 12, '#3a2216');
    },
    rhythm(g, w, h, f) {
      const x = w * 0.08, tw = Math.max(24, w * 0.12);
      rect(g, x, h * 0.25, tw, h * 0.75, '#2b2050');
      rect(g, x - 4, h * 0.22, tw + 8, 6, '#3a2a60');
      for (let k = 0; k < 6; k++) rect(g, x + tw / 2 - 6 + k * 2, h * 0.1 + k * 2, 12 - k * 4 > 0 ? 12 - k * 4 : 1, 2, '#3a2a60');
      const cx = x + tw / 2, cy = h * 0.34, r = tw * 0.32;
      for (let a = 0; a < 6.28; a += 0.2) rect(g, cx + Math.cos(a) * r, cy + Math.sin(a) * r, 1, 1, '#f6e7c8');
      const d = new Date();
      for (const [turns, len] of [[(d.getHours() % 12 + d.getMinutes() / 60) / 12, r * 0.5], [d.getMinutes() / 60, r * 0.85]]) {
        const a = turns * 6.283 - 1.5708;
        for (let s = 0; s < len; s += 1) rect(g, cx + Math.cos(a) * s, cy + Math.sin(a) * s, 1, 1, '#ffc54d');
      }
      for (let i = 0; i < 5; i++) {
        const t = ((f / 90) + i / 5) % 1;
        const nx = x + tw + 8 + i * 12 + Math.sin(t * 6 + i) * 4, ny = h * (0.8 - t * 0.6);
        rect(g, nx, ny, 3, 3, '#8b6cf0'); rect(g, nx + 2, ny - 6, 1, 6, '#8b6cf0');
      }
    },
    memory(g, w, h, f) {
      const cx = w * 0.85, base = h * 0.82, tw = Math.max(40, w * 0.22);
      for (let k = 0; k < 10; k++) rect(g, cx - (k / 10) * tw / 2, base - tw * 0.55 + k * 2 - 20, (k / 10) * tw, 2, k % 2 ? '#d8452e' : '#f6e7c8');
      rect(g, cx - tw / 2, base - tw * 0.35, tw, 4, '#ffc54d');
      for (let i = 0; i < 6; i++) {
        const a = (i / 6) * Math.PI * 2 + f / 50;
        const x = cx + Math.cos(a) * tw * 0.4, y = base - tw * 0.18 + Math.sin(a) * 4 + (Math.sin(f / 6 + i) > 0 ? -2 : 0);
        rect(g, x - 1, base - tw * 0.33, 1, tw * 0.2, '#ffc54d');
        if (Math.sin(a) > -0.2) rect(g, x - 4, y, 8, 5, i % 2 ? '#f6e7c8' : '#8b6cf0');
      }
      rect(g, cx - tw / 2, base, tw, 3, '#3a2216');
      for (let i = 0; i < 3; i++) {
        const t = ((f / 150) + i / 3) % 1;
        const bx = w * (0.1 + i * 0.12), by = h * (1 - t);
        rect(g, bx, by, 6, 7, ['#d8452e', '#ffc54d', '#6fa8d8'][i]);
        rect(g, bx + 3, by + 7, 1, 8, '#f6e7c8');
      }
    },
    fireflies(g, w, h) {
      rect(g, 0, h * 0.86, w, h * 0.14, '#1f3a2a');
      for (let x = 0; x < w; x += 3) rect(g, x, h * 0.84 - (x * 7) % 5, 1, 6, '#2f5a3a');
    },
    constellation(g, w, h) {
      rect(g, w * 0.82, h * 0.6, 3, h * 0.25, '#3a2216');
      rect(g, w * 0.78, h * 0.55, 20, 6, '#8b6cf0');
    },
  };

  let raf = 0, last = 0, f = 0;
  function paint() {
    const id = current();
    scene.dataset.theme = id;
    if (!id) return;
    const T = THEMES[id] || THEMES.stars;
    const hour = id === 'memory' ? 19 : 22;
    const [gf, wf, hf] = fit(layers[0]);
    if (gf && life) life.drawSky(gf, wf, hf, f, { hour, skyRect: [0, 0, 1, 0.7], hills: T.hills });
    const [gm, wm, hm] = fit(layers[1]);
    if (gm) { gm.clearRect(0, 0, wm, hm); (MID[id] || MID.fireflies)(gm, wm, hm, f); }
    const [gn, wn, hn] = fit(layers[2]);
    if (gn && life) { gn.clearRect(0, 0, wn, hn); life.drawNear(gn, wn, hn, f, { fall: T.near, count: 20, plants: [{ x: 0.01, size: 0.22, kind: 'fern' }, { x: 0.99, size: 0.2, kind: 'flowers', bloom: '#f6a7c1' }] }); }
  }
  function loop(now) {
    raf = 0;
    if (doc.hidden || game.hidden || reduced()) { paint(); return; }
    if (now - last >= 1000 / 12) { last = now; f++; paint(); }
    raf = root.requestAnimationFrame(loop);
  }
  function kick() { if (!raf) raf = root.requestAnimationFrame(loop); }
  new root.MutationObserver(kick).observe(game, { attributes: true, attributeFilter: ['hidden'], subtree: true });
  doc.addEventListener('visibilitychange', kick);
  root.addEventListener('resize', () => { paint(); kick(); });
  kick();
  root.NudgeArcadeLevels = Object.freeze({ THEMES, paint });
})(typeof globalThis !== 'undefined' ? globalThis : this);
