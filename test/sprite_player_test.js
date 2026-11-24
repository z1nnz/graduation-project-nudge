// web_dashboard/assets/sprite_player.js on a fake element with a manual
// requestAnimationFrame clock: frame timing, one-shot clips, reduced motion,
// hidden tabs, and that every catalog character ships its sheet.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const sprites = require('../web_dashboard/assets/sprite_player.js');

const root = path.join(__dirname, '..');

function fakeEnv({ reduced = false } = {}) {
  let t = 0;
  let queue = [];
  let id = 0;
  const docListeners = {};
  const mqListeners = [];
  const mq = { matches: reduced, addEventListener: (_, cb) => mqListeners.push(cb), removeEventListener() {} };
  const env = {
    performance: { now: () => t },
    requestAnimationFrame(cb) { queue.push({ id: ++id, cb }); return id; },
    cancelAnimationFrame(x) { queue = queue.filter(q => q.id !== x); },
    matchMedia: () => mq,
    document: {
      visibilityState: 'visible',
      addEventListener: (n, cb) => { (docListeners[n] ||= []).push(cb); },
      removeEventListener: (n, cb) => { docListeners[n] = (docListeners[n] || []).filter(x => x !== cb); },
    },
    advance(ms) {
      const end = t + ms;
      while (t < end) {
        t = Math.min(end, t + 16);
        const run = queue;
        queue = [];
        run.forEach(q => q.cb(t));
      }
    },
    get pending() { return queue.length; },
    setHidden(hidden) {
      env.document.visibilityState = hidden ? 'hidden' : 'visible';
      (docListeners.visibilitychange || []).forEach(cb => cb());
    },
    setReduced(on) { mq.matches = on; mqListeners.forEach(cb => cb()); },
  };
  return env;
}

function fakeEl() {
  const attrs = {};
  const cls = new Set();
  return {
    style: {}, dataset: {}, attrs,
    classList: { add: c => cls.add(c), has: c => cls.has(c) },
    setAttribute: (k, v) => { attrs[k] = String(v); },
    getAttribute: k => attrs[k] ?? null,
  };
}

test('frameAt loops, holds one-shot clips on the last frame and starts at 0', () => {
  assert.equal(sprites.frameAt(0, 4, 8), 0);
  assert.equal(sprites.frameAt(124, 4, 8), 0);
  assert.equal(sprites.frameAt(125, 4, 8), 1);
  assert.equal(sprites.frameAt(500, 4, 8), 0, 'wraps after 4 frames at 8 fps');
  assert.equal(sprites.frameAt(5000, 6, 10, false), 5);
  assert.equal(sprites.frameAt(1000, 1, 8), 0);
  assert.equal(sprites.frameAt(-10, 4, 8), 0);
});

test('the player steps through one sheet row at the requested fps', () => {
  const env = fakeEnv();
  const el = fakeEl();
  const p = sprites.create(el, { src: 'x.webp', frames: 4, fps: 8, row: 2, rows: 4, size: 64, env });
  assert.ok(el.classList.has('w-sprite'));
  assert.equal(el.style.width, '64px');
  assert.equal(el.style.backgroundImage, 'url("x.webp")');
  assert.equal(el.style.backgroundSize, '256px 256px');
  assert.equal(el.style.backgroundPosition, '0px -128px');
  assert.equal(el.attrs['aria-hidden'], 'true', 'decorative unless labelled');
  env.advance(130);
  assert.equal(p.frame, 1);
  assert.equal(el.style.backgroundPosition, '-64px -128px');
  env.advance(375);
  assert.equal(p.frame, 0, 'looped');
  p.destroy();
  assert.equal(env.pending, 0);
});

test('a one-shot clip ends on its last frame and calls onEnd once', () => {
  const env = fakeEnv();
  let ended = 0;
  const p = sprites.create(fakeEl(), { src: 'x', frames: 3, fps: 10, loop: false, onEnd: () => ended++, env });
  env.advance(1000);
  assert.equal(p.frame, 2);
  assert.equal(p.playing, false);
  assert.equal(ended, 1);
  assert.equal(env.pending, 0, 'stops scheduling frames');
});

test('reduced motion shows frame 0 and never schedules frames', () => {
  const env = fakeEnv({ reduced: true });
  let ended = 0;
  const p = sprites.create(fakeEl(), { src: 'x', frames: 4, fps: 8, env });
  assert.equal(env.pending, 0);
  env.advance(1000);
  assert.equal(p.frame, 0);
  assert.equal(p.playing, false);
  p.play({ frames: 6, loop: false, onEnd: () => ended++ });
  assert.equal(p.frame, 0);
  assert.equal(ended, 1, 'reactions still report they are done');
});

