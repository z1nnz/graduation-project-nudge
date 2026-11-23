// Emulator test for the room chat read marker: owner-only, approved-only,
// removed and outside accounts against the canonical room records that the
// scene, presence seat and leave flow read or write.
const assert = require("node:assert/strict");

const projectId = "nudge-discipline-app";
const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST;
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;

if (!firestoreHost || !authHost) {
  console.log(
    "Firestore room read marker rules integration test skipped: emulators are not enabled.",
  );
  process.exit(0);
}

const firestoreBase =
  `http://${firestoreHost}/v1/projects/${projectId}` +
  "/databases/(default)/documents";
const commitUrl = `${firestoreBase}:commit`;

function valueOf(value) {
  if (value === null) return { nullValue: null };
  if (typeof value === "string") return { stringValue: value };
  if (typeof value === "boolean") return { booleanValue: value };
  if (Number.isInteger(value)) return { integerValue: String(value) };
  if (typeof value === "number") return { doubleValue: value };
  if (Array.isArray(value)) return { arrayValue: { values: value.map(valueOf) } };
  return { mapValue: { fields: fieldsOf(value) } };
}

function fieldsOf(data) {
  return Object.fromEntries(
    Object.entries(data).map(([key, value]) => [key, valueOf(value)]),
  );
}

function documentName(path) {
  return `projects/${projectId}/databases/(default)/documents/${path}`;
}

async function signUp(label) {
  const response = await fetch(
    `http://${authHost}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-key`,
    {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        email: `${label}-${Date.now()}@example.test`,
        password: "correct-horse-battery-staple",
        returnSecureToken: true,
      }),
    },
  );
  assert.equal(response.status, 200, await response.clone().text());
  return response.json();
}

async function get(path, token) {
  return fetch(`${firestoreBase}/${path}`, {
    headers: { authorization: `Bearer ${token}` },
  });
}

async function list(path, token) {
  return fetch(`${firestoreBase}/${path}?pageSize=50`, {
    headers: { authorization: `Bearer ${token}` },
  });
}

async function commit(writes, token) {
  return fetch(commitUrl, {
    method: "POST",
    headers: {
      authorization: `Bearer ${token}`,
      "content-type": "application/json",
    },
    body: JSON.stringify({ writes }),
  });
}

function createWrite(path, data) {
  return {
    update: { name: documentName(path), fields: fieldsOf(data) },
    currentDocument: { exists: false },
  };
}

function updateWrite(path, data, fieldPaths = Object.keys(data)) {
  return {
    update: { name: documentName(path), fields: fieldsOf(data) },
    updateMask: { fieldPaths },
    currentDocument: { exists: true },
  };
}

function deleteWrite(path) {
  return { delete: documentName(path), currentDocument: { exists: true } };
}

const now = "2026-11-23T09:00:00.000Z";

function room(roomId, ownerId) {
  return {
    schemaVersion: 2,
    id: roomId,
    name: "場景權限房",
    description: "核准後才看得到座位與訊息",
    ownerId,
    ownerName: ownerId,
    memberIds: [ownerId],
    visibility: "private",
    status: "active",
    joinMode: "approval",
    roomType: "study",
    goalSourceType: "studyRoom",
    dailyGoalValue: 1,
    goalUnitLabel: "小時",
    memberLimit: 6,
    updatedAt: now,
  };
}

function member(roomId, memberId, role, approvalStatus) {
  return {
    schemaVersion: 1,
    roomId,
    memberId,
    displayName: memberId,
    role,
    approvalStatus,
    presenceStatus: "offline",
    sessionSeconds: 0,
    metricValue: 0,
    metricUnit: "minutes",
    activeSessionId: null,
    updatedAt: now,
  };
}

function message(roomId, senderId, id) {
  return {
    id,
    roomId,
    senderId,
    senderName: senderId,
    text: "一起加油",
    type: "text",
    createdAt: now,
  };
}

function leaveEvent(roomId, actorId, id) {
  return {
    id,
    roomId,
    actorId,
    actorName: actorId,
    text: `${actorId} 離開房間`,
    type: "leave",
    createdAt: now,
  };
}

async function expectStatus(promise, status, reason) {
  const response = await promise;
  assert.equal(response.status, status, `${reason}: ${await response.clone().text()}`);
}

function marker(roomId, userId, messageId, createdAt) {
  return {
    schemaVersion: 1,
    roomId,
    userId,
    lastReadMessageId: messageId,
    lastReadCreatedAt: createdAt,
    updatedAt: now,
  };
}

