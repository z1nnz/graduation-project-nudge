const test = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const garden = require('../web_dashboard/assets/garden_core.js');

const web = path.resolve(__dirname, '..', 'web_dashboard');
const read = name => fs.readFileSync(path.join(web, name), 'utf8');
const uid = 'user-1';
// Wednesday 2026-11-25 12:00 Taipei.
const NOW = Date.parse('2026-11-25T04:00:00.000Z');

function session(overrides = {}) {
  const fingerprint = overrides.activityFingerprint || `fp-${Math.random()}`;
  const id = crypto.createHash('sha256').update(fingerprint).digest('hex');
  return {
    id,
    data: {
      activitySessionId: 's-1', activityFingerprint: fingerprint, actorUserId: uid, status: 'completed',
      activityType: 'focus', metricValue: 30, metricUnit: 'minutes', source: 'web',
      startedAt: '2026-11-24T01:00:00.000Z', endedAt: '2026-11-24T01:30:00.000Z',
      ...overrides,
    },
  };
}
const parse = s => garden.parseSession(s.id, s.data, uid, NOW);

test('each activity type grows its own plant', () => {
  assert.equal(garden.plantForType('focus').id, 'flower');
  assert.equal(garden.plantForType('study').id, 'flower');
  assert.equal(garden.plantForType('exercise').id, 'tree');
  assert.equal(garden.plantForType('sleep').id, 'moonflower');
  assert.equal(garden.plantForType('steps').id, 'meadow');
  assert.equal(garden.plantForType('task'), null);
  for (const p of garden.PLANTS) assert.equal(p.thresholds.length, garden.STAGES);
});

test('stages run 0 to 5 by weekly total', () => {
  assert.equal(garden.stageFor('flower', 0), 0);
  assert.equal(garden.stageFor('flower', -3), 0);
  assert.equal(garden.stageFor('flower', NaN), 0);
  assert.equal(garden.stageFor('flower', 1), 1);
  assert.equal(garden.stageFor('flower', 24.9), 1);
  assert.equal(garden.stageFor('flower', 25), 2);
  assert.equal(garden.stageFor('flower', 300), 5);
  assert.equal(garden.stageFor('flower', 9999), 5);
  assert.equal(garden.stageFor('meadow', 19999), 2);
  assert.equal(garden.stageFor('moonflower', 49), 5);
  assert.deepEqual(garden.nextStage('flower', 30), { stage: 3, need: 45 });
  assert.equal(garden.nextStage('tree', 500), null);
  assert.equal(garden.stageName('tree', 5), '大樹');
  assert.equal(garden.stageName('flower', 0), '空土');
});

test('weeks start on Monday at 05:00 Taipei', () => {
  // Monday 2026-11-23 05:00 Taipei = 2026-11-22T21:00Z.
  const monday = Date.parse('2026-11-22T21:00:00.000Z');
  assert.equal(garden.weekStart(NOW), monday);
  assert.equal(garden.weekStart(monday), monday);
  // Monday 04:59 Taipei still belongs to the previous week.
  assert.equal(garden.weekStart(monday - 60000), monday - 7 * 86400000);
  assert.equal(garden.dayKey(monday - 60000), '2026-11-22');
  assert.equal(garden.dayKey(monday), '2026-11-23');
  assert.equal(garden.weekRange(monday), '11/23–11/29');
  assert.deepEqual(garden.weekNumber(monday), { year: 2026, week: 48 });
  const win = garden.weekWindow(NOW);
  assert.equal(win.weeks.length, garden.WEEKS_SHOWN);
  assert.equal(win.weeks.at(-1), monday);
  assert.equal(win.start, new Date(monday - 5 * 7 * 86400000).toISOString());
  assert.equal(win.end, new Date(NOW).toISOString());
  assert.throws(() => garden.weekWindow('nope'));
});

test('seasons follow the Taipei calendar month', () => {
  assert.equal(garden.season(Date.parse('2026-03-01T00:00:00.000Z')).id, 'spring');
  assert.equal(garden.season(Date.parse('2026-07-15T00:00:00.000Z')).id, 'summer');
  assert.equal(garden.season(NOW).id, 'autumn');
  // 2026-11-30 17:00Z is already 12-01 in Taipei.
  assert.equal(garden.season(Date.parse('2026-11-30T17:00:00.000Z')).id, 'winter');
  assert.equal(garden.season(Date.parse('2026-02-10T00:00:00.000Z')).id, 'winter');
});

