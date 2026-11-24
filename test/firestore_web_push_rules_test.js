// The browser can read its own settings; preference mutations and tokens stay behind Cloud Functions.
const assert = require("node:assert/strict");

async function main() {
  const auth = process.env.FIREBASE_AUTH_EMULATOR_HOST;
  const firestore = process.env.FIRESTORE_EMULATOR_HOST;
  if (!auth || !firestore) return;
  const project = "nudge-discipline-app";
  const base = `http://${firestore}/v1/projects/${project}/databases/(default)/documents`;
  async function signUp(label) {
    const response = await fetch(`http://${auth}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-key`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        email: `web-push-${label}-${Date.now()}@example.test`,
        password: "integration-password",
        returnSecureToken: true,
      }),
    });
    assert.equal(response.status, 200);
    return response.json();
  }
  const [owner, other] = await Promise.all([signUp("owner"), signUp("other")]);
  const path = `web_push_preferences/${owner.localId}`;
  const fields = { updatedAt: { stringValue: "2026-11-24T00:00:00Z" } };
  function request(path, token, method = "GET") {
    return fetch(`${base}/${path}`, {
      method,
      headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
      body: method === "PATCH" ? JSON.stringify({ fields }) : undefined,
    });
  }
  assert.equal((await request(path, "owner", "PATCH")).status, 200);
  assert.equal((await request(path, owner.idToken)).status, 200);
  assert.equal((await request(path, other.idToken)).status, 403);
  assert.equal((await request(path, owner.idToken, "PATCH")).status, 403);
  assert.equal((await request("web_push_preferences", owner.idToken)).status, 403);
  assert.equal((await request("push_installations/example", owner.idToken)).status, 403);
}
main().catch(error => { console.error(error); process.exitCode = 1; });
