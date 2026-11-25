(function (root, factory) {
  const api = factory(root);
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.NudgeSpritePlayer = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function (root) {
  'use strict';
  // Plays one row of a sprite sheet on an element's background.
  //
  //   const p = NudgeSpritePlayer.create(el, { src, frames: 4, fps: 8 });
  //   const npc = NudgeSpritePlayer.character(el, 'chestnut', { animation: 'idle', size: 96 });
  //   npc.play('talk');  npc.play('happy', { onEnd: () => npc.play('idle') });
  //   npc.destroy();
  //
  // Frames are drawn with background-position so the pixel grid stays crisp.
  // Reduced motion shows frame 0 and never advances; a hidden tab pauses.

  const CHARACTER_BASE = 'assets/characters/';
  const MAX_FPS = 24;

  // Character sheets, mirrored from assets/characters/characters.json
  // (test/sprite_player_test.js keeps them equal).
  const CATALOG = Object.freeze({
    frameSize: 128,
    layouts: {
      companion: [
        { name: 'idle', frames: 4, fps: 6, loop: true },
        { name: 'walk_down', frames: 4, fps: 8, loop: true },
        { name: 'walk_left', frames: 4, fps: 8, loop: true },
        { name: 'walk_right', frames: 4, fps: 8, loop: true },
        { name: 'walk_up', frames: 4, fps: 8, loop: true },
        { name: 'happy', frames: 6, fps: 10, loop: false },
        { name: 'wave', frames: 4, fps: 8, loop: false },
        { name: 'think', frames: 4, fps: 6, loop: true },
        { name: 'sleep', frames: 4, fps: 4, loop: true },
      ],
      npc: [
        { name: 'idle', frames: 4, fps: 6, loop: true },
        { name: 'talk', frames: 4, fps: 8, loop: true },
        { name: 'walk_down', frames: 4, fps: 8, loop: true },
        { name: 'walk_left', frames: 4, fps: 8, loop: true },
        { name: 'walk_right', frames: 4, fps: 8, loop: true },
        { name: 'walk_up', frames: 4, fps: 8, loop: true },
      ],
    },
    characters: [
      { id: 'companion', name: '夥伴', role: '玩家角色', layout: 'companion' },
      { id: 'chestnut', name: '栗子', role: '雜貨店老闆', layout: 'npc' },
      { id: 'scroll', name: '阿紙', role: '委託所告示員', layout: 'npc' },
      { id: 'bounce', name: '跳跳', role: '遊樂園管理員', layout: 'npc' },
      { id: 'sprout', name: '苗苗', role: '花園園丁', layout: 'npc' },
      { id: 'inky', name: '墨墨', role: '圖書館員', layout: 'npc' },
      { id: 'bell', name: '鐘鐘', role: '塔的守門人', layout: 'npc' },
      { id: 'letty', name: '小信', role: '郵差', layout: 'npc' },
      { id: 'stella', name: '星婆', role: '天文學者', layout: 'npc' },
    ],
  });

  /** Frame index shown after [elapsedMs]; a non-looping clip holds its last frame. */
  function frameAt(elapsedMs, frames, fps, loop = true) {
    if (!(frames > 1) || !(fps > 0) || !(elapsedMs > 0)) return 0;
    const step = Math.floor((elapsedMs * fps) / 1000);
    return loop ? step % frames : Math.min(step, frames - 1);
  }

  function character(id) {
    const c = CATALOG.characters.find(x => x.id === id);
    if (!c) throw new Error(`unknown character: ${id}`);
    const rows = CATALOG.layouts[c.layout];
    return {
      ...c,
      src: `${CHARACTER_BASE}${c.id}/sheet.webp`,
      columns: Math.max(...rows.map(r => r.frames)),
      rows: rows.length,
      animations: Object.fromEntries(rows.map((r, row) => [r.name, { ...r, row }])),
    };
  }

  function reducedMotionQuery(env) {
    try { return env.matchMedia?.('(prefers-reduced-motion: reduce)') || null; } catch { return null; }
  }

  /**
   * options: src, frames, fps (1–24), row = 0, loop = true, frameWidth/frameHeight = 128,
   * columns (sheet width in frames, default = frames), rows (default = row + 1),
   * size (shown px, default frameWidth), autoplay = true, onEnd, env (tests).
   */
  function create(el, options = {}) {
    const env = options.env || root;
    const doc = env.document;
    const raf = env.requestAnimationFrame ? env.requestAnimationFrame.bind(env) : (cb => env.setTimeout(() => cb(Date.now()), 1000 / 60));
    const caf = env.cancelAnimationFrame ? env.cancelAnimationFrame.bind(env) : (id => env.clearTimeout(id));
    const now = () => (env.performance?.now ? env.performance.now() : Date.now());
    const motion = reducedMotionQuery(env);

    const fw = options.frameWidth || 128;
    const fh = options.frameHeight || fw;
    const state = {
      src: options.src, row: options.row || 0, frames: options.frames || 1,
      fps: Math.min(MAX_FPS, Math.max(1, options.fps || 8)), loop: options.loop !== false,
      columns: options.columns || options.frames || 1, rows: options.rows || (options.row || 0) + 1,
      onEnd: options.onEnd || null, frame: -1, start: 0, pausedAt: null, playing: false, handle: null,
      ended: false,
    };
    const size = options.size || fw;
    const scale = size / fw;

    el.classList?.add('w-sprite');
    el.setAttribute?.('aria-hidden', el.getAttribute?.('aria-label') ? 'false' : 'true');
    el.style.width = `${size}px`;
    el.style.height = `${Math.round(fh * scale)}px`;
    el.style.backgroundRepeat = 'no-repeat';
    el.style.imageRendering = 'pixelated';

    const reduced = () => Boolean(motion?.matches);
    const hidden = () => doc?.visibilityState === 'hidden' || doc?.hidden === true;

    function applySheet() {
      el.style.backgroundImage = `url("${state.src}")`;
      el.style.backgroundSize = `${state.columns * fw * scale}px ${state.rows * fh * scale}px`;
    }
    function draw(frame) {
      if (frame === state.frame) return;
      state.frame = frame;
      el.style.backgroundPosition = `${-frame * fw * scale}px ${-state.row * fh * scale}px`;
      if (el.dataset) el.dataset.frame = String(frame);
    }
    function tick() {
      state.handle = null;
      if (!state.playing) return;
      const frame = frameAt(now() - state.start, state.frames, state.fps, state.loop);
      draw(frame);
      if (!state.loop && frame >= state.frames - 1) {
        state.playing = false;
        finish();
        return;
      }
      state.handle = raf(tick);
    }
    function finish() {
      if (state.ended) return;
      state.ended = true;
      const cb = state.onEnd;
      state.onEnd = null;
      cb?.();
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
      state.frame = -1;
      state.ended = false;
      state.start = now();
      state.pausedAt = null;
      draw(0);
      if (reduced()) {
        // Still picture; a one-shot reaction still reports that it is over.
        state.playing = false;
        if (!state.loop) finish();
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
        state.frame = -1;
        draw(0);
      } else if (!state.ended) {
        start();
      }
    }
    doc?.addEventListener?.('visibilitychange', onVisibility);
    motion?.addEventListener?.('change', onMotion);

    applySheet();
    if (options.autoplay === false) draw(0);
    else start();

    return {
      el,
      get frame() { return state.frame; },
      get playing() { return state.playing; },
      /** Switch to another row of the same sheet. */
      play(next = {}) {
        Object.assign(state, {
          row: next.row ?? state.row, frames: next.frames ?? state.frames,
          fps: Math.min(MAX_FPS, Math.max(1, next.fps ?? state.fps)), loop: next.loop ?? state.loop,
          onEnd: next.onEnd || null,
        });
        start();
      },
      stop() { halt(); state.playing = false; state.frame = -1; draw(0); },
      destroy() {
        halt();
        state.playing = false;
        doc?.removeEventListener?.('visibilitychange', onVisibility);
        motion?.removeEventListener?.('change', onMotion);
      },
    };
  }

  /**
   * A catalog character. options: animation = 'idle', size, basePath
   * (prefix for pages outside web_dashboard/), onEnd, env.
   * play(name, { onEnd }) switches animation; unknown names fall back to idle.
   */
  function characterPlayer(el, id, options = {}) {
    const info = character(id);
    const pick = name => info.animations[name] || info.animations.idle;
    const first = pick(options.animation || 'idle');
    const player = create(el, {
      src: (options.basePath || '') + info.src,
      frameWidth: CATALOG.frameSize, columns: info.columns, rows: info.rows,
      row: first.row, frames: first.frames, fps: first.fps, loop: first.loop,
      size: options.size, onEnd: options.onEnd, env: options.env, autoplay: options.autoplay,
    });
    if (el.dataset) Object.assign(el.dataset, { character: id, animation: first.name });
    return Object.assign(Object.create(player), {
      character: info,
      play(name, more = {}) {
        const a = pick(name);
        if (el.dataset) el.dataset.animation = a.name;
        player.play({ row: a.row, frames: a.frames, fps: a.fps, loop: a.loop, onEnd: more.onEnd });
      },
      stop: player.stop, destroy: player.destroy,
    });
  }

  return { CATALOG, frameAt, character, create, characterPlayer };
});
