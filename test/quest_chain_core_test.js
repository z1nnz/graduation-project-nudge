const test = require('node:test');
const assert = require('node:assert/strict');
const core = require('../web_dashboard/assets/quest_chain_core.js');

// Noon in Taipei on a task day is 04:00 UTC the same date.
const noon = day => `${day}T04:00:00.000Z`;
const at = day => new Date(noon(day));
let seq = 0;
const receipt = (day, patch = {}) => ({
  receiptId: `r${++seq}`, actorUserId: 'me', activityType: 'focus', acceptedMetric: 25,
  verifiedAt: noon(day), correctionOfReceiptId: null, ...patch,
});
const chain = (templateId, startDay) => ({ id: `${templateId}:${startDay}:1`, templateId, startDay, attempt: 1, closed: false });
const progress = (templateId, startDay, raw, today) => {
  const now = at(today);
  return core.chainProgress(chain(templateId, startDay), core.confirmedReceipts(raw, 'me', now), now);
};

test('there are 8 templates with unique ids and sane rules', () => {
  assert.equal(core.TEMPLATES.length, 8);
  assert.equal(new Set(core.TEMPLATES.map(t => t.id)).size, 8);
  for (const t of core.TEMPLATES) {
    assert.ok(['streak', 'count'].includes(t.kind), t.id);
    assert.ok(t.target > 0 && t.target <= t.windowDays * (t.unit === 'day' ? 1 : 10), t.id);
    assert.ok(t.rule.includes('雲端確認'), `${t.id} says it only counts Cloud-confirmed activity`);
  }
});

test('task day rolls over at 05:00 Taipei time', () => {
  assert.equal(core.taskDayKey('2026-11-22T20:59:59.999Z'), '2026-11-22'); // 04:59 Taipei on the 23rd
  assert.equal(core.taskDayKey('2026-11-22T21:00:00.000Z'), '2026-11-23'); // 05:00 Taipei on the 23rd
  assert.equal(core.dayStartIso('2026-11-23'), '2026-11-22T21:00:00.000Z');
  assert.equal(core.taskDayKey(core.dayStartIso('2026-03-01')), '2026-03-01');
  assert.equal(core.taskDayKey('nope'), null);
});

test('a 04:30 focus session still counts for the previous day', () => {
  const late = receipt('2026-11-21', { verifiedAt: '2026-11-21T20:30:00.000Z' }); // 04:30 on the 22nd, Taipei
  const p = progress('focus-streak-3', '2026-11-20', [receipt('2026-11-20'), late], '2026-11-22');
  assert.deepEqual(p.stampDays, ['2026-11-20', '2026-11-21']);
  assert.equal(p.run, 2);
  assert.equal(p.status, 'active');
});

test('three days in a row completes the three-day focus chain', () => {
  const raw = [receipt('2026-11-20'), receipt('2026-11-21'), receipt('2026-11-22'), receipt('2026-11-22')];
  const p = progress('focus-streak-3', '2026-11-20', raw, '2026-11-22');
  assert.equal(p.status, 'completed');
  assert.equal(p.stamps, 3);
  assert.equal(p.completedDay, '2026-11-22');
  assert.equal(p.restarts, 0);
});

test('a finished day without a stamp breaks the streak and the run starts again', () => {
  const raw = [receipt('2026-11-20'), receipt('2026-11-21'), receipt('2026-11-23')];
  const p = progress('focus-streak-3', '2026-11-20', raw, '2026-11-23');
  assert.equal(p.run, 1);
  assert.equal(p.stamps, 1);
  assert.equal(p.restarts, 1);
  assert.equal(p.brokenOn, '2026-11-22');
  assert.deepEqual(p.stampDays, ['2026-11-23']);
  assert.equal(p.status, 'active');
});

test('today without a stamp yet does not break the streak', () => {
  const p = progress('focus-streak-3', '2026-11-20', [receipt('2026-11-20'), receipt('2026-11-21')], '2026-11-22');
  assert.equal(p.run, 2);
  assert.equal(p.restarts, 0);
  assert.equal(p.status, 'active');
});

test('empty days before the first stamp are not a break', () => {
  const p = progress('focus-streak-3', '2026-11-20', [receipt('2026-11-22')], '2026-11-22');
  assert.equal(p.restarts, 0);
  assert.equal(p.run, 1);
});

test('a streak that can no longer fit before the deadline is unreachable, then expired', () => {
  // 7-day window 11-20..11-26; nothing until 11-25 leaves only 2 open days for 3 stamps.
  assert.equal(progress('focus-streak-3', '2026-11-20', [], '2026-11-25').status, 'unreachable');
  assert.equal(progress('focus-streak-3', '2026-11-20', [], '2026-11-24').status, 'active');
  const p = progress('focus-streak-3', '2026-11-20', [receipt('2026-11-26')], '2026-11-27');
  assert.equal(p.status, 'expired');
  assert.equal(p.daysLeft, 0);
});

