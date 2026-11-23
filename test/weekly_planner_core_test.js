const test = require('node:test');
const assert = require('node:assert/strict');
const core = require('../web_dashboard/assets/weekly_planner_core.js');

test('Taipei week starts Monday across UTC and year boundaries', () => {
  assert.equal(core.weekStart(new Date('2026-11-22T15:59:00Z')), '2026-11-16');
  assert.equal(core.weekStart(new Date('2026-11-22T16:01:00Z')), '2026-11-23');
  assert.deepEqual(core.weekDays('2026-12-28').at(-1), '2027-01-03');
});
test('only unfinished owned tasks are available once', () => {
  const make = (id, more = {}) => ({ id, userId: 'u1', title: id, ...more });
  assert.deepEqual(core.availableTasks([make('a'), make('a'), make('b', { userId: 'u2' }), make('c', { done: true }), make('d', { isDone: true }), make('e')], 'u1').map(t => t.id), ['a', 'e']);
});
test('assign moves one task and sanitizes stale or repeated plan entries', () => {
  const start = '2026-11-23';
  const slots = core.normalizeSlots({ '2026-11-23': ['a', 'a', 'missing'], '2026-11-24': ['a', 'b'], '2026-12-01': ['b'] }, ['a', 'b'], start);
  assert.deepEqual(slots, { '2026-11-23': ['a'], '2026-11-24': ['b'] });
  assert.deepEqual(core.assign(slots, 'a', '2026-11-24', start), { '2026-11-23': [], '2026-11-24': ['b', 'a'] });
  assert.equal(core.workload({ '2026-11-23': ['1', '2', '3', '4', '5'] }, start)[0].warning, true);
  assert.throws(() => core.assign(slots, 'a', '2026-12-01', start));
});
