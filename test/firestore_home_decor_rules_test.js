const assert = require('node:assert/strict');
const projectId = 'nudge-discipline-app';
const host = process.env.FIRESTORE_EMULATOR_HOST;
const auth = process.env.FIREBASE_AUTH_EMULATOR_HOST;
if (!host || !auth) {
  console.log('Home decor rules integration skipped: emulators not enabled.');
  process.exit(0);
}
for (const endpoint of [host, auth]) {
  assert.match(endpoint, /^(?:127\.0\.0\.1|localhost):\d+$/, 'Only loopback emulators are allowed');
}
const base = `http://${host}/v1/projects/${projectId}/databases/(default)/documents`;
async function signup(label) {
  const response = await fetch(`http://${auth}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake`, {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ email: `${label}-${Date.now()}@example.test`, password: 'test-password-only', returnSecureToken: true }),
  });
  assert.equal(response.status, 200, await response.clone().text());
  return response.json();
}
const decor = (rug, curtain, lamp) => ({ mapValue: { fields: {
  rug: { integerValue: String(rug) }, curtain: { integerValue: String(curtain) }, lamp: { integerValue: String(lamp) },
} } });
async function patch(path, mask, fields, token) {
  return fetch(`${base}/${path}?updateMask.fieldPaths=${mask}`, {
    method: 'PATCH', headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
    body: JSON.stringify({ fields }),
  });
}
async function run() {
  const user = await signup('decor-owner');
  const path = `users/${user.localId}`;
  // The emulator-only owner token seeds the Cloud-owned profile fixture.
  const seed = await fetch(`${base}/${path}`, {
    method: 'PATCH', headers: { authorization: 'Bearer owner', 'content-type': 'application/json' },
    body: JSON.stringify({ fields: {
      nickname: { stringValue: 'Decor owner' },
      homeDecor: decor(0, 0, 0),
    } }),
  });
  assert.equal(seed.status, 200, await seed.clone().text());
  const forged = await patch(path, 'homeDecor', { homeDecor: decor(2, 2, 2) }, user.idToken);
  assert.equal(forged.status, 403, 'Users cannot arrange decor without the Cloud callable');
  const own = await patch(path, 'nickname', { nickname: { stringValue: 'Renamed' } }, user.idToken);
  assert.equal(own.status, 200, await own.clone().text());
  console.log('PASS: homeDecor is Cloud-only while ordinary profile edits still work.');
}
run().catch(error => { console.error(error); process.exitCode = 1; });
