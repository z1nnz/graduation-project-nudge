const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const images = require('../web_dashboard/assets/town_image.js');
const routes = require('../web_dashboard/assets/town_routes.js');

test('WebP art falls back to the original image and only then enters static mode', () => {
  const listeners = new Map();
  const image = { src: '',
    addEventListener(type, callback) { listeners.set(type, callback); },
    removeEventListener(type, callback) { if (listeners.get(type) === callback) listeners.delete(type); } };
  let failed = 0;
  images.load(image, 'assets/town/town_map.jpg', () => failed++);
  assert.equal(image.src, 'assets/town/town_map.webp');
  listeners.get('error')();
  assert.equal(image.src, 'assets/town/town_map.jpg');
  assert.equal(failed, 0);
  listeners.get('error')();
  assert.equal(failed, 1);
});

test('initial town image transfer stays below three megabytes', () => {
  const root = path.join(__dirname, '../web_dashboard');
  const list = ['assets/town/town_map.webp', 'assets/town/guide.webp',
    ...[0, 3, 6].map(n => `assets/avatar/characters/character_${n}.webp`),
    ...['a', 'p', 'b'].map(n => `assets/avatar/poses/walk_0_${n}.webp`)];
  const bytes = list.reduce((sum, file) => sum + fs.statSync(path.join(root, file)).size, 0);
  assert.ok(bytes <= 3_000_000, `first-load art ${bytes} bytes`);
});

test('every Codex-owned player route is available', () => {
  const owned = routes.DESTINATIONS.filter(r => r.owner === 'core' && r.audience === 'player');
  assert.ok(owned.length > 0);
  assert.ok(owned.every(r => r.status === 'available'));
});
