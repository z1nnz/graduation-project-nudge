const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const routes = require('../web_dashboard/assets/town_routes.js');

const web = path.join(__dirname, '..', 'web_dashboard');
const html = fs.readFileSync(path.join(web, 'arcade.html'), 'utf8');
const css = fs.readFileSync(path.join(web, 'assets', 'arcade.css'), 'utf8');
const js = ['arcade.js', 'arcade_games.js'].map(f => fs.readFileSync(path.join(web, 'assets', f), 'utf8')).join('\n');

test('arcade page uses the shared world page skeleton', () => {
  assert.match(html, /<body class="w-page"/);
  assert.match(html, /<header class="w-hud">\s*<a data-town-return href="town.html">← 回小鎮<\/a>\s*<h1>遊樂園<\/h1>/);
  assert.match(html, /<main class="w-main/);
  assert.match(html, /assets\/town_routes\.js\?v=\d+/);
  assert.match(html, /assets\/town_return\.js\?v=\d+/);
  assert.match(html, /assets\/world_ui\.css/);
});

test('the park opens the arcade hall from the route table', () => {
  const park = routes.destinationsFor('park');
  assert.deepEqual(park.map(d => d.href), ['arcade.html']);
  assert.equal(routes.returnHrefForPage('/arcade.html'), 'town.html?at=park');
});

test('every dialog is labelled and modal', () => {
  const dialogs = html.match(/<div id="[^"]+" class="arcade-dialog"[^>]*>/g) || [];
  assert.equal(dialogs.length, 3);
  for (const d of dialogs) {
    assert.match(d, /role="dialog"/);
    assert.match(d, /aria-modal="true"/);
    assert.match(d, /aria-labelledby="/);
  }
});

test('arcade styles use only world tokens and support reduced motion', () => {
  assert.doesNotMatch(css, /#[0-9a-f]{3,8}\b/i, 'no hard-coded hex colours');
  assert.doesNotMatch(css, /rgba?\(/i, 'no hard-coded rgb colours');
  assert.match(css, /@media \(prefers-reduced-motion: reduce\)/);
  assert.match(css, /image-rendering: pixelated/);
  assert.doesNotMatch(js, /['"]#[0-9a-f]{3,8}['"]/i, 'canvas colours come from tokens');
});

test('the arcade never writes to the Cloud or calls a reward function', () => {
  assert.doesNotMatch(js, /\.(set|add|update|delete)\(\s*\{|httpsCallable|functions\(\)/);
  assert.doesNotMatch(html + js, /https?:\/\//, 'no external URLs');
});
