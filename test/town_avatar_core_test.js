const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const avatar = require('../web_dashboard/assets/town_avatar_core.js');

test('town companion faces the actual direction of travel', () => {
  assert.equal(avatar.facing(4, 0), 'east');
  assert.equal(avatar.facing(-4, 0), 'west');
  assert.equal(avatar.facing(0, -4), 'north');
  assert.equal(avatar.facing(0, 4), 'south');
  assert.equal(avatar.facing(0, 0, 'west'), 'west');
  assert.equal(avatar.facing(0, -4, 'east'), 'north');
});

test('side walking uses the matching App art and rests on a standing frame', () => {
  assert.deepEqual(
    [0, 0.125, 0.25, 0.375].map(t => avatar.pose(0, 'east', true, t).frame),
    ['a', 'p', 'b', 'p']
  );
  assert.deepEqual(avatar.pose(0, 'west', false), { kind: 'side', flip: true, frame: 'p' });
  assert.deepEqual(avatar.pose(3, 'east', true, 0), { kind: 'side', flip: false, frame: 'a' });
  assert.equal(avatar.pose(0, 'north', true).kind, 'front');
  assert.deepEqual(avatar.pose(1, 'west', true), { kind: 'front', flip: true, frame: null });
});

test('every declared Web walk frame exists and town loads the selector first', () => {
  const webRoot = path.join(__dirname, '..', 'web_dashboard');
  for (const id of [0, 3, 6, 9, 12, 15]) {
    for (const frame of ['a', 'p', 'b']) {
      const relative = avatar.sidePath(id, frame);
      assert.ok(fs.statSync(path.join(webRoot, relative)).size > 0, relative);
    }
  }
  const html = fs.readFileSync(path.join(webRoot, 'town.html'), 'utf8');
  assert.ok(html.indexOf('town_avatar_core.js') < html.indexOf('town.js?v=5'));
});
