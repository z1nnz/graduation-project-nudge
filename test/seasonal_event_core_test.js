const test = require('node:test');
const assert = require('node:assert/strict');
const core = require('../web_dashboard/assets/seasonal_event_core.js');

test('season uses Taipei local calendar at quarter boundary', () => {
  assert.equal(core.seasonFor(new Date('2026-02-28T15:59:00Z')).id, 'winter');
  assert.equal(core.seasonFor(new Date('2026-02-28T16:01:00Z')).id, 'spring');
  assert.equal(core.seasonFor(new Date('2026-11-22T16:01:00Z')).id, 'autumn');
  assert.equal(core.seasonFor(new Date('2026-12-15T08:00:00Z')).key, '2027-winter');
});
test('stations unlock only on distinct confirmed task days from the owner', () => {
  const now = new Date('2026-11-23T08:00:00Z');
  const record = (id, day, actorUserId = 'u1') => ({ receiptId: id, actorUserId, acceptedMetric: 1,
    activityType: 'focus', verifiedAt: `2026-11-${day}T08:00:00.000Z` });
  const result = core.progress([record('a', '20'), record('b', '20'), record('c', '21'), record('d', '22'), record('e', '23', 'u2')], 'u1', now);
  assert.equal(result.days, 3);
  assert.deepEqual(result.stations.map(station => station.unlocked), [true, true, false]);
  assert.equal(core.progress([], 'u1', now).stations[0].unlocked, true);
});
