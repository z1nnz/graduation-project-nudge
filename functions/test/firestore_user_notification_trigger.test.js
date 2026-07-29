import assert from "node:assert/strict";
import test from "node:test";

import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST;
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;
const functionsEnabled = process.env.NUDGE_FUNCTIONS_E2E === "1";
const emulatorEnabled = Boolean(
  firestoreHost && authHost && functionsEnabled,
);
const projectId = "nudge-discipline-app";
const firestoreBase =
  `http://${firestoreHost}/v1/projects/${projectId}` +
  "/databases/(default)/documents";

function valueOf(value) {
  if (value === null) return { nullValue: null };
  if (typeof value === "string") return { stringValue: value };
  if (typeof value === "boolean") return { booleanValue: value };
  return { mapValue: { fields: fieldsOf(value) } };
}

function fieldsOf(data) {
  return Object.fromEntries(
    Object.entries(data).map(([key, value]) => [key, valueOf(value)]),
  );
}

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

async function waitForNotification(firestore, notificationId) {
  for (let attempt = 0; attempt < 50; attempt += 1) {
    const snapshot = await firestore
      .collection("user_notifications")
      .doc(notificationId)
      .get();
    if (snapshot.exists) return snapshot.data();
    await new Promise(resolve => setTimeout(resolve, 200));
  }
  throw new Error("Timed out waiting for the notification trigger.");
}

test(
  "a real authenticated family request becomes one Cloud inbox item",
  { skip: !emulatorEnabled },
  async () => {
    const app = initializeApp(
      { projectId },
      `user-notification-trigger-${Date.now()}`,
    );
    const firestore = getFirestore(app);
    const guardian = await signUp("notification-guardian");
    const child = await signUp("notification-child");
    const requestId = `guardian-request-${Date.now()}`;
    const notificationId = `family-request--${requestId}--pending`;
    const now = new Date().toISOString();

    const response = await fetch(
      `${firestoreBase}/guardian_requests/${requestId}`,
      {
        method: "PATCH",
        headers: {
          authorization: `Bearer ${guardian.idToken}`,
          "content-type": "application/json",
        },
        body: JSON.stringify({
          fields: fieldsOf({
            senderId: guardian.localId,
            senderNudgeId: "NDG-GUARDIAN",
            senderNickname: "家長",
            senderRole: "guardian",
            receiverId: child.localId,
            receiverNudgeId: "NDG-CHILD",
            receiverRole: "child",
            status: "pending",
            createdAt: now,
            updatedAt: now,
          }),
        }),
      },
    );
    assert.equal(response.status, 200, await response.clone().text());

    const notification = await waitForNotification(
      firestore,
      notificationId,
    );
    assert.equal(notification.recipientUserId, child.localId);
    assert.equal(notification.actorUserId, guardian.localId);
    assert.equal(notification.kind, "family_invitation");
    assert.equal(notification.status, "unread");
    const audit = await firestore
      .collection("audit_events")
      .doc(`family-request--${requestId}--created`)
      .get();
    assert.equal(audit.exists, true);
  },
);
