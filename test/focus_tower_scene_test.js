const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const scene = require('../web_dashboard/assets/scenes/social_world/focus_tower_scene.js');

test('the wall clock follows the shared focus round, or the town time when idle', () => {
  const start = scene.handAngles({ remaining: '25:00' });
  const half = scene.handAngles({ remaining: '12:30' });
  const end = scene.handAngles({ remaining: '00:00' });
  assert.equal(start.round, true);
  assert.equal(start.minute, 0);
  assert.equal(half.minute, 180);
  assert.equal(end.minute, 360);
  const wall = scene.handAngles({ hour: 15, minute: 30, second: 0 });
  assert.equal(wall.round, false);
  assert.equal(wall.hour, 105);
  assert.equal(wall.minute, 180);
});

test('the monster reacts only to real shared focus minutes', () => {
  assert.equal(scene.monsterState(null, 50, 100), 'idle');
  assert.equal(scene.monsterState(50, 40, 100), 'hit');
  assert.equal(scene.monsterState(40, 40, 100), 'idle');
  assert.equal(scene.monsterState(10, 0, 100), 'down');
  assert.equal(scene.monsterState(null, 0, 0), 'idle');
});

test('rooms.html loads the study hall scene after the living room and writes nothing', () => {
  const html = fs.readFileSync('web_dashboard/rooms.html', 'utf8');
  assert.match(html, /data-living-room="rooms"/);
  assert.ok(html.indexOf('living_page.js') < html.indexOf('focus_tower_scene.js'));
  const source = fs.readFileSync('web_dashboard/assets/scenes/social_world/focus_tower_scene.js', 'utf8');
  assert.doesNotMatch(source, /firestore|httpsCallable|\.set\(|\.update\(/);
  assert.match(source, /prefers-reduced-motion/);
});
