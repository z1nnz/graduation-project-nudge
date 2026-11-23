const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const core = require('../web_dashboard/assets/town_desk_core.js');
const routes = require('../web_dashboard/assets/town_routes.js');

const t0 = Date.parse('2026-11-23T08:00:00.000Z');
const memory = values => ({ getItem: key => (key in values ? values[key] : null) });

test('focus time comes from timestamps, so a refresh resumes the same session', () => {
  const s = core.createSession(t0, 25, () => 0.5);
  assert.match(s.sessionId, /^web_focus_\d+_[a-z0-9]+$/);
  assert.equal(core.remainingSeconds(s, t0 + 60_000), 24 * 60);
  const restored = core.parseStored(JSON.stringify(s));
  assert.deepEqual(restored, s);
  assert.equal(core.elapsedSeconds(restored, t0 + 10 * 60_000), 600);
  assert.equal(core.elapsedSeconds(restored, t0 + 99 * 60_000), 25 * 60, 'never past the target');
});

test('pause freezes the clock and resume continues from the paused point', () => {
  let s = core.createSession(t0, 15);
  s = core.pause(s, t0 + 5 * 60_000);
  assert.equal(s.status, 'paused');
  assert.equal(core.elapsedSeconds(s, t0 + 60 * 60_000), 300);
  s = core.resume(s, t0 + 60 * 60_000);
  assert.equal(core.elapsedSeconds(s, t0 + 62 * 60_000), 420);
  const done = core.awaitConfirmation(s, t0 + 200 * 60_000);
  assert.equal(done.status, 'awaiting');
  assert.equal(done.completedSeconds, 15 * 60);
  assert.deepEqual(core.parseStored(JSON.stringify(done)), done);
});

test('unknown durations fall back to 25 minutes and tampered storage is dropped', () => {
  assert.equal(core.createSession(t0, 999).targetSeconds, 25 * 60);
  for (const raw of ['', '{', 'null', '[]',
    JSON.stringify({ sessionId: 'x', status: 'active', targetSeconds: 60, accumulatedSeconds: 0, resumedAtMs: 1 }),
    JSON.stringify({ ...core.createSession(t0, 25), targetSeconds: 9e9 }),
    JSON.stringify({ ...core.createSession(t0, 25), status: 'completed' }),
    JSON.stringify({ ...core.createSession(t0, 25), resumedAtMs: null })]) {
    assert.equal(core.parseStored(raw), null, raw);
  }
});

test('confirmation reports pending, rejected, sent and confirmed honestly', () => {
  const sid = 'web_focus_1_abc';
  const entry = (actorUserId, eventType, extra = {}) => ({ actorUserId, evidence: { sessionId: sid, eventType }, ...extra });
  const outbox = 'nudge_web_activity_ledger_outbox_v1';
  const dead = 'nudge_web_activity_ledger_dead_letters_v1';
  assert.equal(core.confirmation({ uid: 'u1', sessionId: sid, receipt: {}, storage: memory({}) }).state, 'confirmed');
  assert.deepEqual(core.confirmation({ uid: 'u1', sessionId: sid, receipt: null,
    storage: memory({ [outbox]: JSON.stringify([entry('u1', 'completed', { attempts: 2, lastError: 'offline' })]) }) }),
  { state: 'pending', attempts: 2, error: 'offline' });
  assert.equal(core.confirmation({ uid: 'u1', sessionId: sid, receipt: null,
    storage: memory({ [dead]: JSON.stringify([entry('u1', 'completed', { lastError: 'permission-denied' })]) }) }).state, 'rejected');
  assert.equal(core.confirmation({ uid: 'u1', sessionId: sid, receipt: null,
    storage: memory({ [outbox]: JSON.stringify([entry('u2', 'completed'), entry('u1', 'started')]) }) }).state, 'sent',
  'other accounts and non-final events do not count');
  assert.equal(core.confirmation({ uid: 'u1', sessionId: sid, receipt: null, storage: memory({ [outbox]: '{bad' }) }).state, 'sent');
  assert.equal(core.confirmation({ uid: 'u1', sessionId: sid, receipt: null,
    storage: memory({ [outbox]: JSON.stringify([entry('u1', 'completed')]) }) }).state, 'sending');
  assert.deepEqual(core.confirmation({ uid: 'u1', sessionId: sid, receipt: null,
    storage: memory({ [outbox]: JSON.stringify([
      { actorUserId: 'u1', evidence: { sessionId: sid, eventType: 'started' }, attempts: 3, lastError: 'offline' },
      entry('u1', 'completed')]) }) }),
  { state: 'pending', attempts: 3, error: 'offline' }, 'an untried event behind a failed one is stuck too');
});

test('board rows only allow completing manual, ready, unfinished tasks', () => {
  const rows = core.boardTasks([
    { id: 1, title: '讀書 30 分鐘' },
    { id: 'b', title: '散步', sourceType: 'steps' },
    { id: 'c', title: '交報告', taskType: 'deadline' },
    { id: 'd', title: '整理書桌', isDone: true },
    { id: 'e', title: '  ' },
    { title: '沒有 id' },
    null,
  ], task => task.taskType !== 'deadline');
  assert.deepEqual(rows.map(r => [r.id, r.canComplete, r.reason]), [
    ['1', true, ''],
    ['b', false, '自動追蹤，由健康資料或自律房同步'],
    ['c', false, '截止日任務尚未到驗收日'],
    ['d', false, '已完成'],
  ]);
  assert.deepEqual(core.boardTasks(undefined), []);
});

test('board, desk and cabin are registered scenes in the route table', () => {
  const sceneIds = routes.DESTINATIONS.filter(x => x.scene).map(x => [x.building, x.scene]);
  assert.deepEqual(sceneIds.sort(), [['board', 'board'], ['cabin', 'cabin'], ['cabin', 'desk']]);
  assert.throws(() => routes.registerScene('Bad Id', () => {}));
  const opened = [];
  routes.registerScene('test-scene', options => opened.push(options));
  routes.sceneOpener('test-scene')({ a: 1 });
  assert.deepEqual(opened, [{ a: 1 }]);
});

test('scenes reuse the existing Ledger paths and never write Firestore directly', () => {
  const source = fs.readFileSync(path.join(__dirname, '..', 'web_dashboard', 'assets', 'town_scenes.js'), 'utf8');
  assert.match(source, /queueWebTaskLedgerEvent\(/);
  assert.match(source, /queueWebStandaloneFocusLedgerEvent\(/);
  assert.doesNotMatch(source, /\.(set|update|add|delete)\(\s*\{/);
  assert.doesNotMatch(source, /httpsCallable/);
  assert.doesNotMatch(source, /disciplineCoins|avatarExperience/);
  assert.match(source, /where\('activitySessionId', '==', activitySessionId\)/);
});
