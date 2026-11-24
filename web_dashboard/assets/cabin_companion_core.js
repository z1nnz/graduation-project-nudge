(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.NudgeCabinCompanionCore = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';
  // The cabin companion's behaviour, ported from the App's
  // lib/models/cabin_companion_brain.dart so both cabins move the same way.
  // Positions are 0-1 of the cabin stage and mark where the feet touch the
  // floor. Pure: time comes in through tick(dt), randomness is injected.

  const FLOOR = Object.freeze({ left: 0.12, top: 0.6, right: 0.88, bottom: 0.86 });
  const DESK = Object.freeze({ x: 0.62, y: 0.61 });
  const RUG = Object.freeze({ x: 0.5, y: 0.72 });
  const WANDER_SPOTS = Object.freeze([
    { x: 0.5, y: 0.62 }, // window
    { x: 0.27, y: 0.64 }, // bookshelf
    { x: 0.5, y: 0.74 }, // rug
    { x: 0.7, y: 0.66 }, // desk side
    { x: 0.3, y: 0.78 },
    { x: 0.72, y: 0.8 },
  ]);
  const SPEED = 0.18;
  const ACCEL = 0.9;
  const GLANCE_EVERY = 1.4;
  const CHEER_SECONDS = 1.2;
  const NIGHT_START = 22;
  const NIGHT_END = 6;
  const POSE_ART = new Set([0, 3, 6, 9, 12, 15]);

  const dist = (a, b) => Math.hypot(a.x - b.x, a.y - b.y);

  /** Same rule as the App: a running desk focus wins over the night. */
  function wantedActivity({ focusing = false, hour = 12 } = {}) {
    if (focusing) return 'focus';
    return hour >= NIGHT_START || hour < NIGHT_END ? 'rest' : 'wander';
  }

  function clampFloor(p) {
    return {
      x: Math.min(FLOOR.right, Math.max(FLOOR.left, p.x)),
      y: Math.min(FLOOR.bottom, Math.max(FLOOR.top, p.y)),
    };
  }

  function createBrain({ random = Math.random, start = RUG } = {}) {
    const s = {
      position: { ...start }, target: null, activity: 'wander',
      restTimer: 2, cheerTimer: 0, stepClock: 0, speed: 0, glanceTimer: GLANCE_EVERY, facingLeft: false,
    };

    function pose() {
      if (s.cheerTimer > 0) return 'cheer';
      if (s.target) return 'walk';
      if (s.activity === 'focus') return dist(s.position, DESK) < 0.02 ? 'read' : 'idle';
      if (s.activity === 'rest') return dist(s.position, RUG) < 0.02 ? 'sleep' : 'idle';
      return 'idle';
    }

    function setActivity(activity) {
      if (activity === s.activity) return;
      s.activity = activity;
      if (activity === 'focus') s.target = { ...DESK };
      else if (activity === 'rest') s.target = { ...RUG };
      else { s.target = null; s.restTimer = 1.5; }
    }

    /** Walk to a tapped spot. A busy companion (focusing or resting) stays put. */
    function walkTo(point) {
      if (s.activity !== 'wander') return false;
      s.target = clampFloor(point);
      return true;
    }

    function poke() { s.cheerTimer = CHEER_SECONDS; }

    /** Jump straight to where the activity wants to be (reduced motion). */
    function settle() {
      if (s.activity === 'focus') s.position = { ...DESK };
      else if (s.activity === 'rest') s.position = { ...RUG };
      else if (s.target) s.position = { ...s.target };
      s.target = null;
      s.speed = 0;
    }

    function tick(dtRaw) {
      // A hidden tab or a slow frame must not teleport the companion.
      const dt = Math.min(0.1, Math.max(0, Number(dtRaw) || 0));
      if (s.cheerTimer > 0) { s.cheerTimer = Math.max(0, s.cheerTimer - dt); return; }
      if (s.target) {
        const dx = s.target.x - s.position.x;
        const dy = s.target.y - s.position.y;
        const distance = Math.hypot(dx, dy);
        const brake = Math.sqrt(2 * ACCEL * distance);
        s.speed = Math.min(Math.min(SPEED, s.speed + ACCEL * dt), Math.max(brake, 0.02));
        const step = s.speed * dt;
        if (distance <= Math.max(step, 0.002)) {
          s.position = { ...s.target };
          s.target = null;
          s.speed = 0;
          s.restTimer = 3 + random() * 5;
          s.glanceTimer = GLANCE_EVERY;
        } else {
          s.position = { x: s.position.x + dx / distance * step, y: s.position.y + dy / distance * step };
          if (Math.abs(dx) > 0.002) s.facingLeft = dx < 0;
          s.stepClock += dt * (s.speed / SPEED);
        }
        return;
      }
      if (s.activity !== 'wander') return;
      s.glanceTimer -= dt;
      if (s.glanceTimer <= 0) {
        s.facingLeft = !s.facingLeft; // look around while waiting
        s.glanceTimer = GLANCE_EVERY + random();
      }
      s.restTimer -= dt;
      if (s.restTimer <= 0) {
        const options = WANDER_SPOTS.filter(p => dist(p, s.position) > 0.08);
        s.target = { ...options[Math.floor(random() * options.length) % options.length] };
      }
    }

    return {
      get position() { return { ...s.position }; },
      get facingLeft() { return s.facingLeft; },
      get activity() { return s.activity; },
      get walking() { return Boolean(s.target); },
      get stepPhase() { return (s.stepClock * 2.2) % 1; },
      get pose() { return pose(); },
      setActivity, walkTo, poke, settle, tick,
    };
  }

  /**
   * Image for a pose. Characters with generated pose art (one per series)
   * use it; the others show their front sprite, as in the App.
   */
  function spriteFor(face, pose, stepPhase = 0) {
    const f = Number.isInteger(face) && face >= 0 ? face : 0;
    const front = { src: `assets/avatar/characters/character_${f}.png`, kind: 'front' };
    if (!POSE_ART.has(f)) return front;
    if (pose === 'walk') {
      const frames = ['a', 'p', 'b', 'p'];
      const frame = frames[Math.floor((((Number(stepPhase) % 1) + 1) % 1) * 4) % 4];
      return { src: `assets/avatar/poses/walk_${f}_${frame}.png`, kind: 'walk' };
    }
    if (['read', 'sleep', 'cheer'].includes(pose)) return { src: `assets/avatar/poses/pose_${f}_${pose}.png`, kind: pose };
    return front;
  }

  const LINES = Object.freeze({
    focus: ['一起專注，加油！', '我在書桌陪你。'],
    rest: ['呼……晚安', '明天見……'],
    wander: ['今天也一起加油！', '要不要去書桌專注一下？', '小屋好舒服～', '你來看我了！'],
  });

  /** What the companion says when tapped. */
  function lineFor(activity, random = Math.random) {
    const list = LINES[activity] || LINES.wander;
    return list[Math.floor(random() * list.length) % list.length];
  }

  /** Is the Web desk focus timer (town_desk_core.js storage) running for this account? */
  function deskFocusing(raw) {
    try {
      const v = JSON.parse(raw || 'null');
      return Boolean(v && typeof v === 'object' && v.status === 'active' && typeof v.sessionId === 'string');
    } catch { return false; }
  }

  return Object.freeze({
    FLOOR, DESK, RUG, WANDER_SPOTS, SPEED, CHEER_SECONDS,
    wantedActivity, clampFloor, createBrain, spriteFor, lineFor, deskFocusing,
  });
});
