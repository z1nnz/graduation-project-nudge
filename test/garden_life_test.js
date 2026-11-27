// Starlight garden 2.0 (J7): seasons, critters, growth and watering are
// animation only, run on rAF, and stop for reduced motion.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const read = f => fs.readFileSync(path.join(__dirname, '..', f), 'utf8');

test('four seasons, each with its own falling motes', () => {
  const js = read('web_dashboard/assets/garden_scene_life.js');
  for (const [s, fall] of [['spring', 'petals'], ['summer', 'fireflies'], ['autumn', 'leaves'], ['winter', 'snow']]) {
    assert.match(js, new RegExp(`${s}: \\{ fall: '${fall}'`));
  }
  const css = read('web_dashboard/assets/garden_scene_life.css');
  for (const s of ['spring', 'summer', 'autumn', 'winter']) assert.ok(css.includes(`.gl-season--${s}`), s);
});

test('watering changes no records and motion stops for reduced motion', () => {
  const js = read('web_dashboard/assets/garden_scene_life.js');
  assert.ok(!/firestore|httpsCallable/.test(js));
  assert.ok(js.includes('requestAnimationFrame') && !/setInterval\(/.test(js));
  assert.ok(js.includes('prefers-reduced-motion'));
  assert.ok(read('web_dashboard/assets/garden_scene_life.css').includes('prefers-reduced-motion'));
  const html = read('web_dashboard/garden.html');
  assert.ok(html.indexOf('garden_scene.js') < html.indexOf('garden_scene_life.js'));
  assert.ok(read('web_dashboard/assets/garden_scene.js').includes('garden_wide_mid.webp'));
});
