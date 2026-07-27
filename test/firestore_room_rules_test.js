const assert = require("node:assert/strict");

const projectId = "nudge-discipline-app";
const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST;
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;

if (!firestoreHost || !authHost) {
  console.log(
    "Firestore room rules integration test skipped: emulators are not enabled.",
  );
  process.exit(0);
}

const firestoreBase =
  `http://${firestoreHost}/v1/projects/${projectId}` +
  "/databases/(default)/documents";
const commitUrl =
  `http://${firestoreHost}/v1/projects/${projectId}` +
  "/databases/(default)/documents:commit";

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

async function createDoc(path, data, token) {
  return request(path, token, {
    method: "PATCH",
    body: JSON.stringify({ fields: fieldsOf(data) }),
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
  return {
    delete: documentName(path),
    currentDocument: { exists: true },
  };
}

function room(roomId, ownerId, now) {
  return {
    schemaVersion: 2,
    id: roomId,
    name: "自主活動房",
    description: "成員自己開始與完成",
    ownerId,
    ownerName: "房主",
    memberIds: [ownerId],
    visibility: "public",
    status: "active",
    joinMode: "instant",
    roomType: "study",
    goalSourceType: "studyRoom",
    dailyGoalValue: 2,
    goalUnitLabel: "小時",
    memberLimit: 8,
    updatedAt: now,
  };
}

function member(roomId, memberId, now, role = "member") {
  return {
    schemaVersion: 1,
    roomId,
    memberId,
    displayName: memberId,
    role,
    approvalStatus: "approved",
    presenceStatus: "offline",
    sessionSeconds: 0,
    metricValue: 0,
    metricUnit: "minutes",
    activeSessionId: null,
    updatedAt: now,
  };
}

function session(roomId, actorId, now) {
  return {
    schemaVersion: 1,
    sessionId: "session-alice-focus",
    roomId,
    actorId,
    activityKind: "focus",
    metricUnit: "minutes",
    targetValue: 25,
    metricValue: 0,
    source: "app",
    status: "active",
    startedAt: now,
    updatedAt: now,
    endedAt: null,
  };
}

async function run() {
  const owner = await signUp("room-owner");
  const alice = await signUp("room-alice");
  const stranger = await signUp("room-stranger");
  const roomId = "room-member-controlled";
  const roomPath = `rooms/${roomId}`;
  const ownerMemberPath = `${roomPath}/members/${owner.localId}`;
  const aliceMemberPath = `${roomPath}/members/${alice.localId}`;
  const strangerMemberPath = `${roomPath}/members/${stranger.localId}`;
  const sessionPath =
    `${roomPath}/activity_sessions/session-alice-focus`;
  const now = "2026-07-27T09:00:00.000Z";

  let response = await commit(
    [
      createWrite(roomPath, room(roomId, owner.localId, now)),
      createWrite(
        ownerMemberPath,
        member(roomId, owner.localId, now, "owner"),
      ),
    ],
    owner.idToken,
  );
  assert.equal(response.status, 200, await response.clone().text());

  response = await commit(
    [
      updateWrite(roomPath, {
        memberIds: [owner.localId, alice.localId],
        updatedAt: now,
      }),
      createWrite(aliceMemberPath, member(roomId, alice.localId, now)),
    ],
    alice.idToken,
  );
  assert.equal(response.status, 200, await response.clone().text());

  response = await commit(
    [
      updateWrite(roomPath, { name: "被成員竄改的房名" }, ["name"]),
    ],
    alice.idToken,
  );
  assert.equal(
    response.status,
    403,
    "A member cannot overwrite room metadata",
  );

  response = await commit(
    [
      updateWrite(
        aliceMemberPath,
        {
          activeSessionId: "session-alice-focus",
          updatedAt: now,
        },
        ["activeSessionId", "updatedAt"],
      ),
      createWrite(
        sessionPath,
        session(roomId, alice.localId, now),
      ),
    ],
    alice.idToken,
  );
  assert.equal(response.status, 200, await response.clone().text());

  response = await commit(
    [
      updateWrite(
        aliceMemberPath,
        {
          activeSessionId: "second-active-session",
          updatedAt: "2026-07-27T09:01:00.000Z",
        },
        ["activeSessionId", "updatedAt"],
      ),
      createWrite(
        `${roomPath}/activity_sessions/second-active-session`,
        {
          ...session(roomId, alice.localId, now),
          sessionId: "second-active-session",
        },
      ),
    ],
    alice.idToken,
  );
  assert.equal(
    response.status,
    403,
    "A member cannot replace a non-terminal active session",
  );

  response = await createDoc(
    `${roomPath}/activity_sessions/owner-forges-alice`,
    {
      ...session(roomId, alice.localId, now),
      sessionId: "owner-forges-alice",
    },
    owner.idToken,
  );
  assert.equal(
    response.status,
    403,
    "A room owner cannot create another member's activity",
  );

  response = await commit(
    [
      updateWrite(
        sessionPath,
        {
          status: "completed",
          metricValue: 25,
          updatedAt: "2026-07-27T09:25:00.000Z",
          endedAt: "2026-07-27T09:25:00.000Z",
        },
        ["status", "metricValue", "updatedAt", "endedAt"],
      ),
    ],
    owner.idToken,
  );
  assert.equal(
    response.status,
    403,
    "A room owner cannot complete another member's activity",
  );

  response = await commit(
    [
      updateWrite(
        sessionPath,
        {
          status: "paused",
          metricValue: 10,
          updatedAt: "2026-07-27T09:10:00.000Z",
          endedAt: null,
        },
        ["status", "metricValue", "updatedAt", "endedAt"],
      ),
    ],
    alice.idToken,
  );
  assert.equal(response.status, 200, await response.clone().text());

  response = await commit(
    [
      updateWrite(
        aliceMemberPath,
        {
          activeSessionId: null,
          updatedAt: "2026-07-27T09:11:00.000Z",
        },
        ["activeSessionId", "updatedAt"],
      ),
      updateWrite(
        sessionPath,
        {
          status: "completed",
          metricValue: 25,
          updatedAt: "2026-07-27T09:11:00.000Z",
          endedAt: "2026-07-27T09:11:00.000Z",
        },
        ["status", "metricValue", "updatedAt", "endedAt"],
      ),
    ],
    alice.idToken,
  );
  assert.equal(
    response.status,
    200,
    "The actor can atomically complete and clear their active session",
  );

  response = await request(sessionPath, stranger.idToken);
  assert.equal(
    response.status,
    403,
    "A stranger cannot read room activity sessions",
  );

  response = await commit(
    [
      updateWrite(roomPath, {
        memberIds: [owner.localId],
        updatedAt: "2026-07-27T09:11:00.000Z",
      }),
      deleteWrite(aliceMemberPath),
    ],
    alice.idToken,
  );
  assert.equal(response.status, 200, await response.clone().text());

  response = await createDoc(
    `${roomPath}/activity_sessions/after-leave`,
    {
      ...session(roomId, alice.localId, now),
      sessionId: "after-leave",
    },
    alice.idToken,
  );
  assert.equal(
    response.status,
    403,
    "Leaving the room revokes permission to create sessions",
  );

  response = await commit(
    [
      updateWrite(roomPath, {
        memberIds: [owner.localId, stranger.localId],
        updatedAt: "2026-07-27T09:12:00.000Z",
      }),
      createWrite(
        strangerMemberPath,
        member(roomId, stranger.localId, now),
      ),
    ],
    stranger.idToken,
  );
  assert.equal(response.status, 200, await response.clone().text());

  response = await commit(
    [
      updateWrite(roomPath, {
        memberIds: [owner.localId],
        updatedAt: "2026-07-27T09:13:00.000Z",
      }),
      deleteWrite(strangerMemberPath),
    ],
    owner.idToken,
  );
  assert.equal(
    response.status,
    200,
    "A room owner can remove a member atomically",
  );

  console.log("Firestore room rules integration test passed.");
}

run().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
