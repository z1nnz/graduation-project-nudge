// J6: the two new park games' rules, and that the arcade wiring keeps the
// free-play and session rules (they register through NudgeArcade).
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const core = require('../web_dashboard/assets/arcade_more_core.js');
const read = f => fs.readFileSync(path.join(__dirname, '..', f), 'utf8');

test('fireflies: only glowing ones can be caught, quick catches chain', () => {
  const s = core.newFireflies(42);
  const f = s.flies[0];
  // find a time when the first firefly glows
  let t = 0;
  while (!core.flyAt(f, t).lit) t += 10;
  s.t = t;
  const p = core.flyAt(f, t);
  const r1 = core.catchAt(s, p.x, p.y);
  assert.equal(r1.event, 'catch');
  assert.equal(r1.points, 10);
  assert.equal(s.caught, 1);
  const miss = core.catchAt(s, -50, -50);
  assert.equal(miss.event, 'miss');
  assert.equal(s.combo, 0);
  core.stepFireflies(s, core.FIREFLY.MS);
  assert.ok(s.done);
  assert.equal(core.catchAt(s, p.x, p.y).event, 'miss', 'nothing after time is up');
  assert.equal(core.fireflyGrade(320), 'S');
  assert.equal(core.fireflyGrade(10), 'C');
});

test('constellation: show, then pick in order; a round adds a star; two slips end', () => {
  const s = core.newConstellation(3);
  assert.equal(s.stars.length, core.CONST.START);
  assert.equal(core.pick(s, s.order[0]).event, 'wait', 'cannot pick while showing');
  core.stepConstellation(s, core.CONST.SHOW_MS * (s.order.length + 1));
  assert.equal(s.phase, 'input');
  for (let i = 0; i < s.order.length - 1; i++) assert.equal(core.pick(s, s.order[i]).event, 'link');
  assert.equal(core.pick(s, s.order[s.order.length - 1]).event, 'complete');
  assert.equal(s.round, 2);
  assert.equal(s.stars.length, core.CONST.START + 1);
  core.stepConstellation(s, core.CONST.SHOW_MS * (s.order.length + 1));
  const wrong = s.order.find((_, k) => k > 0);
  assert.equal(core.pick(s, wrong).event, 'slip');
  core.stepConstellation(s, core.CONST.SHOW_MS * (s.order.length + 1));
  assert.equal(core.pick(s, wrong).event, 'over');
  assert.ok(s.done);
  assert.ok(core.starAt(s, s.stars[0].x + 2, s.stars[0].y) === 0);
});

test('new games register through the arcade and ride-ins honour reduced motion', () => {
  const games = read('web_dashboard/assets/arcade_more_games.js');
  assert.ok(games.includes("arcade.register(fireflies)") && games.includes("arcade.register(constellation)"));
  assert.ok(games.includes("records.offer('fireflies'") && games.includes("records.offer('constellation'"));
  const html = read('web_dashboard/arcade.html');
  assert.ok(html.indexOf('arcade.js') < html.indexOf('arcade_more_games.js'));
  assert.ok(html.indexOf('arcade_more_core.js') < html.indexOf('arcade_more_games.js'));
  const park = read('web_dashboard/assets/park_scene.js');
  assert.ok(park.includes("play('fireflies')") && park.includes("play('constellation')"));
  const css = read('web_dashboard/assets/arcade_stage.css');
  assert.ok(css.includes('prefers-reduced-motion'));
  assert.match(css, /\.as-ride--wheel/);
  assert.match(css, /\.as-ride--tent/);
  for (const f of ['lantern_post.png', 'telescope.png']) {
    assert.ok(fs.readFileSync(path.join(__dirname, '../web_dashboard/assets/scenes/park', f)).equals(fs.readFileSync(path.join(__dirname, '../assets/scenes/park', f))));
  }
});
