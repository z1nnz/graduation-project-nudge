const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const living = require('../web_dashboard/assets/scenes/social_world/living_room.js');

const web = path.join(__dirname, '..', 'web_dashboard');
function rooms() {
  const sandbox = {};
  sandbox.globalThis = sandbox;
  vm.createContext(sandbox);
  vm.runInContext(fs.readFileSync(path.join(web, 'assets/scenes/social_world/social_rooms.js'), 'utf8'), sandbox);
  return sandbox.NudgeSocialRooms;
}

test('the companion stands just below an object and walks with the right sheet row', () => {
  assert.deepEqual(living.standPoint([0.4, 0.2, 0.2, 0.3]), { x: 0.5, y: 0.53 });
  assert.equal(living.standPoint([0.9, 0.9, 0.2, 0.2]).y, 0.97, 'clamped inside the art');
  assert.equal(living.walkAnimation(0.2, 0.05), 'walk_right');
  assert.equal(living.walkAnimation(-0.2, 0.05), 'walk_left');
  assert.equal(living.walkAnimation(0.01, 0.3), 'walk_down');
  assert.equal(living.walkAnimation(0.01, -0.3), 'walk_up');
  assert.equal(living.walkAnimation(0, 0), 'idle');
});

test('walks take time proportional to distance and ease in and out', () => {
  assert.equal(living.walkDuration({ x: 0, y: 0 }, { x: 0, y: 0 }), 250);
  assert.ok(living.walkDuration({ x: 0, y: 0 }, { x: 0.9, y: 0 }) > living.walkDuration({ x: 0, y: 0 }, { x: 0.3, y: 0 }));
  assert.deepEqual(living.along({ x: 0, y: 0 }, { x: 1, y: 1 }, 0), { x: 0, y: 0 });
  assert.deepEqual(living.along({ x: 0, y: 0 }, { x: 1, y: 1 }, 1), { x: 1, y: 1 });
  assert.ok(living.along({ x: 0, y: 0 }, { x: 1, y: 0 }, 0.25).x < 0.25, 'eases in');
});

test('every object acts and changes in the world before its feature opens', () => {
  assert.equal(living.actionFor({ action: 'write' }), 'think');
  assert.equal(living.actionFor({ action: 'greet' }), 'wave');
  assert.equal(living.actionFor({}), 'happy');
  assert.equal(living.changeFor({ change: 'open' }), 'open');
  assert.equal(living.changeFor({ change: 'explode' }), 'pulse');
  const x0 = living.driftX(1, 0, 0.001), x1 = living.driftX(1, 100, 0.001);
  assert.notEqual(x0, x1, 'the far layer drifts');
});

test('every living room has both compositions, a spot for every object and real destinations', () => {
  const configs = rooms();
  assert.ok(Object.keys(configs).length >= 25);
  for (const [key, config] of Object.entries(configs)) {
    assert.ok(config.layouts.wide && config.layouts.tall, `${key} has wide and tall layouts`);
    for (const layout of ['wide', 'tall']) {
      const l = config.layouts[layout];
      assert.match(l.art, /^assets\//, `${key} ${layout} art path`);
      for (const object of config.objects) {
        const rect = l.rects[object.id];
        assert.ok(rect && rect.length === 4, `${key} ${layout} has a rect for ${object.id}`);
        assert.ok(rect.every(v => v >= 0 && v <= 1), `${key} ${layout} ${object.id} rect is inside the art`);
      }
    }
    for (const object of config.objects) {
      assert.ok(object.section || object.href, `${key}/${object.id} opens a section or a room`);
      if (object.href) assert.ok(fs.existsSync(path.join(web, object.href)), `${key}/${object.id} -> ${object.href} exists`);
    }
  }
});

test('the kit never touches feature logic or rewards', () => {
  const sources = ['living_room.js', 'living_page.js', 'social_rooms.js']
    .map(f => fs.readFileSync(path.join(web, 'assets/scenes/social_world', f), 'utf8')).join('\n');
  assert.doesNotMatch(sources, /firestore|httpsCallable|collection\(|addCoins|grantXp/);
  assert.match(sources, /prefers-reduced-motion/);
  assert.match(sources, /visibilitychange/);
});