test('turning reduced motion on mid-animation snaps back to frame 0', () => {
  const env = fakeEnv();
  const p = sprites.create(fakeEl(), { src: 'x', frames: 4, fps: 8, env });
  env.advance(260);
  assert.equal(p.frame, 2);
  env.setReduced(true);
  assert.equal(p.frame, 0);
  assert.equal(env.pending, 0);
  env.setReduced(false);
  assert.equal(p.playing, true);
});

test('a hidden tab pauses the clock and resumes where it left off', () => {
  const env = fakeEnv();
  const p = sprites.create(fakeEl(), { src: 'x', frames: 4, fps: 8, env });
  env.advance(130);
  assert.equal(p.frame, 1);
  env.setHidden(true);
  assert.equal(env.pending, 0);
  env.advance(10000);
  env.setHidden(false);
  env.advance(16);
  assert.equal(p.frame, 1, 'no jump after coming back');
  p.destroy();
});

test('characterPlayer picks catalog rows and falls back to idle', () => {
  const env = fakeEnv();
  const el = fakeEl();
  const npc = sprites.characterPlayer(el, 'chestnut', { size: 128, env });
  assert.equal(el.dataset.character, 'chestnut');
  assert.equal(el.style.backgroundImage, 'url("assets/characters/chestnut/sheet.webp")');
  assert.equal(el.style.backgroundSize, '512px 768px');
  npc.play('talk');
  assert.equal(el.dataset.animation, 'talk');
  assert.equal(el.style.backgroundPosition, '0px -128px');
  npc.play('walk_up');
  assert.equal(el.style.backgroundPosition, '0px -640px');
  npc.play('nope');
  assert.equal(el.dataset.animation, 'idle');
  const me = sprites.characterPlayer(fakeEl(), 'companion', { env, basePath: '../' });
  assert.equal(me.character.columns, 6);
  assert.deepEqual(Object.keys(me.character.animations),
    ['idle', 'walk_down', 'walk_left', 'walk_right', 'walk_up', 'happy', 'wave', 'think', 'sleep']);
  assert.throws(() => sprites.character('nobody'));
});

test('the web catalog matches assets/characters/characters.json', () => {
  const json = JSON.parse(fs.readFileSync(path.join(root, 'assets/characters/characters.json'), 'utf8'));
  assert.deepEqual(JSON.parse(JSON.stringify(sprites.CATALOG)), json);
});

test('every character ships the same sheet to Web and App', () => {
  const { CATALOG } = sprites;
  assert.equal(CATALOG.characters.length, 9);
  for (const c of CATALOG.characters) {
    const info = sprites.character(c.id);
    const web = path.join(root, 'web_dashboard', info.src);
    const app = path.join(root, 'assets/characters', c.id, 'sheet.webp');
    assert.ok(fs.existsSync(web), web);
    assert.ok(fs.readFileSync(web).equals(fs.readFileSync(app)), `${c.id} sheets differ`);
    const head = fs.readFileSync(web).subarray(0, 30);
    assert.equal(head.toString('ascii', 0, 4), 'RIFF');
    assert.equal(head.toString('ascii', 8, 12), 'WEBP');
    // VP8L / VP8X headers carry the canvas size; check it is the full grid.
    const size = webpSize(fs.readFileSync(web));
    assert.deepEqual(size, [info.columns * CATALOG.frameSize, info.rows * CATALOG.frameSize], c.id);
  }
});

function webpSize(buf) {
  const chunk = buf.toString('ascii', 12, 16);
  if (chunk === 'VP8X') return [1 + buf.readUIntLE(24, 3), 1 + buf.readUIntLE(27, 3)];
  if (chunk === 'VP8L') {
    const b = buf.readUInt32LE(21);
    return [1 + (b & 0x3fff), 1 + ((b >> 14) & 0x3fff)];
  }
  return [buf.readUInt16LE(26) & 0x3fff, buf.readUInt16LE(28) & 0x3fff];
}

test('the player only uses requestAnimationFrame and no external URLs', () => {
  const src = fs.readFileSync(path.join(root, 'web_dashboard/assets/sprite_player.js'), 'utf8');
  assert.doesNotMatch(src, /setInterval/);
  assert.doesNotMatch(src, /https?:\/\//);
});
