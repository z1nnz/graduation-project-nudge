const test = require('node:test');
const assert = require('node:assert/strict');
const core = require('../web_dashboard/assets/arcade_core.js');

const NOW = Date.parse('2026-11-23T10:00:00.000Z');
const receipt = (id, minutes, minsAgo, type = 'focus') => ({
  receiptId: id, activityType: type, acceptedMetric: minutes,
  verifiedAt: new Date(NOW - minsAgo * 60000).toISOString(),
});

test('25+ minutes gives one ticket, 50+ gives two, less gives none', () => {
  assert.equal(core.ticketCount(24.9), 0);
  assert.equal(core.ticketCount(25), 1);
  assert.equal(core.ticketCount(49), 1);
  assert.equal(core.ticketCount(50), 2);
  assert.equal(core.ticketCount(180), 2);
  assert.equal(core.ticketCount('abc'), 0);
});

test('tickets come only from focus or study receipts inside the 2-hour window', () => {
  const list = core.availableTickets([
    receipt('a', 30, 10),
    receipt('run', 60, 10, 'exercise'),
    receipt('old', 30, 121),
    receipt('future', 30, -5),
    receipt('bad', 30, 10, 'focus'),
    { receiptId: 'nodate', activityType: 'focus', acceptedMetric: 30, verifiedAt: 'soon' },
  ].map(r => (r.receiptId === 'bad' ? { ...r, receiptId: '' } : r)), NOW, []);
  assert.deepEqual(list.map(t => t.id), ['a#1']);
  assert.equal(list[0].playMs, 5 * 60 * 1000);
  assert.equal(list[0].expiresAt, NOW - 10 * 60000 + 2 * 3600000);
});

test('a 50-minute focus gives two tickets and holdings cap at two', () => {
  assert.deepEqual(core.availableTickets([receipt('long', 50, 5)], NOW, []).map(t => t.id), ['long#1', 'long#2']);
  const many = core.availableTickets([receipt('x', 60, 5), receipt('y', 60, 30), receipt('z', 30, 1)], NOW, []);
  assert.equal(many.length, core.MAX_TICKETS);
  // soonest-expiring first: y was verified earliest
  assert.deepEqual(many.map(t => t.id), ['y#1', 'y#2']);
});

test('spending a ticket removes exactly that ticket and starts a 5-minute session', () => {
  const receipts = [receipt('long', 55, 5)];
  const first = core.spendTicket(receipts, NOW, []);
  assert.equal(first.ticket.id, 'long#1');
  assert.deepEqual(first.used, ['long#1']);
  assert.deepEqual(first.session, { ticketId: 'long#1', remainingMs: 300000 });
  const second = core.spendTicket(receipts, NOW, first.used);
  assert.equal(second.ticket.id, 'long#2');
  assert.deepEqual(second.used, ['long#1', 'long#2']);
  assert.equal(core.spendTicket(receipts, NOW, second.used), null);
});

test('a receipt already spent by the older in-town game spends all of its tickets', () => {
  assert.deepEqual(core.availableTickets([receipt('long', 55, 5)], NOW, ['long']), []);
});

test('the used list stays bounded', () => {
  const used = Array.from({ length: 60 }, (_, i) => `r${i}#1`);
  const out = core.spendTicket([receipt('new', 30, 1)], NOW, used);
  assert.equal(out.used.length, 40);
  assert.equal(out.used.at(-1), 'new#1');
});

test('sessions drain only by running time and end at zero', () => {
  const s = { ticketId: 'a#1', remainingMs: 300000 };
  assert.deepEqual(core.drainSession(s, 60000), { ticketId: 'a#1', remainingMs: 240000 });
  assert.equal(core.drainSession(s, -5).remainingMs, 300000);
  assert.equal(core.drainSession(s, 999999).remainingMs, 0);
  assert.equal(core.validSession({ ticketId: 'a#1', remainingMs: 0 }), false);
  assert.equal(core.drainSession(null, 1), null);
});

test('stored sessions are parsed defensively', () => {
  assert.deepEqual(core.readSession('{"ticketId":"a#1","remainingMs":1234.4}'), { ticketId: 'a#1', remainingMs: 1234 });
  assert.equal(core.readSession('{"ticketId":"a#1","remainingMs":9999999}'), null, 'cannot exceed one ticket');
  assert.equal(core.readSession('nope'), null);
  assert.equal(core.readSession(null), null);
  assert.deepEqual(core.readList('["a#1", 3, null]'), ['a#1']);
  assert.deepEqual(core.readList('{'), []);
});

test('records are per account and compare the right way', () => {
  assert.equal(core.recordKey('u1', 'fishing'), 'nudge_arcade_best_fishing_u1');
  assert.equal(core.recordKey('', 'fishing'), null);
  assert.equal(core.recordKey('u1', '../x'), null);
  assert.equal(core.isBetter('high', { score: 5 }, null), true);
  assert.equal(core.isBetter('high', { score: 0 }, null), false, 'zero is not a record');
  assert.equal(core.isBetter('low', { moves: 8, ms: 1 }, null), true);
  assert.equal(core.isBetter('high', { score: 5 }, { score: 5 }), false);
  assert.equal(core.isBetter('low', { moves: 10, ms: 9000 }, { moves: 11, ms: 1000 }), true);
  assert.equal(core.isBetter('low', { moves: 10, ms: 9000 }, { moves: 10, ms: 8000 }), false);
  assert.equal(core.formatClock(300000), '5:00');
  assert.equal(core.formatClock(61001), '1:02');
});

test('everyone gets three free plays a day, reset at 05:00, plus focus bonus tickets', () => {
  const core = require('../web_dashboard/assets/arcade_core.js');
  const morning = new Date(2026, 10, 25, 9, 0).getTime();
  const free = core.freeTickets(morning, []);
  assert.equal(free.length, core.FREE_PLAYS_PER_DAY);
  assert.ok(free.every(t => t.free && t.playMs === core.PLAY_MS_PER_TICKET));
  // spending uses one and the next call has one fewer
  const spent = core.spendTicket([], morning, [], { free: true });
  assert.equal(spent.ticket.free, true);
  assert.equal(core.freeTickets(morning, spent.used).length, core.FREE_PLAYS_PER_DAY - 1);
  // 04:59 still counts as the previous day; 05:00 starts a fresh day
  assert.equal(core.playDay(new Date(2026, 10, 26, 4, 59).getTime()), core.playDay(morning));
  assert.notEqual(core.playDay(new Date(2026, 10, 26, 5, 0).getTime()), core.playDay(morning));
  assert.equal(core.freeTickets(new Date(2026, 10, 26, 5, 0).getTime(), spent.used).length, core.FREE_PLAYS_PER_DAY);
  // without the free option the old focus-only rule is unchanged
  assert.equal(core.spendTicket([], morning, []), null);
});
