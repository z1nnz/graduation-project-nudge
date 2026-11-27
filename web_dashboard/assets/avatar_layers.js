(function (root, factory) {
  const api = factory(root);
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.NudgeAvatarLayers = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function (root) {
  'use strict';
  // The layered player character, built from the earlier companion art
  // (tool/character_art/recolor_player.py): body, outfit, headwear and
  // accessory sheets stacked in that order and stepped by one requestAnimationFrame
  // clock, so every layer shows the same frame.
  //
  //   const p = NudgeAvatarLayers.create(el, { look, animation: 'idle', scale: 2 });
  //   p.play('wave', { onEnd: () => p.play('idle') });
  //   p.setLook({ outfit: 'stargown' }, { spin: true });   // turns once on change
  //   p.destroy();
  //
  // Reduced motion shows frame 0 and never advances; a hidden tab pauses.

  const BASE = 'assets/characters/player/';
  const STORAGE_KEY = 'nudge.player.look.v1';

  // Mirrors assets/characters/player/player.json (test/avatar_layers_test.js
  // keeps them equal). Cells are frameWidth x frameHeight, feet on pivot.
  const MANIFEST = Object.freeze({
    frameWidth: 128, frameHeight: 128, columns: 6, pivot: [64, 123],
    order: ['body', 'outfit', 'headwear', 'accessory'],
    animations: [
      { name: 'idle', frames: 4, fps: 8, loop: true },
      { name: 'turn', frames: 4, fps: 8, loop: true },
      { name: 'walk_down', frames: 4, fps: 8, loop: true },
      { name: 'walk_left', frames: 4, fps: 8, loop: true },
      { name: 'walk_right', frames: 4, fps: 8, loop: true },
      { name: 'walk_up', frames: 4, fps: 8, loop: true },
      { name: 'happy', frames: 6, fps: 10, loop: false },
      { name: 'wave', frames: 4, fps: 8, loop: false },
      { name: 'think', frames: 4, fps: 8, loop: true },
      { name: 'sleep', frames: 4, fps: 8, loop: true },
    ],
    aliases: { look: 'idle', sit: 'idle', read: 'think', stretch: 'happy', snack: 'idle', talk: 'idle', run_down: 'walk_down', run_left: 'walk_left', run_right: 'walk_right', run_up: 'walk_up' },
    layers: {
      body: [{ id: 'navy', name: '夜空藍髮' }, { id: 'chestnut', name: '栗子棕髮' }, { id: 'rose', name: '莓果粉髮' }],
      outfit: [{ id: 'adventurer', name: '冒險藍外套' }, { id: 'forest', name: '森林綠外套' }, { id: 'sunset', name: '晚霞紅外套' }, { id: 'starnight', name: '星夜紫外套' }, { id: 'sunny', name: '晨光黃外套' }, { id: 'snow', name: '雪原白外套' }],
      headwear: [{ id: 'starclip', name: '星星髮夾' }, { id: 'strawhat', name: '向陽草帽' }, { id: 'wizard', name: '星光巫師帽' }, { id: 'catears', name: '貓耳髮箍' }, { id: 'beanie', name: '暖暖毛線帽' }, { id: 'flowers', name: '春日花冠' }],
      accessory: [{ id: 'scarf', name: '白色長圍巾' }, { id: 'glasses', name: '圓框眼鏡' }],
    },
    default: { body: 'navy', outfit: 'adventurer', headwear: 'starclip', accessory: 'scarf' },
  });

  const ROWS = Object.fromEntries(MANIFEST.animations.map((a, row) => [a.name, { ...a, row }]));
  const FACING = { down: 0, right: 1, up: 2, left: 3 };

  /** Frame index after [elapsedMs]; a one-shot clip holds its last frame. */
  function frameAt(elapsedMs, frames, fps, loop = true) {
    if (!(frames > 1) || !(fps > 0) || !(elapsedMs > 0)) return 0;
    const step = Math.floor((elapsedMs * fps) / 1000);
    return loop ? step % frames : Math.min(step, frames - 1);
  }

  /**
   * A complete look with known ids. body and outfit always have a value;
   * headwear and accessory may be null (none).
   */
  function normalizeLook(look = {}) {
    const out = {};
    for (const k of MANIFEST.order) {
      const ids = MANIFEST.layers[k].map(x => x.id);
      const v = look?.[k];
      if (v === null && (k === 'headwear' || k === 'accessory')) out[k] = null;
      else out[k] = ids.includes(v) ? v : MANIFEST.default[k];
    }
    return out;
  }

  /** Sheet urls bottom to top; empty slots are skipped. */
  function layerFiles(look, basePath = '') {
    const l = normalizeLook(look);
    return MANIFEST.order.filter(k => l[k]).map(k => `${basePath}${BASE}${k}_${l[k]}.webp`);
  }

  function loadLook(storage = root.localStorage) {
    try {
      const raw = storage?.getItem(STORAGE_KEY);
      return normalizeLook(raw ? JSON.parse(raw) : {});
    } catch {
      return normalizeLook({});
    }
  }

  function saveLook(look, storage = root.localStorage) {
    const l = normalizeLook(look);
    try { storage?.setItem(STORAGE_KEY, JSON.stringify(l)); } catch { /* private mode */ }
    return l;
  }

  /** A clip by name; actions the art has no row for play their alias. */
  function animation(name) {
    return ROWS[name] || ROWS[MANIFEST.aliases[name]] || ROWS.idle;
  }

  /**
   * options: look, animation = 'idle', scale = 2 (whole numbers keep pixels
   * crisp), basePath (prefix for pages outside web_dashboard/), onEnd,
   * label (screen-reader text; decorative without it), env (tests).
   */
  function create(el, options = {}) {
    const env = options.env || root;
    const doc = env.document;
    const raf = env.requestAnimationFrame ? env.requestAnimationFrame.bind(env) : (cb => env.setTimeout(() => cb(Date.now()), 1000 / 60));
    const caf = env.cancelAnimationFrame ? env.cancelAnimationFrame.bind(env) : (id => env.clearTimeout(id));
    const now = () => (env.performance?.now ? env.performance.now() : Date.now());
    let motion = null;
    try { motion = env.matchMedia?.('(prefers-reduced-motion: reduce)') || null; } catch { motion = null; }
    const reduced = () => Boolean(motion?.matches);
    const hidden = () => doc?.visibilityState === 'hidden' || doc?.hidden === true;

    const scale = Math.max(1, Math.round(options.scale || 2));
    const fw = MANIFEST.frameWidth * scale;
    const fh = MANIFEST.frameHeight * scale;
    const basePath = options.basePath || '';
    const state = {
      look: normalizeLook(options.look || {}), clip: animation(options.animation || 'idle'),
      frame: -1, start: 0, pausedAt: null, playing: false, ended: false, handle: null,
      onEnd: options.onEnd || null, hold: null,
    };

    el.classList?.add('w-avatar-layers');
    Object.assign(el.style, {
      position: el.style.position || 'relative', display: 'inline-block',
      width: `${fw}px`, height: `${fh}px`, imageRendering: 'pixelated',
    });
    if (options.label) {
      el.setAttribute?.('role', 'img');
      el.setAttribute?.('aria-label', options.label);
    } else {
      el.setAttribute?.('aria-hidden', 'true');
    }

    const slots = MANIFEST.order.map(k => {
      const s = doc.createElement('span');
      s.dataset && (s.dataset.layer = k);
      Object.assign(s.style, {
        position: 'absolute', left: '0', top: '0', width: `${fw}px`, height: `${fh}px`,
        backgroundRepeat: 'no-repeat', imageRendering: 'pixelated', pointerEvents: 'none',
        backgroundSize: `${MANIFEST.columns * fw}px ${MANIFEST.animations.length * fh}px`,
      });
      el.appendChild(s);
      return { key: k, el: s };
    });

    function applyLook() {
      for (const s of slots) {
        const id = state.look[s.key];
        s.el.style.backgroundImage = id ? `url("${basePath}${BASE}${s.key}_${id}.webp")` : 'none';
        s.el.style.display = id ? 'block' : 'none';
      }
      if (el.dataset) Object.assign(el.dataset, state.look, { headwear: state.look.headwear || '', accessory: state.look.accessory || '' });
    }

    function draw(frame, force = false) {
      if (frame === state.frame && !force) return;
      state.frame = frame;
      const pos = `${-frame * fw}px ${-state.clip.row * fh}px`;
      for (const s of slots) s.el.style.backgroundPosition = pos;
      if (el.dataset) { el.dataset.frame = String(frame); el.dataset.animation = state.clip.name; }
    }

    function finish() {
      if (state.ended) return;
      state.ended = true;
      const cb = state.onEnd;
      state.onEnd = null;
      cb?.();
    }

    function tick() {
      state.handle = null;
      if (!state.playing) return;
      const c = state.clip;
      const f = frameAt(now() - state.start, c.frames, c.fps, c.loop);
      draw(f);
      if (!c.loop && f >= c.frames - 1) {
        // Hold the last frame one beat before reporting the end.
        if (now() - state.start >= (c.frames * 1000) / c.fps) {
          state.playing = false;
          finish();
          return;
        }
      }
      state.handle = raf(tick);
    }
    function schedule() {
      if (state.handle == null && state.playing && !reduced() && !hidden()) state.handle = raf(tick);
    }
    function halt() {
      if (state.handle != null) caf(state.handle);
      state.handle = null;
    }
    function start() {
      halt();
      state.ended = false;
      state.start = now();
      state.pausedAt = null;
      draw(state.hold ?? 0, true);
      if (state.hold != null || reduced()) {
        state.playing = false;
        if (!state.clip.loop || state.hold != null) finish();
        return;
      }
      state.playing = true;
      if (hidden()) state.pausedAt = state.start;
      schedule();
    }

    function onVisibility() {
      if (!state.playing) return;
      if (hidden()) {
        state.pausedAt = now();
        halt();
      } else {
        if (state.pausedAt != null) state.start += now() - state.pausedAt;
        state.pausedAt = null;
        schedule();
      }
    }
    function onMotion() {
      if (reduced()) {
        halt();
        state.playing = false;
        draw(0, true);
      } else if (!state.ended) {
        start();
      }
    }
    doc?.addEventListener?.('visibilitychange', onVisibility);
    motion?.addEventListener?.('change', onMotion);

    applyLook();
    start();

    const api = {
      el,
      get frame() { return state.frame; },
      get animation() { return state.clip.name; },
      get look() { return { ...state.look }; },
      get playing() { return state.playing; },
      /** Play a clip by name; unknown names fall back to idle. */
      play(name, more = {}) {
        state.clip = animation(name);
        state.hold = null;
        state.onEnd = more.onEnd || null;
        start();
        return api;
      },
      /** Stand still facing down, right, up or left. */
      face(dir = 'down') {
        state.clip = ROWS.turn;
        state.hold = FACING[dir] ?? 0;
        state.onEnd = null;
        start();
        return api;
      },
      /** Walk (or run) in a direction: down, left, right, up. */
      walk(dir = 'down', { run = false } = {}) {
        return api.play(`${run ? 'run' : 'walk'}_${FACING[dir] == null ? 'down' : dir}`);
      },
      /** Turn once on the spot (front, right, back, left), then [then]. */
      spin(then = 'idle', onEnd) {
        const turn = ROWS.turn;
        const once = { ...turn, loop: false };
        state.clip = once;
        state.hold = null;
        state.onEnd = () => { api.play(then); onEnd?.(); };
        start();
        return api;
      },
      /** Change some layers; { spin: true } turns once to show it off. */
      setLook(next = {}, { spin = false, save = false, storage } = {}) {
        state.look = normalizeLook({ ...state.look, ...next });
        applyLook();
        if (save) saveLook(state.look, storage);
        if (spin) api.spin(state.clip.loop ? state.clip.name : 'idle');
        return api;
      },
      stop() { halt(); state.playing = false; draw(0, true); },
      destroy() {
        halt();
        state.playing = false;
        doc?.removeEventListener?.('visibilitychange', onVisibility);
        motion?.removeEventListener?.('change', onMotion);
        for (const s of slots) s.el.remove?.();
      },
    };
    return api;
  }

  return { BASE, STORAGE_KEY, MANIFEST, FACING, frameAt, normalizeLook, layerFiles, loadLook, saveLook, animation, create };
});
