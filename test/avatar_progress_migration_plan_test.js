const test = require('node:test');
const assert = require('node:assert/strict');
const catalog = (key, name) => ({ id: key, data: {
  type: 'avatar_series', series_key: key, series_name: name,
} });
const user = ledger => ({ id: 'user-1', data: {
  avatarSeries: '夜影', avatarExperienceLedger: ledger,
} });

test('progress preflight preserves exact XP and never writes or enables apply', async () => {
  const { buildAvatarProgressMigrationPlan: plan } = await import('../scripts/avatar_progress_migration_plan.mjs');
  const input = { catalogs: [catalog('night', '夜影')], users: [user({ day: { 夜影: 100, 星辰旅人: 20 } })] };
  const before = structuredClone(input);
  const result = plan(input);
  assert.deepEqual(input, before);
  assert.equal(result.readyForApply, false);
  assert.equal(result.issues.length, 0);
  assert.equal(result.updates[0].after.avatarSeries, 'night');
  assert.deepEqual(result.updates[0].after.avatarExperienceLedger, { day: { night: 100, 星辰旅人: 20 } });
  const replay = plan({ catalogs: input.catalogs, users: [{ id: 'user-1', data: result.updates[0].after }] });
  assert.equal(replay.updates.length, 0);
});

test('ambiguous names and overlapping keys fail closed without guessing XP', async () => {
  const { buildAvatarProgressMigrationPlan: plan } = await import('../scripts/avatar_progress_migration_plan.mjs');
  for (const input of [
    { catalogs: [catalog('same', '夜影'), catalog('same', '另一角色')], users: [user({ day: { 夜影: 100 } })] },
    { catalogs: [catalog('a', '夜影'), catalog('b', '夜影')], users: [user({ day: { 夜影: 100 } })] },
    { catalogs: [catalog('night', '夜影')], users: [user({ day: { 夜影: 100, night: 20 } })] },
    { catalogs: [catalog('night', '夜影')], users: [user({ day: { 夜影: -1 } })] },
  ]) {
    const result = plan(input);
    assert.ok(result.issues.length > 0);
    assert.equal(result.updates.length, 0);
  }
});
