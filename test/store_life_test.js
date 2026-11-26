// Store 2.0 (J5): layered life on the store room without touching money.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const read = f => fs.readFileSync(path.join(__dirname, '..', f), 'utf8');

test('operations.html adds the life layer after the store room', () => {
  const html = read('web_dashboard/operations.html');
  const at = s => html.indexOf(s);
  assert.ok(at('assets/store_scene.js') < at('assets/store_scene_life.js'));
  assert.ok(at('assets/avatar_layers.js') < at('assets/store_scene_life.js'));
  assert.ok(at('scenes/stage/world_life.js') < at('assets/store_scene_life.js'));
});

test('the store only animates: no ledger calls, purchases stay in reward_shop.js', () => {
  const js = read('web_dashboard/assets/store_scene_life.js');
  assert.ok(!/httpsCallable|firestore\(|\.set\(|\.update\(/.test(js));
  for (const ev of ['nudge-shop-lift', 'nudge-shop-purchase']) assert.ok(js.includes(ev), ev);
  assert.ok(js.includes('prefers-reduced-motion'));
  const css = read('web_dashboard/assets/store_scene_life.css');
  assert.ok(css.includes('prefers-reduced-motion'));
  assert.ok(/steps\(/.test(css));
});

test('store art keeps a live sky behind its window in both layouts', () => {
  const js = read('web_dashboard/assets/store_scene.js');
  assert.ok(js.includes('store_wide_mid.webp') && js.includes('store_mid.webp'));
  for (const f of ['store/store_wide_mid.webp', 'store/store_mid.webp']) {
    assert.ok(fs.existsSync(path.join(__dirname, '../web_dashboard/assets/scenes', f)), f);
  }
});
