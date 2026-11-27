// Pets (J3): manifest mirror, shipped sheets, growth from Cloud focus
// minutes only, the on-device choice, and the follower in reduced motion.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
globalThis.NudgeSpritePlayer = require('../web_dashboard/assets/sprite_player.js');
const pets = require('../web_dashboard/assets/scenes/pet_house/pets.js');

const root = path.join(__dirname, '..');
const web = path.join(root, 'web_dashboard/assets/characters/pets');
const app = path.join(root, 'assets/characters/pets');

function store() {
  const m = new Map();
  return { getItem: k => m.get(k) ?? null, setItem: (k, v) => m.set(k, String(v)) };
}
function fakeEl() {
  const el = {
    style: {}, dataset: {}, children: [], attrs: {},
    classList: { add() {} }, setAttribute(k, v) { el.attrs[k] = v; }, getAttribute: k => el.attrs[k] ?? null,
    append(c) { el.children.push(c); }, remove() {}, ownerDocument: { createElement: () => fakeEl() },
  };
  return el;
}

test('the web manifest matches pets.json', () => {
  const json = JSON.parse(fs.readFileSync(path.join(web, 'pets.json'), 'utf8'));
  const strip = { ...json, species: json.species.map(s => ({ id: s.id, name: s.name, stages: s.stages.map(x => x.name) })) };
  assert.deepEqual(JSON.parse(JSON.stringify(pets.MANIFEST)), strip);
  assert.ok(fs.readFileSync(path.join(web, 'pets.json')).equals(fs.readFileSync(path.join(app, 'pets.json'))));
});

test('three species, three stages, every action with 4+ frames at 8–12 fps', () => {
  assert.equal(pets.MANIFEST.species.length, 3);
  const names = pets.MANIFEST.animations.map(a => a.name);
  for (const n of ['idle', 'walk_down', 'walk_left', 'walk_right', 'walk_up', 'happy', 'sleep', 'cuddle']) assert.ok(names.includes(n), n);
  for (const a of pets.MANIFEST.animations) {
    assert.ok(a.frames >= 4 && a.frames <= pets.MANIFEST.columns, a.name);
    assert.ok(a.fps >= 8 && a.fps <= 12, a.name);
  }
  for (const s of pets.MANIFEST.species) {
    for (const st of pets.MANIFEST.stageNames) {
      const f = `${s.id}_${st}.webp`;
      assert.ok(fs.readFileSync(path.join(web, f)).equals(fs.readFileSync(path.join(app, f))), f);
    }
  }
});

test('growth reads completed focus minutes only', () => {
  assert.equal(pets.stageFor(0), 'baby');
  assert.equal(pets.stageFor(299), 'baby');
  assert.equal(pets.stageFor(300), 'teen');
  assert.equal(pets.stageFor(1500), 'adult');
  assert.equal(pets.toNext(100), 200);
  assert.equal(pets.toNext(2000), 0);
  const docs = [
    { actorUserId: 'u', status: 'completed', activityType: 'focus', metricUnit: 'minutes', metricValue: 25 },
    { actorUserId: 'u', status: 'completed', activityType: 'study', metricUnit: 'minutes', metricValue: 30 },
    { actorUserId: 'u', status: 'pending', activityType: 'focus', metricUnit: 'minutes', metricValue: 90 },
    { actorUserId: 'x', status: 'completed', activityType: 'focus', metricUnit: 'minutes', metricValue: 90 },
    { actorUserId: 'u', status: 'completed', activityType: 'exercise', metricUnit: 'minutes', metricValue: 90 },
    { actorUserId: 'u', status: 'completed', activityType: 'focus', metricUnit: 'minutes', metricValue: 99999 },
    { actorUserId: 'u', status: 'completed', activityType: 'focus', metricUnit: 'steps', metricValue: 9 },
  ];
  assert.equal(pets.focusMinutes(docs, 'u'), 55);
});

test('the query is read-only and refuses cached results', async () => {
  const calls = [];
  const q = {
    where: (...a) => { calls.push(['where', ...a]); return q; }, orderBy: (...a) => { calls.push(['orderBy', ...a]); return q; },
    limit: n => { calls.push(['limit', n]); return q; },
    get: async () => ({ metadata: {}, docs: [{ data: () => ({ actorUserId: 'u', status: 'completed', activityType: 'focus', metricUnit: 'minutes', metricValue: 40 }) }] }),
  };
  const fs_ = { collection: n => { calls.push(['collection', n]); return q; } };
  assert.equal(await pets.loadFocusMinutes(fs_, 'u'), 40);
  assert.deepEqual(calls[0], ['collection', 'activity_sessions']);
  assert.ok(calls.some(c => c[0] === 'where' && c[1] === 'actorUserId' && c[3] === 'u'));
  q.get = async () => ({ metadata: { fromCache: true }, docs: [] });
  await assert.rejects(pets.loadFocusMinutes(fs_, 'u'));
  const src = fs.readFileSync(path.join(root, 'web_dashboard/assets/scenes/pet_house/pets.js'), 'utf8');
  assert.ok(!/\.(set|add|update|delete)\(/.test(src.replace(/storage\?\.setItem|setItem/g, '')), 'no writes to Firestore');
});

test('the choice stays on this device and unknown species are ignored', () => {
  const s = store();
  assert.equal(pets.loadChoice(s), null);
  assert.deepEqual(pets.saveChoice('fox', s), { species: 'fox' });
  assert.deepEqual(pets.loadChoice(s), { species: 'fox' });
  assert.equal(pets.saveChoice('dragon', s), null);
  s.setItem(pets.CHOICE_KEY, '{oops');
  assert.equal(pets.loadChoice(s), null);
  pets.cacheStage('adult', s);
  assert.equal(pets.cachedStage(s), 'adult');
  assert.equal(pets.stageName('slime', 'adult'), '王冠史萊姆');
});

test('a follower sticks beside the player under reduced motion', () => {
  const container = fakeEl();
  let at = [0.5, 0.8];
  const f = pets.follow(container, () => at, { choice: { species: 'owl' }, stage: 'teen', reduced: () => true });
  assert.equal(container.children.length, 1);
  at = [0.3, 0.7];
  f.update(at, 16);
  assert.equal(f.node.style.left, `${(0.3 + 0.06) * 100}%`);
  assert.equal(f.node.style.top, '70%');
  assert.equal(pets.follow(fakeEl(), () => at, { choice: null }), null);
  f.destroy();
});
