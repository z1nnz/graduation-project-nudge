import assert from "node:assert/strict";
import test from "node:test";

import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST;
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;
const emulatorEnabled = Boolean(firestoreHost && authHost);
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

test(
  "privacy consent and audit records are Cloud-written and owner-readable",
  { skip: !emulatorEnabled },
  async () => {
    const app = initializeApp(
      { projectId },
      `privacy-audit-rules-${Date.now()}`,
    );
    const firestore = getFirestore(app);
    const owner = await signUp("privacy-owner");
    const outsider = await signUp("privacy-outsider");
    const auditId = `privacy-consent--${owner.localId}--request-001`;

    await firestore.collection("privacy_consents").doc(owner.localId).set({
      schemaVersion: 1,
      userId: owner.localId,
      status: "accepted",
      policyVersion: "2026-07-29",
      scopes: { healthIngestion: true },
    });
    await firestore.collection("audit_events").doc(auditId).set({
      schemaVersion: 1,
      auditEventId: auditId,
      category: "privacy",
      action: "privacy.health.accept",
      actorUserId: owner.localId,
      targetType: "user",
      targetId: owner.localId,
    });
    await firestore
      .collection("notification_preferences")
      .doc(owner.localId)
      .set({
        schemaVersion: 1,
        userId: owner.localId,
        channels: {
          tasks: { enabled: true, timeLabel: "20:30" },
          sleep: { enabled: true, timeLabel: "23:00" },
          rooms: { enabled: true, timeLabel: "19:30" },
          deadline: { enabled: true, timeLabel: "09:00" },
        },
        delivery: {
          localScheduled: true,
          inApp: true,
          pushConfigured: false,
        },
      });
    const notificationId = `family-request--request-001--pending`;
    await firestore.collection("user_notifications").doc(notificationId).set({
      schemaVersion: 1,
      notificationId,
      recipientUserId: owner.localId,
      category: "relationship",
      kind: "family_invitation",
      status: "unread",
      createdAt: "2026-07-29T02:00:00.000Z",
    });
    const installationId = `${owner.localId}--device_12345678`;
    await firestore.collection("push_installations").doc(installationId).set({
      schemaVersion: 1,
      userId: owner.localId,
      installationId: "device_12345678",
      platform: "android",
      token: "server-only-fcm-token",
      tokenHash: "server-only-token-hash",
      status: "active",
    });
    await firestore.collection("push_delivery_state").doc(owner.localId).set({
      schemaVersion: 1,
      userId: owner.localId,
      activeInstallationIds: ["device_12345678"],
      configured: true,
    });
    await firestore.collection("push_delivery_jobs").doc(notificationId).set({
      schemaVersion: 1,
      jobId: notificationId,
      recipientUserId: owner.localId,
      status: "pending",
    });
    const privacyRequestId = `${owner.localId}--privacy-data-request-001`;
    await firestore
      .collection("privacy_data_requests")
      .doc(privacyRequestId)
      .set({
        schemaVersion: 1,
        requestId: privacyRequestId,
        userId: owner.localId,
        type: "export",
        status: "ready",
      });
    await firestore
      .collection("privacy_export_access")
      .doc(privacyRequestId)
      .set({
        schemaVersion: 1,
        requestId: privacyRequestId,
        userId: owner.localId,
        downloadToken: "server-only-download-token",
      });

    assert.equal(
      (
        await request(
          `privacy_consents/${owner.localId}`,
          owner.idToken,
        )
      ).status,
      200,
    );
    assert.equal(
      (
        await request(
          `privacy_consents/${owner.localId}`,
          outsider.idToken,
        )
      ).status,
      403,
    );
    assert.equal(
      (
        await request(
          `privacy_data_requests/${privacyRequestId}`,
          owner.idToken,
        )
      ).status,
      200,
    );
    assert.equal(
      (
        await request(
          `privacy_data_requests/${privacyRequestId}`,
          outsider.idToken,
        )
      ).status,
      403,
    );
    assert.equal(
      (
        await request(
          `privacy_export_access/${privacyRequestId}`,
          owner.idToken,
        )
      ).status,
      403,
    );
    assert.equal(
      (
        await request(
          `user_notifications/${notificationId}`,
          owner.idToken,
        )
      ).status,
      200,
    );
    assert.equal(
      (
        await request(
          `user_notifications/${notificationId}`,
          outsider.idToken,
        )
      ).status,
      403,
    );
    assert.equal(
      (
        await request(
          `privacy_data_requests/${privacyRequestId}`,
          owner.idToken,
          {
            method: "PATCH",
            body: JSON.stringify({
              fields: fieldsOf({
                status: "completed",
              }),
            }),
          },
        )
      ).status,
      403,
    );
    assert.equal(
      (await request(`audit_events/${auditId}`, owner.idToken)).status,
      200,
    );
    assert.equal(
      (await request(`audit_events/${auditId}`, outsider.idToken)).status,
      403,
    );
    assert.equal(
      (
        await request(
          `notification_preferences/${owner.localId}`,
          owner.idToken,
        )
      ).status,
      200,
    );
    assert.equal(
      (
        await request(
          `notification_preferences/${owner.localId}`,
          outsider.idToken,
        )
      ).status,
      403,
    );
    assert.equal(
      (
        await request(
          `push_delivery_state/${owner.localId}`,
          owner.idToken,
        )
      ).status,
      200,
    );
    assert.equal(
      (
        await request(
          `push_delivery_state/${owner.localId}`,
          outsider.idToken,
        )
      ).status,
      403,
    );
    assert.equal(
      (
        await request(
          `push_installations/${installationId}`,
          owner.idToken,
        )
      ).status,
      403,
    );
    assert.equal(
      (
        await request(
          `push_delivery_jobs/${notificationId}`,
          owner.idToken,
        )
      ).status,
      200,
    );
    assert.equal(
      (
        await request(
          `push_delivery_jobs/${notificationId}`,
          outsider.idToken,
        )
      ).status,
      403,
    );
    assert.equal(
      (
        await request(
          `privacy_consents/${owner.localId}`,
          owner.idToken,
          {
            method: "PATCH",
            body: JSON.stringify({
              fields: fieldsOf({
                status: "accepted",
                scopes: { healthIngestion: true },
              }),
            }),
          },
        )
      ).status,
      403,
    );
    assert.equal(
      (
        await request(
          `notification_preferences/${owner.localId}`,
          owner.idToken,
          {
            method: "PATCH",
            body: JSON.stringify({
              fields: fieldsOf({
                userId: owner.localId,
                channels: {
                  tasks: { enabled: false, timeLabel: "20:30" },
                },
              }),
            }),
          },
        )
      ).status,
      403,
    );
    assert.equal(
      (
        await request(
          `user_notifications/${notificationId}`,
          owner.idToken,
          {
            method: "PATCH",
            body: JSON.stringify({
              fields: fieldsOf({
                status: "read",
              }),
            }),
          },
        )
      ).status,
      403,
    );
    assert.equal(
      (
        await request(
          `push_delivery_state/${owner.localId}`,
          owner.idToken,
          {
            method: "PATCH",
            body: JSON.stringify({
              fields: fieldsOf({
                configured: false,
              }),
            }),
          },
        )
      ).status,
      403,
    );
    assert.equal(
      (
        await request(
          `push_installations/${installationId}`,
          owner.idToken,
          {
            method: "PATCH",
            body: JSON.stringify({
              fields: fieldsOf({
                token: "attacker-controlled-token",
              }),
            }),
          },
        )
      ).status,
      403,
    );
  },
);
