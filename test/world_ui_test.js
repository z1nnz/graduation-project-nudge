const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const web = path.join(__dirname, '..', 'web_dashboard');
const css = fs.readFileSync(path.join(web, 'assets', 'world_ui.css'), 'utf8');

test('the world UI ships the pixel font and the shared dusk tokens', () => {
  assert.ok(fs.statSync(path.join(web, 'assets', 'fonts', 'Cubic11.woff2')).size > 100000);
  assert.ok(fs.existsSync(path.join(web, 'assets', 'fonts', 'Cubic11-LICENSE.txt')));
  for (const token of ['--w-gold', '--w-parchment', '--w-wood', '--w-frame', '--w-night', '--w-pixel']) {
    assert.match(css, new RegExp(`${token}:`), token);
  }
});

test('the components the work packages rely on exist', () => {
  for (const cls of ['.w-page', '.w-hud', '.w-panel', '.w-parchment', '.w-btn', '.is-gold', '.w-chip',
    '.w-tabs', '.w-input', '.w-toast', '.w-empty']) {
    assert.ok(css.includes(cls), cls);
  }
  assert.match(css, /prefers-reduced-motion/);
});
