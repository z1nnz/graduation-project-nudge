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
  if (Number.isInteger(value)) return { integerValue: String(value) };
  if (typeof value === "number") return { doubleValue: value };
  if (Array.isArray(value)) {
    return { arrayValue: { values: value.map(valueOf) } };
  }
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
  "Activity Ledger documents are Cloud-written and relationship-readable",
  { skip: !emulatorEnabled },
  async () => {
    const app = initializeApp({ projectId });
    const firestore = getFirestore(app);
    const actor = await signUp("ledger-actor");
    const roomMember = await signUp("ledger-room-member");
    const outsider = await signUp("ledger-outsider");
    const unique = `${Date.now()}-${Math.random().toString(16).slice(2)}`;
    const roomId = `ledger-room-${unique}`;
    const eventId = `ledger-event-${unique}`;
    const contributionId = `ledger-contribution-${unique}`;

    await firestore.collection("rooms").doc(roomId).set({
      schemaVersion: 2,
      id: roomId,
      ownerId: actor.localId,
      memberIds: [actor.localId, roomMember.localId],
      status: "active",
    });
    await Promise.all(
      [actor.localId, roomMember.localId].map(userId =>
        firestore
          .collection("rooms")
          .doc(roomId)
          .collection("members")
          .doc(userId)
          .set({
            memberId: userId,
            approvalStatus: "approved",
            role: userId === actor.localId ? "owner" : "member",
          }),
      ),
    );
    await firestore.collection("activity_events").doc(eventId).set({
      actorUserId: actor.localId,
      eventType: "completed",
    });
    await firestore
      .collection("room_contributions")
      .doc(contributionId)
      .set({
        actorUserId: actor.localId,
        roomId,
        metricValue: 25,
      });

    assert.equal(
      (await request(`activity_events/${eventId}`, actor.idToken)).status,
      200,
    );
    assert.equal(
      (await request(`activity_events/${eventId}`, outsider.idToken)).status,
      403,
    );
    assert.equal(
      (
        await request(`room_contributions/${contributionId}`, roomMember.idToken)
      ).status,
      200,
    );
    assert.equal(
      (
        await request(`room_contributions/${contributionId}`, outsider.idToken)
      ).status,
      403,
    );
    assert.equal(
      (
        await request(`activity_events/client-write-${unique}`, actor.idToken, {
          method: "PATCH",
          body: JSON.stringify({
            fields: fieldsOf({
              actorUserId: actor.localId,
              eventType: "completed",
            }),
          }),
        })
      ).status,
      403,
    );
  },
);
