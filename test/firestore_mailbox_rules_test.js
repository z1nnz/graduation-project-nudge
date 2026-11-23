// Emulator test for the town mailbox permission matrix: recipients, senders,
// and other accounts against the canonical notifications and requests the
// mailbox reads. Clients never write notifications.
const assert = require("node:assert/strict");

const projectId = "nudge-discipline-app";
const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST;
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;

if (!firestoreHost || !authHost) {
  console.log(
    "Firestore mailbox rules integration test skipped: emulators are not enabled.",
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
const day = "2026-11-23";

async function adminSet(path, data) {
  const response = await fetch(`${firestoreBase}/${path}`, {
    method: "PATCH",
    headers: { authorization: "Bearer owner", "content-type": "application/json" },
    body: JSON.stringify({ fields: fieldsOf(data) }),
  });
  assert.equal(response.status, 200, await response.clone().text());
}

async function expectStatus(promise, status, reason) {
  const response = await promise;
  assert.equal(response.status, status, `${reason}: ${await response.clone().text()}`);
}

async function run() {
  const receiver = await signUp("mail-receiver");
  const sender = await signUp("mail-sender");
  const outsider = await signUp("mail-outsider");
  const r = receiver.localId;
  const s = sender.localId;
  const requestId = `req-${Date.now()}`;
  const notificationId = `family-request--${requestId}--pending`;
  await adminSet(`guardian_requests/${requestId}`, { senderId: s, receiverId: r, senderRole: "guardian", receiverRole: "child", status: "pending", createdAt: now });
  const letter = {
    schemaVersion: 1, notificationId, recipientUserId: r, category: "relationship", kind: "family_invitation",
    sourceType: "family_request", sourceId: requestId, actorUserId: s, actorPrincipalId: s,
    title: "新的家庭連結邀請", body: "一位使用者邀請你建立家庭連結。", route: "guardian", status: "unread", createdAt: now, updatedAt: now,
  };
  await adminSet(`user_notifications/${notificationId}`, letter);

  await expectStatus(get(`user_notifications/${notificationId}`, receiver.idToken), 200, "the recipient reads their letter");
  await expectStatus(get(`user_notifications/${notificationId}`, sender.idToken), 403, "the sender cannot read the recipient's letter");
  await expectStatus(get(`user_notifications/${notificationId}`, outsider.idToken), 403, "an outsider cannot read the letter");
  await expectStatus(commit([updateWrite(`user_notifications/${notificationId}`, { status: "read" }, ["status"])], receiver.idToken), 403,
    "even the recipient cannot mark read without the audited callable");
  await expectStatus(commit([createWrite(`user_notifications/forged-${Date.now()}`, { ...letter, recipientUserId: r })], sender.idToken), 403,
    "nobody can forge a letter into another mailbox");
  await expectStatus(get(`guardian_requests/${requestId}`, receiver.idToken), 200, "the recipient sees the invitation status");
  await expectStatus(get(`guardian_requests/${requestId}`, outsider.idToken), 403, "an outsider cannot see the invitation status");

  console.log("Firestore mailbox rules integration test passed.");
}

run().catch(error => {
  console.error(error);
  process.exit(1);
});