const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const core = require('../web_dashboard/assets/town_hud_core.js');

test('XP ring follows the Cloud ledger level curve without fabricating values', () => {
  assert.equal(core.required(1), 0);
  assert.equal(core.progress(1, 0).fraction, 0);
  assert.equal(core.progress(1, core.required(2)).fraction, 1);
  assert.equal(core.progress(1, core.required(2)).remaining, 0);
  assert.equal(core.progress(60, core.required(60)).fraction, 1);
  assert.equal(core.progress(1, NaN), null);
});

test('quest tracker shows one next action and at most three pending tasks', () => {
  const tasks = [
    { title: '先走五分鐘', done: false }, { title: '讀一頁', done: false },
    { title: '已完成', done: true }, { title: '喝水', done: false },
    { title: '早睡', done: false },
  ];
  assert.deepEqual(core.quests(tasks, () => ({ title: '先走五分鐘' })), {
    next: '先走五分鐘', pending: ['先走五分鐘', '讀一頁', '喝水'],
  });
});

test('streak uses Taipei dates from confirmed receipts and yesterday grace', () => {
  const receipts = [
    { verifiedAt: '2026-11-24T03:00:00Z' },
    { verifiedAt: '2026-11-23T16:30:00Z' }, // same Taipei day
    { verifiedAt: '2026-11-22T20:00:00Z' },
    { verifiedAt: '2026-11-21T20:00:00Z' },
  ];
  assert.deepEqual(core.streak(receipts, '2026-11-24T08:00:00Z'), { count: 3, lowerBound: false });
  assert.deepEqual(core.streak(receipts.slice(2), '2026-11-24T08:00:00Z', true), { count: 2, lowerBound: true });
  assert.deepEqual(core.streak([], '2026-11-24T08:00:00Z'), { count: 0, lowerBound: false });
});

test('unread badge counts only unread Cloud letters', () => {
  assert.equal(core.unread([{ status: 'unread' }, { status: 'read' }, { status: 'unread' }]), 2);
});

test('town loads HUD before map and keeps five mobile actions', () => {
  const html = fs.readFileSync(path.join(__dirname, '../web_dashboard/town.html'), 'utf8');
  assert.ok(html.indexOf('town_hud_core.js') < html.indexOf('town_hud.js'));
  assert.ok(html.indexOf('town_hud.js') < html.indexOf('town.js'));
  assert.equal((html.match(/data-town-(?:scene|page)=/g) || []).length, 5);
});
