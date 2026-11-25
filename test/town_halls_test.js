'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const routes = require('../web_dashboard/assets/town_routes.js');
const halls = require('../web_dashboard/assets/town_halls.js');

const web = path.join(__dirname, '..', 'web_dashboard');

test('every building opens on its own interior art', () => {
  for (const id of Object.keys(routes.BUILDINGS)) {
    const hall = halls.hallFor(id);
    assert.ok(hall, `${id} has an interior`);
    assert.ok(fs.existsSync(path.join(web, hall.art)), `${id}: ${hall.art}`);
    assert.ok(hall.aspect > 0.3 && hall.aspect < 3, id);
    assert.ok(hall.line && hall.npc, `${id} has someone to talk to`);
  }
});

test('spots only name real destinations of that building and stay on the art', () => {
  for (const [id, hall] of Object.entries(halls.HALLS)) {
    const ids = new Set(routes.destinationsFor(id, { includePlanned: true }).map(d => d.id));
    for (const [dest, [x, y, w, h]] of Object.entries(hall.spots)) {
      assert.ok(ids.has(dest), `${id}: ${dest} is a destination of this building`);
      assert.ok(x >= 0 && y >= 0 && w > 0 && h > 0 && x + w <= 1.001 && y + h <= 1.001, `${id}: ${dest} fits`);
    }
  }
});

test('the town keeps its panel entries and only decorates them when the view is loaded', () => {
  const town = fs.readFileSync(path.join(web, 'assets/town.js'), 'utf8');
  assert.match(town, /li\.dataset\.dest = dest\.id;/);
  assert.match(town, /root\.NudgeTownHallView\?\.decorate\(b, els\('townPanel'\), list, locked\);/);
  const html = fs.readFileSync(path.join(web, 'town.html'), 'utf8');
  const order = ['sprite_player.js', 'npc_dialog.js', 'town_halls.js', 'town_hall_view.js', 'town.js?v=10']
    .map(f => html.indexOf(`assets/${f}`));
  assert.ok(order.every(i => i > 0), 'scripts are loaded');
  assert.deepEqual([...order].sort((a, b) => a - b), order);
  assert.match(html, /assets\/town_halls\.css/);
  const view = fs.readFileSync(path.join(web, 'assets/town_hall_view.js'), 'utf8');
  assert.doesNotMatch(view, /\.href\s*=|location/, 'the view never rewrites where an entry goes');
  const css = fs.readFileSync(path.join(web, 'assets/town_halls.css'), 'utf8');
  assert.match(css, /prefers-reduced-motion: reduce/);
  assert.match(css, /min-width: 44px;\s*min-height: 44px;/);
});
