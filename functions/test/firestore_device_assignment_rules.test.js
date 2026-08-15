import assert from "node:assert/strict";
import test from "node:test";

import { deleteApp, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST;
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;
const emulatorEnabled = Boolean(firestoreHost && authHost);
const projectId = "nudge-discipline-app";
const firestoreBase =
  `http://${firestoreHost}/v1/projects/${projectId}` +
  "/databases/(default)/documents";

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

function request(path, token, options = {}) {
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
  "device assignment is owner-readable and always Cloud-written",
  { skip: !emulatorEnabled },
  async () => {
    const suffix = `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
    const app = initializeApp(
      { projectId },
      `device-assignment-rules-${suffix}`,
    );
    const firestore = getFirestore(app);
    const owner = await signUp("device-owner");
    const outsider = await signUp("device-outsider");
    const staff = await signUp("device-staff");
    const deviceId = `nudge-${suffix}`;
    const path = `device_assignments/${deviceId}`;
    const lockPath = `device_transfer_locks/${deviceId}`;
    try {
      await firestore.collection("users").doc(staff.localId).set({
        staffRole: "admin",
      });
      await firestore.collection("device_assignments").doc(deviceId).set({
        schemaVersion: 1,
        assignmentId: deviceId,
        deviceId,
        assignedUserId: owner.localId,
        status: "active",
        allowedRoomIds: [],
        validFrom: "2026-08-15T10:00:00.000Z",
        validUntil: null,
        updatedAt: "2026-08-15T10:00:00.000Z",
      });

      assert.equal((await request(path, owner.idToken)).status, 200);
      assert.equal((await request(path, outsider.idToken)).status, 403);
      assert.equal((await request(path, staff.idToken)).status, 200);
      assert.equal(
        (await request(path, owner.idToken, {
          method: "PATCH",
          body: JSON.stringify({
            fields: { status: { stringValue: "revoked" } },
          }),
        })).status,
        403,
      );
      await firestore.collection("device_transfer_locks").doc(deviceId).set({
        schemaVersion: 1,
        deviceId,
        status: "wipe_required",
        reason: "account_deletion",
        lockedAt: "2026-08-15T10:00:00.000Z",
        updatedAt: "2026-08-15T10:00:00.000Z",
      });
      assert.equal((await request(lockPath, owner.idToken)).status, 403);
      assert.equal((await request(lockPath, outsider.idToken)).status, 403);
      assert.equal((await request(lockPath, staff.idToken)).status, 200);
      assert.equal(
        (await request(lockPath, staff.idToken, {
          method: "DELETE",
        })).status,
        403,
      );
    } finally {
      await firestore.collection("device_assignments").doc(deviceId).delete();
      await firestore.collection("device_transfer_locks").doc(deviceId).delete();
      await firestore.collection("users").doc(staff.localId).delete();
      await deleteApp(app);
    }
  },
);