test('short or other-type activity does not stamp a focus chain', () => {
  const raw = [
    receipt('2026-11-20', { acceptedMetric: 24 }),
    receipt('2026-11-20', { activityType: 'exercise', acceptedMetric: 60 }),
    receipt('2026-11-20', { activityType: 'study', acceptedMetric: 30 }),
  ];
  assert.deepEqual(progress('focus-streak-3', '2026-11-20', raw, '2026-11-20').stampDays, ['2026-11-20']);
});

test('receipts outside the window, from others or in the future never count', () => {
  const raw = [
    receipt('2026-11-19'),
    receipt('2026-11-20', { actorUserId: 'someone-else' }),
    receipt('2026-11-21', { verifiedAt: '2026-11-30T04:00:00.000Z' }),
    receipt('2026-11-21', { acceptedMetric: Number.NaN }),
    receipt('2026-11-21', { activityType: 'custom' }),
  ];
  assert.equal(progress('focus-streak-3', '2026-11-20', raw, '2026-11-21').stamps, 0);
});

test('a corrected receipt replaces the one it corrects', () => {
  const original = receipt('2026-11-20', { receiptId: 'orig', acceptedMetric: 30 });
  const fixed = receipt('2026-11-20', { receiptId: 'fix', acceptedMetric: 10, correctionOfReceiptId: 'orig' });
  const list = core.confirmedReceipts([original, fixed], 'me', at('2026-11-21'));
  assert.deepEqual(list.map(r => r.receiptId), ['fix']);
  assert.equal(progress('focus-streak-3', '2026-11-20', [original, fixed], '2026-11-21').stamps, 0);
});

test('duplicated receipt ids count once', () => {
  const r = receipt('2026-11-20', { activityType: 'task', acceptedMetric: 1 });
  assert.equal(progress('tasks-week-10', '2026-11-20', [r, { ...r }], '2026-11-20').stamps, 1);
});

test('count chains by receipt stamp each qualifying receipt, capped at the target', () => {
  const ex = day => receipt(day, { activityType: 'exercise', acceptedMetric: 20 });
  const p = progress('exercise-week-3', '2026-11-20', [ex('2026-11-20'), ex('2026-11-20'), ex('2026-11-22'), ex('2026-11-23')], '2026-11-23');
  assert.equal(p.status, 'completed');
  assert.equal(p.stamps, 3);
  assert.equal(p.completedDay, '2026-11-22');
  assert.equal(progress('exercise-week-3', '2026-11-20', [ex('2026-11-20')], '2026-11-26').status, 'active');
  assert.equal(progress('exercise-week-3', '2026-11-20', [ex('2026-11-20')], '2026-11-27').status, 'expired');
});

test('count chains by day give one stamp per day', () => {
  const sleep = (day, hours) => receipt(day, { activityType: 'sleep', acceptedMetric: hours });
  const raw = [sleep('2026-11-20', 7.5), sleep('2026-11-20', 8), sleep('2026-11-21', 6.5), sleep('2026-11-22', 7)];
  const p = progress('sleep-week-5', '2026-11-20', raw, '2026-11-22');
  assert.deepEqual(p.stampDays, ['2026-11-20', '2026-11-22']);
  assert.equal(p.status, 'active');
  // 2 stamps + open days 11-24..11-26 = 5: still possible; from 11-25 only 4.
  assert.equal(progress('sleep-week-5', '2026-11-20', raw, '2026-11-24').status, 'active');
  assert.equal(progress('sleep-week-5', '2026-11-20', raw, '2026-11-25').status, 'unreachable');
});

test('creating chains: one per template, at most 3 open at once', () => {
  const now = at('2026-11-23');
  const a = core.createChain('focus-streak-3', now, []);
  assert.equal(a.startDay, '2026-11-23');
  assert.equal(a.attempt, 1);
  assert.throws(() => core.createChain('focus-streak-3', now, [a]), /進行中/);
  const b = core.createChain('exercise-week-3', now, [a]);
  const c = core.createChain('sleep-week-5', now, [a, b]);
  assert.throws(() => core.createChain('tasks-week-10', now, [a, b, c]), /最多/);
  assert.doesNotThrow(() => core.createChain('tasks-week-10', now, [a, b, { ...c, closed: true }]));
  assert.throws(() => core.createChain('made-up', now, []), /範本/);
  const again = core.createChain('sleep-week-5', now, [{ ...c, closed: true }]);
  assert.equal(again.attempt, 2);
  assert.notEqual(again.id, c.id);
});

test('restart only moves a chain that can no longer finish', () => {
  const c = chain('focus-streak-3', '2026-11-20');
  const now = at('2026-11-27');
  const expired = core.chainProgress(c, [], now);
  const restarted = core.restartChain(c, expired, now);
  assert.equal(restarted.startDay, '2026-11-27');
  assert.equal(restarted.attempt, 2);
  assert.notEqual(restarted.id, c.id);
  const live = core.chainProgress(c, [], at('2026-11-21'));
  assert.equal(core.restartChain(c, live, at('2026-11-21')), c);
});

