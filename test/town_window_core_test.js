const test = require('node:test');
const assert = require('node:assert/strict');
const win = require('../web_dashboard/assets/town_window_core.js');

const BASE = 'https://nudge.example/web/town.html';

test('player pages on the same site open inside the town window', () => {
  assert.equal(win.windowPath('rooms.html', BASE), 'rooms.html');
  assert.equal(win.windowPath('rooms.html?room=r1#chat', BASE), 'rooms.html?room=r1');
  assert.equal(win.windowPath('https://nudge.example/web/personal.html', BASE), 'personal.html');
});

test('the town itself, sign-in, the landing page and other sites navigate normally', () => {
  for (const href of ['town.html', 'town.html#park', 'login.html', 'index.html',
    'https://elsewhere.example/rooms.html', 'assets/app.js', '#plaza', 'mailto:a@b.c',
    'javascript:alert(1)', '../other/rooms.html']) {
    assert.equal(win.windowPath(href, BASE), null, href);
  }
});

test('the open page lives in the URL hash so refresh and back work', () => {
  const hash = win.hashFor('rooms.html?room=r1');
  assert.equal(win.pathFromHash(hash), 'rooms.html?room=r1');
  assert.equal(win.pathFromHash(''), null);
  assert.equal(win.pathFromHash('#park'), null);
  assert.equal(win.pathFromHash('#open=' + encodeURIComponent('https://evil.example/x.html')), null);
  assert.equal(win.pathFromHash('#open=' + encodeURIComponent('town.html')), null);
});

test('pages load in embed mode', () => {
  assert.equal(win.embedUrl('rooms.html'), 'rooms.html?embed=1');
  assert.equal(win.embedUrl('rooms.html?room=r1'), 'rooms.html?room=r1&embed=1');
});

test('a page knows it is inside the town window', () => {
  const town = { document: { body: { dataset: { page: 'town' } } } };
  const page = { parent: town };
  assert.equal(win.isTownEmbed(page), true);
  const alone = {}; alone.parent = alone;
  assert.equal(win.isTownEmbed(alone), false);
  const foreign = { get parent() { return { get document() { throw new Error('cross-origin'); } }; } };
  assert.equal(win.isTownEmbed(foreign), false);
});
