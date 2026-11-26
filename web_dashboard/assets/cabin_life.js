(function (root) {
  'use strict';
  // Cabin 3.0 (J4) on top of cabin.js, without touching its data flow:
  // a live sky behind the window (art keyed in tool/world_art), the player's
  // layered character instead of the flat companion picture, the companion's
  // day by the real clock (stretch at dawn, desk, snack at noon, the window
  // at dusk, futon at night), curtains that draw at night, a lamp that lights
  // the room, a ticking wall clock, books that slide out, a pet that tags
  // along, and dust or ivy in front. Reduced motion: one still frame.
  const doc = root.document;
  const stage = doc?.getElementById('cabinStage');
  const core = root.NudgeWorldLifeCore;
  const life = root.NudgeWorldLife;
  if (!stage || !core) return;

  const media = root.matchMedia?.('(prefers-reduced-motion: reduce)');
  const reduced = () => Boolean(media?.matches);
  const MID = {
    'assets/home/room_base.png': 'assets/scenes/cabin/room_base_mid.webp',
    'assets/scenes/workbench/cabin_wide.webp': 'assets/scenes/workbench/cabin_wide_mid.webp',
  };
  const SPOTS = {
    tall: { clock: [0.455, 0.262, 0.09, 0.05], folded: [0.72, 0.6, 0.15, 0.07], sky: [0.3, 0.05, 0.4, 0.19] },
    wide: { clock: [0.635, 0.29, 0.04, 0.065], folded: [0.66, 0.63, 0.07, 0.09], sky: [0.38, 0.09, 0.26, 0.26] },
  };
  const hour = () => { const d = new Date(); return d.getHours() + d.getMinutes() / 60; };
  const wide = () => stage.dataset.layout === 'wide';
  const rugView = () => (wide() ? [0.5, 0.7 + ((0.72 - 0.6) / 0.26) * 0.25] : [0.5, 0.72]);

  stage.classList.add('cl-on');
  const make = (tag, cls) => { const n = doc.createElement(tag); n.className = cls; n.setAttribute('aria-hidden', 'true'); return n; };
  const sky = make('canvas', 'cl-sky');
  const near = make('canvas', 'cl-near');
  const light = make('div', 'cl-light');
  const clock = make('canvas', 'cl-clock');
  const futon = make('img', 'cl-futon');
  const blanket = make('img', 'cl-blanket');
  const drape = make('div', 'cl-drape');
  drape.append(make('i', 'cl-drape-l'), make('i', 'cl-drape-r'));
  const actors = make('div', 'cl-actors');
  futon.alt = blanket.alt = '';
  blanket.src = 'assets/scenes/cabin/blanket.png';
  stage.prepend(sky);
  stage.append(futon, actors, blanket, drape, clock, light, near);

  // Keyed base art: the sky shows through the window.
  const base = doc.getElementById('cabinBase');
  function swapBase() {
    const src = base.getAttribute('src');
    if (MID[src]) base.setAttribute('src', MID[src]);
  }
  new root.MutationObserver(swapBase).observe(base, { attributes: true, attributeFilter: ['src'] });
  swapBase();

  // Layered player as the companion.
  const button = doc.getElementById('cabinCompanion');
  const holder = make('span', 'cl-avatar');
  button.append(holder);
  let avatar = null, scale = 0;
  function buildAvatar() {
    if (!root.NudgeAvatarLayers) return;
    const h = button.getBoundingClientRect().height || 150;
    const s = Math.max(1, Math.round(h / (56 * 0.72)));
    if (s === scale && avatar) return;
    scale = s;
    avatar?.destroy();
    avatar = root.NudgeAvatarLayers.create(holder, { look: root.NudgeAvatarLayers.loadLook(), scale: s });
    stage.classList.add('cl-avatar-on');
    anim = '';
  }

  let anim = '', last = null, lastT = 0, curtainOpen = null, lampOn = true;
  function pos() { return [parseFloat(button.style.left) / 100 || 0.5, parseFloat(button.style.top) / 100 || 0.72]; }
  function wanted(p) {
    const pose = button.dataset.pose;
    if (pose === 'walk' && last) {
      const dx = p[0] - last[0], dy = p[1] - last[1];
      if (Math.hypot(dx, dy) > 0.0004) return `walk_${core.direction(last, p, wide() ? 1.5 : 0.56)}`;
      return anim.startsWith('walk_') ? anim : 'idle';
    }
    if (pose === 'read') return 'read';
    if (pose === 'sleep') return 'sleep';
    if (pose === 'cheer') return 'happy';
    const r = core.routineAt(hour());
    return ['stretch', 'snack', 'look', 'sit', 'read'].includes(r.act) ? r.act : 'idle';
  }
  function setAnim(a) {
    if (!avatar || a === anim) return;
    anim = a;
    avatar.play(a, { onEnd: () => { anim = ''; } });
    button.dataset.avatarAnimation = a;
  }

  const pet = root.NudgePets?.follow(actors, () => pos(), { reduced, scale: 3 });

  function place(n, r) {
    Object.assign(n.style, { left: r[0] * 100 + '%', top: r[1] * 100 + '%', width: r[2] * 100 + '%', height: r[3] * 100 + '%' });
  }
  function layoutProps() {
    const S = SPOTS[wide() ? 'wide' : 'tall'];
    place(clock, S.clock);
    const curtain = stage.querySelector('img[data-slot="curtain"]');
    if (curtain) {
      drape.style.left = curtain.style.left; drape.style.top = curtain.style.top;
      drape.style.width = curtain.style.width; drape.style.height = curtain.style.height;
    }
    const lamp = stage.querySelector('img[data-slot="lamp"]');
    if (lamp) {
      light.style.setProperty('--cl-lamp-x', `${parseFloat(lamp.style.left) + parseFloat(lamp.style.width) / 2}%`);
      light.style.setProperty('--cl-lamp-y', `${parseFloat(lamp.style.top) + parseFloat(lamp.style.height) / 3}%`);
    }
    const h = hour();
    const sleeping = button.dataset.pose === 'sleep';
    const bedtime = h >= 21 || h < 6.5 || sleeping;
    const [rx, ry] = rugView();
    const fw = wide() ? 0.2 : 0.42;
    if (bedtime) {
      futon.src = 'assets/scenes/cabin/futon_open.png';
      place(futon, [rx - fw / 2, ry - fw * (22 / 56) * (wide() ? 1.5 : 0.5629) * 0.8, fw, fw * (22 / 56) * (wide() ? 1.5 : 0.5629)]);
    } else {
      futon.src = 'assets/scenes/cabin/futon_folded.png';
      place(futon, S.folded);
    }
    blanket.hidden = !sleeping;
    if (sleeping) {
      const p = pos();
      const bw = fw * 0.62;
      place(blanket, [p[0] - bw * 0.1, p[1] - bw * (14 / 40) * (wide() ? 1.5 : 0.5629) * 0.9, bw, bw * (14 / 40) * (wide() ? 1.5 : 0.5629)]);
    }
    stage.dataset.bed = sleeping ? 'asleep' : bedtime ? 'open' : 'folded';
    const shouldOpen = curtainOpen ?? core.daylight(h) > 0.2;
    stage.classList.toggle('cl-curtain-closed', !shouldOpen);
    lampOn = !stage.classList.contains('is-lamp-off');
    light.style.setProperty('--cl-dark', String((1 - core.daylight(h)) * (lampOn ? 0.18 : 0.42)));
    light.classList.toggle('is-lamp', lampOn && core.daylight(h) < 0.6);
    stage.dataset.phase = core.phaseAt(h);
  }

  function drawClock(g, w, h) {
    g.clearRect(0, 0, w, h);
    const cx = w / 2, cy = h / 2, r = Math.min(w, h) / 2 - 1;
    g.fillStyle = '#3a2216';
    g.fillRect(cx - r, cy - r + 1, r * 2, r * 2 - 2);
    g.fillRect(cx - r + 1, cy - r, r * 2 - 2, r * 2);
    g.fillStyle = '#f6e7c8';
    g.fillRect(cx - r + 1, cy - r + 2, r * 2 - 2, r * 2 - 4);
    g.fillRect(cx - r + 2, cy - r + 1, r * 2 - 4, r * 2 - 2);
    g.fillStyle = '#8a5a34';
    for (let i = 0; i < 12; i += 3) {
      const a = (i / 12) * Math.PI * 2;
      g.fillRect(Math.round(cx + Math.sin(a) * (r - 2)) - 0, Math.round(cy - Math.cos(a) * (r - 2)), 1, 1);
    }
    const d = new Date();
    const hand = (a, len, color) => {
      g.fillStyle = color;
      for (let s = 0; s <= len; s += 0.5) g.fillRect(Math.round(cx + Math.sin(a) * s - 0.5), Math.round(cy - Math.cos(a) * s - 0.5), 1, 1);
    };
    hand(((d.getHours() % 12) + d.getMinutes() / 60) / 12 * Math.PI * 2, r * 0.5, '#2a1a14');
    hand((d.getMinutes() + d.getSeconds() / 60) / 60 * Math.PI * 2, r * 0.8, '#2a1a14');
    hand(d.getSeconds() / 60 * Math.PI * 2, r * 0.85, '#d8452e');
  }

  const PX = 3;
  function fit(c, div = PX) {
    const w = Math.max(8, Math.ceil(c.clientWidth / div)), h = Math.max(8, Math.ceil(c.clientHeight / div));
    if (c.width !== w || c.height !== h) { c.width = w; c.height = h; }
    return [w, h];
  }
  let frameNo = 0;
  function paint() {
    const S = SPOTS[wide() ? 'wide' : 'tall'];
    const gs = sky.getContext('2d');
    if (gs && life) { const [w, h] = fit(sky); life.drawSky(gs, w, h, frameNo, { hour: hour(), skyRect: S.sky, hills: S.sky[1] + S.sky[3] * 0.95 }); }
    const gn = near.getContext('2d');
    if (gn && life) {
      const [w, h] = fit(near);
      gn.clearRect(0, 0, w, h);
      life.drawNear(gn, w, h, frameNo, { fall: core.phaseAt(hour()) === 'night' ? 'fireflies' : 'dust', count: 14,
        plants: [{ x: 0.02, y: 0, size: 0.14, kind: 'ivy' }, { x: 0.98, y: 0, size: 0.12, kind: 'ivy' }] });
    }
    const gc = clock.getContext('2d');
    if (gc) { const [w, h] = fit(clock, 2); drawClock(gc, w, h); }
    layoutProps();
  }

  let raf = 0, lastPaint = 0;
  function loop(now) {
    raf = 0;
    if (doc.hidden || reduced()) return;
    const p = pos();
    setAnim(wanted(p));
    pet?.update(p, now);
    last = p;
    if (now - lastPaint > 1000 / 12) { lastPaint = now; frameNo++; paint(); }
    lastT = now;
    raf = root.requestAnimationFrame(loop);
  }
  function sync() {
    buildAvatar();
    if (reduced()) {
      if (raf) root.cancelAnimationFrame(raf);
      raf = 0;
      setAnim(wanted(pos()));
      pet?.update(pos(), 0);
      paint();
    } else if (!raf && !doc.hidden) raf = root.requestAnimationFrame(loop);
  }

  // Furniture answers: curtains draw, books slide out, lamp brightens.
  stage.addEventListener('click', e => {
    const t = e.target.closest?.('.cabin-touch');
    if (!t) return;
    const label = t.getAttribute('aria-label') || '';
    if (label.startsWith('窗戶')) {
      curtainOpen = !(curtainOpen ?? core.daylight(hour()) > 0.2);
      root.NudgeSfx?.play('open');
    } else if (label.startsWith('書架')) {
      const books = stage.querySelector('img[data-slot="books"]');
      if (books && !reduced()) { books.classList.remove('cl-pull'); void books.offsetWidth; books.classList.add('cl-pull'); }
      root.NudgeSfx?.play('page');
    } else if (label.startsWith('檯燈')) {
      root.NudgeSfx?.play('tap');
    }
    root.setTimeout(paint, 30);
  }, true);

  doc.addEventListener('visibilitychange', sync);
  media?.addEventListener?.('change', sync);
  root.addEventListener('resize', () => root.setTimeout(() => { scale = 0; buildAvatar(); paint(); }, 150));
  root.addEventListener('nudge-cabin-layout', () => root.setTimeout(paint, 0));
  new root.MutationObserver(() => { if (!avatar) sync(); }).observe(button, { attributes: true, attributeFilter: ['style'] });
  root.NudgeCabinLife = Object.freeze({ paint, routine: () => core.routineAt(hour()), get avatar() { return avatar; } });
  sync();
})(typeof globalThis !== 'undefined' ? globalThis : this);