test('a certificate is earned once per completed chain', () => {
  const c = chain('focus-streak-3', '2026-11-20');
  const raw = [receipt('2026-11-20'), receipt('2026-11-21'), receipt('2026-11-22')];
  const p = progress('focus-streak-3', '2026-11-20', raw, '2026-11-22');
  const store = { chains: [c], certificates: [], seenStamps: {} };
  const first = core.collectCertificates(store, { [c.id]: p });
  assert.equal(first.earned.length, 1);
  assert.equal(first.earned[0].completedDay, '2026-11-22');
  const second = core.collectCertificates(first.store, { [c.id]: p });
  assert.equal(second.earned.length, 0);
  assert.equal(core.certificateFor(c, progress('focus-streak-3', '2026-11-20', raw.slice(0, 2), '2026-11-22')), null);
});

test('the local store drops anything malformed', () => {
  const store = core.normalizeStore({
    chains: [
      chain('focus-streak-3', '2026-11-20'),
      chain('focus-streak-3', '2026-11-20'),
      { id: 'x', templateId: 'nope', startDay: '2026-11-20' },
      { id: 'y', templateId: 'deep-focus-3', startDay: '2026-02-30' },
      '<img onerror=alert(1)>',
    ],
    certificates: [{ id: 'c1', templateId: 'focus-streak-3', title: '<b>forged</b>', startDay: '2026-11-20', completedDay: '2026-11-22' }],
    seenStamps: { 'focus-streak-3:2026-11-20:1': 2, other: 3, 'deep-focus-3:x': -1 },
  });
  assert.equal(store.chains.length, 1);
  assert.equal(store.certificates[0].title, '三天讀書挑戰');
  assert.deepEqual(store.seenStamps, { 'focus-streak-3:2026-11-20:1': 2 });
  assert.deepEqual(core.normalizeStore('garbage'), { chains: [], certificates: [], seenStamps: {} });
});

test('receipts are read from the start of the oldest open chain', () => {
  const chains = [chain('focus-streak-3', '2026-11-18'), { ...chain('deep-focus-3', '2026-11-01'), closed: true }, chain('exercise-week-3', '2026-11-21')];
  assert.equal(core.receiptWindowStart(chains, at('2026-11-23')), '2026-11-17T21:00:00.000Z');
  assert.equal(core.receiptWindowStart([], at('2026-11-23')), '2026-11-22T21:00:00.000Z');
});

test('the townsfolk request picks one of today\'s own tasks and keeps it all day', () => {
  const tasks = [
    { id: 't1', userId: 'me', title: '背 20 個單字', taskType: 'fixed', isDone: false },
    { id: 't2', userId: 'me', title: '整理書桌', taskType: 'fixed', isDone: false },
    { id: 't3', userId: 'me', title: '交報告', taskType: 'deadline', dueDate: '2026-11-23T10:00:00.000Z', isDone: false },
    { id: 't4', userId: 'me', title: '下週的考試', taskType: 'deadline', dueDate: '2026-11-30T10:00:00.000Z' },
    { id: 't5', userId: 'other', title: '別人的任務' },
    { id: 't6', userId: 'me', title: '走路', sourceType: 'steps', isAutoTracked: true },
    { id: 't7', userId: 'me', title: '   ' },
  ];
  const morning = new Date('2026-11-22T22:00:00.000Z'); // 06:00 Taipei, 11-23
  const night = new Date('2026-11-23T15:00:00.000Z'); // 23:00 Taipei, 11-23
  assert.deepEqual(core.todaysTasks(tasks, 'me', morning).map(t => t.id), ['t1', 't2', 't3']);
  const a = core.townsfolkRequest(tasks, 'me', morning);
  assert.ok(['t1', 't2', 't3'].includes(a.taskId));
  assert.ok(a.line.includes(a.taskTitle));
  assert.ok(core.TOWNSFOLK.some(n => n.id === a.npc.id));
  // Ticking the chosen task keeps the same request, now marked done.
  const ticked = tasks.map(t => (t.id === a.taskId ? { ...t, isDone: true } : t));
  const b = core.townsfolkRequest(ticked, 'me', night);
  assert.equal(b.taskId, a.taskId);
  assert.equal(b.npc.id, a.npc.id);
  assert.equal(b.done, true);
  assert.equal(core.townsfolkRequest([], 'me', morning), null);
  assert.equal(core.townsfolkRequest(tasks, '', morning), null);
});

test('different days can give a different request', () => {
  const tasks = Array.from({ length: 12 }, (_, i) => ({ id: `t${i}`, userId: 'me', title: `任務 ${i}`, taskType: 'fixed' }));
  const picks = new Set();
  for (let d = 1; d <= 14; d += 1) picks.add(core.townsfolkRequest(tasks, 'me', at(`2026-11-${String(d).padStart(2, '0')}`)).taskId);
  assert.ok(picks.size > 1);
});
