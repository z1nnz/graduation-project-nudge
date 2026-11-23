// Emulator test for the Web room scene permission matrix: pending, approved,
// removed and outside accounts against the canonical room records that the
// scene, presence seat and leave flow read or write.
const assert = require("node:assert/strict");

const projectId = "nudge-discipline-app";
const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST;
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;

if (!firestoreHost || !authHost) {
  console.log(
    "Firestore room scene rules integration test skipped: emulators are not enabled.",
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

async function run() {
  const owner = await signUp("scene-owner");
  const alice = await signUp("scene-alice");
  const outsider = await signUp("scene-outsider");
  const roomId = `room-scene-${Date.now()}`;
  const roomPath = `rooms/${roomId}`;
  const ownerPath = `${roomPath}/members/${owner.localId}`;
  const alicePath = `${roomPath}/members/${alice.localId}`;

  await expectStatus(commit([
    createWrite(roomPath, room(roomId, owner.localId)),
    createWrite(ownerPath, member(roomId, owner.localId, "owner", "approved")),
  ], owner.idToken), 200, "owner creates an approval room");
  await expectStatus(commit([
    createWrite(`${roomPath}/messages/m-owner`, message(roomId, owner.localId, "m-owner")),
  ], owner.idToken), 200, "owner posts the first message");

  // Alice requests admission: she becomes a pending participant.
  await expectStatus(commit([
    updateWrite(roomPath, { memberIds: [owner.localId, alice.localId], updatedAt: now }),
    createWrite(alicePath, member(roomId, alice.localId, "member", "pending")),
  ], alice.idToken), 200, "alice joins as pending");

  await expectStatus(list(`${roomPath}/messages`, alice.idToken), 403,
    "a pending member cannot read room messages");
  await expectStatus(list(`${roomPath}/events`, alice.idToken), 403,
    "a pending member cannot read room events");
  await expectStatus(commit([
    createWrite(`${roomPath}/messages/m-alice-pending`, message(roomId, alice.localId, "m-alice-pending")),
  ], alice.idToken), 403, "a pending member cannot post a message");
  await expectStatus(commit([
    updateWrite(alicePath, { approvalStatus: "approved", updatedAt: now }),
  ], alice.idToken), 403, "a pending member cannot approve themself");

  await expectStatus(list(`${roomPath}/messages`, outsider.idToken), 403,
    "an outside account cannot read room messages");
  await expectStatus(list(`${roomPath}/members`, outsider.idToken), 403,
    "an outside account cannot read room memberships");

  await expectStatus(commit([
    updateWrite(alicePath, { approvalStatus: "approved", updatedAt: now }),
  ], owner.idToken), 200, "the owner approves alice");

  // Presence seat: each member controls only their own coarse posture.
  await expectStatus(commit([
    updateWrite(alicePath, { presenceStatus: "resting", updatedAt: now }),
  ], alice.idToken), 200, "alice takes her own seat");
  await expectStatus(commit([
    updateWrite(alicePath, { presenceStatus: "studying", updatedAt: now }),
  ], owner.idToken), 403, "the owner cannot change alice's presence");
  await expectStatus(commit([
    updateWrite(ownerPath, { presenceStatus: "studying", updatedAt: now }),
  ], alice.idToken), 403, "alice cannot change the owner's presence");
  await expectStatus(commit([
    updateWrite(alicePath, { presenceStatus: "dancing", updatedAt: now }),
  ], alice.idToken), 403, "presence is limited to the fixed postures");
  await expectStatus(commit([
    updateWrite(alicePath, { metricValue: 999, updatedAt: now }),
  ], owner.idToken), 403, "the owner cannot fabricate alice's progress");

  await expectStatus(list(`${roomPath}/messages`, alice.idToken), 200,
    "an approved member reads room messages");

  // The owner cannot leave while another approved member remains.
  await expectStatus(commit([
    updateWrite(roomPath, { memberIds: [alice.localId], updatedAt: now }),
    deleteWrite(ownerPath),
  ], owner.idToken), 403, "the owner must transfer before leaving");

  // Alice leaves: leave event first (still approved), then membership removal.
  await expectStatus(commit([
    createWrite(`${roomPath}/events/e-alice-leave`, leaveEvent(roomId, alice.localId, "e-alice-leave")),
  ], alice.idToken), 200, "alice records her leave event while approved");
  await expectStatus(commit([
    updateWrite(roomPath, { memberIds: [owner.localId], updatedAt: now }),
    deleteWrite(alicePath),
  ], alice.idToken), 200, "alice leaves the room herself");

  await expectStatus(list(`${roomPath}/messages`, alice.idToken), 403,
    "a former member immediately loses message read access");
  await expectStatus(get(`${roomPath}/messages/m-owner`, alice.idToken), 403,
    "a former member cannot read a remembered message id");
  await expectStatus(list(`${roomPath}/members`, alice.idToken), 403,
    "a former member cannot read room memberships");
  await expectStatus(commit([
    createWrite(`${roomPath}/messages/m-alice-after`, message(roomId, alice.localId, "m-alice-after")),
  ], alice.idToken), 403, "a former member cannot post a message");

  // Last member closes instead of deleting, preserving the audit trail.
  await expectStatus(commit([
    updateWrite(roomPath, { status: "closed", updatedAt: now }),
  ], owner.idToken), 200, "the final owner closes the room");

  console.log("Firestore room scene rules integration test passed.");
}

run().catch(error => {
  console.error(error);
  process.exit(1);
});
