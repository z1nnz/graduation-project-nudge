(function (root) {
  'use strict';
  // Living-scene layer on top of a scene_room.js room, without changing it:
  //   far  – a live pixel sky behind the art (time of day, clouds, stars,
  //          moon, birds) seen through windows keyed out of the art;
  //   mid  – the room art, plus object pieces that move (doors swing,
  //          drawers slide, lamps light) when used;
  //   near – swaying foreground plants and falling petals/leaves/snow.
  // The player's companion (the earlier companion sheet, or the layered
  // character with { player: 'layered' } in the dressing room) walks to
  // whatever you tap,
  // acts, and only then the room opens the feature. NPCs get emotes and hop
  // when they talk. Parallax follows the pointer. One rAF loop at 12 fps,
  // paused for hidden tabs; prefers-reduced-motion draws one full still frame
  // and the player steps straight to the spot.
  //
  //   NudgeWorldLife.attach(room, { layouts: { wide: {...}, tall: {...} }, acts, near, ... })
  //
  // Suggested for the shared components once it settles (共用元件).
  const doc = root.document;
  const core = root.NudgeWorldLifeCore;
  if (!doc || !core) return;

  const FPS = 12;
  const PX = 3; // css px per canvas pixel: chunky like the art

  function el(tag, cls, attrs = {}) {
    const n = doc.createElement(tag);
    if (cls) n.className = cls;
    for (const [k, v] of Object.entries(attrs)) n.setAttribute(k, v);
    return n;
  }
  const hash = i => { const x = Math.sin(i * 127.1 + 311.7) * 43758.5453; return x - Math.floor(x); };

  // ---------------------------------------------------------------- sky
  function drawSky(g, w, h, f, o) {
    const hour = o.hour;
    const [top, mid, low] = core.skyColors(hour);
    const phase = core.phaseAt(hour);
    const bands = [top, top, mid, mid, low];
    const bh = Math.ceil(h / bands.length);
    for (let i = 0; i < bands.length; i++) {
      g.fillStyle = bands[i];
      g.fillRect(0, i * bh, w, bh + 1);
      if (i + 1 < bands.length && bands[i + 1] !== bands[i]) {
        g.fillStyle = bands[i + 1];
        for (let x = (i % 2); x < w; x += 2) g.fillRect(x, (i + 1) * bh - 1, 1, 1);
      }
    }
    const [sx, sy, sw, sh] = o.skyRect || [0, 0, 1, 0.3];
    const X = v => Math.round((sx + v * sw) * w), Y = v => Math.round((sy + v * sh) * h);
    if (phase === 'night' || phase === 'dusk' || phase === 'dawn') {
      for (let i = 0; i < 70; i++) {
        const tw = (Math.floor(f / 6) + i) % 9 === 0;
        if (tw) continue;
        g.fillStyle = i % 7 === 0 ? '#ffe7a8' : '#f6f0ff';
        g.fillRect(X(hash(i)), Y(hash(i + 99) * 0.9), 1, 1);
      }
      if (phase === 'night' && (f % 240) < 10) {
        const k = (f % 240) / 10;
        g.fillStyle = '#fff';
        g.fillRect(X(0.2 + k * 0.3), Y(0.1 + k * 0.15), 2, 1);
      }
    }
    const b = core.bodyAt(hour);
    const bx = X(b.x), by = Y(0.15 + b.y * 0.7), r = 3;
    g.fillStyle = b.kind === 'sun' ? '#ffd56b' : '#f6f0d8';
    g.fillRect(bx - r, by - r + 1, r * 2, r * 2 - 2);
    g.fillRect(bx - r + 1, by - r, r * 2 - 2, r * 2);
    if (b.kind === 'moon') {
      g.fillStyle = top;
      g.fillRect(bx, by - r, r, r * 2 - 1);
    }
    const cloud = phase === 'day' ? '#ffffff' : phase === 'night' ? '#3c2d66' : '#f2b2c4';
    for (let i = 0; i < 5; i++) {
      const speed = 0.004 + hash(i + 5) * 0.004;
      const cx = ((hash(i + 11) + f * speed / 10) % 1.3) - 0.15;
      const cy = 0.15 + hash(i + 21) * 0.6;
      const cw = Math.max(6, Math.round(sw * w * (0.12 + hash(i) * 0.1)));
      const x0 = X(cx), y0 = Y(cy);
      g.fillStyle = cloud;
      g.fillRect(x0, y0, cw, 2);
      g.fillRect(x0 + 2, y0 - 1, cw - 4, 1);
      g.fillRect(x0 + Math.round(cw / 3), y0 - 2, Math.round(cw / 3), 1);
    }
    if (phase === 'day') {
      for (let i = 0; i < 3; i++) {
        const t = ((f / 400) + i * 0.33) % 1;
        const x = X(t), y = Y(0.3 + 0.2 * Math.sin(t * 6 + i));
        g.fillStyle = '#3a2a40';
        const flap = (f + i * 3) % 6 < 3;
        g.fillRect(x - 1, y - (flap ? 1 : 0), 1, 1);
        g.fillRect(x, y, 1, 1);
        g.fillRect(x + 1, y - (flap ? 1 : 0), 1, 1);
      }
    }
    if (o.hills) {
      const hy = Y(o.hills);
      g.fillStyle = phase === 'day' ? '#6f8fb8' : '#2b2050';
      for (let x = 0; x < w; x++) {
        const y = hy - Math.round(3 + 2 * Math.sin(x / 9) + 1.5 * Math.sin(x / 4 + 2));
        g.fillRect(x, y, 1, h - y);
      }
    }
  }

  // ---------------------------------------------------------------- near
  const FALL = {
    petals: ['#f6a7c1', '#f9c9d8'], leaves: ['#d9793a', '#c9a227'], snow: ['#ffffff', '#e4ecff'],
    dust: ['#ffe7a8', '#fff3cf'], fireflies: ['#e9ff8a', '#ffe36b'],
  };
  function drawNear(g, w, h, f, o) {
    const kinds = FALL[o.fall || 'dust'] || FALL.dust;
    const n = o.count ?? 18;
    for (let i = 0; i < n; i++) {
      const sp = 0.6 + hash(i) * 0.8;
      const y = ((hash(i + 3) * h + f * sp * (o.fall === 'snow' ? 0.5 : 0.35)) % (h + 10)) - 5;
      const x = (hash(i + 7) * w + Math.sin(f / 25 + i) * 6 + (o.fall === 'dust' ? 0 : f * 0.15)) % w;
      g.fillStyle = kinds[i % kinds.length];
      if (o.fall === 'fireflies') {
        if ((f + i * 5) % 30 < 14) g.fillRect(x | 0, (h * 0.4 + (y % (h * 0.6))) | 0, 1, 1);
      } else if (o.fall === 'leaves' || o.fall === 'petals') {
        const flip = (f + i * 4) % 16 < 8;
        g.fillRect(x | 0, y | 0, flip ? 2 : 1, flip ? 1 : 2);
      } else {
        g.fillRect(x | 0, y | 0, o.fall === 'snow' && i % 3 === 0 ? 2 : 1, 1);
      }
    }
    for (const p of o.plants || []) drawPlant(g, w, h, f, p);
  }

  function drawPlant(g, w, h, f, p) {
    const [px, py] = [Math.round(p.x * w), Math.round((p.y ?? 1) * h)];
    const size = Math.round((p.size || 0.16) * h);
    const dark = p.color || '#1f3a2a', light = p.light || '#2f5a3a';
    const hanging = p.kind === 'ivy';
    const fronds = p.fronds || (hanging ? 4 : 6);
    for (let i = 0; i < fronds; i++) {
      const spread = (i / Math.max(1, fronds - 1) - 0.5) * (hanging ? 0.6 : 1.6);
      const sway = Math.sin(f / 18 + i * 0.9 + p.x * 10) * 0.08;
      const ang = (hanging ? Math.PI / 2 : -Math.PI / 2) + spread + sway;
      const len = size * (0.6 + 0.4 * hash(i + p.x * 50));
      for (let s = 0; s < len; s += 1) {
        const bend = (s / len) ** 2 * (spread > 0 ? 0.5 : -0.5) * (hanging ? -1 : 1);
        const x = px + Math.cos(ang + bend) * s, y = py + Math.sin(ang + bend) * s;
        g.fillStyle = s % 4 < 2 ? dark : light;
        g.fillRect(x | 0, y | 0, 1, 1);
        if (s % 3 === 0 && s > 2) {
          g.fillRect((x + 1) | 0, (y + (hanging ? 1 : -1)) | 0, 1, 1);
          g.fillRect((x - 1) | 0, (y + (hanging ? 1 : -1)) | 0, 1, 1);
        }
      }
      if (p.kind === 'flowers' && i % 2 === 0) {
        const x = px + Math.cos(ang) * len, y = py + Math.sin(ang) * len;
        g.fillStyle = p.bloom || '#e27aa6';
        g.fillRect((x - 1) | 0, (y - 1) | 0, 2, 2);
      }
    }
  }

  // ---------------------------------------------------------------- emotes
  const emoteCache = new Map();
  function emoteUrl(kind) {
    if (emoteCache.has(kind)) return emoteCache.get(kind);
    const grid = core.EMOTES[kind] || core.EMOTES.dots;
    const c = doc.createElement('canvas');
    c.width = 11; c.height = 11;
    const g = c.getContext('2d');
    if (!g) return '';
    g.fillStyle = '#fff6e4';
    g.fillRect(1, 1, 9, 9);
    g.fillStyle = '#2a1a14';
    g.fillRect(1, 0, 9, 1); g.fillRect(1, 10, 9, 1); g.fillRect(0, 1, 1, 9); g.fillRect(10, 1, 1, 9);
    grid.forEach((row, y) => [...row].forEach((ch, x) => {
      if (ch === '.') return;
      g.fillStyle = ch === '#' ? '#2a1a14' : ch === 'x' ? core.EMOTE_COLORS[kind] || '#2a1a14' : '#fff6e4';
      g.fillRect(x + 1, y + 1, 1, 1);
    }));
    const url = c.toDataURL();
    emoteCache.set(kind, url);
    return url;
  }

  // ---------------------------------------------------------------- actor
  // The earlier companion sheet with the layered player's API. Actions the
  // sheet has no row for play its nearest row plus a small code-drawn motion
  // (sit, read, stretch, snack, look, talk), like the App's CompanionSprite.
  const ACT_ROW = {
    idle: 'idle', look: 'idle', turn: 'idle', sit: 'idle', read: 'think', sleep: 'sleep', happy: 'happy', wave: 'wave',
    think: 'think', stretch: 'happy', snack: 'idle', talk: 'idle',
  };
  const ONE_SHOT = { stretch: 900, happy: 0, wave: 0 };
  function companionActor(el, opts = {}) {
    const P = root.NudgeSpritePlayer;
    if (!P) return null;
    el.dataset.kind = 'companion';
    let name = opts.animation || 'idle', timer = 0;
    const sp = P.characterPlayer(el, 'companion', { animation: 'idle', size: opts.size || 112 });
    function play(next, more = {}) {
      root.clearTimeout(timer);
      name = next;
      const walk = /^(walk|run)_(down|left|right|up)$/.exec(next);
      const row = walk ? `walk_${walk[2]}` : ACT_ROW[next] || 'idle';
      el.dataset.act = walk ? 'walk' : next;
      const ms = ONE_SHOT[next];
      if (ms === 0) sp.play(row, { onEnd: more.onEnd });
      else {
        sp.play(row);
        if (ms) timer = root.setTimeout(() => more.onEnd?.(), ms);
      }
      return api;
    }
    const api = {
      el,
      get animation() { return name; },
      get look() { return {}; },
      play,
      walk(dir = 'down', o = {}) { return play(`${o.run ? 'run' : 'walk'}_${['down', 'left', 'right', 'up'].includes(dir) ? dir : 'down'}`); },
      face(dir = 'down') {
        name = 'turn';
        el.dataset.act = 'idle';
        if (dir === 'down') sp.play('idle');
        else { sp.play(`walk_${dir}`); sp.stop(); }
        return api;
      },
      spin(then = 'idle', onEnd) {
        const dirs = ['right', 'up', 'left', 'down'];
        let i = 0;
        const step = () => {
          if (i < dirs.length) { api.face(dirs[i++]); timer = root.setTimeout(step, 140); }
          else { play(then); onEnd?.(); }
        };
        step();
        return api;
      },
      setLook() { return api; },
      stop() { sp.stop(); },
      destroy() { root.clearTimeout(timer); sp.destroy(); },
    };
    play(name);
    return api;
  }

  // ---------------------------------------------------------------- attach
  function attach(room, config = {}) {
    const frame = room.frame;
    const stage = room.stage;
    const art = frame.querySelector('.room-art');
    const media = root.matchMedia('(prefers-reduced-motion: reduce)');
    const reduced = () => media.matches;
    stage.classList.add('wl-stage');

    const sky = el('canvas', 'wl-sky', { 'aria-hidden': 'true' });
    const near = el('canvas', 'wl-near', { 'aria-hidden': 'true' });
    const actors = el('div', 'wl-actors', { 'aria-hidden': 'true' });
    const light = el('div', 'wl-light', { 'aria-hidden': 'true' });
    frame.insertBefore(sky, art);
    const crowd = frame.querySelector('.room-crowd');
    (crowd?.nextSibling ? frame.insertBefore(actors, crowd.nextSibling) : frame.append(actors));
    actors.after(light);
    light.after(near);

    let key = room.layout();
    const L = () => ({ floor: [0.62, 0.95], ...(config.layouts?.[key] || {}), rects: config.layouts?.[key]?.rects || {} });
    const hour = () => (config.hour ? config.hour() : new Date().getHours() + new Date().getMinutes() / 60);

    // ---- player (and an optional pet that follows) ----
    let player = null;
    let at = (L().start || [0.5, 0.86]).slice();
    const pNode = el('span', 'wl-player');
    actors.append(pNode);
    function buildPlayer() {
      player?.destroy?.();
      if (config.player === false) return;
      const roomScale = parseFloat(getComputedStyle(frame).getPropertyValue('--room-scale') || '1');
      if (config.player === 'layered' && root.NudgeAvatarLayers) {
        const scale = Math.max(config.playerScaleMin || 2, Math.round(roomScale * (config.playerScale || 2)));
        delete pNode.dataset.kind;
        player = root.NudgeAvatarLayers.create(pNode, { look: root.NudgeAvatarLayers.loadLook(), scale, animation: config.idle || 'idle' });
      } else {
        player = companionActor(pNode, { size: Math.round(112 * Math.max(0.7, roomScale)), animation: config.idle || 'idle' });
      }
    }
    function place(node, p) {
      node.style.left = p[0] * 100 + '%';
      node.style.top = p[1] * 100 + '%';
      node.style.zIndex = String(Math.round(p[1] * 100));
    }
    buildPlayer();
    place(pNode, at);
    const pet = config.pet && root.NudgePets ? root.NudgePets.follow(actors, () => at, { reduced }) : null;

    // ---- walking ----
    let walk = null;
    function walkTo(target, opts = {}) {
      return new Promise(resolve => {
        if (!target) { resolve(); return; }
        const aspect = frame.clientWidth / Math.max(1, frame.clientHeight);
        if (reduced() || !player) {
          at = target.slice();
          place(pNode, at);
          player?.face(opts.face || 'up');
          resolve();
          return;
        }
        const from = at.slice();
        const ms = Math.min(1600, core.walkTime(from, target, opts.run ? 0.5 : 0.32, aspect));
        if (ms < 60) { player.face(opts.face || 'up'); resolve(); return; }
        player.walk(core.direction(from, target, aspect), { run: opts.run || ms > 1100 });
        walk = { from, to: target.slice(), start: performance.now(), ms, resolve, face: opts.face || 'up' };
        kick();
      });
    }
    function stepWalk(now) {
      if (!walk) return;
      const t = Math.min(1, (now - walk.start) / walk.ms);
      at = [walk.from[0] + (walk.to[0] - walk.from[0]) * t, walk.from[1] + (walk.to[1] - walk.from[1]) * t];
      place(pNode, at);
      if (t >= 1) {
        const w = walk;
        walk = null;
        player?.face(w.face);
        w.resolve();
      }
    }

    // ---- object pieces: the object itself moves ----
    function piece(id, kind = 'pop') {
      const r = L().rects[id] || room.layout && config.layouts?.[key]?.rects?.[id];
      if (!r || reduced()) return null;
      const p = el('span', `wl-piece wl-piece--${kind}`, { 'aria-hidden': 'true' });
      p.style.left = r[0] * 100 + '%';
      p.style.top = r[1] * 100 + '%';
      p.style.width = r[2] * 100 + '%';
      p.style.height = r[3] * 100 + '%';
      p.style.backgroundImage = `url("${art.currentSrc || art.src}")`;
      p.style.backgroundSize = `${100 / r[2]}% ${100 / r[3]}%`;
      p.style.backgroundPosition = `${(r[0] / Math.max(0.0001, 1 - r[2])) * 100}% ${(r[1] / Math.max(0.0001, 1 - r[3])) * 100}%`;
      frame.append(p);
      p.addEventListener('animationend', () => p.remove(), { once: true });
      root.setTimeout(() => p.remove(), 1400);
      return p;
    }

    // ---- emotes above anything ----
    function emote(target, kind, ms = 1600) {
      const node = typeof target === 'string' ? (target === 'player' ? pNode : room.object(target)) : target;
      if (!node) return;
      const e = el('span', 'wl-emote', { 'aria-hidden': 'true' });
      e.style.backgroundImage = `url("${emoteUrl(kind)}")`;
      if (node === pNode || node.parentNode === actors) {
        node.append(e);
      } else {
        node.append(e);
      }
      root.setTimeout(() => e.remove(), ms);
    }

    // ---- npc acting ----
    const npcBody = room.npcButton?.querySelector('.room-npc-body');
    function npcAct(kind) {
      if (!room.npcButton) return;
      const b = room.npcButton;
      b.classList.remove('wl-hop', 'wl-sway', 'wl-wave');
      void b.offsetWidth;
      if (!reduced()) b.classList.add(kind === 'happy' ? 'wl-hop' : kind === 'think' ? 'wl-sway' : 'wl-wave');
      emote(b, kind === 'happy' ? 'heart' : kind === 'think' ? '?' : 'wave');
    }
    // The room object is frozen, so NPC acting hooks the tap instead of say().
    function npcSpeaks(lines) {
      const first = [].concat(lines || [])[0] || '';
      const mood = core.moodOf(first);
      emote(room.npcButton, mood);
      if (!reduced()) {
        room.npcButton.classList.remove('wl-hop', 'wl-sway');
        void room.npcButton.offsetWidth;
        room.npcButton.classList.add(mood === '?' ? 'wl-sway' : 'wl-hop');
      }
      player?.face?.(at[0] < (L().npcAt?.[0] ?? 0.2) ? 'left' : 'right');
    }
    function onNpc() { npcSpeaks([]); }
    room.npcButton?.addEventListener('click', onNpc, true);
    /** Say through the room with the NPC acting it out. */
    function say(lines, actions) {
      if (room.npcButton) npcSpeaks(lines);
      return room.say(lines, actions);
    }

    // ---- tap → walk → act → open ----
    const acts = config.acts || {};
    function onClick(event) {
      const b = event.target.closest?.('.room-object');
      if (!b || !frame.contains(b)) return;
      if (b.dataset.wlPass === '1') { delete b.dataset.wlPass; return; }
      const id = b.dataset.object;
      const a = acts[id] || {};
      if (a.skip) return;
      event.stopImmediatePropagation();
      event.preventDefault();
      if (b.dataset.wlBusy === '1') return;
      b.dataset.wlBusy = '1';
      const spot = core.spotFor(L(), id);
      walkTo(spot, { face: a.face || 'up' }).then(() => {
        if (a.anim && player) player.play(a.anim, {});
        piece(id, a.fx || 'pop');
        if (a.sfx) root.NudgeSfx?.play(a.sfx);
        if (a.emote) emote('player', a.emote);
        a.onArrive?.(api, b);
        const wait = reduced() ? 0 : a.wait ?? 420;
        root.setTimeout(() => {
          delete b.dataset.wlBusy;
          if (a.after) { a.after(api, b); return; }
          b.dataset.wlPass = '1';
          b.click();
          if (a.anim) root.setTimeout(() => player?.play(config.idle || 'idle'), 900);
        }, wait);
      });
    }
    frame.addEventListener('click', onClick, true);

    // Tap on open floor: just stroll there.
    function onFloor(event) {
      if (event.target !== frame && !event.target.classList?.contains('room-life') && event.target !== art) return;
      const r = frame.getBoundingClientRect();
      const x = (event.clientX - r.left) / r.width, y = (event.clientY - r.top) / r.height;
      const [f0, f1] = L().floor;
      if (y < f0 - 0.05) return;
      walkTo([core.clamp(x, 0.05, 0.95), core.clamp(y, f0, f1)], { face: 'down' }).then(() => player?.play(config.idle || 'idle'));
    }
    frame.addEventListener('click', onFloor);

    // ---- leaving: close like a door ----
    function onLeave(event) {
      const a = event.target.closest?.('a[data-town-return], a[data-wl-door]');
      if (!a || reduced() || event.defaultPrevented || event.metaKey || event.ctrlKey) return;
      const href = a.href;
      if (!href) return;
      event.preventDefault();
      stage.classList.add('wl-leaving');
      root.NudgeSfx?.play('open');
      root.setTimeout(() => { root.location.href = a.href || href; }, 380);
    }
    doc.addEventListener('click', onLeave);

    // ---- parallax ----
    let px = 0, py = 0, tx = 0, ty = 0;
    function onPointer(e) {
      const r = stage.getBoundingClientRect();
      tx = ((e.clientX - r.left) / Math.max(1, r.width) - 0.5) * 2;
      ty = ((e.clientY - r.top) / Math.max(1, r.height) - 0.5) * 2;
    }
    stage.addEventListener('pointermove', onPointer);

    // ---- loop ----
    let raf = null, frameNo = 0, last = 0;
    function size(c) {
      const w = Math.max(16, Math.ceil(frame.clientWidth / PX)), h = Math.max(16, Math.ceil(frame.clientHeight / PX));
      if (c.width !== w || c.height !== h) { c.width = w; c.height = h; }
      return [w, h];
    }
    function paint(f) {
      const lay = L();
      const gs = sky.getContext('2d'), gn = near.getContext('2d');
      if (gs) {
        const [w, h] = size(sky);
        gs.imageSmoothingEnabled = false;
        drawSky(gs, w, h, f, { hour: hour(), skyRect: lay.skyRect, hills: lay.hills });
      }
      if (gn) {
        const [w, h] = size(near);
        gn.imageSmoothingEnabled = false;
        gn.clearRect(0, 0, w, h);
        drawNear(gn, w, h, f, { ...(config.near || {}), ...(lay.near || {}) });
      }
      const dl = core.daylight(hour());
      light.style.setProperty('--wl-night', String((1 - dl) * (config.nightShade ?? 0.28)));
      stage.dataset.phase = core.phaseAt(hour());
      config.onPaint?.(api, f);
    }
    function loop(now) {
      raf = null;
      if (doc.hidden) return;
      stepWalk(now);
      pet?.update?.(at, now);
      px += (tx - px) * 0.08;
      py += (ty - py) * 0.08;
      sky.style.transform = `translate(${(-px * 6).toFixed(1)}px, ${(-py * 3).toFixed(1)}px) scale(1.03)`;
      near.style.transform = `translate(${(px * 10).toFixed(1)}px, ${(py * 4).toFixed(1)}px) scale(1.04)`;
      if (now - last >= 1000 / FPS) {
        last = now;
        frameNo++;
        paint(frameNo);
        if (room.layout() !== key) { key = room.layout(); at = (L().start || at).slice(); place(pNode, at); }
      }
      kick();
    }
    function kick() {
      if (raf == null && !reduced() && !doc.hidden) raf = root.requestAnimationFrame(loop);
    }
    function sync() {
      if (reduced()) {
        if (raf != null) root.cancelAnimationFrame(raf);
        raf = null;
        sky.style.transform = near.style.transform = '';
        paint(0);
      } else kick();
    }
    doc.addEventListener('visibilitychange', sync);
    media.addEventListener('change', sync);
    let resizeT = null;
    const onResize = () => {
      root.clearTimeout(resizeT);
      resizeT = root.setTimeout(() => { key = room.layout(); at = (L().start || at).slice(); place(pNode, at); buildPlayer(); paint(frameNo); }, 120);
    };
    root.addEventListener('resize', onResize);
    paint(0);
    if (!reduced()) stage.classList.add('wl-entering');
    sync();

    const api = {
      room, stage, frame, player: () => player, at: () => at.slice(), walkTo, emote, piece, npcAct, say,
      layout: L, hour, paint: () => paint(frameNo), actors, light,
      setLook(look, opts) { player?.setLook(look, opts); },
      destroy() {
        if (raf != null) root.cancelAnimationFrame(raf);
        player?.destroy?.();
        pet?.destroy?.();
        frame.removeEventListener('click', onClick, true);
        frame.removeEventListener('click', onFloor);
        room.npcButton?.removeEventListener('click', onNpc, true);
        doc.removeEventListener('click', onLeave);
        doc.removeEventListener('visibilitychange', sync);
        media.removeEventListener('change', sync);
        root.removeEventListener('resize', onResize);
        stage.removeEventListener('pointermove', onPointer);
        sky.remove(); near.remove(); actors.remove(); light.remove();
      },
    };
    return api;
  }

  root.NudgeWorldLife = Object.freeze({ attach, drawSky, drawNear, emoteUrl, companionActor });
})(typeof globalThis !== 'undefined' ? globalThis : this);
