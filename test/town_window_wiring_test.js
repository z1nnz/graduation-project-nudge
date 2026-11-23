const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const web = path.join(__dirname, '..', 'web_dashboard');
const read = name => fs.readFileSync(path.join(web, name), 'utf8');

test('the town has the window and loads its scripts after the route table', () => {
  const html = read('town.html');
  assert.match(html, /id="townWindow"[^>]*role="dialog"/);
  assert.match(html, /id="townWindowFrame"/);
  const at = name => html.indexOf(name);
  assert.ok(at('town_routes.js') < at('town_window_core.js'));
  assert.ok(at('town_window_core.js') < at('town_window.js'));
});

test('every page with a back-to-town link can close the town window', () => {
  for (const name of fs.readdirSync(web).filter(f => f.endsWith('.html'))) {
    const html = read(name);
    const linksTown = /data-town-return|href="town\.html/.test(html);
    if (!linksTown || name === 'town.html' || name === 'index.html' || name === 'login.html') continue;
    assert.match(html, /town_return\.js\?v=2/, name);
  }
});
