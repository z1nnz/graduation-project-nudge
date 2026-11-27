// Web collection case (J10): same catalog and drop rule as the App's
// lib/models/collection_book.dart, and the page only reads.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const core = require('../web_dashboard/assets/scenes/collection/collection_core.js');

const root = path.join(__dirname, '..');

test('the catalog matches the App catalog, in order', () => {
  const dart = fs.readFileSync(path.join(root, 'lib/models/collection_book.dart'), 'utf8');
  const rows = [...dart.matchAll(/Keepsake\('([a-z]+)', '([^']+)', '[^']+'(, rare: true)?\)/g)].map(m => ({ id: m[1], name: m[2], rare: Boolean(m[3]) }));
  assert.equal(rows.length, 24);
  assert.deepEqual(core.CATALOG.map(k => ({ ...k })), rows);
  assert.ok(dart.includes(`commonMinutes = ${core.COMMON_MINUTES}`));
  assert.ok(dart.includes(`rareMinutes = ${core.RARE_MINUTES}`));
});

test('FNV-1a and drops follow the App rule', () => {
  assert.equal(core.fnv1a(''), 0x811c9dc5);
  assert.equal(core.fnv1a('a'), 0xe40c292c);
  const d = core.drops([{ date: '2026-11-20', focusMinutes: 30 }, { date: '2026-11-21', focusMinutes: 10 }, { date: '2026-11-22', focusMinutes: 130 }, { date: '2026-11-20', focusMinutes: 200 }]);
  assert.deepEqual(d.map(x => x.date), ['2026-11-22', '2026-11-20']);
  assert.equal(d[0].item.rare, true);
  assert.equal(d[1].item.rare, false);
});

test('the page reads only, honours reduced motion and ships its atlas', () => {
  const js = fs.readFileSync(path.join(root, 'web_dashboard/assets/scenes/collection/collection.js'), 'utf8');
  assert.ok(!/\.(set|update|add)\(\s*\{/.test(js), 'no Firestore writes');
  assert.ok(js.includes('prefers-reduced-motion'));
  const a = path.join(root, 'web_dashboard/assets/scenes/collection/keepsakes.png');
  assert.ok(fs.readFileSync(a).equals(fs.readFileSync(path.join(root, 'assets/scenes/collection/keepsakes.png'))));
  const html = fs.readFileSync(path.join(root, 'web_dashboard/cabin.html'), 'utf8');
  assert.ok(html.includes('id="collectionOpen"'), 'opens from the cabin');
  assert.ok(html.indexOf('collection_core.js') < html.indexOf('scenes/collection/collection.js'));
});
