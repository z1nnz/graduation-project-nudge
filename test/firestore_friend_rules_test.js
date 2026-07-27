const assert = require("node:assert/strict");

const projectId = "nudge-discipline-app";
const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST;
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;

if (!firestoreHost || !authHost) {
  console.log(
    "Firestore friend rules integration test skipped: emulators are not enabled.",
  );
  process.exit(0);
}

const firestoreBase =
  `http://${firestoreHost}/v1/projects/${projectId}` +
  "/databases/(default)/documents";
const runQueryUrl =
  `http://${firestoreHost}/v1/projects/${projectId}` +
  "/databases/(default)/documents:runQuery";
const commitUrl =
  `http://${firestoreHost}/v1/projects/${projectId}` +
  "/databases/(default)/documents:commit";

function valueOf(value) {
  if (typeof value === "string") return { stringValue: value };
  if (typeof value === "boolean") return { booleanValue: value };
  throw new TypeError(`Unsupported test value: ${typeof value}`);
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

function documentName(path) {
  return `projects/${projectId}/databases/(default)/documents/${path}`;
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

async function runMessageQuery(senderId, receiverId, token) {
  return fetch(runQueryUrl, {
    method: "POST",
    headers: {
      authorization: `Bearer ${token}`,
      "content-type": "application/json",
    },
    body: JSON.stringify({
      structuredQuery: {
        from: [{ collectionId: "friend_messages" }],
        where: {
          compositeFilter: {
            op: "AND",
            filters: [
              {
                fieldFilter: {
                  field: { fieldPath: "senderId" },
                  op: "EQUAL",
                  value: { stringValue: senderId },
                },
              },
              {
                fieldFilter: {
                  field: { fieldPath: "receiverId" },
                  op: "EQUAL",
                  value: { stringValue: receiverId },
                },
              },
            ],
          },
        },
        limit: 50,
      },
    }),
  });
}

function message(senderId, receiverId) {
  return {
    senderId,
    receiverId,
    senderName: "愛麗絲",
    senderAvatar: "🧑‍🚀",
    content: "一起繼續加油！",
    type: "text",
    createdAt: "2026-07-27T00:00:00.000Z",
  };
}

async function run() {
  const alice = await signUp("friend-alice");
  const bob = await signUp("friend-bob");
  const stranger = await signUp("friend-stranger");

  for (const account of [alice, bob, stranger]) {
    const response = await createDoc(
      `users/${account.localId}`,
      { username: `NDG_${account.localId}`, userRole: "individual" },
      account.idToken,
    );
    assert.equal(response.status, 200, await response.clone().text());
  }

  let response = await createDoc(
    `friend_messages/stranger-to-bob`,
    message(stranger.localId, bob.localId),
    stranger.idToken,
  );
  assert.equal(
    response.status,
    403,
    "A stranger cannot send a message without a mutual friendship",
  );

  response = await createDoc(
    `users/${alice.localId}/friends/${bob.localId}`,
    { id: bob.localId, name: "Bob", isFollowing: true },
    alice.idToken,
  );
  assert.equal(
    response.status,
    403,
    "A sender cannot manufacture their own half of a friendship",
  );

  response = await createDoc(
    `users/${bob.localId}/friends/${alice.localId}`,
    { id: alice.localId, name: "Alice", isFollowing: true },
    alice.idToken,
  );
  assert.equal(
    response.status,
    403,
    "A sender cannot manufacture the receiver's half either",
  );

  const requestId = `req_${alice.localId}_${bob.localId}`;
  response = await createDoc(
    `friend_requests/${requestId}`,
    {
      senderId: alice.localId,
      senderNudgeId: `NDG_${alice.localId}`,
      senderName: "Alice",
      receiverId: bob.localId,
      receiverNudgeId: `NDG_${bob.localId}`,
      receiverName: "Bob",
      status: "pending",
      createdAt: "2026-07-27T00:00:00.000Z",
    },
    alice.idToken,
  );
  assert.equal(response.status, 200, await response.clone().text());

  response = await createDoc(
    "friend_messages/still-pending",
    message(alice.localId, bob.localId),
    alice.idToken,
  );
  assert.equal(
    response.status,
    403,
    "A pending request does not authorize messages",
  );

  response = await commit(
    [
      updateWrite(`friend_requests/${requestId}`, { status: "accepted" }, [
        "status",
      ]),
    ],
    bob.idToken,
  );
  assert.equal(
    response.status,
    403,
    "Accepting without both friend projections is not atomic and is denied",
  );

  response = await commit(
    [
      updateWrite(`friend_requests/${requestId}`, { status: "accepted" }, [
        "status",
      ]),
      createWrite(`users/${alice.localId}/friends/${bob.localId}`, {
        id: bob.localId,
        name: "Bob",
        isFollowing: true,
      }),
      createWrite(`users/${bob.localId}/friends/${alice.localId}`, {
        id: alice.localId,
        name: "Alice",
        isFollowing: true,
      }),
    ],
    bob.idToken,
  );
  assert.equal(response.status, 200, await response.clone().text());

  const messagePath = "friend_messages/alice-to-bob";
  response = await createDoc(
    messagePath,
    message(alice.localId, bob.localId),
    alice.idToken,
  );
  assert.equal(response.status, 200, await response.clone().text());

  response = await request(messagePath, alice.idToken);
  assert.equal(response.status, 200, "The sender can read their message");

  response = await request(messagePath, bob.idToken);
  assert.equal(response.status, 200, "The receiver can read their message");

  response = await request(messagePath, stranger.idToken);
  assert.equal(
    response.status,
    403,
    "A stranger cannot read another conversation",
  );

  response = await runMessageQuery(
    alice.localId,
    bob.localId,
    alice.idToken,
  );
  assert.equal(
    response.status,
    200,
    `The sender-scoped Web query is authorized: ${await response.clone().text()}`,
  );

  response = await runMessageQuery(
    alice.localId,
    bob.localId,
    stranger.idToken,
  );
  assert.equal(
    response.status,
    403,
    "The same query is denied to a non-participant",
  );

  response = await request(messagePath, alice.idToken, {
    method: "DELETE",
  });
  assert.equal(response.status, 403, "Published messages are immutable");

  response = await commit(
    [
      updateWrite(`friend_requests/${requestId}`, { status: "removed" }, [
        "status",
      ]),
      deleteWrite(`users/${alice.localId}/friends/${bob.localId}`),
      deleteWrite(`users/${bob.localId}/friends/${alice.localId}`),
    ],
    alice.idToken,
  );
  assert.equal(response.status, 200, await response.clone().text());

  response = await createDoc(
    "friend_messages/after-removal",
    message(alice.localId, bob.localId),
    alice.idToken,
  );
  assert.equal(
    response.status,
    403,
    "Removing a friendship revokes permission to send new messages",
  );

  console.log("Firestore friend rules integration test passed.");
}

run().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
