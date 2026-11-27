// web_dashboard/assets/avatar_layers.js on fake elements with a manual
// requestAnimationFrame clock, plus the layered sheets it plays: every layer
// in one frame, reduced motion, hidden tabs, looks and the shipped files.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const avatar = require('../web_dashboard/assets/avatar_layers.js');

const root = path.join(__dirname, '..');
const webDir = path.join(root, 'web_dashboard/assets/characters/player');
const appDir = path.join(root, 'assets/characters/player');

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
      createElement: () => fakeEl(),
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
  const el = {
    style: {}, dataset: {}, attrs, children: [],
    classList: { add: c => cls.add(c), has: c => cls.has(c) },
    setAttribute: (k, v) => { attrs[k] = String(v); },
    getAttribute: k => attrs[k] ?? null,
    appendChild(c) { el.children.push(c); c.parent = el; return c; },
    remove() { if (el.parent) el.parent.children = el.parent.children.filter(x => x !== el); },
  };
  return el;
}

function webpSize(file) {
  const b = fs.readFileSync(file);
  assert.equal(b.toString('ascii', 0, 4), 'RIFF');
  assert.equal(b.toString('ascii', 8, 12), 'WEBP');
  const kind = b.toString('ascii', 12, 16);
  if (kind === 'VP8X') return { width: b.readUIntLE(24, 3) + 1, height: b.readUIntLE(27, 3) + 1 };
  assert.equal(kind, 'VP8L', `${path.basename(file)} keeps its alpha`);
  const bits = b.readUInt32LE(21);
  return { width: (bits & 0x3fff) + 1, height: ((bits >> 14) & 0x3fff) + 1 };
}

const positions = el => el.children.map(c => c.style.backgroundPosition);

test('the web manifest matches assets/characters/player/player.json', () => {
  const json = JSON.parse(fs.readFileSync(path.join(webDir, 'player.json'), 'utf8'));
  const strip = m => ({
    ...m,
    layers: Object.fromEntries(Object.entries(m.layers).map(([k, v]) => [k, v.map(({ id, name }) => ({ id, name }))])),
  });
  assert.deepEqual(JSON.parse(JSON.stringify(avatar.MANIFEST)), strip(json));
});

test('every action plays a row (its own or an alias) with 4+ frames at 8–12 fps', () => {
  const names = [...avatar.MANIFEST.animations.map(a => a.name), ...Object.keys(avatar.MANIFEST.aliases)];
  const required = [
    'idle', 'look', 'sit', 'read', 'sleep', 'happy', 'wave', 'think', 'stretch', 'snack', 'talk',
    ...['down', 'left', 'right', 'up'].flatMap(d => [`walk_${d}`, `run_${d}`]),
  ];
  for (const r of required) assert.ok(names.includes(r), `missing ${r}`);
  for (const a of avatar.MANIFEST.animations) {
    assert.ok(a.frames >= 4, `${a.name} has ${a.frames} frames`);
    assert.ok(a.frames <= avatar.MANIFEST.columns, `${a.name} fits the sheet`);
    assert.ok(a.fps >= 8 && a.fps <= 12, `${a.name} runs at ${a.fps} fps`);
  }
  for (const [k, v] of Object.entries(avatar.MANIFEST.aliases)) assert.ok(avatar.MANIFEST.animations.some(a => a.name === v), `${k} -> ${v}`);
  assert.equal(avatar.animation('read').name, 'think');
  assert.equal(avatar.animation('run_left').name, 'walk_left');
  const counts = Object.fromEntries(Object.entries(avatar.MANIFEST.layers).map(([k, v]) => [k, v.length]));
  assert.ok(counts.outfit >= 6 && counts.headwear >= 6, 'at least 6 outfits and 6 headwear');
});

test('every layer sheet ships to Web and App, same bytes, one full grid', () => {
  const m = avatar.MANIFEST;
  const want = { width: m.columns * m.frameWidth, height: m.animations.length * m.frameHeight };
  for (const [k, items] of Object.entries(m.layers)) {
    for (const it of items) {
      const file = `${k}_${it.id}.webp`;
      const web = path.join(webDir, file);
      const app = path.join(appDir, file);
      assert.ok(fs.existsSync(web), `web ${file}`);
      assert.ok(fs.existsSync(app), `app ${file}`);
      assert.ok(fs.readFileSync(web).equals(fs.readFileSync(app)), `${file} differs between Web and App`);
      assert.deepEqual(webpSize(web), want, file);
      assert.ok(fs.statSync(web).size < 300 * 1024, `${file} is small`);
    }
  }
  assert.ok(fs.readFileSync(path.join(webDir, 'player.json')).equals(fs.readFileSync(path.join(appDir, 'player.json'))));
});

test('all four layers stack in order and always show the same frame', () => {
  const env = fakeEnv();
  const el = fakeEl();
  const p = avatar.create(el, { scale: 2, env, animation: 'walk_left' });
  assert.deepEqual(el.children.map(c => c.dataset.layer), ['body', 'outfit', 'headwear', 'accessory']);
  assert.match(el.children[1].style.backgroundImage, /characters\/player\/outfit_adventurer\.webp/);
  assert.equal(el.style.width, '256px');
  assert.equal(el.style.height, '256px');
  assert.equal(el.children[0].style.backgroundSize, `${6 * 256}px ${avatar.MANIFEST.animations.length * 256}px`);
  const row = avatar.animation('walk_left').row;
  assert.deepEqual(new Set(positions(el)), new Set([`0px ${-row * 256}px`]));
  env.advance(250); // 8 fps
  assert.equal(p.frame, 2);
  assert.deepEqual(new Set(positions(el)), new Set([`-512px ${-row * 256}px`]), 'layers move together');
  assert.equal(el.attrs['aria-hidden'], 'true');
});

