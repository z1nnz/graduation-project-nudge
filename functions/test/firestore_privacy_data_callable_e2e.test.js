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
  "a real authenticated account needs App Check for an audited deletion request",
  { skip: !emulatorEnabled },
  async () => {
    const app = initializeApp(
      { projectId },
      `privacy-data-callable-e2e-${Date.now()}`,
    );
    const firestore = getFirestore(app);
    const account = await signUp("privacy-data-account");
    const clientRequestId = `privacy-delete-${Date.now()}`;
    const requestId = `${account.localId}--${clientRequestId}`;

    const response = await fetch(
      `http://${functionsHost}/${projectId}/asia-east1/requestPrivacyDataAction`,
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
            action: "request_account_deletion",
            clientRequestId,
            sourceSurface: "app",
            reason: "real-account-e2e",
          },
        }),
      },
    );
    const responseBody = await response.json();
    const requestRef = firestore
      .collection("privacy_data_requests")
      .doc(requestId);
    if (!appCheckJwt) {
      assert.equal(response.status, 401, JSON.stringify(responseBody));
      assert.equal(responseBody.error?.status, "UNAUTHENTICATED");
      assert.equal((await requestRef.get()).exists, false);
      return;
    }

    assert.equal(response.status, 200, JSON.stringify(responseBody));
    const result = responseBody.result ?? responseBody.data;
    assert.equal(result.request.requestId, requestId);
    assert.equal(result.request.status, "pending");
    assert.equal((await requestRef.get()).exists, true);
    assert.equal(
      (
        await firestore
          .collection("audit_events")
          .doc(`privacy-data--${account.localId}--${clientRequestId}`)
          .get()
      ).exists,
      true,
    );
  },
);

test(
  "a real staff account needs App Check before executing account deletion",
  { skip: !emulatorEnabled },
  async () => {
    const app = initializeApp(
      { projectId },
      `account-deletion-callable-e2e-${Date.now()}`,
    );
    const firestore = getFirestore(app);
    const staff = await signUp("privacy-delete-staff");
    const subject = await signUp("privacy-delete-subject");
    const requestId = `${subject.localId}--privacy-delete-execute-001`;
    await firestore.collection("users").doc(staff.localId).set({
      staffRole: "operator",
    });
    await firestore.collection("users").doc(subject.localId).set({
      nickname: "應被刪除",
    });
    await firestore.collection("privacy_data_requests").doc(requestId).set({
      schemaVersion: 1,
      requestId,
      userId: subject.localId,
      type: "account_deletion",
      status: "in_review",
      reviewAfter: "2026-07-01T00:00:00.000Z",
      updatedAt: "2026-07-01T00:00:00.000Z",
    });

    const response = await fetch(
      `http://${functionsHost}/${projectId}/asia-east1/executeAccountDeletion`,
      {
        method: "POST",
        headers: {
          authorization: `Bearer ${staff.idToken}`,
          "content-type": "application/json",
          ...(appCheckJwt
            ? { "x-firebase-appcheck": appCheckJwt }
            : {}),
        },
        body: JSON.stringify({
          data: {
            requestId,
            clientRequestId: "privacy-execute-e2e-001",
            sourceSurface: "admin_web",
            caseId: "CASE-2026-E2E01",
            resolutionNote: "已完成正式環境刪除前核對",
            confirmation: "DELETE ACCOUNT",
          },
        }),
      },
    );
    const responseBody = await response.json();
    const requestSnapshot = await firestore
      .collection("privacy_data_requests")
      .doc(requestId)
      .get();
    if (!appCheckJwt) {
      assert.equal(response.status, 401, JSON.stringify(responseBody));
      assert.equal(requestSnapshot.data().status, "in_review");
      assert.equal(
        (await firestore.collection("users").doc(subject.localId).get()).exists,
        true,
      );
      return;
    }

    assert.equal(response.status, 200, JSON.stringify(responseBody));
    const result = responseBody.result ?? responseBody.data;
    assert.equal(result.request.status, "completed");
    assert.equal(result.request.caseId, "CASE-2026-E2E01");
    assert.equal(
      (await firestore.collection("users").doc(subject.localId).get()).exists,
      false,
    );
  },
);
