'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const routes = require('../web_dashboard/assets/town_routes.js');
const halls = require('../web_dashboard/assets/town_halls.js');

const web = path.join(__dirname, '..', 'web_dashboard');

test('every building opens on its own interior art, with someone to talk to', () => {
  for (const id of Object.keys(routes.BUILDINGS)) {
    const hall = halls.hallFor(id);
    assert.ok(hall, `${id} has an interior`);
    assert.ok(hall.npc && hall.line, `${id} has an NPC line`);
    const layouts = halls.layoutsFor(id);
    assert.ok(layouts.wide || layouts.tall, id);
    for (const [key, l] of Object.entries(layouts)) {
      assert.ok(fs.existsSync(path.join(web, l.art)), `${id}.${key}: ${l.art}`);
      assert.ok(l.aspect > 0.3 && l.aspect < 3, `${id}.${key}`);
    }
  }
});

test('desktop art is landscape and phone art is portrait', () => {
  for (const id of Object.keys(halls.HALLS)) {
    const layouts = halls.layoutsFor(id);
    if (layouts.wide) assert.ok(layouts.wide.aspect > 1, `${id} wide`);
    if (layouts.tall) assert.ok(layouts.tall.aspect < 1, `${id} tall`);
  }
});

test('spots only name real destinations of that building and stay on the art', () => {
  for (const id of Object.keys(halls.HALLS)) {
    const ids = new Set(routes.destinationsFor(id, { includePlanned: true }).map(d => d.id));
    for (const [key, l] of Object.entries(halls.layoutsFor(id))) {
      for (const [dest, [x, y, w, h]] of Object.entries(l.rects)) {
        assert.ok(ids.has(dest), `${id}.${key}: ${dest} is a destination of this building`);
        assert.ok(x >= 0 && y >= 0 && w > 0 && h > 0 && x + w <= 1.001 && y + h <= 1.001, `${id}.${key}: ${dest} fits`);
      }
      for (const w of l.walkers) for (const [px, py] of w.path) assert.ok(px >= 0 && px <= 1 && py >= 0 && py <= 1, `${id}.${key} walker`);
    }
  }
});

test('the town keeps its panel entries; the room only presses them', () => {
  const town = fs.readFileSync(path.join(web, 'assets/town.js'), 'utf8');
  assert.ok(town.includes('li.dataset.dest = dest.id;'));
  assert.ok(town.includes("root.NudgeTownHallView?.decorate(b, els('townPanel'), list, locked);"));
  const html = fs.readFileSync(path.join(web, 'town.html'), 'utf8');
  const order = ['sprite_player.js', 'npc_dialog.js', 'scene_room.js', 'town_halls.js', 'town_hall_view.js', 'town.js?v=']
    .map(f => html.indexOf(`assets/${f}`));
  assert.ok(order.every(i => i > 0), 'scripts are loaded');
  assert.deepEqual([...order].sort((a, b) => a - b), order);
  const view = fs.readFileSync(path.join(web, 'assets/town_hall_view.js'), 'utf8');
  assert.ok(view.includes('e.control.click();'), 'objects press the town entry itself');
  assert.doesNotMatch(view, /\.href\s*=|location/, 'the view never rewrites where an entry goes');
});
