const assert = require('node:assert/strict');
const projectId = 'nudge-discipline-app';
const host = process.env.FIRESTORE_EMULATOR_HOST;
const auth = process.env.FIREBASE_AUTH_EMULATOR_HOST;
if (!host || !auth) {
  console.log('Activity feedback rules integration skipped: emulators not enabled.');
  process.exit(0);
}
for (const endpoint of [host, auth]) {
  assert.match(endpoint, /^(?:127\.0\.0\.1|localhost):\d+$/, 'Only loopback emulators are allowed');
}
const base = `http://${host}/v1/projects/${projectId}/databases/(default)/documents`;
function receiptFields(id, actor, date) {
  return {
    receiptId: { stringValue: id }, actorUserId: { stringValue: actor },
    verifiedAt: { stringValue: date }, activityType: { stringValue: 'focus' },
    acceptedMetric: { integerValue: '25' }, metricUnit: { stringValue: 'minutes' },
    eventId: { stringValue: `${id}-event` }, sourceRecordId: { stringValue: `${id}-source` },
    activitySessionId: { stringValue: `${id}-session` }, activityFingerprint: { stringValue: `${id}-fingerprint` },
    rewardEligible: { booleanValue: false }, rewardIssued: { booleanValue: false },
    characterExperienceEligible: { booleanValue: false }, characterExperienceIssued: { booleanValue: false },
    rewardEntryId: { nullValue: null }, correctionOfReceiptId: { nullValue: null },
  };
}
async function signup(label) {
  const response = await fetch(`http://${auth}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake`, {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ email: `${label}-${Date.now()}@example.test`, password: 'test-password-only', returnSecureToken: true }),
  });
  assert.equal(response.status, 200, await response.clone().text());
  return response.json();
}
async function query(actor, token) {
  return fetch(`${base}:runQuery`, { method: 'POST',
    headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
    body: JSON.stringify({ structuredQuery: {
      from: [{ collectionId: 'activity_receipts' }],
      where: { fieldFilter: { field: { fieldPath: 'actorUserId' }, op: 'EQUAL', value: { stringValue: actor } } },
      orderBy: [{ field: { fieldPath: 'verifiedAt' }, direction: 'DESCENDING' }], limit: 1,
    } }),
  });
}
async function run() {
  const owner = await signup('feedback-owner');
  const outsider = await signup('feedback-outsider');
  const prefix = `feedback-${Date.now()}`;
  // The emulator-only owner token seeds Cloud-owned fixtures; never used
  // against production (both emulator hosts are mandatory above).
  for (const [suffix, date] of [['old', '2026-11-21T06:00:00.000Z'], ['new', '2026-11-22T06:00:00.000Z']]) {
    const id = `${prefix}-${suffix}`;
    const response = await fetch(`${base}/activity_receipts/${id}`, {
      method: 'PATCH', headers: { authorization: 'Bearer owner', 'content-type': 'application/json' },
      body: JSON.stringify({ fields: receiptFields(id, owner.localId, date) }),
    });
    assert.equal(response.status, 200, await response.clone().text());
  }
  const ownQuery = await query(owner.localId, owner.idToken);
  assert.equal(ownQuery.status, 200, await ownQuery.clone().text());
  const rows = (await ownQuery.json()).filter(row => row.document);
  assert.equal(rows.length, 1);
  assert.ok(rows[0].document.name.endsWith(`${prefix}-new`));
  const denied = await query(owner.localId, outsider.idToken);
  assert.equal(denied.status, 403, await denied.clone().text());
  const otherOwn = await query(outsider.localId, outsider.idToken);
  assert.equal(otherOwn.status, 200, await otherOwn.clone().text());
  assert.equal((await otherOwn.json()).filter(row => row.document).length, 0);
  const path = `${base}/activity_receipts/${prefix}-new`;
  const create = await fetch(`${base}/activity_receipts/${prefix}-forged`, {
    method: 'PATCH', headers: { authorization: `Bearer ${owner.idToken}`, 'content-type': 'application/json' },
    body: JSON.stringify({ fields: receiptFields(`${prefix}-forged`, owner.localId, '2026-11-22T06:00:00.000Z') }),
  });
  assert.equal(create.status, 403, 'Owner cannot create a confirmation receipt');
  const metricUpdate = await fetch(`${path}?updateMask.fieldPaths=acceptedMetric`, {
    method: 'PATCH', headers: { authorization: `Bearer ${owner.idToken}`, 'content-type': 'application/json' },
    body: JSON.stringify({ fields: { acceptedMetric: { integerValue: '999' } } }),
  });
  assert.equal(metricUpdate.status, 403, 'Owner cannot forge metrics while retaining receipt ownership');
  assert.equal((await fetch(path)).status, 403, 'Unauthenticated reads must fail');
  for (const [method, token] of [['PATCH', owner.idToken], ['DELETE', owner.idToken], ['PATCH', outsider.idToken]]) {
    const response = await fetch(path, { method,
      headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
      ...(method === 'PATCH' ? { body: JSON.stringify({ fields: { actorUserId: { stringValue: outsider.localId } } }) } : {}),
    });
    assert.equal(response.status, 403, `${method} receipt must be Cloud-only`);
  }
  console.log('PASS: latest receipt query, own-account isolation, and Cloud-only mutations.');
}
run().catch(error => { console.error(error); process.exitCode = 1; });
