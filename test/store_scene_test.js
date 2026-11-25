'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const web = path.join(__dirname, '..', 'web_dashboard');
const read = file => fs.readFileSync(path.join(web, file), 'utf8');

test('the store opens on a room, not a card grid', () => {
  const html = read('operations.html');
  assert.match(html, /assets\/scene_room\.js\?v=\d+/);
  assert.match(html, /assets\/store_scene\.js\?v=\d+/);
  assert.doesNotMatch(html, /class="hero split"|insight-strip/, 'old hero and card strip are gone');
  // The real shop lives behind the shelves and stays hidden until opened.
  assert.match(html, /id="storeShelf" data-room-hidden="1" hidden/);
  assert.match(html, /id="storeLedger" data-room-hidden="1" hidden/);
  const order = ['reward_shop_core.js', 'reward_shop.js', 'app.js', 'sprite_player.js', 'npc_dialog.js', 'scene_room.js', 'store_scene.js']
    .map(f => html.indexOf(`assets/${f}`));
  assert.deepEqual([...order].sort((a, b) => a - b), order);
  assert.ok(fs.statSync(path.join(web, 'assets/scenes/store/store.webp')).size <= 300_000);
});

test('each shelf opens its own shop tabs and Chestnut talks', () => {
  const js = read('assets/store_scene.js');
  for (const [id, tabs] of [['clothes', "['permanent']"], ['furniture', "['decor']"], ['cabinet', "['limited', 'event_character']"]]) {
    assert.match(js, new RegExp(`id: '${id}'[\\s\\S]*?openShelf\\(${tabs.replace(/[[\]]/g, '\\$&')}`), id);
  }
  assert.match(js, /npc: 'chestnut'/);
  assert.match(js, /nudge-shop-short[\s\S]*還差 \$\{missing\} 枚金幣/);
  assert.match(js, /quests\.html/, 'short of coins points to the commission hall');
});

test('the scene only reacts to Cloud results; it never moves coins itself', () => {
  const scene = read('assets/store_scene.js') + read('assets/scene_room.js');
  assert.doesNotMatch(scene, /firestore\(|httpsCallable|disciplineCoins/);
  const shop = read('assets/reward_shop.js');
  assert.match(shop, /dispatchEvent\(new root\.CustomEvent\('nudge-shop-purchase'/);
  // The purchase event fires only after Cloud's answer was validated.
  assert.ok(shop.indexOf('validPurchaseResult') < shop.indexOf("'nudge-shop-purchase'"));
  // Being short of coins never calls buy().
  assert.match(shop, /if \(look\.reason === 'balance'\) \{[\s\S]*?return;\s*\}/);
});

test('scene rooms respect reduced motion and hidden tabs', () => {
  const room = read('assets/scene_room.js');
  assert.match(room, /prefers-reduced-motion: reduce/);
  assert.match(room, /function running\(\) \{ return !media\.matches && !doc\.hidden && visible && !dialog\.open; \}/);
  assert.match(room, /if \(media\.matches\) return;/, 'bursts are skipped under reduced motion');
  assert.match(room, /'aria-label': o\.label/);
  const css = read('assets/scene_room.css');
  assert.match(css, /@media \(prefers-reduced-motion: reduce\)/);
  assert.match(css, /min-width: 44px;\s*min-height: 44px;/);
});