test('one-shot clips end on their last frame and report once', () => {
  const env = fakeEnv();
  const el = fakeEl();
  let ended = 0;
  const p = avatar.create(el, { env });
  p.play('happy', { onEnd: () => ended++ });
  env.advance(2000);
  assert.equal(p.frame, 5);
  assert.equal(ended, 1);
  assert.equal(env.pending, 0, 'no frames scheduled after the end');
});

test('reduced motion shows the full first frame and never schedules frames', () => {
  const env = fakeEnv({ reduced: true });
  const el = fakeEl();
  let ended = 0;
  const p = avatar.create(el, { env, animation: 'run_down' });
  assert.equal(p.frame, 0);
  assert.equal(env.pending, 0);
  assert.ok(el.children.every(c => c.style.backgroundImage.startsWith('url(')), 'never blank');
  p.play('wave', { onEnd: () => ended++ });
  assert.equal(ended, 1, 'one-shot still reports its end');
  env.advance(1000);
  assert.equal(p.frame, 0);
});

test('turning reduced motion on mid-clip snaps back to frame 0', () => {
  const env = fakeEnv();
  const el = fakeEl();
  const p = avatar.create(el, { env, animation: 'idle' });
  env.advance(400);
  assert.ok(p.frame > 0);
  env.setReduced(true);
  assert.equal(p.frame, 0);
  assert.equal(env.pending, 0);
});

test('a hidden tab pauses the clock and resumes where it left off', () => {
  const env = fakeEnv();
  const el = fakeEl();
  const p = avatar.create(el, { env, animation: 'walk_down' });
  env.advance(150);
  const before = p.frame;
  env.setHidden(true);
  assert.equal(env.pending, 0);
  env.advance(5000);
  env.setHidden(false);
  assert.equal(p.frame, before);
  env.advance(100);
  assert.equal(p.frame, before + 1);
});

test('face, walk and spin pick the right rows', () => {
  const env = fakeEnv();
  const el = fakeEl();
  const p = avatar.create(el, { env });
  p.face('up');
  assert.equal(p.animation, 'turn');
  assert.equal(p.frame, 2);
  env.advance(1000);
  assert.equal(p.frame, 2, 'facing holds still');
  p.walk('right', { run: true });
  assert.equal(p.animation, 'walk_right', 'running plays the walk row');
  p.walk('sideways');
  assert.equal(p.animation, 'walk_down');
  let spun = 0;
  p.spin('idle', () => spun++);
  env.advance(1000);
  assert.equal(spun, 1);
  assert.equal(p.animation, 'idle');
  p.play('nope');
  assert.equal(p.animation, 'idle');
});

test('looks are normalized, saved and changed with a spin', () => {
  const store = new Map();
  const storage = { getItem: k => store.get(k) ?? null, setItem: (k, v) => store.set(k, v) };
  assert.deepEqual(avatar.loadLook(storage), avatar.MANIFEST.default);
  assert.deepEqual(avatar.normalizeLook({ body: 'rose', outfit: '???', headwear: null, accessory: 'glasses' }),
    { body: 'rose', outfit: 'adventurer', headwear: null, accessory: 'glasses' });
  storage.setItem(avatar.STORAGE_KEY, '{broken');
  assert.deepEqual(avatar.loadLook(storage), avatar.MANIFEST.default);

  const env = fakeEnv();
  const el = fakeEl();
  const p = avatar.create(el, { env, look: { headwear: null } });
  assert.equal(el.children[2].style.display, 'none', 'no headwear');
  p.setLook({ outfit: 'sunny', headwear: 'wizard' }, { spin: true, save: true, storage });
  assert.equal(p.animation, 'turn');
  assert.match(el.children[1].style.backgroundImage, /outfit_sunny/);
  assert.match(el.children[2].style.backgroundImage, /headwear_wizard/);
  assert.equal(JSON.parse(store.get(avatar.STORAGE_KEY)).outfit, 'sunny');
  env.advance(1000);
  assert.equal(p.animation, 'idle', 'back to idle after the turn');
  assert.deepEqual(avatar.layerFiles({ accessory: null }, '../').length, 3);
});

test('destroy stops the clock and removes the layers', () => {
  const env = fakeEnv();
  const el = fakeEl();
  const p = avatar.create(el, { env, label: '你的角色' });
  assert.equal(el.attrs.role, 'img');
  p.destroy();
  assert.equal(env.pending, 0);
  assert.equal(el.children.length, 0);
});

test('the player only uses requestAnimationFrame and no external URLs', () => {
  const src = fs.readFileSync(path.join(root, 'web_dashboard/assets/avatar_layers.js'), 'utf8');
  assert.ok(src.includes('requestAnimationFrame'));
  assert.ok(!/setInterval\(/.test(src));
  assert.ok(!/https?:\/\//.test(src));
});
