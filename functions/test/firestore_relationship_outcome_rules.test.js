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
  "relationship outcomes and memories are Cloud-written and membership-readable",
  { skip: !emulatorEnabled },
  async () => {
    const app = initializeApp(
      { projectId },
      `relationship-outcome-rules-${Date.now()}`,
    );
    const firestore = getFirestore(app);
    const member = await signUp("outcome-member");
    const formerMember = await signUp("outcome-former-member");
    const outsider = await signUp("outcome-outsider");
    const unique = `${Date.now()}-${Math.random().toString(16).slice(2)}`;
    const scopeId = `family-${unique}`;
    const outcomeId = `family--${scopeId}`;
    const memoryId = `goal_completed--goal-${unique}`;

    await Promise.all(
      [
        [member.localId, "active"],
        [formerMember.localId, "ended"],
      ].map(([userId, status]) =>
        firestore
          .collection("relationship_memberships")
          .doc(`family--${scopeId}--${userId}`)
          .set({
            membershipId: `family--${scopeId}--${userId}`,
            scopeType: "family",
            scopeId,
            userId,
            role: "child",
            status,
          }),
      ),
    );
    const outcomeRef = firestore
      .collection("relationship_outcomes")
      .doc(outcomeId);
    await outcomeRef.set({
      outcomeId,
      scopeType: "family",
      scopeId,
      growth: { kind: "family_tree", xp: 10, level: 2 },
    });
    await outcomeRef.collection("memories").doc(memoryId).set({
      memoryId,
      scopeType: "family",
      scopeId,
      title: "一起完成了一個共同目標",
    });

    assert.equal(
      (await request(`relationship_outcomes/${outcomeId}`, member.idToken))
        .status,
      200,
    );
    assert.equal(
      (
        await request(
          `relationship_outcomes/${outcomeId}`,
          formerMember.idToken,
        )
      ).status,
      200,
    );
    assert.equal(
      (
        await request(
          `relationship_outcomes/${outcomeId}/memories/${memoryId}`,
          member.idToken,
        )
      ).status,
      200,
    );
    assert.equal(
      (await request(`relationship_outcomes/${outcomeId}`, outsider.idToken))
        .status,
      403,
    );
    assert.equal(
      (
        await request(
          `relationship_outcomes/family--client-${unique}`,
          member.idToken,
          {
            method: "PATCH",
            body: JSON.stringify({
              fields: fieldsOf({
                outcomeId: `family--client-${unique}`,
                scopeType: "family",
                scopeId,
              }),
            }),
          },
        )
      ).status,
      403,
    );
  },
);
