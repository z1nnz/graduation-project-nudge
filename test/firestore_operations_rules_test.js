const assert = require("node:assert/strict");

const projectId = "nudge-discipline-app";
const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST;
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;

if (!firestoreHost || !authHost) {
  console.log(
    "Firestore operations rules integration test skipped: emulators are not enabled.",
  );
  process.exit(0);
}

const firestoreBase =
  `http://${firestoreHost}/v1/projects/${projectId}` +
  "/databases/(default)/documents";

async function signUp() {
  const response = await fetch(
    `http://${authHost}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-key`,
    {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        email: `operations-${Date.now()}@example.test`,
        password: "correct-horse-battery-staple",
        returnSecureToken: true,
      }),
    },
  );
  assert.equal(response.status, 200, await response.clone().text());
  return response.json();
}

async function request(path, token, options = {}) {
  return fetch(`${firestoreBase}/${path}`, {
    ...options,
    headers: {
      authorization: `Bearer ${token}`,
      "content-type": "application/json",
      ...(options.headers || {}),
    },
  });
}

async function run() {
  const account = await signUp();
  for (const path of [
    "relationship_migration_before_images/client-write",
    "relationship_before_image_privacy_deletions/client-write",
    "production_acceptance_evidence/client-write",
    "migration_runs/client-write",
  ]) {
    const write = await request(path, account.idToken, {
      method: "PATCH",
      body: JSON.stringify({
        fields: { injected: { booleanValue: true } },
      }),
    });
    assert.equal(write.status, 403, `${path} must reject client writes`);

    const read = await request(path, account.idToken);
    assert.equal(read.status, 403, `${path} must reject client reads`);
  }
  console.log("Firestore operations rules integration test passed.");
}

run().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
