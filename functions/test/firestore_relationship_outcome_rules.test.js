import assert from "node:assert/strict";
import test from "node:test";

import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

import {
  createRefreshRelationshipOutcomeHandler,
} from "../src/relationship-outcome-service.js";

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

async function setRelationshipMembership(
  firestore,
  { scopeType, scopeId, userId, role, status = "active" },
) {
  const membershipId = `${scopeType}--${scopeId}--${userId}`;
  await firestore.collection("relationship_memberships").doc(membershipId).set({
    schemaVersion: 1,
    membershipId,
    scopeType,
    scopeId,
    userId,
    role,
    status,
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

test(
  "relationship outcome refresh requires every formal Membership and role",
  { skip: !emulatorEnabled },
  async () => {
    const app = initializeApp(
      { projectId },
      `relationship-outcome-membership-${Date.now()}`,
    );
    const firestore = getFirestore(app);
    const unique = `${Date.now()}-${Math.random().toString(16).slice(2)}`;
    const scopeId = `family-${unique}`;
    const guardianId = `guardian-${unique}`;
    const childId = `child-${unique}`;

    await firestore.collection("family_links").doc(scopeId).set({
      familyLinkId: scopeId,
      guardianId,
      childId,
      participantIds: [guardianId, childId],
      status: "active",
    });
    await setRelationshipMembership(firestore, {
      scopeType: "family",
      scopeId,
      userId: guardianId,
      role: "guardian",
    });

    const handler = createRefreshRelationshipOutcomeHandler({
      firestore,
      clock: () => new Date("2026-07-29T06:00:00.000Z"),
    });
    await assert.rejects(
      () =>
        handler({
          auth: { uid: guardianId },
          data: { scopeType: "family", scopeId },
        }),
      error => error.code === "permission-denied",
    );

    await setRelationshipMembership(firestore, {
      scopeType: "family",
      scopeId,
      userId: childId,
      role: "guardian",
    });
    await assert.rejects(
      () =>
        handler({
          auth: { uid: guardianId },
          data: { scopeType: "family", scopeId },
        }),
      error => error.code === "permission-denied",
    );

    await setRelationshipMembership(firestore, {
      scopeType: "family",
      scopeId,
      userId: childId,
      role: "child",
    });
    const result = await handler({
      auth: { uid: guardianId },
      data: { scopeType: "family", scopeId },
    });
    assert.equal(result.outcome.scopeType, "family");
    assert.equal(result.outcome.scopeId, scopeId);
    assert.equal(result.outcome.refreshedBy, guardianId);
    assert.deepEqual(result.outcome.participantIds, [childId, guardianId]);
  },
);

test(
  "relationship outcome refresh aborts when any participant is deleting",
  { skip: !emulatorEnabled },
  async () => {
    const app = initializeApp(
      { projectId },
      `relationship-outcome-fence-${Date.now()}`,
    );
    const firestore = getFirestore(app);
    const unique = `${Date.now()}-${Math.random().toString(16).slice(2)}`;
    const scopeId = `group-${unique}`;
    const memberId = `member-${unique}`;
    const deletingMemberId = `deleting-${unique}`;

    await firestore.collection("groups").doc(scopeId).set({
      groupId: scopeId,
      name: "刪除競態測試團體",
      status: "active",
      ownerId: memberId,
      memberIds: [memberId, deletingMemberId],
    });
    await Promise.all([
      setRelationshipMembership(firestore, {
        scopeType: "group",
        scopeId,
        userId: memberId,
        role: "manager",
      }),
      setRelationshipMembership(firestore, {
        scopeType: "group",
        scopeId,
        userId: deletingMemberId,
        role: "member",
      }),
    ]);
    await firestore
      .collection("account_deletion_fences")
      .doc(deletingMemberId)
      .set({
        schemaVersion: 1,
        requestId: `request-${unique}`,
        executionId: `execution-${unique}`,
        status: "deleting",
      });

    const handler = createRefreshRelationshipOutcomeHandler({
      firestore,
      clock: () => new Date("2026-07-29T06:00:00.000Z"),
    });
    await assert.rejects(
      () =>
        handler({
          auth: { uid: memberId },
          data: { scopeType: "group", scopeId },
        }),
      error => error.code === "failed-precondition",
    );
    assert.equal(
      (
        await firestore
          .collection("relationship_outcomes")
          .doc(`group--${scopeId}`)
          .get()
      ).exists,
      false,
    );
  },
);
