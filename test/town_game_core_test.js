const test = require('node:test');
const assert = require('node:assert/strict');
const game = require('../web_dashboard/assets/town_game_core.js');

test('a fifth consecutive star gives local bonus and clouds reset the combo', () => {
  let state = { score: 0, combo: 0 };
  for (let i = 0; i < 5; i += 1) state = game.catchObject(state.score, state.combo, 'star');
  assert.equal(state.score, 6);
  assert.equal(state.combo, 5);
  state = game.catchObject(state.score, state.combo, 'cloud');
  assert.deepEqual(state, { score: 4, combo: 0, bonus: 0 });
  assert.equal(game.catchObject(1, 0, 'cloud').score, 0);
});
test('pause preserves remaining time and pace has a capped increase', () => {
  assert.equal(game.resumeDeadline(10000, 2000, 7000), 15000);
  assert.equal(game.resumeDeadline(10000, 7000, 2000), 10000);
  assert.deepEqual(game.spawnRates(0), { stars: 1.6, clouds: 0.5 });
  assert.deepEqual(game.spawnRates(900), { stars: 2.6, clouds: 0.9 });
});
