const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const routes = require('../web_dashboard/assets/town_routes.js');

const webRoot = path.resolve(__dirname, '..', 'web_dashboard');
const file = href => href.split('#')[0].split('?')[0];

test('every Web page is classified in the town route table', () => {
  const pages = fs.readdirSync(webRoot).filter(name => name.endsWith('.html'));
  const known = new Set(routes.DESTINATIONS.map(x => file(x.href)));
  const missing = pages.filter(page => !known.has(page));
  assert.deepEqual(missing, [], 'add new pages to town_routes.js and docs/specs/web-town-routes.md');
});

test('available destinations point at pages that exist; planned ones are not reachable yet', () => {
  for (const dest of routes.DESTINATIONS) {
    assert.ok(!/^[a-z]+:|^\/\//i.test(dest.href), `${dest.id} must stay on this site`);
    const exists = fs.existsSync(path.join(webRoot, file(dest.href)));
    if (dest.status === 'available') assert.ok(exists, `${dest.id} -> ${dest.href} is missing`);
    else assert.equal(routes.entryState(dest, { signedIn: true, level: 99 }).kind, 'planned');
  }
});

test('ids are unique and every row uses known enums', () => {
  const ids = routes.DESTINATIONS.map(x => x.id);
  assert.equal(new Set(ids).size, ids.length);
  for (const dest of routes.DESTINATIONS) {
    assert.ok(['player', 'tool'].includes(dest.audience), dest.id);
    assert.ok(['public', 'login'].includes(dest.auth), dest.id);
    assert.ok(['cloud', 'mixed', 'demo', 'static'].includes(dest.source), dest.id);
    assert.ok(['#82', '#83', '#84', 'core'].includes(dest.owner), dest.id);
    if (dest.building) assert.ok(routes.isBuilding(dest.building), dest.id);
    if (dest.audience === 'tool') assert.equal(dest.building, null, `${dest.id}: tools stay out of the world`);
  }
});

test('every building has at least one destination once planned scenes land', () => {
  for (const id of Object.keys(routes.BUILDINGS)) {
    assert.ok(routes.destinationsFor(id, { includePlanned: true }).length > 0, id);
  }
});

test('the main player features named in #82 have a world entry', () => {
  const pages = new Set(routes.DESTINATIONS.filter(x => x.audience === 'player' && x.building).map(x => file(x.href)));
  for (const page of ['notifications.html', 'privacy.html', 'friend.html', 'guardian.html', 'groups.html',
    'personal.html', 'operations.html', 'planet.html', 'personal-focus.html', 'rooms.html']) {
    assert.ok(pages.has(page), page);
  }
});

test('arrival parameter only accepts known building ids', () => {
  assert.equal(routes.arrivalBuilding('?at=tower'), 'tower');
  assert.equal(routes.arrivalBuilding('?at=https://evil.example'), null);
  assert.equal(routes.arrivalBuilding('?at=__proto__'), null);
  assert.equal(routes.arrivalBuilding(''), null);
  assert.equal(routes.townHref('store'), 'town.html?at=store');
  assert.equal(routes.townHref('nope'), 'town.html');
});

test('return links go back to the owning building, tools to the square', () => {
  assert.equal(routes.returnHrefForPage('/web_dashboard/rooms.html'), 'town.html?at=tower');
  assert.equal(routes.returnHrefForPage('operations.html?tab=x'), 'town.html?at=store');
  assert.equal(routes.returnHrefForPage('research.html'), 'town.html');
  assert.equal(routes.returnHrefForPage('unknown.html'), 'town.html');
});

test('entry state explains login and level gates without granting access', () => {
  const shop = routes.DESTINATIONS.find(x => x.id === 'shop');
  assert.equal(routes.entryState(shop, { signedIn: false }).kind, 'login');
  assert.deepEqual(routes.entryState(shop, { signedIn: true }), { kind: 'open', href: 'operations.html', reason: '' });
  const family = routes.DESTINATIONS.find(x => x.id === 'guardian');
  const open = routes.entryState(family, { signedIn: true });
  assert.equal(open.kind, 'open');
  assert.match(open.reason, /連結頁/);
  const landing = routes.DESTINATIONS.find(x => x.id === 'quest-board');
  assert.equal(routes.entryState(landing, { signedIn: false }).kind, 'open');
});
