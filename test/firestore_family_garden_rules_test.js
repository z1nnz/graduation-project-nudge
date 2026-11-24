// Family garden documents are reachable only through the authenticated callable.
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
        email: `family-garden-${label}-${Date.now()}@example.test`,
        password: "integration-password",
        returnSecureToken: true,
      }),
    });
    assert.equal(response.status, 200);
    return response.json();
  }
  const [owner, other] = await Promise.all([signUp("owner"), signUp("other")]);
  const fields = {
    authorId: { stringValue: owner.localId },
    recipientId: { stringValue: other.localId },
    guardianId: { stringValue: owner.localId },
    childId: { stringValue: other.localId },
    userId: { stringValue: owner.localId },
  };
  function request(path, token, method = "GET") {
    return fetch(`${base}/${path}`, {
      method,
      headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
      body: method === "PATCH" ? JSON.stringify({ fields }) : undefined,
    });
  }
  for (const collection of ["family_weekly_notes", "family_letter_preferences", "family_scheduled_letters"]) {
    const path = collection + "/" + owner.localId;
    assert.equal((await request(path, "owner", "PATCH")).status, 200);
    for (const token of [owner.idToken, other.idToken]) {
      assert.equal((await request(path, token)).status, 403);
      assert.equal((await request(path, token, "PATCH")).status, 403);
    }
  }
}
main().catch(error => { console.error(error); process.exitCode = 1; });
