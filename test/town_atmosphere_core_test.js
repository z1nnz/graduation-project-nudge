const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const core = require('../web_dashboard/assets/town_atmosphere_core.js');

test('Taipei clock selects four phases with twenty minute blending', () => {
  const taipei = (h, m) => new Date(`2026-05-10T${h}:${m}:00+08:00`);
  assert.deepEqual(core.phaseAt(taipei('04', '59')), { name: 'night', from: 'dusk', blend: 1 });
  assert.deepEqual(core.phaseAt(taipei('05', '00')), { name: 'dawn', from: 'night', blend: 0 });
  assert.deepEqual(core.phaseAt(taipei('05', '10')), { name: 'dawn', from: 'night', blend: .5 });
  assert.equal(core.phaseAt(taipei('07', '20')).name, 'day');
  assert.deepEqual(core.phaseAt(taipei('17', '10')), { name: 'dusk', from: 'day', blend: .5 });
  assert.equal(core.phaseAt(taipei('19', '20')).name, 'night');
});

test('weather uses Taipei calendar day and stays deterministic across time zones', () => {
  const a = new Date('2026-03-31T16:30:00Z'); // April 1 in Taipei
  const b = new Date('2026-04-01T15:59:00Z');
  assert.deepEqual(core.weatherAt(a), core.weatherAt(b));
  assert.equal(core.weatherAt(a).key, '2026-04-01');
  assert.equal(core.weatherAt(a).season, 'spring');
  assert.equal(core.weatherAt(new Date('2026-07-01T04:00:00Z')).season, 'summer');
  assert.equal(core.weatherAt(new Date('2026-10-01T04:00:00Z')).season, 'autumn');
  assert.equal(core.weatherAt(new Date('2026-12-01T04:00:00Z')).season, 'winter');
  assert.ok(['rain', 'petal'].includes(core.weatherAt(a).kind));
});

test('particle count is capped at 60 on phone, 120 on larger screens', () => {
  assert.equal(core.particleLimit(0, 900), 0);
  assert.ok(core.particleLimit(375, 812) <= 60);
  assert.equal(core.particleLimit(599, 2000), 60);
  assert.equal(core.particleLimit(1200, 1200), 120);
});

test('three townsfolk follow bounded paths and each has eight lines', () => {
  assert.equal(core.NPCS.length, 3);
  for (const npc of core.NPCS) {
    assert.equal(Object.values(npc.lines).flat().length, 8);
    for (const t of [0, 4, 9, 25, 100]) {
      const position = core.npcPosition(npc, t);
      assert.ok(position.x >= 0 && position.x <= 1);
      assert.ok(position.y >= 0 && position.y <= 1);
    }
    assert.ok(npc.lines.dawn.includes(core.npcLine(npc, 'dawn', '2026-05-10')));
  }
});

test('town loads atmosphere rules before renderer and main loop', () => {
  const html = fs.readFileSync(path.join(__dirname, '../web_dashboard/town.html'), 'utf8');
  assert.ok(html.indexOf('town_atmosphere_core.js') < html.indexOf('town_atmosphere.js'));
  assert.ok(html.indexOf('town_atmosphere.js') < html.indexOf('town.js'));
});
