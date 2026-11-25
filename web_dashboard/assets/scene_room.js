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
  };

  function mount(options) {
    const {
      host, art, title, aspect = '2 / 3', npc, npcAt = [0.12, 0.62], npcSize = 128,
      greeting = [], tips = [], objects = [], effects = [], panelVariant = 'parchment',
    } = options;
    const media = root.matchMedia('(prefers-reduced-motion: reduce)');
    const stage = el('section', { class: 'room-stage', 'aria-label': `${title}場景` });
    stage.style.setProperty('--room-art', `url("${new URL(art, doc.baseURI).href}")`);
    const frame = el('div', { class: 'room-frame' });
    frame.style.aspectRatio = aspect;
    const picture = el('img', { class: 'room-art', src: art, alt: '', 'aria-hidden': 'true', decoding: 'async' });
    const canvas = el('canvas', { class: 'room-life', 'aria-hidden': 'true' });
    const fx = el('div', { class: 'room-fx', 'aria-hidden': 'true' });
    const live = el('p', { class: 'room-live', role: 'status', 'aria-live': 'polite' });
    frame.append(picture, canvas);
    stage.append(frame, live);
    (host || doc.querySelector('main') || doc.body).prepend(stage);

    // ---- objects ----
    const buttons = new Map();
    for (const o of objects) {
      const b = el('button', {
        type: 'button', class: `room-object${o.className ? ' ' + o.className : ''}`,
        'aria-label': o.label + (o.hint ? `：${o.hint}` : ''), 'data-object': o.id,
      });
      b.style.left = o.x * 100 + '%';
      b.style.top = o.y * 100 + '%';
      b.style.width = (o.w || 0.16) * 100 + '%';
      b.style.height = (o.h || 0.12) * 100 + '%';
      const sign = el('span', { class: 'room-sign' });
      sign.append(el('span', { class: 'room-sign-text' }, o.label));
      const badge = el('span', { class: 'room-badge', hidden: true });
      b.append(el('span', { class: 'room-glow', 'aria-hidden': 'true' }), sign, badge);
      b.addEventListener('click', event => {
        poke(b);
        o.onSelect?.(event, api);
      });
      frame.append(b);
      buttons.set(o.id, b);
    }

    // ---- npc ----
    let player = null, npcButton = null, speech = null;
    if (npc) {
      npcButton = el('button', { type: 'button', class: 'room-npc', 'aria-label': `和${characterName(npc)}說話`, 'aria-haspopup': 'dialog' });
      npcButton.style.left = npcAt[0] * 100 + '%';
      npcButton.style.top = npcAt[1] * 100 + '%';
      npcButton.style.setProperty('--npc-size', npcSize + 'px');
      const body = el('span', { class: 'room-npc-body', 'aria-hidden': 'true' });
      const tag = el('span', { class: 'room-sign room-npc-name' });
      tag.append(el('span', { class: 'room-sign-text' }, characterName(npc)));
      const bubble = el('span', { class: 'room-npc-bubble', 'aria-hidden': 'true' }, '…');
      npcButton.append(bubble, body, tag);
      frame.append(npcButton);
      player = root.NudgeSpritePlayer.characterPlayer(body, npc, { animation: 'idle', size: npcSize });
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
        speech = root.NudgeNpcDialog.open({
          speaker: npc, lines, actions,
          onClose: () => { player?.play('idle'); speech = null; },
        });
      } catch { speech = null; }
      return speech;
    }

    // ---- panel ----
    const dialog = el('dialog', { class: `room-panel room-panel--${panelVariant}`, 'aria-label': title });
    const head = el('div', { class: 'room-panel-bar' });
    const heading = el('h2', { class: 'room-panel-title' }, title);
    const closeBtn = el('button', { type: 'button', class: 'w-btn room-panel-close' }, '放回去');
    const body = el('div', { class: 'room-panel-body' });
    head.append(heading, closeBtn);
    dialog.append(head, body);
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
    function closePanel() {
      if (!dialog.open) return;
      dialog.close();
    }
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
      const r = frame.getBoundingClientRect();
      const dpr = Math.min(root.devicePixelRatio || 1, 2);
      const w = Math.max(1, Math.round(r.width)), h = Math.max(1, Math.round(r.height));
      if (canvas.width !== w * dpr || canvas.height !== h * dpr) { canvas.width = w * dpr; canvas.height = h * dpr; }
      g.setTransform(dpr, 0, 0, dpr, 0, 0);
      g.clearRect(0, 0, w, h);
      for (const e of effects) {
        const fn = EFFECTS[e.type];
        if (fn) { g.save(); fn(g, w, h, f, e); g.restore(); }
      }
    }
    function tick(now) {
      raf = null;
      if (last != null) elapsed += Math.min(now - last, 100);
      last = now;
      const f = Math.floor(elapsed / 100); // 10 fps keeps the pixel feel
      if (f !== lastFrame) { paint(f); lastFrame = f; }
      if (running()) raf = root.requestAnimationFrame(tick);
    }
    function running() { return !media.matches && !doc.hidden && visible && !dialog.open; }
    function sync() {
      if (raf != null) root.cancelAnimationFrame(raf);
      raf = null; last = null;
      stage.classList.toggle('is-still', media.matches);
      if (running()) { player?.play('idle'); raf = root.requestAnimationFrame(tick); }
      else { paint(0); player?.stop?.(); }
    }
    const io = new IntersectionObserver(entries => { visible = entries[0].isIntersecting; sync(); });
    io.observe(stage);
    doc.addEventListener('visibilitychange', sync);
    media.addEventListener('change', sync);
    root.addEventListener('resize', () => { lastFrame = -1; if (!running()) paint(0); });
    if (!media.matches) stage.classList.add('is-arriving');
    picture.addEventListener('load', () => { lastFrame = -1; sync(); });
    sync();

    const api = Object.freeze({
      stage, frame, dialog, body, say, openPanel, closePanel, burst, poke, announce, setBadge,
      object: id => buttons.get(id), npcButton,
      destroy() {
        if (raf != null) root.cancelAnimationFrame(raf);
        io.disconnect();
        player?.destroy?.();
        media.removeEventListener('change', sync);
        doc.removeEventListener('visibilitychange', sync);
        dialog.remove(); stage.remove(); fx.remove();
      },
    });
    return api;
  }

  root.NudgeSceneRoom = Object.freeze({ mount, EFFECTS: Object.keys(EFFECTS) });
})(typeof globalThis !== 'undefined' ? globalThis : this);
