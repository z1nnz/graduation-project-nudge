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
const runQueryUrl =
  `http://${firestoreHost}/v1/projects/${projectId}` +
  "/databases/(default)/documents:runQuery";

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

function querySignals(roomId, token) {
  return fetch(runQueryUrl, {
    method: "POST",
    headers: {
      authorization: `Bearer ${token}`,
      "content-type": "application/json",
    },
    body: JSON.stringify({
      structuredQuery: {
        from: [{ collectionId: "room_resonance_signals" }],
        where: {
          fieldFilter: {
            field: { fieldPath: "roomId" },
            op: "EQUAL",
            value: { stringValue: roomId },
          },
        },
      },
    }),
  });
}

test(
  "room resonance stays private to its owner and approved room members",
  { skip: !emulatorEnabled },
  async () => {
    const suffix = `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
    const app = initializeApp(
      { projectId },
      `room-resonance-rules-${suffix}`,
    );
    const firestore = getFirestore(app);
    const owner = await signUp("resonance-owner");
    const member = await signUp("resonance-member");
    const outsider = await signUp("resonance-outsider");
    const roomId = `resonance-room-${suffix}`;
    const preferenceId = `${roomId}--${owner.localId}`;
    const signalId = `${roomId}--${owner.localId}`;
    const acknowledgementId = `${signalId}--generation--${member.localId}`;
    const preferencePath = `room_resonance_preferences/${preferenceId}`;
    const signalPath = `room_resonance_signals/${signalId}`;
    const acknowledgementPath =
      `room_resonance_acknowledgements/${acknowledgementId}`;
    try {
      await firestore.collection("rooms").doc(roomId).set({
        id: roomId,
        status: "active",
        memberIds: [owner.localId, member.localId],
      });
      await Promise.all([owner.localId, member.localId].map(userId =>
        firestore.collection("rooms").doc(roomId).collection("members")
          .doc(userId).set({
            memberId: userId,
            approvalStatus: "approved",
          })
      ));
      await firestore.collection("room_resonance_preferences")
        .doc(preferenceId).set({
          schemaVersion: 1,
          preferenceId,
          roomId,
          userId: owner.localId,
          enabled: true,
          audience: "room_members_only",
          shareMode: "cue_only",
        });
      await firestore.collection("room_resonance_signals").doc(signalId).set({
        schemaVersion: 1,
        signalId,
        roomId,
        ownerUserId: owner.localId,
        generationId: "generation",
        cueKey: "gentle_restart",
        status: "active",
        visibility: "room_members_only",
      });
      await firestore.collection("room_resonance_acknowledgements")
        .doc(acknowledgementId).set({
          schemaVersion: 1,
          acknowledgementId,
          roomId,
          signalId,
          signalOwnerUserId: owner.localId,
          actorUserId: member.localId,
          responseKey: "with_you",
        });

      assert.equal((await request(preferencePath, owner.idToken)).status, 200);
      assert.equal((await request(preferencePath, member.idToken)).status, 403);
      assert.equal((await request(signalPath, member.idToken)).status, 200);
      assert.equal((await request(signalPath, outsider.idToken)).status, 403);
      assert.equal((await querySignals(roomId, member.idToken)).status, 200);
      assert.equal((await querySignals(roomId, outsider.idToken)).status, 403);
      assert.equal(
        (await request(acknowledgementPath, owner.idToken)).status,
        200,
      );
      assert.equal(
        (await request(signalPath, owner.idToken, {
          method: "PATCH",
          body: JSON.stringify({ fields: fieldsOf({ status: "withdrawn" }) }),
        })).status,
        403,
      );
      assert.equal(
        (await request(acknowledgementPath, member.idToken, {
          method: "PATCH",
          body: JSON.stringify({
            fields: fieldsOf({ responseKey: "cheer" }),
          }),
        })).status,
        403,
      );

      await firestore.collection("rooms").doc(roomId).update({
        memberIds: [owner.localId],
      });
      await firestore.collection("rooms").doc(roomId).collection("members")
        .doc(member.localId).delete();
      assert.equal((await request(signalPath, member.idToken)).status, 403);
    } finally {
      await firestore.recursiveDelete(
        firestore.collection("rooms").doc(roomId),
      ).catch(() => {});
      await Promise.all([
        firestore.collection("room_resonance_preferences").doc(preferenceId)
          .delete().catch(() => {}),
        firestore.collection("room_resonance_signals").doc(signalId)
          .delete().catch(() => {}),
        firestore.collection("room_resonance_acknowledgements")
          .doc(acknowledgementId).delete().catch(() => {}),
      ]);
      await deleteApp(app);
    }
  },
);
