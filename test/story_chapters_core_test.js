const test = require('node:test');
const assert = require('node:assert/strict');
const core = require('../web_dashboard/assets/story_chapters_core.js');

const now = new Date('2026-11-23T12:00:00.000Z');
const action = (id, verifiedAt, patch = {}) => ({
  receiptId: id, actorUserId: 'me', activityType: 'focus', acceptedMetric: 25, verifiedAt, ...patch,
});

test('task day uses the 05:00 Taipei rollover', () => {
  assert.equal(core.taskDayKey('2026-11-22T20:59:59.000Z'), '2026-11-22');
  assert.equal(core.taskDayKey('2026-11-22T21:00:00.000Z'), '2026-11-23');
  assert.equal(core.windowStart(now), '2026-10-26T21:00:00.000Z');
});

test('chapters advance only from actor-owned accepted actions on distinct task days', () => {
  const receipts = [
    action('a', '2026-11-23T01:00:00.000Z'),
    action('b', '2026-11-23T03:00:00.000Z'),
    action('c', '2026-11-22T01:00:00.000Z', { activityType: 'task', acceptedMetric: 1 }),
    action('d', '2026-11-21T01:00:00.000Z', { activityType: 'study' }),
    action('foreign', '2026-11-20T01:00:00.000Z', { actorUserId: 'other' }),
    action('zero', '2026-11-20T01:00:00.000Z', { acceptedMetric: 0 }),
    action('future', '2026-11-24T01:00:00.000Z'),
    action('old', '2026-10-25T01:00:00.000Z'),
  ];
  const result = core.progress(receipts, 'me', now);
  assert.equal(result.actions, 4);
  assert.equal(result.days, 3);
  assert.deepEqual(result.chapters.map(item => item.completed), [true, true, false]);
  assert.deepEqual(result.chapters.map(item => item.unlocked), [true, true, true]);
});

test('empty or invalid data never becomes a completed chapter', () => {
  assert.deepEqual(core.progress([], 'me', now).chapters.map(item => item.completed), [false, false, false]);
  assert.equal(core.verifiedActions([action('a', 'bad-date')], 'me', now).length, 0);
  assert.equal(core.verifiedActions([action('a', '2026-11-23T01:00:00.000Z')], '', now).length, 0);
});
