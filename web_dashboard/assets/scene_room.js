(function (root) {
  'use strict';
  // A facility room: generated art, glowing objects, a talking NPC, ambient
  // life on a canvas, reward bursts, and a themed panel for the real feature.
  // Positions are percentages of the art, so hotspots stay on their objects
  // at every width. Motion stops for prefers-reduced-motion and hidden tabs.
  const doc = root.document;

  function el(tag, attrs = {}, text) {
    const n = doc.createElement(tag);
    for (const [k, v] of Object.entries(attrs)) {
      if (v == null || v === false) continue;
      if (k === 'class') n.className = v;
      else n.setAttribute(k, v === true ? '' : v);
    }
    if (text != null) n.textContent = text;
    return n;
  }

  function characterName(id) {
    try { return root.NudgeSpritePlayer.character(id).name; } catch { return '店員'; }
  }

  const EFFECTS = {
    // Slow motes drifting up through light.
    dust(g, w, h, f, o) {
      g.fillStyle = o.color || '#ffe7a8';
      for (let i = 0; i < (o.count || 18); i++) {
        const x = ((i * 0.618 + f * 0.0007 * (1 + (i % 3))) % 1) * w;
        const y = (1 - ((i * 0.377 + f * 0.0011) % 1)) * h;
        g.globalAlpha = 0.25 + 0.25 * Math.sin(f / 9 + i);
        g.fillRect(x | 0, y | 0, 2, 2);
      }
    },
    // Blinking green-gold fireflies wandering in a band.
    fireflies(g, w, h, f, o) {
      const top = (o.top ?? 0.3) * h, band = (o.band ?? 0.5) * h;
      for (let i = 0; i < (o.count || 14); i++) {
        const x = (0.5 + 0.45 * Math.sin(f / 70 + i * 1.7)) * w;
        const y = top + (0.5 + 0.5 * Math.sin(f / 53 + i * 2.3)) * band;
        const on = Math.sin(f / 7 + i * 1.3);
        if (on < 0) continue;
        g.globalAlpha = on;
        g.fillStyle = '#d8ff8a';
        g.fillRect(x | 0, y | 0, 3, 3);
        g.globalAlpha = on * 0.25;
        g.fillRect((x - 3) | 0, (y - 3) | 0, 9, 9);
      }
    },
    // Warm flicker halos at fixed points (candles, lamps, torches).
    glow(g, w, h, f, o) {
      for (const [i, p] of (o.points || []).entries()) {
        const r = (o.radius || 0.06) * w * (1 + 0.08 * Math.sin(f / 3 + i * 2) + 0.05 * Math.sin(f / 1.7 + i));
        const grad = g.createRadialGradient(p[0] * w, p[1] * h, 0, p[0] * w, p[1] * h, r);
        grad.addColorStop(0, o.color || 'rgba(255,200,90,0.45)');
        grad.addColorStop(1, 'rgba(255,200,90,0)');
        g.globalAlpha = 1;
        g.fillStyle = grad;
        g.fillRect(p[0] * w - r, p[1] * h - r, r * 2, r * 2);
      }
    },
    // Twinkling sparkles at points (glass cabinet, stars, magic items).
    sparkle(g, w, h, f, o) {
      g.fillStyle = o.color || '#fff6c8';
      for (const [i, p] of (o.points || []).entries()) {
        const phase = (f + i * 7) % 24;
        if (phase > 8) continue;
        const s = phase < 4 ? phase : 8 - phase;
        const x = p[0] * w, y = p[1] * h;
        g.globalAlpha = 0.9;
        g.fillRect((x - s) | 0, y | 0, (s * 2 + 1) | 0, 1);
        g.fillRect(x | 0, (y - s) | 0, 1, (s * 2 + 1) | 0);
      }
    },
    // Paper slips or leaves fluttering down.
    flutter(g, w, h, f, o) {
      g.fillStyle = o.color || '#f6e7c8';
      for (let i = 0; i < (o.count || 6); i++) {
        const t = ((f * 0.004 + i / (o.count || 6)) % 1);
        const x = ((o.x ?? 0.5) + 0.35 * Math.sin(i * 2.1) + 0.05 * Math.sin(f / 8 + i)) * w;
        const y = ((o.top ?? 0.2) + t * (o.fall ?? 0.6)) * h;
        g.globalAlpha = 0.8 * (1 - t);
        const flip = Math.abs(Math.sin(f / 5 + i)) * 4 + 1;
        g.fillRect(x | 0, y | 0, 5, flip | 0);
      }
    },
    // Night stars twinkling in the upper sky.
    stars(g, w, h, f, o) {
      g.fillStyle = '#fff';
      for (let i = 0; i < (o.count || 26); i++) {
        const x = ((i * 0.733) % 1) * w, y = ((i * 0.419) % 1) * (o.height ?? 0.25) * h;
        g.globalAlpha = 0.3 + 0.7 * Math.max(0, Math.sin(f / 6 + i * 1.9));
        g.fillRect(x | 0, y | 0, 2, 2);
      }
    },
    // Balloons bobbing on their strings at points.
    balloons(g, w, h, f, o) {
      const colors = o.colors || ['#ff7a9c', '#ffc54d', '#8b6cf0', '#7fd3ff'];
      for (const [i, p] of (o.points || []).entries()) {
        const x = p[0] * w + Math.sin(f / 9 + i * 1.3) * 3;
        const y = p[1] * h + Math.sin(f / 7 + i) * 4;
        const r = (o.radius || 0.018) * w;
        g.globalAlpha = 1;
        g.fillStyle = '#3a2216';
        g.fillRect(x | 0, (y + r) | 0, 1, (r * 2.2) | 0);
        g.fillStyle = colors[i % colors.length];
        g.fillRect((x - r) | 0, (y - r) | 0, (r * 2) | 0, (r * 2) | 0);
        g.fillStyle = 'rgba(255,255,255,0.7)';
        g.fillRect((x - r * 0.5) | 0, (y - r * 0.6) | 0, 2, 2);
      }
    },
    // Rising wisps (chimney smoke, steam from tea).
    steam(g, w, h, f, o) {
      for (const [i, p] of (o.points || []).entries()) {
        for (let k = 0; k < 5; k++) {
          const t = ((f * 0.02 + k / 5 + i * 0.3) % 1);
          g.globalAlpha = 0.35 * (1 - t);
          g.fillStyle = o.color || '#f3eee8';
          const x = p[0] * w + Math.sin(t * 6 + i) * 6, y = p[1] * h - t * (o.rise ?? 0.08) * h;
          g.fillRect(x | 0, y | 0, 4, 4);
        }
      }
    },
    // A small flock crossing the sky every so often.
    birds(g, w, h, f, o) {
      const period = o.period || 160, t = (f % period) / period;
      if (t > 0.6) return;
      const k = t / 0.6, dir = Math.floor(f / period) % 2 ? -1 : 1;
      const baseX = dir > 0 ? -0.1 + k * 1.2 : 1.1 - k * 1.2;
      const baseY = (o.y ?? 0.12) + Math.sin(k * 6) * 0.01;
      g.globalAlpha = 0.85;
      g.fillStyle = o.color || '#2b1d3a';
      for (let i = 0; i < (o.count || 5); i++) {
        const x = (baseX - dir * i * 0.03) * w, y = (baseY + (i % 2) * 0.015 + i * 0.004) * h;
        const flap = (f + i * 2) % 4 < 2 ? 2 : 0;
        g.fillRect((x - 4) | 0, (y - flap) | 0, 4, 2);
        g.fillRect(x | 0, y | 0, 2, 2);
        g.fillRect((x + 2) | 0, (y - flap) | 0, 4, 2);
      }
    },
    // Soft pixel clouds drifting through a sky band.
    clouds(g, w, h, f, o) {
      const top = (o.top ?? 0.02) * h, band = (o.band ?? 0.15) * h;
      for (let i = 0; i < (o.count || 4); i++) {
        const span = w * 1.4;
        const x = ((i * 0.37 * span + f * (0.6 + (i % 3) * 0.25)) % span) - w * 0.2;
        const y = top + ((i * 0.53) % 1) * band;
        const cw = w * (0.08 + (i % 3) * 0.03), ch = cw * 0.32;
        g.globalAlpha = o.alpha ?? 0.35;
        g.fillStyle = o.color || '#f4e6ff';
        g.fillRect(x | 0, (y + ch * 0.4) | 0, cw | 0, (ch * 0.6) | 0);
        g.fillRect((x + cw * 0.2) | 0, y | 0, (cw * 0.45) | 0, ch | 0);
        g.fillRect((x + cw * 0.5) | 0, (y + ch * 0.15) | 0, (cw * 0.35) | 0, (ch * 0.85) | 0);
      }
    },
    // Fountain: droplets arcing out of each jet and ripple rings in the basin.
    fountain(g, w, h, f, o) {
      const k = o.scale || 1;
      for (const [j, p] of (o.points || []).entries()) {
        const x0 = p[0] * w, y0 = p[1] * h, unit = w * 0.01 * k;
        g.fillStyle = '#e6f6ff';
        for (let i = 0; i < 14; i++) {
          const t = ((f * 0.9 + i * 1.7 + j * 3) % 10) / 10;
          const side = i % 2 ? 1 : -1, spread = (1 + (i % 5)) * 0.6;
          g.globalAlpha = 0.9 - t * 0.4;
          g.fillRect((x0 + side * spread * t * unit * 3) | 0, (y0 - (5 * t - 7 * t * t) * unit * 2) | 0, 2, 3);
        }
        const ring = ((f + j * 4) % 12) / 12, rx = unit * (2 + ring * 7), ry = rx * 0.35;
        g.globalAlpha = 0.5 * (1 - ring);
        g.fillStyle = '#c9e9ff';
        const by = y0 + unit * (o.basin ?? 2.5);
        g.fillRect((x0 - rx) | 0, (by - ry) | 0, (rx * 2) | 0, 1);
        g.fillRect((x0 - rx) | 0, (by + ry) | 0, (rx * 2) | 0, 1);
      }
    },
    // Chimney smoke: grey puffs rising and widening.
    smoke(g, w, h, f, o) {
      for (const [i, p] of (o.points || []).entries()) {
        for (let k = 0; k < 4; k++) {
          const t = ((f * 0.08 + k / 4 + i * 0.29) % 1);
          g.globalAlpha = 0.32 * (1 - t);
          g.fillStyle = o.color || '#e9e3ee';
          const size = 4 + t * 10;
          g.fillRect((p[0] * w + Math.sin(t * 5 + i) * 6 - size / 2) | 0, (p[1] * h - t * (o.rise ?? 0.08) * h) | 0, size | 0, (size * 0.7) | 0);
        }
      }
    },
    // Lantern and window lights breathing at points.
    flicker(g, w, h, f, o) {
      for (const [i, p] of (o.points || []).entries()) {
        const a = 0.18 + 0.12 * Math.sin(f / 2.3 + i * 1.7) + 0.06 * Math.sin(f / 0.9 + i);
        g.globalAlpha = Math.max(0, a);
        g.fillStyle = o.color || '#ffcf6a';
        const r = (o.radius || 0.03) * w;
        g.fillRect((p[0] * w - r) | 0, (p[1] * h - r) | 0, (r * 2) | 0, (r * 2) | 0);
      }
    },
  };

  // Desktop (wide, landscape art) or phone (tall, portrait art).
  function layoutKey(layouts) {
    if (!layouts.wide) return 'tall';
    if (!layouts.tall) return 'wide';
    return root.innerWidth >= 860 && root.innerWidth / Math.max(1, root.innerHeight) >= 1.05 ? 'wide' : 'tall';
  }

  function mount(options) {
    const {
      host, title, npc, npcSize = 128, greeting = [], tips = [], objects = [], panelVariant = 'parchment',
    } = options;
    const toAspect = a => (typeof a === 'string' ? a.split('/').map(Number).reduce((x, y) => x / y) : a || 2 / 3);
    // Old single-art configs become the tall layout.
    const layouts = options.layouts || {
      tall: {
        art: options.art, aspect: options.aspect, npcAt: options.npcAt, effects: options.effects,
        walkers: options.walkers, rects: Object.fromEntries(objects.map(o => [o.id, [o.x, o.y, o.w, o.h]])),
      },
    };
    const media = root.matchMedia('(prefers-reduced-motion: reduce)');
    const stage = el('section', { class: 'room-stage', 'aria-label': `${title}場景` });
    const frame = el('div', { class: 'room-frame' });
    const picture = el('img', { class: 'room-art', alt: '', 'aria-hidden': 'true', decoding: 'async' });
    const canvas = el('canvas', { class: 'room-life', 'aria-hidden': 'true' });
    const crowd = el('div', { class: 'room-crowd', 'aria-hidden': 'true' });
    const fx = el('div', { class: 'room-fx', 'aria-hidden': 'true' });
    const live = el('p', { class: 'room-live', role: 'status', 'aria-live': 'polite' });
    frame.append(picture, canvas, crowd);
    stage.append(frame, live);
    (host || doc.querySelector('main') || doc.body).prepend(stage);

    // ---- objects ----
    const buttons = new Map();
    for (const o of objects) {
      const b = el('button', {
        type: 'button', class: `room-object${o.className ? ' ' + o.className : ''}`,
        'aria-label': o.label + (o.hint ? `：${o.hint}` : ''), 'data-object': o.id,
      });
      const sign = el('span', { class: 'room-sign' });
      sign.append(el('span', { class: 'room-sign-text' }, o.label));
      const badge = el('span', { class: 'room-badge', hidden: true });
      b.append(el('span', { class: 'room-glow', 'aria-hidden': 'true' }), sign, badge);
      b.addEventListener('click', event => { poke(b); o.onSelect?.(event, api); });
      frame.append(b);
      buttons.set(o.id, b);
    }

    // ---- npc ----
    let player = null, npcButton = null, speech = null;
    if (npc) {
      npcButton = el('button', { type: 'button', class: 'room-npc', 'aria-label': `和${characterName(npc)}說話`, 'aria-haspopup': 'dialog' });
      const body = el('span', { class: 'room-npc-body', 'aria-hidden': 'true' });
      const tag = el('span', { class: 'room-sign room-npc-name' });
      tag.append(el('span', { class: 'room-sign-text' }, characterName(npc)));
      const bubble = el('span', { class: 'room-npc-bubble', 'aria-hidden': 'true' }, '…');
      npcButton.append(bubble, body, tag);
      frame.append(npcButton);
      let tipIndex = 0;
      npcButton.addEventListener('click', () => {
        const lines = [...(typeof greeting === 'function' ? greeting() : greeting)];
        const pool = typeof tips === 'function' ? tips() : tips;
        if (pool.length) lines.push(pool[tipIndex++ % pool.length]);
        say(lines.length ? lines : ['你好！']);
      });
    }
    function say(lines, actions) {
      if (!npc) return null;
      speech?.close?.();
      player?.play('talk');
      try {
        speech = root.NudgeNpcDialog.open({ speaker: npc, lines, actions, onClose: () => { player?.play('idle'); speech = null; } });
      } catch { speech = null; }
      return speech;
    }

    // ---- walkers: townsfolk strolling along paths ----
    let walkers = [];
    function buildWalkers(list) {
      for (const w of walkers) w.player?.destroy?.();
      crowd.textContent = '';
      walkers = (list || []).map((w, i) => {
        const node = el('span', { class: 'room-walker' });
        crowd.append(node);
        let wp = null;
        try { wp = root.NudgeSpritePlayer.characterPlayer(node, w.id, { animation: 'idle', size: Math.round(64 * scale) }); } catch { wp = null; }
        return { ...w, node, player: wp, seg: 0, t: (i * 0.37) % 1, rest: 0, anim: '' };
      });
    }
    function placeWalker(w, dtMs) {
      const path = w.path;
      if (!path || path.length < 2) return;
      if (dtMs && !media.matches) {
        if (w.rest > 0) w.rest -= dtMs;
        else {
          const a = path[w.seg], b = path[(w.seg + 1) % path.length];
          const len = Math.hypot(b[0] - a[0], b[1] - a[1]) || 0.01;
          w.t += (dtMs / 1000) * (w.speed || 0.035) / len;
          if (w.t >= 1) {
            w.t = 0;
            w.seg = (w.seg + 1) % path.length;
            if (w.pause && Math.random() < 0.5) w.rest = w.pause;
          }
        }
      }
      const a = path[w.seg], b = path[(w.seg + 1) % path.length];
      const x = a[0] + (b[0] - a[0]) * w.t, y = a[1] + (b[1] - a[1]) * w.t;
      const dx = b[0] - a[0], dy = b[1] - a[1];
      const anim = media.matches || w.rest > 0 ? 'idle'
        : Math.abs(dx) > Math.abs(dy) ? (dx > 0 ? 'walk_right' : 'walk_left') : (dy > 0 ? 'walk_down' : 'walk_up');
      if (anim !== w.anim && w.player) { w.player.play(anim); w.anim = anim; }
      w.node.style.left = x * 100 + '%';
      w.node.style.top = y * 100 + '%';
      w.node.style.zIndex = String(Math.round(y * 100));
    }

    // ---- layout: art, object spots and life for wide or tall screens ----
    let current = null, layout = null, scale = 1;
    function buildNpc() {
      if (!npcButton) return;
      player?.destroy?.();
      const size = Math.round(npcSize * scale);
      npcButton.style.setProperty('--npc-size', size + 'px');
      player = root.NudgeSpritePlayer.characterPlayer(npcButton.querySelector('.room-npc-body'), npc, { animation: 'idle', size });
    }
    function applyLayout(force) {
      const key = layoutKey(layouts);
      if (key === current && !force) return;
      current = key;
      layout = { ...layouts[key], aspect: toAspect(layouts[key].aspect) };
      stage.dataset.layout = key;
      picture.src = layout.art;
      stage.style.setProperty('--room-art', `url("${new URL(layout.art, doc.baseURI).href}")`);
      for (const [id, b] of buttons) {
        const r = layout.rects?.[id];
        b.hidden = !r;
        if (!r) continue;
        b.style.left = r[0] * 100 + '%';
        b.style.top = r[1] * 100 + '%';
        b.style.width = r[2] * 100 + '%';
        b.style.height = r[3] * 100 + '%';
      }
      if (npcButton) {
        const at = layout.npcAt || [0.12, 0.9];
        npcButton.style.left = at[0] * 100 + '%';
        npcButton.style.top = at[1] * 100 + '%';
      }
      buildWalkers(layout.walkers);
      for (const w of walkers) placeWalker(w, 0);
      options.onLayout?.(key, api);
    }
    // Fill the screen below the HUD: cover it, cropping at most ~8% per side
    // so objects near the edges stay reachable.
    function fit() {
      const top = Math.max(0, stage.getBoundingClientRect().top + root.scrollY);
      const sw = stage.clientWidth || root.innerWidth;
      const sh = Math.max(360, root.innerHeight - top);
      stage.style.height = sh + 'px';
      const a = layout.aspect;
      let w = Math.max(sw, sh * a), h = w / a;
      if (w > sw * 1.16) { w = sw * 1.16; h = w / a; }
      if (h > sh * 1.22) { h = sh * 1.22; w = h * a; }
      frame.style.width = Math.round(w) + 'px';
      frame.style.height = Math.round(h) + 'px';
      frame.style.left = Math.round((sw - w) / 2) + 'px';
      frame.style.top = Math.round((sh - h) / 2) + 'px';
      const next = Math.max(0.6, Math.min(1.4, Math.min(w, h * 1.5) / 1100));
      frame.style.setProperty('--room-scale', String(next));
      if (!player || Math.abs(next - scale) > 0.04) {
        scale = next;
        buildNpc();
        buildWalkers(layout.walkers);
        for (const wk of walkers) placeWalker(wk, 0);
        sync();
      }
      lastFrame = -1;
      if (!running()) paint(0);
    }

    // ---- panel ----
    const dialog = el('dialog', { class: `room-panel room-panel--${panelVariant}`, 'aria-label': title });
    const bar = el('div', { class: 'room-panel-bar' });
    const heading = el('h2', { class: 'room-panel-title' }, title);
    const closeBtn = el('button', { type: 'button', class: 'w-btn room-panel-close' }, '放回去');
    const body = el('div', { class: 'room-panel-body' });
    bar.append(heading, closeBtn);
    dialog.append(bar, body);
    doc.body.append(dialog);
    let returnFocus = null, panelHome = null, onPanelClose = null;
    function openPanel({ title: label = title, content, variant, from, onClose } = {}) {
      returnFocus = from || doc.activeElement;
      heading.textContent = label;
      dialog.className = `room-panel room-panel--${variant || panelVariant}`;
      if (panelHome) panelHome.parent.insertBefore(panelHome.node, panelHome.next);
      panelHome = null;
      body.replaceChildren();
      if (content) {
        if (content.parentNode) panelHome = { node: content, parent: content.parentNode, next: content.nextSibling };
        body.append(content);
        content.hidden = false;
      }
      onPanelClose = onClose || null;
      if (!dialog.open) dialog.showModal();
      dialog.classList.remove('is-entering');
      void dialog.offsetWidth;
      if (!media.matches) dialog.classList.add('is-entering');
      closeBtn.focus({ preventScroll: true });
      sync();
    }
    function closePanel() { if (dialog.open) dialog.close(); }
    dialog.addEventListener('close', () => {
      if (panelHome) {
        panelHome.parent.insertBefore(panelHome.node, panelHome.next);
        if (panelHome.node.dataset.roomHidden === '1') panelHome.node.hidden = true;
        panelHome = null;
      }
      const done = onPanelClose; onPanelClose = null;
      done?.();
      returnFocus?.focus?.({ preventScroll: true });
      sync();
    });
    closeBtn.addEventListener('click', closePanel);
    dialog.addEventListener('click', e => { if (e.target === dialog) closePanel(); });

    // ---- reward bursts ----
    function centerOf(target) {
      const node = typeof target === 'string' ? buttons.get(target) : target;
      const fr = frame.getBoundingClientRect();
      if (!node) return [fr.left + fr.width / 2, fr.top + fr.height / 2];
      const r = node.getBoundingClientRect();
      return [r.left + r.width / 2, r.top + r.height / 2];
    }
    const GLYPH = { coin: '●', star: '★', heart: '♥', seal: '✦', note: '♪', leaf: '✿' };
    function burst({ kind = 'star', count = 8, from, to, text } = {}) {
      if (text) announce(text);
      if (media.matches) return;
      if (!fx.isConnected) doc.body.append(fx);
      const [sx, sy] = centerOf(from);
      const [tx, ty] = to ? centerOf(to) : [sx, sy - 120];
      for (let i = 0; i < count; i++) {
        const p = el('span', { class: `room-particle room-particle--${kind}` }, GLYPH[kind] || '★');
        const spread = (i - (count - 1) / 2) * 14;
        p.style.left = sx + 'px';
        p.style.top = sy + 'px';
        p.style.setProperty('--dx', (tx - sx + (to ? 0 : spread)) + 'px');
        p.style.setProperty('--dy', (ty - sy) + 'px');
        p.style.setProperty('--arc', (-40 - (i % 3) * 22) + 'px');
        p.style.setProperty('--spread', spread + 'px');
        p.style.animationDelay = i * 45 + 'ms';
        fx.append(p);
        p.addEventListener('animationend', () => p.remove(), { once: true });
      }
    }
    function poke(node) {
      if (media.matches || !node) return;
      node.classList.remove('is-poked');
      void node.offsetWidth;
      node.classList.add('is-poked');
    }
    function announce(text) { live.textContent = ''; root.setTimeout(() => { live.textContent = text; }, 30); }
    function setBadge(id, value) {
      const b = buttons.get(id)?.querySelector('.room-badge');
      if (!b) return;
      b.hidden = !value;
      b.textContent = value ? String(value) : '';
    }

    // ---- ambient loop ----
    const g = canvas.getContext('2d');
    let raf = null, last = null, elapsed = 0, lastFrame = -1, visible = true;
    function paint(f) {
      const w = Math.max(1, Math.round(frame.clientWidth)), h = Math.max(1, Math.round(frame.clientHeight));
      const dpr = Math.min(root.devicePixelRatio || 1, 2);
      if (canvas.width !== w * dpr || canvas.height !== h * dpr) { canvas.width = w * dpr; canvas.height = h * dpr; }
      g.setTransform(dpr, 0, 0, dpr, 0, 0);
      g.clearRect(0, 0, w, h);
      for (const e of layout?.effects || []) {
        const fn = EFFECTS[e.type];
        if (fn) { g.save(); fn(g, w, h, f, e); g.restore(); }
      }
    }
    function tick(now) {
      raf = null;
      const dt = last != null ? Math.min(now - last, 100) : 0;
      elapsed += dt;
      last = now;
      for (const w of walkers) placeWalker(w, dt);
      const f = Math.floor(elapsed / 100); // 10 fps keeps the pixel feel
      if (f !== lastFrame) { paint(f); lastFrame = f; }
      if (running()) raf = root.requestAnimationFrame(tick);
    }
    function running() { return !media.matches && !doc.hidden && visible && !dialog.open; }
    function sync() {
      if (raf != null) root.cancelAnimationFrame(raf);
      raf = null; last = null;
      stage.classList.toggle('is-still', media.matches);
      if (running()) {
        player?.play('idle');
        for (const w of walkers) w.anim = '';
        raf = root.requestAnimationFrame(tick);
      } else {
        paint(0);
        player?.stop?.();
        for (const w of walkers) { w.player?.stop?.(); w.anim = 'stopped'; }
      }
    }
    const io = new IntersectionObserver(entries => { visible = entries[0].isIntersecting; sync(); });
    io.observe(stage);
    doc.addEventListener('visibilitychange', sync);
    media.addEventListener('change', sync);
    let resizeTimer = null;
    const onResize = () => {
      root.clearTimeout(resizeTimer);
      resizeTimer = root.setTimeout(() => { applyLayout(false); fit(); }, 80);
    };
    root.addEventListener('resize', onResize);
    if (!media.matches) stage.classList.add('is-arriving');

    const api = {
      stage, frame, dialog, body, say, openPanel, closePanel, burst, poke, announce, setBadge,
      object: id => buttons.get(id), npcButton, layout: () => current,
      destroy() {
        if (raf != null) root.cancelAnimationFrame(raf);
        io.disconnect();
        player?.destroy?.();
        for (const w of walkers) w.player?.destroy?.();
        media.removeEventListener('change', sync);
        doc.removeEventListener('visibilitychange', sync);
        root.removeEventListener('resize', onResize);
        dialog.remove(); stage.remove(); fx.remove();
      },
    };
    applyLayout(true);
    fit();
    picture.addEventListener('load', fit);
    sync();
    return Object.freeze(api);
  }

  root.NudgeSceneRoom = Object.freeze({ mount, layoutKey, EFFECTS: Object.keys(EFFECTS) });
})(typeof globalThis !== 'undefined' ? globalThis : this);
