import assert from "node:assert/strict";
import test from "node:test";

import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST;
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;
const functionsHost =
  process.env.FUNCTIONS_EMULATOR_HOST || "127.0.0.1:5001";
const functionsEnabled = process.env.NUDGE_FUNCTIONS_E2E === "1";
const appCheckJwt = process.env.NUDGE_APP_CHECK_JWT || "";
const emulatorEnabled = Boolean(
  firestoreHost && authHost && functionsEnabled,
);
const projectId = "nudge-discipline-app";

async function signUp(label) {
  const response = await fetch(
    `http://${authHost}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-key`,
    {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        email: `${label}-${Date.now()}-${Math.random()}@example.test`,
        password: "correct-horse-battery-staple",
        returnSecureToken: true,
      }),
    },
  );
  assert.equal(response.status, 200, await response.clone().text());
  return response.json();
}

test(
  "a real authenticated account needs App Check to register a secret push token",
  { skip: !emulatorEnabled },
  async () => {
    const app = initializeApp(
      { projectId },
      `push-installation-callable-e2e-${Date.now()}`,
    );
    const firestore = getFirestore(app);
    const account = await signUp("push-installation-account");
    const installationId = `device_${Date.now()}`;
    const clientRequestId = `push-request-${Date.now()}`;
    const token = `e2e-fcm-token-${Date.now()}-long-enough-for-validation`;

    const response = await fetch(
      `http://${functionsHost}/${projectId}/asia-east1/updatePushInstallation`,
      {
        method: "POST",
        headers: {
          authorization: `Bearer ${account.idToken}`,
          "content-type": "application/json",
          ...(appCheckJwt
            ? { "x-firebase-appcheck": appCheckJwt }
            : {}),
        },
        body: JSON.stringify({
          data: {
            action: "register",
            installationId,
            platform: "android",
            token,
            clientRequestId,
          },
        }),
      },
    );
    const responseBody = await response.json();
    const installationRef = firestore
      .collection("push_installations")
      .doc(`${account.localId}--${installationId}`);
    if (!appCheckJwt) {
      assert.equal(response.status, 401, JSON.stringify(responseBody));
      assert.equal(responseBody.error?.status, "UNAUTHENTICATED");
      assert.equal((await installationRef.get()).exists, false);
      return;
    }

    assert.equal(response.status, 200, JSON.stringify(responseBody));
    const result = responseBody.result ?? responseBody.data;
    assert.equal(result.installationId, installationId);
    assert.equal(result.configured, true);
    const installation = await installationRef.get();
    assert.equal(installation.exists, true);
    assert.equal(installation.data().token, token);
    const audit = await firestore
      .collection("audit_events")
      .doc(
        `push-installation--${account.localId}--${clientRequestId}`,
      )
      .get();
    assert.equal(audit.exists, true);
    assert.equal(JSON.stringify(audit.data()).includes(token), false);
  },
);
