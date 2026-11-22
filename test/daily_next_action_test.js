const test = require('node:test');
const assert = require('node:assert/strict');
const { resolve } = require('../web_dashboard/assets/daily_next_action.js');
const fixtures = require('./fixtures/daily_next_action.json');
const fs = require('node:fs');
const vm = require('node:vm');
for (const fixture of fixtures) {
  test(`shared next action: ${fixture.name}`, () => {
    const before = structuredClone(fixture.tasks);
    const action = resolve(fixture.tasks);
    assert.equal(action.kind, fixture.kind);
    assert.equal(action.title, fixture.title);
    assert.deepEqual(fixture.tasks, before);
  });
}

test('Web next action resets on account switch and ignores stale callbacks', () => {
  const nodes = Object.fromEntries(['dailyActionTitle', 'dailyActionDetail', 'dailyActionLink', 'dailyActionStatus', 'dailyActivityFeedback'].map(id => [id, {}]));
  let auth;
  const listeners = [];
  const receipts = [];
  const events = {};
  const context = {
    NudgeConfirmedActivityFeedback: require('../web_dashboard/assets/confirmed_activity_feedback.js'),
    document: { getElementById: id => nodes[id], addEventListener() {} },
    addEventListener: (name, callback) => { events[name] = callback; },
    firebase: {
      apps: [{}],
      auth: () => ({ onAuthStateChanged: callback => { auth = callback; return () => {}; } }),
      firestore: () => ({ collection: name => {
        if (name === 'activity_receipts') return {
          where: (field, op, uid) => {
            assert.equal(field, 'actorUserId'); assert.equal(op, '==');
            return { orderBy: (field, order) => {
              assert.equal(field, 'verifiedAt'); assert.equal(order, 'desc');
              return { limit: count => {
                assert.equal(count, 1);
                return { onSnapshot: (options, success, error) => {
                  const listener = { uid, success, error, cancelled: false };
                  receipts.push(listener);
                  return () => { listener.cancelled = true; };
                } };
              } };
            } };
          },
        };
        assert.equal(name, 'users');
        return { doc: uid => ({ onSnapshot: (options, success, error) => {
          const listener = { uid, success, error, cancelled: false };
          listeners.push(listener);
          return () => { listener.cancelled = true; };
        } }) };
      } }),
    },
  };
  vm.runInNewContext(fs.readFileSync(require.resolve('../web_dashboard/assets/daily_next_action.js'), 'utf8'), context);
  auth({ uid: 'first' });
  const confirmed = {
    docs: [{ id: 'receipt-1', data: () => ({
      receiptId: 'receipt-1', actorUserId: 'first', activityType: 'focus',
      acceptedMetric: 25, verifiedAt: '2026-11-22T06:00:00.000Z',
      rewardIssued: true, characterExperienceIssued: true,
    }) }],
    metadata: { fromCache: false, hasPendingWrites: false },
  };
  receipts[0].success(confirmed);
  assert.match(nodes.dailyActivityFeedback.textContent, /專注紀錄已由雲端確認/);
  assert.doesNotMatch(nodes.dailyActivityFeedback.textContent, /\+\d+|獲得/);
  receipts[0].success({ ...confirmed, metadata: { fromCache: false, hasPendingWrites: true } });
  assert.doesNotMatch(nodes.dailyActivityFeedback.textContent, /專注紀錄已由雲端確認/);
  const snap = title => ({ exists: true, data: () => ({ tasks: [{ title }] }), metadata: { fromCache: true } });
  listeners[0].success(snap('<img src=x onerror=alert(1)>'));
  assert.equal(nodes.dailyActionTitle.textContent, '<img src=x onerror=alert(1)>');
  assert.equal(nodes.dailyActionTitle.innerHTML, undefined);
  assert.match(nodes.dailyActionStatus.textContent, /快取/);
  listeners[0].success({ ...snap('等待同步'), metadata: { fromCache: false, hasPendingWrites: true } });
  assert.match(nodes.dailyActionStatus.textContent, /本機清單變更/);
  auth({ uid: 'second' });
  assert.equal(receipts[0].cancelled, true);
  receipts[0].error();
  receipts[0].success(confirmed);
  assert.equal(nodes.dailyActivityFeedback.textContent, '正在讀取活動確認');
  assert.equal(listeners[0].cancelled, true);
  assert.equal(listeners[1].uid, 'second');
  listeners[0].success(snap('old private title'));
  listeners[0].error();
  assert.equal(nodes.dailyActionTitle.textContent, '正在整理你的下一步');
  listeners[1].error();
  assert.equal(nodes.dailyActionTitle.textContent, '暫時無法讀取清單');
  auth(null);
  assert.equal(listeners[1].cancelled, true);
  assert.equal(nodes.dailyActionStatus.textContent, '尚未登入');
  events.pagehide();
  events.pageshow();
  auth({ uid: 'third' });
  assert.equal(listeners[2].uid, 'third');
  listeners[1].success(snap('stale after restore'));
  assert.equal(nodes.dailyActionTitle.textContent, '正在整理你的下一步');
  listeners[2].success(snap('fresh after restore'));
  assert.equal(nodes.dailyActionTitle.textContent, 'fresh after restore');
});