async function run() {
  const owner = await signUp("marker-owner");
  const alice = await signUp("marker-alice");
  const pending = await signUp("marker-pending");
  const outsider = await signUp("marker-outsider");
  const roomId = `room-marker-${Date.now()}`;
  const roomPath = `rooms/${roomId}`;
  const ownerPath = `${roomPath}/members/${owner.localId}`;
  const alicePath = `${roomPath}/members/${alice.localId}`;
  const pendingPath = `${roomPath}/members/${pending.localId}`;
  const aliceMarker = `room_read_markers/${roomId}--${alice.localId}`;
  const pendingMarker = `room_read_markers/${roomId}--${pending.localId}`;
  const later = "2026-11-23T09:05:00.000Z";

  await expectStatus(commit([
    createWrite(roomPath, room(roomId, owner.localId)),
    createWrite(ownerPath, member(roomId, owner.localId, "owner", "approved")),
  ], owner.idToken), 200, "owner creates room");
  await expectStatus(commit([
    createWrite(`${roomPath}/messages/m1`, message(roomId, owner.localId, "m1")),
    createWrite(`${roomPath}/messages/m2`, { ...message(roomId, owner.localId, "m2"), createdAt: later }),
  ], "owner"), 200, "seed messages for independent marker checks");
  await expectStatus(commit([
    updateWrite(roomPath, { memberIds: [owner.localId, alice.localId], updatedAt: now }),
    createWrite(alicePath, member(roomId, alice.localId, "member", "pending")),
  ], alice.idToken), 200, "alice joins");
  await expectStatus(commit([
    updateWrite(alicePath, { approvalStatus: "approved", updatedAt: now }),
  ], owner.idToken), 200, "owner approves alice");
  await expectStatus(commit([
    updateWrite(roomPath, { memberIds: [owner.localId, alice.localId, pending.localId], updatedAt: now }),
    createWrite(pendingPath, member(roomId, pending.localId, "member", "pending")),
  ], pending.idToken), 200, "pat joins and stays pending");

  await expectStatus(commit([
    createWrite(pendingMarker, marker(roomId, pending.localId, "m1", now)),
  ], pending.idToken), 403, "a pending member cannot create a read marker");
  await expectStatus(get(aliceMarker, alice.idToken), 404,
    "an approved member may listen before her first marker exists");
  await expectStatus(get(pendingMarker, pending.idToken), 403,
    "a pending member cannot even probe for a marker");
  await expectStatus(commit([
    createWrite(aliceMarker, marker(roomId, alice.localId, "missing", now)),
  ], alice.idToken), 403, "a marker must point at an existing message");
  await expectStatus(commit([
    createWrite(aliceMarker, marker(roomId, alice.localId, "m1", later)),
  ], alice.idToken), 403, "a marker timestamp must match the message");
  await expectStatus(commit([
    createWrite(aliceMarker, { ...marker(roomId, alice.localId, "m1", now), extra: true }),
  ], alice.idToken), 403, "a marker has a closed field set");
  await expectStatus(commit([
    createWrite(`room_read_markers/${roomId}--${owner.localId}`, marker(roomId, alice.localId, "m1", now)),
  ], alice.idToken), 403, "a member cannot write another member's marker id");
  await expectStatus(commit([
    createWrite(aliceMarker, marker(roomId, alice.localId, "m1", now)),
  ], alice.idToken), 200, "an approved member saves her own marker");
  await expectStatus(get(aliceMarker, alice.idToken), 200, "the owner of a marker can read it");
  await expectStatus(get(aliceMarker, owner.idToken), 403, "the room owner cannot read alice's marker");
  await expectStatus(get(aliceMarker, outsider.idToken), 403, "an outsider cannot read the marker");
  await expectStatus(commit([
    updateWrite(aliceMarker, marker(roomId, alice.localId, "m2", later)),
  ], alice.idToken), 200, "the marker moves forward on another device");
  await expectStatus(commit([
    updateWrite(aliceMarker, marker(roomId, alice.localId, "m1", now)),
  ], alice.idToken), 403, "the marker cannot move backwards");

  await expectStatus(commit([
    updateWrite(roomPath, { memberIds: [owner.localId, pending.localId], updatedAt: now }),
    deleteWrite(alicePath),
  ], alice.idToken), 200, "alice leaves");
  await expectStatus(get(aliceMarker, alice.idToken), 403, "a former member cannot read the old marker");
  await expectStatus(commit([
    updateWrite(aliceMarker, { ...marker(roomId, alice.localId, "m2", later), updatedAt: later }),
  ], alice.idToken), 403, "a former member cannot write the marker");
  await expectStatus(commit([deleteWrite(aliceMarker)], alice.idToken), 200,
    "the owner of a marker can still delete it");

  console.log("Firestore room read marker rules integration test passed.");
}

run().catch(error => {
  console.error(error);
  process.exit(1);
});
