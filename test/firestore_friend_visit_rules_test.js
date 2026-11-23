// Emulator test for the friend visit permission matrix: friends, non-friends,
// revoked visibility and host responses against the visit records the
// friend-visits page reads or writes.
const assert = require("node:assert/strict");

const projectId = "nudge-discipline-app";
const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST;
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;

if (!firestoreHost || !authHost) {
  console.log(
    "Firestore friend visit rules integration test skipped: emulators are not enabled.",
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

function settings(userId, allowVisits, sceneKey = "garden") {
  return { schemaVersion: 1, userId, allowVisits, sceneKey, updatedAt: now };
}

function visit(hostId, visitorId, overrides = {}) {
  return {
    schemaVersion: 1, hostId, visitorId, dateKey: day, sceneKey: "garden",
    reactionKey: "cheer", responseKey: null, createdAt: now, respondedAt: null, ...overrides,
  };
}

async function run() {
  const host = await signUp("visit-host");
  const friend = await signUp("visit-friend");
  const stranger = await signUp("visit-stranger");
  const h = host.localId;
  const f = friend.localId;
  for (const id of [h, f, stranger.localId]) await adminSet(`users/${id}`, { uid: id });
  await adminSet(`users/${h}/friends/${f}`, { id: f });
  await adminSet(`users/${f}/friends/${h}`, { id: h });
  const settingsPath = `friend_visit_settings/${h}`;
  const visitPath = `friend_visits/${h}--${f}--${day}`;

  await expectStatus(commit([createWrite(settingsPath, settings(h, true))], friend.idToken), 403,
    "only the host writes their visit settings");
  await expectStatus(commit([createWrite(settingsPath, { ...settings(h, true), sceneKey: "bedroom" })], host.idToken), 403,
    "only fixed scenes can be published");
  await expectStatus(commit([createWrite(settingsPath, settings(h, false))], host.idToken), 200,
    "the host saves closed settings");
  await expectStatus(get(settingsPath, friend.idToken), 403, "a friend cannot read closed settings");
  await expectStatus(commit([createWrite(visitPath, visit(h, f))], friend.idToken), 403,
    "a friend cannot visit while visits are closed");

  await expectStatus(commit([updateWrite(settingsPath, settings(h, true))], host.idToken), 200,
    "the host opens visits");
  await expectStatus(get(settingsPath, friend.idToken), 200, "a mutual friend reads open settings");
  await expectStatus(get(settingsPath, stranger.idToken), 403, "a non-friend cannot read open settings");
  await expectStatus(get(`users/${h}`, friend.idToken), 403, "a friend still cannot read the host's private user document");

  await expectStatus(commit([createWrite(`friend_visits/${h}--${stranger.localId}--${day}`, visit(h, stranger.localId))], stranger.idToken), 403,
    "a non-friend cannot visit");
  await expectStatus(commit([createWrite(visitPath, visit(h, f, { reactionKey: "free text" }))], friend.idToken), 403,
    "reactions are a fixed set");
  await expectStatus(commit([createWrite(visitPath, visit(h, f, { sceneKey: "cabin" }))], friend.idToken), 403,
    "a visit must target the host's currently public scene");
  await expectStatus(commit([createWrite(visitPath, { ...visit(h, f), coins: 5 })], friend.idToken), 403,
    "a visit cannot carry reward fields");
  const v2Path = `friend_visits/${h}--${f}--2026-11-24`;
  const letter = {
    schemaVersion: 2, hostId: h, visitorId: f, dateKey: "2026-11-24", sceneKey: "cabin",
    noteKey: "cheer", stickerKey: "heart", removed: false, createdAt: now,
  };
  await expectStatus(commit([createWrite(v2Path, letter)], friend.idToken), 403,
    "guestbook letters can only be written by Cloud");
  await expectStatus(commit([createWrite(v2Path, letter)], "owner"), 200,
    "seed a verified guestbook letter");
  await expectStatus(commit([deleteWrite(v2Path)], friend.idToken), 403,
    "the visitor cannot erase the daily limit");
  await expectStatus(commit([deleteWrite(v2Path)], host.idToken), 403,
    "the host must use the callable that removes the letter and retains the daily marker");
  await expectStatus(commit([createWrite(visitPath, visit(h, f))], friend.idToken), 200,
    "a mutual friend records a real visit");
  await expectStatus(commit([createWrite(visitPath, visit(h, f))], friend.idToken), 409,
    "the same pair cannot visit twice on one day");
  await expectStatus(get(visitPath, stranger.idToken), 403, "a third party cannot read the visit");

  await expectStatus(commit([updateWrite(visitPath, { responseKey: "thanks", respondedAt: now }, ["responseKey", "respondedAt"])], friend.idToken), 403,
    "the visitor cannot answer on the host's behalf");
  await expectStatus(commit([updateWrite(visitPath, { reactionKey: "proud" }, ["reactionKey"])], host.idToken), 403,
    "the host cannot rewrite the visitor's reaction");
  await expectStatus(commit([updateWrite(visitPath, { responseKey: "thanks", respondedAt: now }, ["responseKey", "respondedAt"])], host.idToken), 200,
    "the host answers once with a fixed response");
  await expectStatus(commit([updateWrite(visitPath, { responseKey: "heart", respondedAt: now }, ["responseKey", "respondedAt"])], host.idToken), 403,
    "the host answers only once");

  await expectStatus(commit([updateWrite(settingsPath, settings(h, false))], host.idToken), 200,
    "the host withdraws visibility");
  await expectStatus(get(settingsPath, friend.idToken), 403, "withdrawn settings are immediately unreadable");
  await expectStatus(get(visitPath, friend.idToken), 200, "the visitor keeps reading their own past visit record");

  console.log("Firestore friend visit rules integration test passed.");
}

run().catch(error => {
  console.error(error);
  process.exit(1);
});