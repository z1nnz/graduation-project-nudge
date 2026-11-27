// Living-scene core (world_life_core.js): time of day, sky, spots, facing,
// emotes and the companion's day used by the cabin.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const core = require('../web_dashboard/assets/scenes/stage/world_life_core.js');

test('phases and daylight follow the clock', () => {
  assert.equal(core.phaseAt(2), 'night');
  assert.equal(core.phaseAt(6), 'dawn');
  assert.equal(core.phaseAt(12), 'day');
  assert.equal(core.phaseAt(18), 'dusk');
  assert.equal(core.phaseAt(22), 'night');
  assert.equal(core.daylight(0), 0);
  assert.equal(core.daylight(12), 1);
  assert.ok(core.daylight(6) > 0 && core.daylight(6) < 1);
  for (const p of Object.keys(core.SKY)) assert.equal(core.SKY[p].length, 3);
  assert.equal(core.bodyAt(12).kind, 'sun');
  assert.equal(core.bodyAt(23).kind, 'moon');
});

test('the companion has a whole day', () => {
  assert.equal(core.routineAt(3).act, 'sleep');
  assert.equal(core.routineAt(7).act, 'stretch');
  assert.equal(core.routineAt(9).act, 'read');
  assert.equal(core.routineAt(12.5).act, 'snack');
  assert.equal(core.routineAt(18.5).act, 'look');
  assert.equal(core.routineAt(23.5).act, 'sleep');
});

test('the player stands below an object or on its spot, and faces the walk', () => {
  const layout = { rects: { desk: [0.4, 0.4, 0.2, 0.1] }, spots: { door: [0.1, 0.8] }, floor: [0.6, 0.95] };
  assert.deepEqual(core.spotFor(layout, 'door'), [0.1, 0.8]);
  const s = core.spotFor(layout, 'desk');
  assert.ok(Math.abs(s[0] - 0.5) < 1e-9);
  assert.ok(s[1] >= 0.6 && s[1] <= 0.95);
  assert.equal(core.spotFor(layout, 'nope'), null);
  assert.equal(core.direction([0.5, 0.5], [0.9, 0.55]), 'right');
  assert.equal(core.direction([0.5, 0.5], [0.45, 0.1]), 'up');
  assert.ok(core.walkTime([0, 0], [0.3, 0], 0.3) === 1000);
});

test('emotes are 9x9 pixel grids and lines pick a mood', () => {
  for (const [k, g] of Object.entries(core.EMOTES)) {
    assert.equal(g.length, 9, k);
    for (const row of g) assert.equal(row.length, 9, k);
    assert.ok(core.EMOTE_COLORS[k], k);
  }
  assert.equal(core.moodOf('要帶我回家嗎？'), '?');
  assert.equal(core.moodOf('太好了！'), '!');
  assert.equal(core.moodOf('謝謝你'), 'heart');
});

test('the living layer pauses for hidden tabs, honours reduced motion and uses rAF', () => {
  for (const f of ['scenes/stage/world_life.js', 'cabin_life.js']) {
    const file = path.join(__dirname, '../web_dashboard/assets', f);
    if (!fs.existsSync(file)) continue; // cabin_life.js arrives with the cabin slice
    const src = fs.readFileSync(file, 'utf8');
    assert.ok(src.includes('requestAnimationFrame'), f);
    assert.ok(src.includes('prefers-reduced-motion'), f);
    assert.ok(/visibilitychange/.test(src), f);
    assert.ok(!/setInterval\(/.test(src), f);
  }
});

test('keyed scene art ships to Web and App under 300 KB', () => {
  const spec = JSON.parse(fs.readFileSync(path.join(__dirname, '../tool/world_art/sky_spec.json'), 'utf8'));
  for (const j of spec.jobs) {
    const w = path.join(__dirname, '../web_dashboard/assets', j.out);
    const a = path.join(__dirname, '../assets', j.out);
    assert.ok(fs.readFileSync(w).equals(fs.readFileSync(a)), j.out);
    assert.ok(fs.statSync(w).size < 300 * 1024, j.out);
  }
});
