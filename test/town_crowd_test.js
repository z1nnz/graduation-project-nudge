'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const crowd = require('../web_dashboard/assets/town_crowd.js');

const ts = ms => ({ toMillis: () => ms });

test('only fresh town records with fixed choices become people on the map', () => {
  const now = 1_000_000;
  const ok = crowd.townPerson({ building: 'town', updatedAt: ts(now - 1000), town: { x: 0.4, y: 0.6, facing: 'east', emote: 'wave', say: 'hi', face: 3 } }, now);
  assert.deepEqual(ok, { x: 0.4, y: 0.6, facing: 'east', emote: 'wave', say: 'hi', face: 3, updated: now - 1000 });
  assert.equal(crowd.townPerson({ building: 'tower', updatedAt: ts(now), town: { x: 0.4, y: 0.6 } }, now), null, 'inside a building is not on the map');
  assert.equal(crowd.townPerson({ building: 'town', updatedAt: ts(now - 6 * 60_000), town: { x: 0.4, y: 0.6 } }, now), null, 'stale');
  assert.equal(crowd.townPerson({ building: 'town', updatedAt: ts(now), town: { x: 2, y: 0.6 } }, now), null, 'off the map');
  const odd = crowd.townPerson({ building: 'town', updatedAt: ts(now), town: { x: 0.1, y: 0.1, facing: 'up', emote: 'rude', say: '<b>hey</b>', face: -1 } }, now);
  assert.deepEqual([odd.facing, odd.emote, odd.say, odd.face], ['south', null, null, 0], 'unknown choices are dropped, never shown as text');
});

test('updates are sent when moving, changing emote or as a slow heartbeat', () => {
  const base = { x: 0.5, y: 0.5, facing: 'south', emote: null, say: null };
  assert.equal(crowd.shouldSend(null, base, 0), true);
  const last = { ...base, at: 10_000 };
  assert.equal(crowd.shouldSend(last, { ...base, x: 0.6 }, 10_500), false, 'not more than once a second');
  assert.equal(crowd.shouldSend(last, { ...base, x: 0.6 }, 11_100), true);
  assert.equal(crowd.shouldSend(last, base, 11_100), false, 'standing still stays quiet');
  assert.equal(crowd.shouldSend(last, { ...base, emote: 'cheer' }, 11_100), true);
  assert.equal(crowd.shouldSend(last, base, 31_000), true, 'heartbeat');
});

test('phrases are a fixed list and the town loads the crowd before its loop', () => {
  assert.deepEqual(Object.keys(crowd.PHRASES), ['hi', 'study', 'great', 'rest', 'bye', 'go']);
  const html = fs.readFileSync('web_dashboard/town.html', 'utf8');
  assert.ok(html.indexOf('assets/town_crowd.js') > 0 && html.indexOf('assets/town_crowd.js') < html.indexOf('assets/town.js?v=11'));
  const js = fs.readFileSync('web_dashboard/assets/town_crowd.js', 'utf8');
  assert.doesNotMatch(js, /\.doc\([^)]*\)\s*\.(set|update|delete)\(|collection\([^)]*\)\.add\(/, 'the page never writes presence itself');
});
