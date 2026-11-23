const test = require('node:test');
const assert = require('node:assert/strict');
const core = require('../web_dashboard/assets/town_core.js');

const now = Date.parse('2026-11-23T12:00:00.000Z');
const ago = minutes => new Date(now - minutes * 60000).toISOString();
const receipt = (id, type, minutes, verifiedAt) => ({ receiptId: id, activityType: type, acceptedMetric: minutes, verifiedAt });

test('break tickets come only from confirmed focus of 25+ minutes within two hours', () => {
  const tickets = core.breakTickets([
    receipt('a', 'focus', 30, ago(10)),
    receipt('b', 'study', 55, ago(30)),
    receipt('c', 'focus', 20, ago(5)),
    receipt('d', 'exercise', 60, ago(5)),
    receipt('e', 'focus', 40, ago(130)),
  ], now, []);
  assert.deepEqual(tickets.map(t => [t.receiptId, t.minutes]), [['a', 5], ['b', 10]]);
  assert.equal(tickets[0].expiresAt, Date.parse(ago(10)) + 2 * 3600000);
});

test('used tickets are excluded and at most two are kept', () => {
  const receipts = [1, 2, 3, 4].map(i => receipt(`r${i}`, 'focus', 25, ago(i)));
  assert.deepEqual(core.breakTickets(receipts, now, ['r1']).map(t => t.receiptId), ['r2', 'r3']);
});

test('movement slides along a blocking building and stays in bounds', () => {
  const blockers = [{ x: 100, y: 100, w: 100, h: 100 }];
  const bounds = { x: 0, y: 0, w: 400, h: 400 };
  const moved = core.step({ x: 90, y: 150 }, { x: 1, y: 1 }, 0.1, 200, blockers, bounds, 6);
  assert.ok(moved.x <= 100 - 6 + 0.001, 'blocked on x');
  assert.ok(moved.y > 150, 'slides on y');
  const clamped = core.step({ x: 2, y: 2 }, { x: -1, y: -1 }, 1, 200, [], bounds, 6);
  assert.deepEqual(clamped, { x: 6, y: 6 });
});

test('nearest door within reach and level unlocks', () => {
  const buildings = [
    { id: 'tower', door: { x: 100, y: 100 } },
    { id: 'garden', door: { x: 300, y: 300 }, minLevel: 10 },
  ];
  assert.equal(core.nearestDoor({ x: 120, y: 110 }, buildings, 60)?.id, 'tower');
  assert.equal(core.nearestDoor({ x: 200, y: 200 }, buildings, 60), null);
  assert.equal(core.isUnlocked(buildings[1], 9), false);
  assert.equal(core.isUnlocked(buildings[1], 10), true);
  assert.equal(core.isUnlocked(buildings[0], 1), true);
});

test('click-to-move direction stops at the target', () => {
  assert.deepEqual(core.directionTo({ x: 0, y: 0 }, { x: 3, y: 4 }, 1), { x: 0.6, y: 0.8 });
  assert.equal(core.directionTo({ x: 0, y: 0 }, { x: 0.5, y: 0 }, 1), null);
});
