(function (root, factory) {
  const api = factory(root);
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.NudgeLivingRoom = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function (root) {
  'use strict';
  // Living social scenes (#200 H2-H8). Wraps the shared NudgeSceneRoom (not
  // modified) and adds what the living-town brief asks for:
  //  - the player's companion walks to an object first, acts, and the object
  //    itself changes (door opens, lamp lights, poster flutters) before the
  //    real feature opens in the scene panel;
  //  - three moving layers: far (drifting clouds / stars over a sky band),
  //    the room art with its life (effects, walkers), near (swaying
  //    foreground plants and falling petals, light parallax);
  //  - reduced motion: the companion jumps, nothing moves, first frame stays.
  // Feature logic is untouched: object content is the page's existing DOM.

  // ---------- pure helpers (tested) ----------
  const ACTIONS = Object.freeze({ open: 'happy', read: 'think', write: 'think', greet: 'wave', rest: 'sleep', cheer: 'happy' });
  const CHANGES = Object.freeze(['open', 'lit', 'flutter', 'shake', 'pulse', 'rise']);

  /** Where the companion stands to use an object: just below its centre. */
  function standPoint(rect) {
    const [x, y, w, h] = rect;
    return { x: Math.min(0.96, Math.max(0.04, x + w / 2)), y: Math.min(0.97, Math.max(0.08, y + h + 0.03)) };
  }

  /** Walk animation for a step, matching the sprite sheet rows. */
  function walkAnimation(dx, dy) {
    if (Math.abs(dx) < 1e-6 && Math.abs(dy) < 1e-6) return 'idle';
    return Math.abs(dx) > Math.abs(dy) ? (dx > 0 ? 'walk_right' : 'walk_left') : (dy > 0 ? 'walk_down' : 'walk_up');
  }

  /** Milliseconds to cross between two art-fraction points (min 250ms). */
  function walkDuration(from, to, speed = 0.45) {
    const d = Math.hypot(to.x - from.x, to.y - from.y);
    return Math.max(250, Math.round((d / speed) * 1000));
  }

  /** Position along a walk, eased in and out, for progress 0..1. */
  function along(from, to, t) {
    const p = Math.min(1, Math.max(0, t));
    const e = p < 0.5 ? 2 * p * p : 1 - Math.pow(-2 * p + 2, 2) / 2;
    return { x: from.x + (to.x - from.x) * e, y: from.y + (to.y - from.y) * e };
  }

  function actionFor(object) { return ACTIONS[object.action] || 'happy'; }
  function changeFor(object) { return CHANGES.includes(object.change) ? object.change : 'pulse'; }

  /** Drifting far-layer item x position (0..1) for item i at frame f. */
  function driftX(i, f, speed) { return ((i * 0.37 + f * speed * (1 + (i % 3) * 0.3)) % 1.2) - 0.1; }

  const pure = { ACTIONS, CHANGES, standPoint, walkAnimation, walkDuration, along, actionFor, changeFor, driftX };
  const doc = root.document;
  if (!doc) return Object.freeze({ ...pure, mount: null });

  const media = root.matchMedia ? root.matchMedia('(prefers-reduced-motion: reduce)') : { matches: false, addEventListener() {} };
  const still = () => media.matches;

  function el(tag, cls) { const n = doc.createElement(tag); if (cls) n.className = cls; return n; }

  function resolveContent(content) {
    if (!content) return null;
    if (typeof content === 'function') return content();
    return typeof content === 'string' ? doc.querySelector(content) : content;
  }

  /**
   * options: everything NudgeSceneRoom.mount accepts, plus
   *   objects[].content  selector / node / () => node opened in the panel
   *   objects[].action   open | read | write | greet | rest | cheer
   *   objects[].change   open | lit | flutter | shake | pulse | rise
   *   objects[].panelTitle, objects[].variant
   *   companion          character id for the player (default 'companion')
   *   playerAt           start point [x, y] in art fractions (per layout too)
   *   far                { band: [top, bottom], kind: 'clouds' | 'stars' | 'lanterns' | 'snow' | 'petals' }
   *   near               { plants: true, petals: 'petal' | 'leaf' | 'snow' | false }
   */
  function mount(options) {
    if (!root.NudgeSceneRoom) return null;
    const companionId = options.companion || 'companion';
    let room = null, companion = null, sprite = null, position = null, walking = null;

    const objects = (options.objects || []).map(object => ({
      ...object,
      onSelect: (event, api) => use(object, event?.currentTarget || api.object(object.id)),
    }));
    room = root.NudgeSceneRoom.mount({ ...options, objects, onLayout: (key, api) => { placeCompanion(key); options.onLayout?.(key, api); } });

    // ---------- companion ----------
    function layoutPoint(key) {
      const layout = options.layouts?.[key] || {};
      const p = layout.playerAt || options.playerAt || [0.5, 0.9];
      return { x: p[0], y: p[1] };
    }
    function placeCompanion(key) {
      if (!room) return;
      if (!companion) {
        companion = el('span', 'living-companion');
        companion.setAttribute('aria-hidden', 'true');
        room.frame.append(companion);
      }
      sprite?.destroy?.();
      try {
        sprite = root.NudgeSpritePlayer.characterPlayer(companion, companionId, { animation: 'idle', size: 88 });
      } catch { sprite = null; }
      position = layoutPoint(key || room.layout());
      draw();
    }
    function draw() {
      if (!companion || !position) return;
      companion.style.left = `${position.x * 100}%`;
      companion.style.top = `${position.y * 100}%`;
      companion.style.zIndex = String(Math.round(position.y * 100) + 1);
    }
    function rectOf(object) {
      const layout = options.layouts?.[room.layout()] || {};
      return layout.rects?.[object.id] || [object.x ?? 0.4, object.y ?? 0.4, object.w ?? 0.2, object.h ?? 0.2];
    }
    function walkTo(target) {
      return new Promise(resolve => {
        if (walking) root.cancelAnimationFrame(walking.raf);
        const from = { ...position };
        if (still() || doc.hidden) { position = target; draw(); resolve(); return; }
        const duration = walkDuration(from, target);
        const anim = walkAnimation(target.x - from.x, target.y - from.y);
        sprite?.play(anim);
        const start = root.performance.now();
        const step = now => {
          position = along(from, target, (now - start) / duration);
          draw();
          if (now - start < duration) walking = { raf: root.requestAnimationFrame(step) };
          else { walking = null; sprite?.play('idle'); resolve(); }
        };
        walking = { raf: root.requestAnimationFrame(step) };
      });
    }
    function act(object) {
      return new Promise(resolve => {
        const anim = actionFor(object);
        if (still() || !sprite) { resolve(); return; }
        let done = false;
        const finish = () => { if (!done) { done = true; sprite?.play('idle'); resolve(); } };
        try { sprite.play(anim, { onEnd: finish }); } catch { finish(); }
        root.setTimeout(finish, 700);
      });
    }
    async function use(object, button) {
      if (object.busy) return;
      object.busy = true;
      try {
        await walkTo(standPoint(rectOf(object)));
        await act(object);
        const change = changeFor(object);
        button?.classList.add('living-changed', `living-change--${change}`);
        room.announce(`${object.label}${object.hint ? '：' + object.hint : ''}`);
        const content = resolveContent(object.content);
        if (object.onUse) object.onUse(room, button);
        if (content || !object.onUse) {
          room.openPanel({ title: object.panelTitle || object.label, content, variant: object.variant, from: button,
            onClose: () => button?.classList.remove('living-changed', `living-change--${change}`) });
        }
      } finally {
        object.busy = false;
      }
    }

    // ---------- far and near layers ----------
    const far = el('canvas', 'living-far');
    far.setAttribute('aria-hidden', 'true');
    const near = el('div', 'living-near');
    near.setAttribute('aria-hidden', 'true');
    room.frame.append(far, near);
    const farOptions = options.far || { band: [0, 0.18], kind: 'clouds' };
    const nearOptions = options.near || { plants: true, petals: 'petal' };
    if (nearOptions.plants !== false) {
      for (let i = 0; i < 5; i++) {
        const plant = el('span', `living-plant living-plant--${i % 3}`);
        plant.style.left = `${[2, 22, 48, 71, 90][i]}%`;
        plant.style.animationDelay = `${-i * 0.7}s`;
        near.append(plant);
      }
    }
    if (nearOptions.petals) {
      for (let i = 0; i < 9; i++) {
        const petal = el('span', `living-petal living-petal--${nearOptions.petals}`);
        petal.style.left = `${(i * 11 + 4) % 100}%`;
        petal.style.animationDelay = `${-i * 1.3}s`;
        petal.style.animationDuration = `${7 + (i % 4)}s`;
        near.append(petal);
      }
    }
    const g = far.getContext ? far.getContext('2d') : null;
    let raf = null, frameNo = 0, lastTick = 0;
    function paintFar() {
      if (!g) return;
      const w = Math.max(1, room.frame.clientWidth), h = Math.max(1, room.frame.clientHeight);
      if (far.width !== w || far.height !== h) { far.width = w; far.height = h; }
      g.clearRect(0, 0, w, h);
      const [top, bottom] = farOptions.band || [0, 0.18];
      const unit = Math.max(2, Math.round(w / 420));
      const kind = farOptions.kind || 'clouds';
      for (let i = 0; i < 7; i++) {
        const x = driftX(i, frameNo, kind === 'clouds' ? 0.0008 : 0.0003) * w;
        const y = (top + (bottom - top) * ((i * 0.43) % 1)) * h;
        if (kind === 'stars') {
          g.globalAlpha = 0.4 + 0.5 * Math.abs(Math.sin(frameNo / 12 + i));
          g.fillStyle = '#fff2c4';
          g.fillRect(x | 0, y | 0, unit, unit);
        } else if (kind === 'lanterns') {
          g.globalAlpha = 0.85;
          g.fillStyle = '#e8613a';
          g.fillRect(x | 0, (y + Math.sin(frameNo / 10 + i) * unit * 2) | 0, unit * 4, unit * 5);
          g.fillStyle = '#ffd77a';
          g.fillRect((x + unit) | 0, (y + unit + Math.sin(frameNo / 10 + i) * unit * 2) | 0, unit * 2, unit * 3);
        } else {
          g.globalAlpha = 0.55;
          g.fillStyle = '#fff3e6';
          g.fillRect(x | 0, y | 0, unit * 16, unit * 3);
          g.fillRect((x + unit * 4) | 0, (y - unit * 2) | 0, unit * 8, unit * 2);
        }
      }
      g.globalAlpha = 1;
    }
    function loop(now) {
      raf = null;
      if (now - lastTick >= 100) { frameNo++; lastTick = now; paintFar(); }
      if (!still() && !doc.hidden) raf = root.requestAnimationFrame(loop);
    }
    function sync() {
      room.stage.classList.toggle('living-still', still());
      if (raf != null) root.cancelAnimationFrame(raf);
      raf = null;
      paintFar();
      if (!still() && !doc.hidden) raf = root.requestAnimationFrame(loop);
    }
    // Light parallax: near moves more than far as the pointer moves.
    room.stage.addEventListener('pointermove', event => {
      if (still()) return;
      const r = room.stage.getBoundingClientRect();
      const dx = (event.clientX - r.left) / Math.max(1, r.width) - 0.5;
      near.style.transform = `translateX(${Math.round(-dx * 14)}px)`;
      far.style.transform = `translateX(${Math.round(dx * 6)}px)`;
    });
    doc.addEventListener('visibilitychange', sync);
    media.addEventListener?.('change', sync);
    room.stage.classList.add('living-room');
    placeCompanion(room.layout());
    sync();

    return Object.freeze({ ...room, use: id => { const o = objects.find(x => x.id === id); return o ? use(o, room.object(id)) : null; },
      walkTo, companion: () => sprite });
  }

  return Object.freeze({ ...pure, mount });
});