test('only the signed-in user\'s completed, well-formed sessions count', () => {
  const ok = parse(session());
  assert.equal(ok.row.plant, 'flower');
  assert.equal(ok.row.value, 30);
  assert.equal(ok.row.day, '2026-11-24');
  assert.equal(parse(session({ actorUserId: 'someone-else' })), null);
  assert.equal(parse(session({ status: 'active' })), null);
  assert.equal(parse(session({ metricUnit: 'hours' })), null);
  assert.equal(parse(session({ metricValue: -1 })), null);
  assert.equal(parse(session({ metricValue: 5000 })), null);
  assert.equal(parse(session({ source: 'mystery' })), null);
  assert.equal(parse(session({ endedAt: '2026-12-01T00:00:00.000Z' })), null, 'future');
  assert.equal(parse(session({ startedAt: '2026-11-24T02:00:00.000Z' })), null, 'starts after it ends');
  assert.equal(parse(session({ endedAt: '2026-11-24 01:30' })), null);
  assert.equal(garden.parseSession('not-a-hash', session().data, uid, NOW), null);
  assert.deepEqual(parse(session({ activityType: 'task', metricUnit: 'completion', metricValue: 1 })), { ignored: true });
  assert.deepEqual(parse(session({ activityType: 'custom' })), { ignored: true });
  assert.equal(parse(session({ activityType: 'sleep', metricUnit: 'hours', metricValue: 7 })).row.plant, 'moonflower');
});

test('garden grows one plot per kind and week, each session once', () => {
  const { weeks } = garden.weekWindow(NOW);
  const rows = [
    session({ activityFingerprint: 'a', metricValue: 30 }),
    session({ activityFingerprint: 'b', metricValue: 50, endedAt: '2026-11-25T01:00:00.000Z', startedAt: '2026-11-25T00:10:00.000Z' }),
    session({ activityFingerprint: 'a', metricValue: 30 }), // duplicate id
    session({ activityFingerprint: 'c', activityType: 'steps', metricUnit: 'steps', metricValue: 6000 }),
    session({ activityFingerprint: 'd', activityType: 'exercise', metricValue: 30,
      startedAt: '2026-11-17T01:00:00.000Z', endedAt: '2026-11-17T01:30:00.000Z' }),
    // Before the shown weeks: ignored.
    session({ activityFingerprint: 'e', startedAt: '2026-09-01T01:00:00.000Z', endedAt: '2026-09-01T01:30:00.000Z' }),
  ].map(parse).map(r => r.row);
  const beds = garden.grow(rows, weeks);
  assert.deepEqual(beds.map(b => b.plant), ['flower', 'tree', 'moonflower', 'meadow']);
  for (const bed of beds) assert.equal(bed.plots.length, weeks.length);
  const flowerNow = beds[0].plots.at(-1);
  assert.equal(flowerNow.count, 2);
  assert.equal(flowerNow.total, 80);
  assert.equal(flowerNow.stage, 3);
  assert.equal(flowerNow.days, 2);
  assert.ok(flowerNow.sessions[0].endedAt < flowerNow.sessions[1].endedAt);
  assert.equal(beds[1].plots.at(-2).stage, 2, 'last week\'s exercise grew last week\'s tree');
  assert.equal(beds[1].plots.at(-1).stage, 0);
  assert.equal(beds[3].plots.at(-1).stage, 2);
  assert.equal(beds[2].plots.every(p => p.stage === 0), true);
  const total = beds.flatMap(b => b.plots).reduce((n, p) => n + p.count, 0);
  assert.equal(total, 4);
});

test('a plant tells which week and which action grew it', () => {
  const { weeks } = garden.weekWindow(NOW);
  const rows = [parse(session({ activityFingerprint: 'x', metricValue: 30 })).row];
  const plot = garden.grow(rows, weeks)[0].plots.at(-1);
  assert.equal(garden.describe(plot),
    '第 48 週（11/23–11/29）由 1 筆雲端確認的專注紀錄（1 天、共 30 分鐘）長出，現在是第 2 階段「嫩芽」。');
  const empty = garden.grow([], weeks)[2].plots[0];
  assert.match(garden.describe(empty), /還沒有雲端確認的睡眠紀錄/);
});

test('garden page keeps the gate, reads only its own sessions and never writes', () => {
  const html = read('garden.html');
  assert.match(html, /<body class="w-page"/);
  assert.match(html, /role="dialog"/);
  assert.match(html, /雲端確認中/);
  const js = read('assets/garden.js');
  assert.match(js, /core\.access\(data\?\.avatarLevel\)/);
  assert.match(js, /where\('actorUserId', '==', uid\)/);
  assert.match(js, /where\('status', '==', 'completed'\)/);
  assert.doesNotMatch(js, /\.(set|update|delete)\(|\.collection\([^)]*\)\.add\(|httpsCallable|batch\(|runTransaction/);
  assert.doesNotMatch(js, /localStorage\.setItem/);
  const css = read('assets/garden.css');
  assert.match(css, /prefers-reduced-motion/);
  assert.match(css, /image-rendering: pixelated/);
  assert.doesNotMatch(css, /#[0-9a-f]{3,8}\b/i, 'only --w-* colour tokens');
  for (const p of garden.PLANTS) assert.ok(fs.existsSync(path.join(web, 'assets', p.sprite)), p.sprite);
  assert.ok(fs.existsSync(path.join(web, 'assets/garden/garden_plot_bg.png')));
});
