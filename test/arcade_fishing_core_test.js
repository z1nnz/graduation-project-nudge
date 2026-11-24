const test = require('node:test');
const assert = require('node:assert/strict');
const fish = require('../web_dashboard/assets/arcade_fishing_core.js');

test('five rarities, rarer ones are less likely and give a shorter window', () => {
  assert.deepEqual(fish.RARITIES.map(r => r.name), ['普通', '少見', '稀有', '閃亮', '傳說']);
  for (let i = 1; i < fish.RARITIES.length; i += 1) {
    assert.ok(fish.RARITIES[i].weight < fish.RARITIES[i - 1].weight);
    assert.ok(fish.windowFor(fish.RARITIES[i].id) < fish.windowFor(fish.RARITIES[i - 1].id));
  }
  assert.equal(fish.windowFor('common'), 600);
  assert.ok(fish.RARITIES.every(r => fish.windowFor(r.id) <= 600));
  const sum = fish.RARITIES.reduce((s, r) => s + fish.chance(r.id), 0);
  assert.ok(Math.abs(sum - 1) < 1e-9);
  assert.equal(fish.chance('legendary'), 0.03);
});

test('rarity roll follows the weights at the boundaries', () => {
  const at = v => fish.rollFish(() => v).rarity.id;
  assert.equal(at(0), 'common');
  assert.equal(at(0.4999), 'common');
  assert.equal(at(0.5), 'uncommon');
  assert.equal(at(0.75), 'rare');
  assert.equal(at(0.9), 'shiny');
  assert.equal(at(0.97), 'legendary');
  assert.equal(at(0.9999), 'legendary');
  assert.equal(at(1), 'legendary', 'rng values are clamped');
});

test('rarity roll matches the weights over many rolls', () => {
  let seed = 7;
  const rng = () => { seed = (seed * 16807) % 2147483647; return (seed - 1) / 2147483646; };
  const counts = {};
  const N = 20000;
  for (let i = 0; i < N; i += 1) { const r = fish.rollFish(rng).rarity.id; counts[r] = (counts[r] || 0) + 1; }
  for (const r of fish.RARITIES) assert.ok(Math.abs(counts[r.id] / N - fish.chance(r.id)) < 0.015, r.id);
});

test('ten fish, two per rarity, each rolled fish matches its rarity', () => {
  assert.equal(fish.FISH.length, 10);
  for (const r of fish.RARITIES) assert.equal(fish.FISH.filter(f => f.rarity === r.id).length, 2);
  const out = fish.rollFish(() => 0.99);
  assert.equal(out.fish.rarity, out.rarity.id);
});

test('release judgement: early, inside the window, or too late', () => {
  assert.equal(fish.judgeRelease(1000, null, 600), 'early');
  assert.equal(fish.judgeRelease(999, 1000, 600), 'early');
  assert.equal(fish.judgeRelease(1000, 1000, 600), 'caught');
  assert.equal(fish.judgeRelease(1600, 1000, 600), 'caught');
  assert.equal(fish.judgeRelease(1601, 1000, 600), 'late');
  assert.equal(fish.judgeRelease(1300, 1000, fish.windowFor('legendary')), 'late');
  assert.equal(fish.escaped(1601, 1000, 600), true);
  assert.equal(fish.escaped(1600, 1000, 600), false);
  assert.equal(fish.escaped(5000, null, 600), false);
});

test('bite delay and cast power stay in range', () => {
  assert.equal(fish.biteDelayMs(() => 0), 1500);
  assert.equal(fish.biteDelayMs(() => 0.9999999), 4500);
  assert.equal(fish.castPower(0), 0.35);
  assert.equal(fish.castPower(800), 1);
  assert.equal(fish.castPower(5000), 1);
});

test('the local collection counts catches and ignores junk', () => {
  let dex = fish.addToDex({}, 'starscale', 10);
  dex = fish.addToDex(dex, 'starscale', 20);
  dex = fish.addToDex(dex, 'not-a-fish', 30);
  assert.deepEqual(dex, { starscale: { count: 2, firstAt: 10 } });
  assert.deepEqual(fish.readDex(JSON.stringify({ ...dex, ghost: { count: 1, firstAt: 1 }, reed_perch: 3 })), dex);
  assert.deepEqual(fish.readDex('{'), {});
});
