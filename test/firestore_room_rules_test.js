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

async function adminCreateDoc(path, data) {
  return request(path, "owner", {
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

function canonicalSession(roomId, actorId, now) {
  return {
    schemaVersion: 1,
    activitySessionId: "session-alice-focus",
    actorUserId: actorId,
    activityType: "focus",
    source: "app",
    status: "active",
    roomIds: [roomId],
    roomTargetValue: 25,
    metricUnit: "minutes",
    metricValue: 0,
    startedAt: now,
    updatedAt: now,
    endedAt: null,
  };
}

function message(roomId, senderId, messageId, now) {
  return {
    id: messageId,
    roomId,
    senderId,
    senderName: senderId,
    text: "一起加油",
    type: "text",
    createdAt: now,
  };
}

function event(roomId, actorId, eventId, now) {
  return {
    id: eventId,
    roomId,
    actorId,
    actorName: actorId,
    text: "完成一輪活動",
    type: "complete",
    createdAt: now,
  };
}

async function verifyVoiceRoom() {
  const participants = await Promise.all(Array.from({ length: 9 }, (_, index) => signUp("voice-" + index)));
  const [host, listener, third] = participants;
  const pending = await signUp("voice-pending");
  const outsider = await signUp("voice-outsider");
  const roomId = "voice-room-" + Date.now();
  const path = `rooms/${roomId}`;
  const now = new Date().toISOString();
  const memberIds = [...participants, pending].map(user => user.localId);
  let response = await commit([
    createWrite(path, { ...room(roomId, host.localId, now), memberIds, memberLimit: 12 }),
    ...participants.map((user, index) => createWrite(`${path}/members/${user.localId}`,
      member(roomId, user.localId, now, index ? "member" : "owner"))),
    createWrite(`${path}/members/${pending.localId}`, {
      ...member(roomId, pending.localId, now), approvalStatus: "pending",
    }),
    ...participants.map(user => createWrite(`users/${user.localId}`, { nickname: "測試成員" })),
  ], "owner");
  assert.equal(response.status, 200, await response.clone().text());

  async function join(user, previous) {
    const presence = createWrite(`${path}/voice_participants/${user.localId}`, {
      uid: user.localId, joinedAt: now, muted: true, handRaised: false,
    });
    presence.updateTransforms = [{ fieldPath: "updatedAt", setToServerValue: "REQUEST_TIME" }];
    const capacity = createWrite(`${path}/voice_state/capacity`, { uids: [...previous, user.localId] });
    delete capacity.currentDocument;
    return commit([presence, capacity], user.idToken);
  }

  response = await join(host, []);
  assert.equal(response.status, 403, "Voice is disabled by default");
  response = await commit([updateWrite(path, { voiceEnabled: true })], listener.idToken);
  assert.equal(response.status, 403, "Only the owner can enable voice");
  response = await commit([updateWrite(path, { voiceEnabled: true })], host.idToken);
  assert.equal(response.status, 200, await response.clone().text());
  response = await join(outsider, []);
  assert.equal(response.status, 403, "A nonmember cannot join voice");
  response = await join(pending, []);
  assert.equal(response.status, 403, "A pending member cannot join voice");

  const reserved = [];
  for (const user of participants.slice(0, 8)) {
    response = await join(user, reserved);
    assert.equal(response.status, 200, await response.clone().text());
    reserved.push(user.localId);
  }
  response = await join(participants[8], reserved);
  assert.equal(response.status, 403, "The ninth reservation fails");

  const signalPath = `${path}/voice_signals/first`;
  function signal(from, to) {
    const write = createWrite(signalPath, { from, to, type: "offer", payload: "{}" });
    write.updateTransforms = [{ fieldPath: "createdAt", setToServerValue: "REQUEST_TIME" }];
    return write;
  }
  response = await commit([signal(participants[8].localId, listener.localId)], participants[8].idToken);
  assert.equal(response.status, 403, "An approved spectator without a voice reservation cannot signal");
  response = await commit([signal(host.localId, listener.localId)], third.idToken);
  assert.equal(response.status, 403, "A member cannot forge the sender");
  response = await commit([signal(host.localId, listener.localId)], host.idToken);
  assert.equal(response.status, 200, await response.clone().text());
  response = await request(signalPath, third.idToken);
  assert.equal(response.status, 403, "Uninvolved approved members cannot read a signal");
  response = await request(signalPath, listener.idToken);
  assert.equal(response.status, 200, "The recipient can read the signal");
  response = await commit([updateWrite(signalPath, { payload: "changed" })], listener.idToken);
  assert.equal(response.status, 403, "Signals are immutable");
  response = await commit([deleteWrite(signalPath)], listener.idToken);
  assert.equal(response.status, 200, "The recipient can consume the signal");

  response = await commit([
    updateWrite(`${path}/voice_state/capacity`, { uids: reserved.slice(1) }),
    deleteWrite(`${path}/voice_participants/${host.localId}`),
  ], host.idToken);
  assert.equal(response.status, 200, await response.clone().text());
  response = await join(participants[8], reserved.slice(1));
  assert.equal(response.status, 200, "Leaving frees a seat atomically");
}

async function run() {
  await verifyVoiceRoom();
  const owner = await signUp("room-owner");
  const alice = await signUp("room-alice");
  const stranger = await signUp("room-stranger");
  const bob = await signUp("room-bob");
  const roomId = `room-member-controlled-${Date.now()}`;
  const roomPath = `rooms/${roomId}`;
  const ownerMemberPath = `${roomPath}/members/${owner.localId}`;
  const aliceMemberPath = `${roomPath}/members/${alice.localId}`;
  const strangerMemberPath = `${roomPath}/members/${stranger.localId}`;
  const bobMemberPath = `${roomPath}/members/${bob.localId}`;
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
  assert.equal(
    response.status,
    403,
    "Room sessions and active pointers are Cloud Ledger projections",
  );

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
    "A member cannot create another canonical room session",
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

  response = await adminCreateDoc(
    sessionPath,
    session(roomId, alice.localId, now),
  );
  assert.equal(
    response.status,
    200,
    "The Cloud service can persist its transactional room aggregate",
  );

  response = await request(sessionPath, alice.idToken);
  assert.equal(
    response.status,
    403,
    "A member reads the canonical top-level Ledger session, not the Cloud room aggregate",
  );

  const canonicalSessionPath =
    "activity_sessions/session-alice-focus";
  response = await adminCreateDoc(
    canonicalSessionPath,
    canonicalSession(roomId, alice.localId, now),
  );
  assert.equal(response.status, 200, await response.clone().text());

  response = await request(canonicalSessionPath, alice.idToken);
  assert.equal(
    response.status,
    200,
    "The actor can read the canonical Ledger session used by App and Web",
  );

  response = await request(canonicalSessionPath, owner.idToken);
  assert.equal(
    response.status,
    403,
    "Room ownership does not reveal another member's canonical Ledger session",
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
    "A room owner cannot update another member's canonical activity",
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
  assert.equal(
    response.status,
    403,
    "A member cannot pause a canonical room session directly",
  );

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
    403,
    "The actor must complete through the Cloud Activity Ledger",
  );

  response = await request(sessionPath, stranger.idToken);
  assert.equal(
    response.status,
    403,
    "A stranger cannot read room activity sessions",
  );

  const focusRound = `${roomPath}/focus_rounds/current`;
  function roundWrite(path, startedBy, durationMin = 25) {
    const write = createWrite(path, { startedBy, durationMin, breakMin: 5 });
    delete write.currentDocument;
    write.updateTransforms = [{ fieldPath: "startAt", setToServerValue: "REQUEST_TIME" }];
    return write;
  }
  response = await commit([roundWrite(focusRound, stranger.localId)], stranger.idToken);
  assert.equal(response.status, 403, "Outsiders cannot start the shared timer");
  response = await commit([roundWrite(focusRound, owner.localId)], alice.idToken);
  assert.equal(response.status, 403, "Members cannot forge the initiator");
  response = await commit([roundWrite(focusRound, alice.localId, 1)], alice.idToken);
  assert.equal(response.status, 403, "Clients cannot shorten the round");
  const contests = await Promise.all([
    commit([roundWrite(focusRound, alice.localId)], alice.idToken),
    commit([roundWrite(focusRound, owner.localId)], owner.idToken),
  ]);
  assert.deepEqual(contests.map(result => result.status).sort(), [200, 403],
    "Simultaneous starts result in exactly one shared round");
  response = await commit([roundWrite(`${roomPath}/focus_rounds/another`, alice.localId)], alice.idToken);
  assert.equal(response.status, 403, "An alternate document cannot bypass the single active round");
  response = await request(focusRound, stranger.idToken);
  assert.equal(response.status, 403, "Outsiders cannot read the timer");
  response = await request(focusRound, alice.idToken);
  assert.equal(response.status, 200, "Approved members share the timer");
  const advanceClock = updateWrite(focusRound, { startAt: "" });
  advanceClock.update.fields.startAt = { timestampValue: now };
  response = await commit([advanceClock], "owner");
  assert.equal(response.status, 200, "Seed a past round with the emulator admin");
  response = await commit([roundWrite(focusRound, alice.localId)], alice.idToken);
  assert.equal(response.status, 200, "After the break an approved member can replace the round");

  const aliceMessagePath = `${roomPath}/messages/message-alice`;
  async function sendMessage(actor, id, data, previous = {}) {
    const path = `${roomPath}/chat_throttles/${actor.localId}`;
    const throttle = {
      userId: actor.localId,
      messageId: id,
      t0: previous.t1 ?? null,
      t1: previous.t2 ?? null,
      t2: previous.t3 ?? null,
      t3: previous.t4 ?? null,
    };
    const write = createWrite(path, throttle);
    delete write.currentDocument;
    for (const [field, value] of Object.entries(throttle)) {
      if (field.startsWith("t") && value) write.update.fields[field] = { timestampValue: value };
    }
    write.updateTransforms = [{ fieldPath: "t4", setToServerValue: "REQUEST_TIME" }];
    const response = await commit([
      createWrite(`${roomPath}/messages/${id}`, data),
      write,
    ], actor.idToken);
    if (response.ok) {
      const stored = await request(path, actor.idToken);
      assert.equal(stored.status, 200);
      Object.assign(previous, (await stored.json()).fields);
      // Keep typed Firestore timestamps for subsequent shifted writes.
      for (const field of ["t0", "t1", "t2", "t3", "t4"]) {
        previous[field] = previous[field]?.timestampValue ?? null;
      }
    }
    return response;
  }

  const history = {};
  response = await createDoc(
    aliceMessagePath, message(roomId, alice.localId, "message-alice", now), alice.idToken,
  );
  assert.equal(response.status, 403, "A message requires a throttle write");
  for (let index = 0; index < 5; index++) {
    const id = index === 0 ? "message-alice" : `alice-message-${index}`;
    response = await sendMessage(alice, id, message(roomId, alice.localId, id, now), history);
    assert.equal(response.status, 200, `Approved member message ${index + 1}`);
  }
  response = await sendMessage(alice, "alice-sixth", message(roomId, alice.localId, "alice-sixth", now), history);
  assert.equal(response.status, 403, "The sixth message in ten seconds is denied");
  const forgery = message(roomId, alice.localId, "owner-forges-alice", now);
  response = await sendMessage(owner, forgery.id, forgery);
  assert.equal(response.status, 403, "A room owner cannot impersonate another message sender");
  const wrongName = { ...message(roomId, owner.localId, "wrong-name", now), senderName: "偽造" };
  response = await sendMessage(owner, wrongName.id, wrongName);
  assert.equal(response.status, 403, "A member cannot forge the displayed message sender name");
  const long = { ...message(roomId, owner.localId, "too-long", now), text: "a".repeat(501) };
  response = await sendMessage(owner, long.id, long);
  assert.equal(response.status, 403, "A 501-character message is denied");

  response = await request(aliceMessagePath, stranger.idToken);
  assert.equal(
    response.status,
    403,
    "A stranger cannot read room messages",
  );

  const aliceEventPath = `${roomPath}/events/event-alice`;
  response = await createDoc(
    aliceEventPath,
    event(roomId, alice.localId, "event-alice", now),
    alice.idToken,
  );
  assert.equal(
    response.status,
    200,
    "An approved member can create their own room event",
  );

  response = await createDoc(
    `${roomPath}/events/owner-forges-alice`,
    event(roomId, alice.localId, "owner-forges-alice", now),
    owner.idToken,
  );
  assert.equal(
    response.status,
    403,
    "A room owner cannot impersonate another event actor",
  );

  response = await createDoc(
    `${roomPath}/events/alice-forges-system`,
    {
      ...event(roomId, alice.localId, "alice-forges-system", now),
      text: "房主已移交",
      type: "system",
    },
    alice.idToken,
  );
  assert.equal(
    response.status,
    403,
    "A regular member cannot forge a system event",
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
      updateWrite(
        bobMemberPath,
        {
          role: "owner",
          updatedAt: "2026-07-27T09:14:30.000Z",
        },
        ["role", "updatedAt"],
      ),
      createWrite(
        `${roomPath}/events/ownership-transfer`,
        {
          ...event(
            roomId,
            owner.localId,
            "ownership-transfer",
            "2026-07-27T09:15:00.000Z",
          ),
          text: `房主已移交給 ${bob.localId}`,
          type: "system",
        },
      ),
    ],
    owner.idToken,
  );
  assert.equal(
    response.status,
    403,
    "The owner cannot change roles outside an atomic ownership transfer",
  );

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

  response = await commit(
    [
      updateWrite(roomPath, {
        memberIds: [owner.localId, bob.localId],
        updatedAt: "2026-07-27T09:14:00.000Z",
      }),
      createWrite(bobMemberPath, member(roomId, bob.localId, now)),
    ],
    bob.idToken,
  );
  assert.equal(response.status, 200, await response.clone().text());

  response = await commit(
    [
      updateWrite(roomPath, {
        ownerId: bob.localId,
        ownerName: bob.localId,
        updatedAt: "2026-07-27T09:15:00.000Z",
      }),
      updateWrite(
        ownerMemberPath,
        {
          role: "member",
          updatedAt: "2026-07-27T09:15:00.000Z",
        },
        ["role", "updatedAt"],
      ),
      updateWrite(
        bobMemberPath,
        {
          role: "owner",
          updatedAt: "2026-07-27T09:15:00.000Z",
        },
        ["role", "updatedAt"],
      ),
    ],
    owner.idToken,
  );
  assert.equal(
    response.status,
    200,
    "The current owner can atomically transfer room ownership",
  );

  response = await commit(
    [updateWrite(roomPath, { name: "舊房主不能再管理" }, ["name"])],
    owner.idToken,
  );
  assert.equal(
    response.status,
    403,
    "The previous owner loses room-management permission immediately",
  );

  response = await commit(
    [
      updateWrite(
        roomPath,
        {
          status: "closed",
          updatedAt: "2026-07-27T09:16:00.000Z",
        },
        ["status", "updatedAt"],
      ),
    ],
    bob.idToken,
  );
  assert.equal(
    response.status,
    403,
    "A room cannot close while another member remains",
  );

  response = await commit(
    [
      updateWrite(roomPath, {
        memberIds: [bob.localId],
        updatedAt: "2026-07-27T09:16:30.000Z",
      }),
      deleteWrite(ownerMemberPath),
    ],
    bob.idToken,
  );
  assert.equal(
    response.status,
    200,
    "The new owner can remove the previous owner before closing",
  );

  response = await commit(
    [
      updateWrite(
        roomPath,
        {
          status: "closed",
          updatedAt: "2026-07-27T09:17:00.000Z",
        },
        ["status", "updatedAt"],
      ),
    ],
    bob.idToken,
  );
  assert.equal(
    response.status,
    200,
    "The final owner can close a room without deleting its audit parent",
  );

  response = await commit(
    [
      updateWrite(
        roomPath,
        {
          status: "active",
          updatedAt: "2026-07-27T09:18:00.000Z",
        },
        ["status", "updatedAt"],
      ),
    ],
    bob.idToken,
  );
  assert.equal(
    response.status,
    403,
    "A closed room cannot be reopened by a client",
  );

  response = await createDoc(
    `${roomPath}/events/after-close`,
    {
      ...event(roomId, bob.localId, "after-close", now),
      text: "關房後不能再追加",
      type: "complete",
    },
    bob.idToken,
  );
  assert.equal(
    response.status,
    403,
    "A closed room rejects new interaction events",
  );

  response = await request(roomPath, bob.idToken, { method: "DELETE" });
  assert.equal(
    response.status,
    403,
    "Clients cannot orphan room subcollections by deleting the parent",
  );

  const closedWithoutProjectionId = "closed-without-member-projection-" + Date.now();
  const closedWithoutProjectionPath = `rooms/${closedWithoutProjectionId}`;
  response = await createDoc(
    closedWithoutProjectionPath,
    room(closedWithoutProjectionId, stranger.localId, now),
    stranger.idToken,
  );
  assert.equal(response.status, 200, await response.clone().text());

  response = await commit(
    [
      updateWrite(
        closedWithoutProjectionPath,
        {
          status: "closed",
          updatedAt: "2026-07-27T09:19:00.000Z",
        },
        ["status", "updatedAt"],
      ),
    ],
    stranger.idToken,
  );
  assert.equal(response.status, 200, await response.clone().text());

  response = await createDoc(
    `${closedWithoutProjectionPath}/members/${stranger.localId}`,
    member(closedWithoutProjectionId, stranger.localId, now, "owner"),
    stranger.idToken,
  );
  assert.equal(
    response.status,
    403,
    "A closed room rejects late member projection creation",
  );

  console.log("Firestore room rules integration test passed.");
}

run().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
