const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const { parse } = require('../web_dashboard/assets/confirmed_activity_feedback.js');
for (const fixture of require('./fixtures/confirmed_activity_feedback.json')) {
  test(`receipt feedback: ${fixture.name}`, () => {
    const result = parse('receipt-1', {
      receiptId: 'receipt-1', actorUserId: 'user-1', activityType: 'focus',
      acceptedMetric: 25, verifiedAt: '2026-11-22T06:00:00.000Z', ...fixture.patch,
    }, 'user-1');
    assert.equal(result !== null, fixture.valid);
    if (result) assert.equal(result.label, fixture.label);
  });
}
test('receipt query index and Cloud-only write rule remain explicit', () => {
  const indexes = JSON.parse(fs.readFileSync('firestore.indexes.json', 'utf8')).indexes;
  assert.ok(indexes.some(i => i.collectionGroup === 'activity_receipts' &&
    i.fields[0].fieldPath === 'actorUserId' && i.fields[1].fieldPath === 'verifiedAt' && i.fields[1].order === 'DESCENDING'));
  const rules = fs.readFileSync('firestore.rules', 'utf8');
  assert.match(rules, /match \/activity_receipts\/\{receiptId\}[\s\S]*?allow write: if false;/);
});
