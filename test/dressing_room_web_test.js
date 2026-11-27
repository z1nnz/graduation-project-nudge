// Dressing room (J2) on profile.html: room config, script order, and that
// the look stays on the device while the name card keeps its own controls.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.join(__dirname, '..');
const read = f => fs.readFileSync(path.join(root, f), 'utf8');

test('the name card page is a dressing room with both layouts', () => {
  globalThis.NudgePageRooms = undefined;
  require('../web_dashboard/assets/page_rooms_home.js');
  const cfg = globalThis.NudgePageRooms.profile;
  assert.equal(cfg.title, '更衣室');
  const ids = cfg.objects.map(o => o.id);
  for (const id of ['mirror', 'rack', 'card', 'shelf']) assert.ok(ids.includes(id), id);
  for (const id of ids) assert.equal(cfg.wide.rects[id].length, 4, `wide rect for ${id}`);
  assert.ok(cfg.aspect < 1 && cfg.wide.aspect > 1, 'tall for phones, wide for desktop');
  assert.ok(fs.existsSync(path.join(root, 'web_dashboard', cfg.art)));
  assert.ok(fs.existsSync(path.join(root, 'web_dashboard', cfg.wide.art)));
});

test('profile.html loads the layers after the room, nothing removed', () => {
  const html = read('web_dashboard/profile.html');
  const at = s => html.indexOf(s);
  assert.ok(at('assets/page_room.js') < at('assets/scenes/dressing/dressing_room.js'));
  assert.ok(at('assets/avatar_layers.js') < at('assets/scenes/dressing/dressing_room.js'));
  assert.ok(at('scenes/stage/world_life.js') < at('assets/scenes/dressing/dressing_room.js'));
  for (const id of ['profileEditCardBtn', 'profileSaveCardBtn', 'profileMainName', 'profileGrowthTracks']) {
    assert.ok(html.includes(`id="${id}"`), id);
  }
});

test('the dressing room changes looks on the device only and honours reduced motion', () => {
  const js = read('web_dashboard/assets/scenes/dressing/dressing_room.js');
  assert.ok(js.includes('save: true'), 'saves the look locally');
  assert.ok(js.includes("player: 'layered'"), 'the dressing room walks the layered character');
  assert.ok(!/firestore|httpsCallable/.test(js), 'no Cloud writes');
  const css = read('web_dashboard/assets/scenes/dressing/dressing_room.css');
  assert.ok(css.includes('prefers-reduced-motion'));
  assert.ok(/steps\(/.test(css), 'pixel stepping, no soft tweens');
  for (const f of ['mirror.png', 'rack.png']) {
    assert.ok(fs.existsSync(path.join(root, 'web_dashboard/assets/scenes/dressing', f)));
    assert.ok(fs.readFileSync(path.join(root, 'web_dashboard/assets/scenes/dressing', f)).equals(fs.readFileSync(path.join(root, 'assets/scenes/dressing', f))));
  }
});
