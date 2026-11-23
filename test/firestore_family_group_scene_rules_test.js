// Emulator test for the family courtyard and group hall scene writes: guardians,
// children, managers and members against the existing canonical records the
// scene pages write. No Rules were added for these scenes.
const assert = require("node:assert/strict");

const projectId = "nudge-discipline-app";
const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST;
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;

if (!firestoreHost || !authHost) {
  console.log(
    "Firestore family/group scene rules integration test skipped: emulators are not enabled.",
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

const scopesOff = { summary: false, weeklyReport: false, taskCategories: false, healthTrends: false };

async function run() {
  const guardian = await signUp("court-guardian");
  const child = await signUp("court-child");
  const manager = await signUp("hall-manager");
  const member = await signUp("hall-member");
  const outsider = await signUp("hall-outsider");
  const g = guardian.localId;
  const c = child.localId;
  const linkId = `link-${Date.now()}`;
  const link = `family_links/${linkId}`;
  await adminSet(link, {
    schemaVersion: 1, guardianId: g, childId: c, participantIds: [g, c], status: "active",
    consentScopes: { ...scopesOff, weeklyReport: true }, createdAt: now, updatedAt: now,
  });
  await adminSet(`${link}/summaries/current`, { schemaVersion: 1, childId: c, weeklyReport: "本週 5 天", updatedAt: now });
  await adminSet(`${link}/encouragements/e1`, { schemaVersion: 1, senderId: g, recipientId: c, title: "以你為榮", message: "很棒", status: "sent", createdAt: now });
  await adminSet(`${link}/goals/g1`, { schemaVersion: 1, title: "散步", message: "", status: "proposed", proposedBy: g, decisionBy: c, createdAt: now, updatedAt: now });

  await expectStatus(get(`${link}/summaries/current`, guardian.idToken), 200, "guardian reads the consented weekly report");
  await expectStatus(commit([updateWrite(`${link}/goals/g1`, { status: "accepted", acceptedAt: now, updatedAt: now })], guardian.idToken), 403,
    "a guardian cannot accept a goal for the child");
  await expectStatus(commit([updateWrite(`${link}/encouragements/e1`, { status: "acknowledged", acknowledgedAt: now })], guardian.idToken), 403,
    "a guardian cannot acknowledge their own card");
  await expectStatus(commit([updateWrite(link, { consentScopes: { ...scopesOff, healthTrends: true }, updatedAt: now })], guardian.idToken), 403,
    "a guardian cannot grant consent for the child");

  await expectStatus(commit([
    updateWrite(`${link}/encouragements/e1`, { status: "acknowledged", acknowledgedAt: now }),
    createWrite(`${link}/bond_events/encouragement_e1`, { schemaVersion: 1, type: "acknowledgement", sourceId: "e1", actorId: c, points: 3, createdAt: now }),
  ], child.idToken), 200, "the child acknowledges with one idempotent bond event");
  await expectStatus(commit([
    createWrite(`${link}/bond_events/encouragement_e1`, { schemaVersion: 1, type: "acknowledgement", sourceId: "e1", actorId: c, points: 3, createdAt: now }),
  ], child.idToken), 409, "the same acknowledgement cannot add bond XP twice");
  await expectStatus(commit([updateWrite(`${link}/goals/g1`, { status: "accepted", acceptedAt: now, updatedAt: now })], child.idToken), 200,
    "the child accepts the goal");
  await expectStatus(commit([
    updateWrite(`${link}/goals/g1`, { status: "completed", completedAt: now, updatedAt: now }),
    createWrite(`${link}/bond_events/goal_g1`, { schemaVersion: 1, type: "goalCompleted", sourceId: "g1", actorId: c, points: 10, createdAt: now }),
  ], child.idToken), 200, "the child completes the goal with one bond event");

  // Revoke: consent change and summary rewrite in one batch, as the scene does.
  await expectStatus(commit([
    updateWrite(link, { consentScopes: scopesOff, updatedAt: now }),
    { update: { name: documentName(`${link}/summaries/current`), fields: fieldsOf({ schemaVersion: 1, childId: c, updatedAt: now }) } },
  ], child.idToken), 200, "the child withdraws weekly report consent");
  const after = await get(`${link}/summaries/current`, guardian.idToken);
  const body = await after.json();
  assert.ok(after.status === 200 && !body.fields?.weeklyReport, "the withdrawn report is no longer readable or exportable");
  await expectStatus(commit([
    updateWrite(link, { consentScopes: { ...scopesOff, weeklyReport: true }, updatedAt: now }),
    { update: { name: documentName(`${link}/summaries/current`), fields: fieldsOf({ schemaVersion: 1, childId: c, weeklyReport: "本週 6 天", updatedAt: now }) } },
  ], child.idToken), 200, "the child may opt back in");
  await expectStatus(commit([
    updateWrite(link, { consentScopes: scopesOff, updatedAt: now }),
  ], child.idToken), 403, "a revoke must strip the revoked field from the summary in the same write");

  // Group hall.
  const m = manager.localId;
  const u = member.localId;
  const groupId = `group-${Date.now()}`;
  const group = `groups/${groupId}`;
  await adminSet(group, { schemaVersion: 1, id: groupId, name: "期末讀書會", ownerId: m, memberIds: [m, u], status: "active", updatedAt: now });
  await adminSet(`${group}/templates/t1`, { schemaVersion: 1, groupId, type: "每日讀書", days: 2, effort: "medium", strategy: "steady", status: "active", publishedBy: m, updatedAt: now });
  const challenge = { schemaVersion: 2, challengeId: "ch1", groupId, groupName: "期末讀書會", type: "每日讀書", days: 2, reward: "團體星球成長", status: "active", publishedBy: m, updatedAt: now };
  await expectStatus(commit([createWrite(`${group}/challenges/current`, challenge)], member.idToken), 403, "a member cannot publish a challenge");
  await expectStatus(commit([createWrite(`${group}/challenges/current`, challenge)], manager.idToken), 200, "the manager publishes from a template");
  const joined = { schemaVersion: 1, groupId, challengeId: "ch1", memberId: u, status: "joined", completedDays: 0, totalDays: 2, joinedAt: now, updatedAt: now };
  const participant = `${group}/challenges/current/participants/${u}`;
  await expectStatus(commit([createWrite(participant, joined)], manager.idToken), 403, "the manager cannot enrol a member");
  await expectStatus(commit([createWrite(participant, joined)], member.idToken), 200, "the member joins by themself");
  await expectStatus(commit([updateWrite(participant, { ...joined, completedDays: 1 })], manager.idToken), 403, "the manager cannot check in for a member");
  await expectStatus(commit([updateWrite(participant, { ...joined, completedDays: 1 })], member.idToken), 200, "the member checks in");
  await expectStatus(commit([createWrite(`${group}/study_schedules/s1`, { schemaVersion: 1, groupId, title: "週三讀書", meta: "19:30", status: "scheduled", publishedBy: m, createdAt: now })], member.idToken), 403,
    "a member cannot publish a shared session");
  await expectStatus(commit([createWrite(`${group}/study_schedules/s1`, { schemaVersion: 1, groupId, title: "週三讀書", meta: "19:30", status: "scheduled", publishedBy: m, createdAt: now })], manager.idToken), 200,
    "the manager proposes a shared session");
  await adminSet(`${group}/member_summaries/${u}`, { schemaVersion: 1, groupId, memberId: u, displayName: "阿禾", status: "shared", summary: { disciplineScore: 80, completedTasks: 3, totalTasks: 4, focusMinutes: 60, steps: 1000, sleepHours: 7 }, updatedAt: now });
  await expectStatus(commit([deleteWrite(`${group}/member_summaries/${u}`)], manager.idToken), 403, "the manager cannot withdraw a member's summary while they are a member");
  await expectStatus(commit([deleteWrite(`${group}/member_summaries/${u}`)], member.idToken), 200, "the member withdraws their summary");
  await expectStatus(list(`${group}/member_summaries`, outsider.idToken), 403, "an outsider cannot read group summaries");
  await expectStatus(get(`users/${u}`, manager.idToken), 403, "the manager cannot read the member's private user document");

  console.log("Firestore family/group scene rules integration test passed.");
}

run().catch(error => {
  console.error(error);
  process.exit(1);
});