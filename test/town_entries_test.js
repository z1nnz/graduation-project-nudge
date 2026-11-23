const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const routes = require('../web_dashboard/assets/town_routes.js');
const garden = require('../web_dashboard/assets/garden_core.js');

const web = path.resolve(__dirname, '..', 'web_dashboard');
const read = name => fs.readFileSync(path.join(web, name), 'utf8');
const hrefs = id => routes.destinationsFor(id).map(x => x.href);

test('#79 name/destination mismatches are fixed', () => {
  assert.ok(!hrefs('cabin').includes('personal.html'), 'cabin no longer opens personal analysis');
  assert.ok(hrefs('library').includes('personal.html'), 'personal analysis lives in the library');
  assert.deepEqual(hrefs('store'), ['operations.html'], 'the store opens the shop, not the profile card');
  assert.ok(hrefs('observatory').includes('planet.html'));
  assert.ok(!hrefs('observatory').includes('personal-focus.html'));
  assert.doesNotMatch(routes.BUILDINGS.observatory.desc, /Orbit|Station|裝置/);
  assert.ok(hrefs('garden').includes('garden.html'), 'unlocked garden has a real scene');
});

test('town geometry covers exactly the buildings in the route table', () => {
  const source = read('assets/town.js');
  const block = source.slice(source.indexOf('const GEOMETRY = {'), source.indexOf('};', source.indexOf('const GEOMETRY = {')));
  const ids = [...block.matchAll(/^\s{4}(\w+): \{/gm)].map(m => m[1]).sort();
  assert.deepEqual(ids, Object.keys(routes.BUILDINGS).sort());
  assert.doesNotMatch(source, /href: '[^']+\.html'/, 'destinations come from town_routes.js only');
});

test('town loads the route contract before the town script', () => {
  const html = read('town.html');
  const routesAt = html.indexOf('assets/town_routes.js');
  const townAt = html.indexOf('assets/town.js');
  assert.ok(routesAt > 0 && townAt > routesAt);
  for (const id of ['townPanel', 'townPanelList', 'townDirectoryToggle', 'townToolList']) {
    assert.match(html, new RegExp(`id="${id}"`));
  }
  assert.match(html, /role="dialog"[^>]*aria-modal="true"/);
});

test('every #82 page can return to the world', () => {
  for (const page of ['personal-focus.html', 'planet.html', 'operations.html', 'profile.html', 'dashboard.html', 'garden.html']) {
    const html = read(page);
    assert.match(html, /data-town-return/, page);
    const routesAt = html.indexOf('assets/town_routes.js');
    const returnAt = html.indexOf('assets/town_return.js');
    assert.ok(routesAt > 0 && returnAt > routesAt, `${page} loads town_return after town_routes`);
  }
  assert.match(read('assets/app.js'), /\["town", "夥伴小鎮", "town\.html"\]/, 'sidebar links back to the town');
});

test('garden is not public and re-checks the level gate itself', () => {
  const app = read('assets/app.js');
  const publicLine = app.split('\n').find(line => line.startsWith('const isPublicPage'));
  assert.doesNotMatch(publicLine, /garden/);
  assert.deepEqual(garden.access(9), {
    unlocked: false, level: 9, reason: '角色 Lv 10 才能進入星光花園，你目前是 Lv 9，還差 1 級。',
  });
  assert.equal(garden.access(10).unlocked, true);
  assert.equal(garden.access('abc').level, 1);
  assert.equal(garden.access(undefined).unlocked, false);
  assert.match(read('assets/garden.js'), /core\.access\(data\?\.avatarLevel\)/);
});

test('guests see a sign-in entry and planned scenes are never linked', () => {
  const guest = { signedIn: false, level: 1 };
  for (const dest of routes.DESTINATIONS.filter(x => x.audience === 'player' && x.building)) {
    const state = routes.entryState(dest, guest);
    if (dest.status !== 'available') assert.equal(state.kind, 'planned', dest.id);
    else if (dest.auth === 'login') assert.equal(state.kind, 'login', dest.id);
    else assert.equal(state.kind, 'open', dest.id);
  }
  const gardenDest = routes.DESTINATIONS.find(x => x.id === 'garden-scene');
  assert.equal(routes.entryState(gardenDest, { signedIn: true, level: 3 }).kind, 'locked');
  assert.equal(routes.entryState(gardenDest, { signedIn: true, level: 10 }).kind, 'open');
});
