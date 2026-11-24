// The Web cabin companion follows the App's CabinCompanionBrain
// (lib/models/cabin_companion_brain.dart): same floor, desk, rug and wander
// spots, desk focus wins over the night, busy companions ignore taps.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');

const pal = require('../web_dashboard/assets/cabin_companion_core.js');

const run = (brain, seconds, step = 1 / 60) => { for (let t = 0; t < seconds; t += step) brain.tick(step); };

test('the spots match the App brain', () => {
  const dart = fs.readFileSync('lib/models/cabin_companion_brain.dart', 'utf8');
  assert.match(dart, /Rect\.fromLTRB\(0\.12, 0\.6, 0\.88, 0\.86\)/);
  assert.deepEqual(pal.FLOOR, { left: 0.12, top: 0.6, right: 0.88, bottom: 0.86 });
  assert.match(dart, /desk = Offset\(0\.62, 0\.61\)/);
  assert.deepEqual(pal.DESK, { x: 0.62, y: 0.61 });
  assert.match(dart, /rug = Offset\(0\.5, 0\.72\)/);
  assert.deepEqual(pal.RUG, { x: 0.5, y: 0.72 });
  const spots = [...dart.matchAll(/Offset\(([\d.]+), ([\d.]+)\),/g)].map(m => ({ x: Number(m[1]), y: Number(m[2]) }));
  assert.deepEqual(pal.WANDER_SPOTS, spots);
  assert.match(dart, /speed = 0\.18/);
  assert.equal(pal.SPEED, 0.18);
});

test('a desk focus wins over the night; night means rest', () => {
  assert.equal(pal.wantedActivity({ focusing: true, hour: 23 }), 'focus');
  assert.equal(pal.wantedActivity({ hour: 22 }), 'rest');
  assert.equal(pal.wantedActivity({ hour: 5 }), 'rest');
  assert.equal(pal.wantedActivity({ hour: 6 }), 'wander');
  assert.equal(pal.wantedActivity({ hour: 21 }), 'wander');
});

test('focusing walks to the desk and reads; resting walks to the rug and sleeps', () => {
  const brain = pal.createBrain({ random: () => 0.5, start: { x: 0.3, y: 0.78 } });
  brain.setActivity('focus');
  assert.equal(brain.pose, 'walk');
  run(brain, 8);
  assert.deepEqual(brain.position, pal.DESK);
  assert.equal(brain.pose, 'read');
  assert.equal(brain.walkTo({ x: 0.2, y: 0.7 }), false, 'busy companions stay put');
  brain.setActivity('rest');
  run(brain, 8);
  assert.deepEqual(brain.position, pal.RUG);
  assert.equal(brain.pose, 'sleep');
});

test('wandering picks a spot away from where it stands and eases to a stop', () => {
  let i = 0;
  const seq = [0.1, 0.9, 0.3];
  const brain = pal.createBrain({ random: () => seq[i++ % seq.length] });
  assert.equal(brain.activity, 'wander');
  run(brain, 2.1);
  assert.equal(brain.walking, true, 'starts walking after the first rest');
  let max = 0;
  let last = brain.position;
  for (let k = 0; k < 600 && brain.walking; k++) {
    brain.tick(1 / 60);
    const p = brain.position;
    max = Math.max(max, Math.hypot(p.x - last.x, p.y - last.y) * 60);
    last = p;
  }
  assert.equal(brain.walking, false);
  assert.ok(max <= pal.SPEED + 1e-9, 'never faster than the App speed');
  assert.ok(pal.WANDER_SPOTS.some(s => Math.hypot(s.x - last.x, s.y - last.y) < 1e-9), 'stops on a wander spot');
});

test('tap targets are clamped to the floor; a poke cheers for 1.2 s; big frames are clamped', () => {
  const brain = pal.createBrain({ random: () => 0 });
  assert.equal(brain.walkTo({ x: 2, y: -1 }), true);
  run(brain, 5);
  assert.deepEqual(brain.position, { x: 0.88, y: 0.6 });
  brain.poke();
  assert.equal(brain.pose, 'cheer');
  run(brain, pal.CHEER_SECONDS + 0.05);
  assert.notEqual(brain.pose, 'cheer');
  const far = pal.createBrain({ start: { x: 0.12, y: 0.86 } });
  far.walkTo({ x: 0.88, y: 0.6 });
  far.tick(30); // the tab was hidden for 30 s
  const p = far.position;
  assert.ok(Math.hypot(p.x - 0.12, p.y - 0.86) < 0.02, 'one long frame does not teleport');
  far.settle();
  assert.deepEqual(far.position, { x: 0.88, y: 0.6 }, 'reduced motion jumps straight to the target');
});

test('sprites use the App pose art when the character has it, otherwise the front sprite', () => {
  assert.deepEqual(pal.spriteFor(3, 'read'), { src: 'assets/avatar/poses/pose_3_read.png', kind: 'read' });
  assert.deepEqual(pal.spriteFor(0, 'walk', 0), { src: 'assets/avatar/poses/walk_0_a.png', kind: 'walk' });
  assert.equal(pal.spriteFor(0, 'walk', 0.3).src, 'assets/avatar/poses/walk_0_p.png');
  assert.equal(pal.spriteFor(0, 'walk', 0.6).src, 'assets/avatar/poses/walk_0_b.png');
  assert.equal(pal.spriteFor(4, 'sleep').src, 'assets/avatar/characters/character_4.png');
  assert.equal(pal.spriteFor(-1, 'idle').src, 'assets/avatar/characters/character_0.png');
  for (const f of [0, 3, 6, 9, 12, 15]) {
    for (const p of ['read', 'sleep', 'cheer']) {
      const web = `web_dashboard/${pal.spriteFor(f, p).src}`;
      assert.ok(fs.existsSync(web), web);
      assert.deepEqual(fs.readFileSync(web), fs.readFileSync(web.replace('web_dashboard/', '')), 'copied from the App');
    }
  }
});

test('lines fit the activity, and only a running desk timer counts as focusing', () => {
  assert.equal(pal.lineFor('rest', () => 0), '呼……晚安');
  assert.match(pal.lineFor('focus', () => 0.99), /書桌|專注/);
  assert.equal(typeof pal.lineFor('unknown', () => 0), 'string');
  assert.equal(pal.deskFocusing(JSON.stringify({ sessionId: 'web_focus_1_a', status: 'active' })), true);
  assert.equal(pal.deskFocusing(JSON.stringify({ sessionId: 'web_focus_1_a', status: 'paused' })), false);
  assert.equal(pal.deskFocusing('not json'), false);
  assert.equal(pal.deskFocusing(null), false);
});
