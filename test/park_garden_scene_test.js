'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const web = path.join(__dirname, '..', 'web_dashboard');
const read = f => fs.readFileSync(path.join(web, f), 'utf8');

test('the park map opens every arcade game from its ride', () => {
  const html = read('arcade.html');
  for (const f of ['scene_room.js', 'park_scene.js', 'arcade.js']) assert.ok(html.includes(`assets/${f}`), f);
  assert.ok(html.indexOf('assets/arcade.js') < html.indexOf('assets/park_scene.js'));
  const js = read('assets/park_scene.js');
  for (const game of ['stars', 'fishing', 'rhythm', 'memory']) assert.ok(js.includes(`play('${game}')`), game);
  assert.match(js, /\.arcade-cabinet\[data-game="\$\{id\}"\]/, 'rides press the real cabinet button');
  assert.doesNotMatch(js, /localStorage|firestore|ticket\s*[-+]=/, 'tickets stay with arcade.js');
  // cabinets stay reachable for screen readers
  assert.match(read('assets/park_scene.css'), /\.arcade-stage \{ position: absolute; width: 1px;/);
});

test('garden plants are buttons that open the Cloud-backed week dialog', () => {
  const html = read('garden.html');
  assert.ok(html.indexOf('assets/garden.js') < html.indexOf('assets/garden_scene.js'));
  const js = read('assets/garden_scene.js');
  assert.match(js, /source\.click\(\)/, 'a plant opens garden.js\'s own dialog');
  assert.match(js, /btn\.disabled = source\.disabled/);
  assert.match(js, /setAttribute\('aria-label', source\.getAttribute\('aria-label'\)/);
  assert.doesNotMatch(js, /firestore|collection\(/);
  for (const plant of ['flower', 'tree', 'moonflower', 'meadow']) assert.match(js, new RegExp(plant + ': [0-9]'));
  assert.ok(fs.existsSync(path.join(web, 'assets/scenes/garden/plants.webp')));
  assert.match(read('assets/garden_scene.css'), /prefers-reduced-motion: reduce/);
});
