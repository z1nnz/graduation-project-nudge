const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const festival = require('../web_dashboard/assets/scenes/social_world/festival_core.js');

const at = (y, m, d) => new Date(Date.UTC(y, m - 1, d, 4)); // noon in Taipei

test('four festivals follow the Taipei calendar, including one across the new year', () => {
  assert.equal(festival.FESTIVALS.length, 4);
  assert.equal(festival.festivalAt(at(2027, 2, 1)).key, 'lantern');
  assert.equal(festival.festivalAt(at(2027, 4, 1)).key, 'cherry');
  assert.equal(festival.festivalAt(at(2027, 7, 20)).key, 'starlight');
  assert.equal(festival.festivalAt(at(2026, 12, 25)).key, 'snowman');
  assert.equal(festival.festivalAt(at(2027, 1, 5)).key, 'snowman');
  assert.equal(festival.festivalAt(at(2027, 10, 1)), null);
  assert.equal(festival.festivalAt(at(2027, 10, 1), 'cherry').key, 'cherry', 'preview for screenshots');
  for (const f of festival.FESTIVALS) {
    assert.ok(f.lines.length >= 2 && f.melody.length >= 6 && f.decor.length >= 1);
    assert.equal(Object.keys(f).some(k => /coin|xp|reward/i.test(k)), false, 'festivals grant no rewards');
  }
});

test('town-goal fireworks play once per week after the cloud goal is reached', () => {
  const store = new Map();
  const storage = { getItem: k => store.get(k) ?? null, setItem: (k, v) => store.set(k, v) };
  const week = festival.weekKey(at(2026, 11, 26));
  assert.equal(week, '2026-11-23');
  assert.equal(festival.takeFireworks(storage, week), false, 'nothing before the goal');
  festival.markGoalReached(storage, week);
  assert.equal(festival.takeFireworks(storage, week), true, 'the town fires once');
  assert.equal(festival.takeFireworks(storage, week), false, 'and not again that week');
  festival.markGoalReached(storage, week);
  assert.equal(festival.takeFireworks(storage, week), false, 'marking again does not re-arm it');
});

test('fireworks expand and fade', () => {
  const early = festival.fireworkParticles(1, 0.1);
  const late = festival.fireworkParticles(1, 0.9);
  assert.equal(early.length, 18);
  assert.ok(Math.hypot(late[0].x, late[0].y) > Math.hypot(early[0].x, early[0].y));
  assert.ok(late[0].alpha < early[0].alpha);
});

test('the town and festival pages load the festival modules', () => {
  const town = fs.readFileSync('web_dashboard/town.html', 'utf8');
  assert.ok(town.indexOf('festival_core.js') < town.indexOf('town_festival.js'));
  assert.ok(town.indexOf('town_festival.js') < town.indexOf('assets/town.js'));
  assert.match(fs.readFileSync('web_dashboard/assets/town.js', 'utf8'), /NudgeTownFestival\?\.draw/);
  for (const page of ['seasonal-event.html', 'town-goals.html']) {
    const html = fs.readFileSync(`web_dashboard/${page}`, 'utf8');
    assert.match(html, /festival_scene\.js/);
    assert.ok(html.indexOf('living_page.js') < html.indexOf('festival_scene.js'));
  }
});
