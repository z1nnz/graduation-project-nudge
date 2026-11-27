const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const emotes = require('../web_dashboard/assets/town_pixel_emotes.js');
const crowd = require('../web_dashboard/assets/town_crowd.js');

test('every shared emote has a pixel animation instead of an emoji', () => {
  for (const key of Object.keys(crowd.EMOTES)) {
    assert.ok(emotes.BITMAPS[key], `${key} has a bitmap`);
    assert.ok(emotes.cells(key, 0).length > 6, `${key} draws pixels`);
  }
  const moving = ['wave', 'heart', 'sleep', 'cheer'].filter(k =>
    JSON.stringify(emotes.cells(k, 0)) !== JSON.stringify(emotes.cells(k, 1)));
  assert.equal(moving.length, 4, 'emotes animate across frames');
  assert.equal(emotes.frameAt(999999, true), 0, 'reduced motion keeps the first frame');
  assert.equal(emotes.cells('unknown', 0).length, 0);
});

test('friend name tags say what they are doing from fixed signals only', () => {
  assert.equal(crowd.activityText({ emote: 'study' }), '在讀書');
  assert.equal(crowd.activityText({ say: 'rest' }), '坐著休息');
  assert.equal(crowd.activityText({}), '在小鎮散步');
});

test('interactions are a fixed set: wave, bench, photo and hug', () => {
  assert.deepEqual(crowd.ACTIONS.map(a => a.id), ['wave', 'bench', 'photo', 'hug']);
  for (const action of crowd.ACTIONS) {
    assert.ok(Object.hasOwn(crowd.EMOTES, action.emote), `${action.id} uses a shared emote`);
    assert.ok(action.say === null || Object.hasOwn(crowd.PHRASES, action.say), `${action.id} uses a fixed phrase`);
  }
});

test('the crowd reuses the existing friend presence and hug callables', () => {
  const source = fs.readFileSync('web_dashboard/assets/town_crowd.js', 'utf8');
  assert.match(source, /httpsCallable\('manageFriendPresence'\)/);
  assert.match(source, /httpsCallable\('sendDeviceHug'\)\(\{ toUserId \}\)/);
  assert.match(source, /setAttribute\('role', 'dialog'\)/);
  assert.match(source, /menuReturn\?\.focus/);
  assert.doesNotMatch(source, /collection\('presence'\)\.doc\([^)]*\)\.(set|update)/, 'presence is only written by the callable');
  const town = fs.readFileSync('web_dashboard/town.html', 'utf8');
  assert.ok(town.indexOf('town_pixel_emotes.js') < town.indexOf('assets/town.js'));
});
