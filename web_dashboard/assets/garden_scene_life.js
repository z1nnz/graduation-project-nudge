(function (root) {
  'use strict';
  // Starlight garden 2.0 (J7) on garden_scene.js: the garden dresses for the
  // season (spring blossom, summer fireflies, autumn maple, winter snow),
  // butterflies, bees and a frog live in it, plants grow up frame by frame
  // the first time you see them this visit, and watering pours from a can
  // while the plant shivers. Watering is play only; no record changes.
  const doc = root.document;
  const room = root.NudgeGardenRoom;
  if (!doc || !room || !root.NudgeWorldLife) return;
  const reduced = () => root.matchMedia('(prefers-reduced-motion: reduce)').matches;

  const SEASONS = {
    spring: { fall: 'petals', label: '春櫻', bloom: '#f6a7c1' },
    summer: { fall: 'fireflies', label: '夏螢', bloom: '#ffe36b' },
    autumn: { fall: 'leaves', label: '秋楓', bloom: '#d9793a' },
    winter: { fall: 'snow', label: '冬雪', bloom: '#e4ecff' },
  };
  function seasonOf(date = new Date()) {
    const m = date.getMonth() + 1;
    return m >= 3 && m <= 5 ? 'spring' : m >= 6 && m <= 8 ? 'summer' : m >= 9 && m <= 11 ? 'autumn' : 'winter';
  }
  const season = (root.location?.search.match(/season=(spring|summer|autumn|winter)/) || [])[1] || seasonOf();
  const S = SEASONS[season];
  room.stage.dataset.season = season;

  const life = root.NudgeWorldLife.attach(room, {
    layouts: {
      wide: { rects: { greenhouse: [0.1, 0.1, 0.18, 0.26], well: [0.79, 0.15, 0.11, 0.23], shed: [0.77, 0.5, 0.22, 0.3] }, skyRect: [0, 0, 1, 0.1],
        spots: { greenhouse: [0.2, 0.42], well: [0.84, 0.42], shed: [0.8, 0.86] }, floor: [0.58, 0.95], start: [0.52, 0.9],
        near: { fall: S.fall, count: 22, plants: [{ x: 0.01, size: 0.2, kind: 'flowers', bloom: S.bloom }, { x: 0.99, size: 0.18, kind: 'flowers', bloom: S.bloom }] } },
      tall: { rects: { greenhouse: [0.03, 0.1, 0.3, 0.22], well: [0.76, 0.15, 0.2, 0.17], shed: [0.62, 0.6, 0.36, 0.22] }, skyRect: [0, 0, 1, 0.07],
        spots: { greenhouse: [0.18, 0.36], well: [0.84, 0.36], shed: [0.78, 0.86] }, floor: [0.56, 0.96], start: [0.5, 0.92],
        near: { fall: S.fall, count: 16, plants: [{ x: 0.02, size: 0.12, kind: 'flowers', bloom: S.bloom }] } },
    },
    acts: {
      greenhouse: { face: 'up', anim: 'think', fx: 'pop', sfx: 'page' },
      well: { face: 'up', anim: 'stretch', fx: 'shake', sfx: 'sparkle', onArrive: () => waterAll() },
      shed: { face: 'up', anim: 'look', fx: 'open', sfx: 'open' },
    },
  });

  // ---- season dressing ----
  const tint = doc.createElement('div');
  tint.className = `gl-season gl-season--${season}`;
  tint.setAttribute('aria-hidden', 'true');
  room.frame.append(tint);
  const chip = doc.getElementById('gardenSeason');
  if (chip) chip.textContent = `季節：${S.label}`;

  // ---- critters: butterflies, bees, a frog ----
  const critters = doc.createElement('canvas');
  critters.className = 'gl-critters';
  critters.setAttribute('aria-hidden', 'true');
  room.frame.append(critters);
  const PX = 3;
  function drawCritters(f) {
    const g = critters.getContext('2d');
    if (!g) return;
    const w = Math.max(16, Math.ceil(room.frame.clientWidth / PX)), h = Math.max(16, Math.ceil(room.frame.clientHeight / PX));
    if (critters.width !== w || critters.height !== h) { critters.width = w; critters.height = h; }
    g.clearRect(0, 0, w, h);
    const flap = f % 4 < 2;
    if (season !== 'winter') {
      for (let i = 0; i < 3; i++) {
        const t = f / 60 + i * 2.1;
        const x = (0.3 + 0.35 * Math.sin(t * 0.7 + i)) * w, y = (0.42 + 0.12 * Math.sin(t * 1.3 + i * 2)) * h;
        g.fillStyle = ['#f6a7c1', '#bfe3ff', '#ffe36b'][i];
        g.fillRect(x - (flap ? 2 : 1), y - 1, flap ? 2 : 1, 2);
        g.fillRect(x + 1, y - 1, flap ? 2 : 1, 2);
        g.fillStyle = '#2a1a14';
        g.fillRect(x, y - 1, 1, 3);
      }
      for (let i = 0; i < 2; i++) {
        const t = f / 20 + i * 3;
        const x = (0.45 + 0.2 * Math.sin(t * 0.5 + i) + 0.01 * Math.sin(t * 6)) * w, y = (0.5 + 0.08 * Math.cos(t * 0.9 + i)) * h;
        g.fillStyle = '#ffc54d'; g.fillRect(x, y, 2, 1);
        g.fillStyle = '#2a1a14'; g.fillRect(x + 1, y, 1, 1);
        g.fillStyle = '#e4ecff'; g.fillRect(x, y - (flap ? 1 : 0), 1, 1);
      }
    }
    // the frog hops between two stones near the path
    const hop = Math.floor(f / 36) % 2, k = (f % 36) / 36;
    const fx = (0.56 + (hop ? 0.06 : 0) + (k < 0.3 ? (hop ? -0.06 : 0.06) * (1 - k / 0.3) : 0)) * w;
    const fy = 0.84 * h - (k < 0.3 ? Math.sin((k / 0.3) * Math.PI) * 4 : 0);
    g.fillStyle = season === 'winter' ? '#7aa6b8' : '#5aa04a';
    g.fillRect(fx - 2, fy - 2, 5, 3);
    g.fillRect(fx - 1, fy - 3, 1, 1); g.fillRect(fx + 1, fy - 3, 1, 1);
    g.fillStyle = '#2a1a14'; g.fillRect(fx - 1, fy - 3, 1, 1); g.fillRect(fx + 2, fy - 3, 1, 1);
  }
  let raf = 0, last = 0, f = 0;
  function loop(now) {
    raf = 0;
    if (doc.hidden || reduced()) return;
    if (now - last > 1000 / 12) { last = now; f++; drawCritters(f); }
    raf = root.requestAnimationFrame(loop);
  }
  function sync() { if (reduced()) { drawCritters(0); } else if (!raf && !doc.hidden) raf = root.requestAnimationFrame(loop); }
  doc.addEventListener('visibilitychange', sync);
  sync();

  // ---- plants grow up frame by frame (once per visit) ----
  const grown = new Set();
  function growIn() {
    if (reduced()) return;
    for (const p of room.frame.querySelectorAll('.gs-plant')) {
      const stage = Number(p.dataset.stage) || 0;
      const key = p.getAttribute('aria-label') || '';
      if (stage < 2 || grown.has(key)) continue;
      grown.add(key);
      p.style.setProperty('--col', '0');
      const t0 = root.performance.now();
      const step = now => {
        const c = Math.min(stage - 1, Math.floor((now - t0) / 180));
        p.style.setProperty('--col', String(c));
        if (c < stage - 1) root.requestAnimationFrame(step);
      };
      root.requestAnimationFrame(step);
    }
  }
  new root.MutationObserver(() => root.setTimeout(growIn, 30)).observe(room.frame, { childList: true, subtree: true });
  growIn();

  // ---- watering: a can pours, the plant shivers ----
  function can(target) {
    if (reduced() || !target) return;
    const r = target.getBoundingClientRect();
    const c = doc.createElement('span');
    c.className = 'gl-can';
    c.setAttribute('aria-hidden', 'true');
    Object.assign(c.style, { left: `${r.left + r.width * 0.55}px`, top: `${r.top - 34}px` });
    c.innerHTML = '<i class="gl-can-body"></i><i class="gl-can-spout"></i><i class="gl-drop"></i><i class="gl-drop"></i><i class="gl-drop"></i>';
    doc.body.append(c);
    target.classList.remove('gl-shake');
    void target.offsetWidth;
    target.classList.add('gl-shake');
    root.setTimeout(() => { c.remove(); target.classList.remove('gl-shake'); }, 1300);
  }
  function waterAll() {
    for (const p of [...room.frame.querySelectorAll('.gs-plant:not([data-stage="0"])')].slice(-6)) can(p);
  }
  doc.getElementById('gardenWater')?.addEventListener('click', () => can(doc.getElementById('gardenDialogSprite')));

  root.NudgeGardenLife = Object.freeze({ season, seasonOf, waterAll, life });
})(typeof globalThis !== 'undefined' ? globalThis : this);
