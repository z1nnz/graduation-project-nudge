import crypto from "node:crypto";

const projectId =
  process.env.NUDGE_FIREBASE_PROJECT_ID?.trim() || "nudge-discipline-app";
const apiKey = process.env.NUDGE_FIREBASE_WEB_API_KEY?.trim() || "";
const adminAccessToken =
  process.env.NUDGE_FIREBASE_ADMIN_ACCESS_TOKEN?.trim() || "";

if (!apiKey || !adminAccessToken) {
  throw new Error(
    "NUDGE_FIREBASE_WEB_API_KEY and NUDGE_FIREBASE_ADMIN_ACCESS_TOKEN are required.",
  );
}

const runId = `${Date.now()}-${crypto.randomBytes(4).toString("hex")}`;
const groupId = `E2E-GROUP-${runId}`;
const requestId = `E2E-REQUEST-${runId}`;
const identityBase = "https://identitytoolkit.googleapis.com/v1";
const firestoreResourceBase =
  `projects/${projectId}/databases/(default)/documents`;
const firestoreBase =
  `https://firestore.googleapis.com/v1/${firestoreResourceBase}`;
const steps = [];
const accounts = [];

function encoded(value) {
  if (value === null) return { nullValue: null };
  if (typeof value === "string") return { stringValue: value };
  if (typeof value === "boolean") return { booleanValue: value };
  if (Number.isInteger(value)) return { integerValue: String(value) };
  if (typeof value === "number") return { doubleValue: value };
  if (Array.isArray(value)) {
    return { arrayValue: { values: value.map(encoded) } };
  }
  if (value && typeof value === "object") {
    return {
      mapValue: {
        fields: Object.fromEntries(
          Object.entries(value).map(([key, item]) => [key, encoded(item)]),
        ),
      },
    };
  }
  throw new TypeError(`Unsupported Firestore value: ${typeof value}`);
}

function document(name, data) {
  return {
    name: `${firestoreResourceBase}/${name}`,
    fields: Object.fromEntries(
      Object.entries(data).map(([key, value]) => [key, encoded(value)]),
    ),
  };
}

function updateWrite(name, data, fieldPaths = null) {
  return {
    update: document(name, data),
    ...(fieldPaths
      ? { updateMask: { fieldPaths } }
      : {}),
  };
}

async function jsonRequest(url, options = {}) {
  const response = await fetch(url, {
    ...options,
    signal: AbortSignal.timeout(20_000),
  });
  const text = await response.text();
  let body = {};
  try {
    body = text ? JSON.parse(text) : {};
  } catch {
    body = { raw: text.slice(0, 500) };
  }
  return { response, body };
}

async function identity(method, payload) {
  return jsonRequest(`${identityBase}/${method}?key=${apiKey}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });
}

async function createAccount(label) {
  const email = `nudge.e2e.${runId}.${label}@example.com`;
  const password = `Nudge!${crypto.randomBytes(18).toString("base64url")}`;
  const { response, body } = await identity("accounts:signUp", {
    email,
    password,
    returnSecureToken: true,
  });
  if (!response.ok || !body.localId || !body.idToken) {
    throw new Error(
      `Unable to create synthetic ${label} account: ` +
        `${response.status} ${body.error?.message || "unknown error"}`,
    );
  }
  const account = {
    label,
    email,
    password,
    uid: body.localId,
    idToken: body.idToken,
  };
  accounts.push(account);
  steps.push({ step: `auth.create.${label}`, status: "passed" });
  return account;
}

async function commit(idToken, writes, expectedStatus = 200) {
  const { response, body } = await jsonRequest(`${firestoreBase}:commit`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${idToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ writes }),
  });
  if (response.status !== expectedStatus) {
    throw new Error(
      `Firestore commit expected ${expectedStatus}, received ` +
        `${response.status}: ${body.error?.status || "unknown"} ` +
        `${body.error?.message || ""}`.trim(),
    );
  }
  return body;
}

async function readDocument(idToken, name, expectedStatus = 200) {
  const { response, body } = await jsonRequest(`${firestoreBase}/${name}`, {
    headers: { Authorization: `Bearer ${idToken}` },
  });
  if (response.status !== expectedStatus) {
    throw new Error(
      `Firestore read ${name} expected ${expectedStatus}, received ` +
        `${response.status}: ${body.error?.status || body.error?.message || "unknown"}`,
    );
  }
  return body;
}

async function adminDeleteDocuments(names) {
  const writes = names.map(name => ({
    delete: `${firestoreResourceBase}/${name}`,
  }));
  const { response, body } = await jsonRequest(`${firestoreBase}:batchWrite`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${adminAccessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ writes }),
  });
  if (!response.ok) {
    throw new Error(
      `Admin cleanup failed: ${response.status} ` +
        `${body.error?.status || body.error?.message || "unknown"}`,
    );
  }
}

async function adminDeleteAccounts(targets) {
  if (targets.length === 0) return;
  const { response, body } = await jsonRequest(
    `${identityBase}/projects/${projectId}/accounts:batchDelete`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${adminAccessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        localIds: targets.map(account => account.uid),
        force: true,
      }),
    },
  );
  if (!response.ok || body.errors?.length) {
    throw new Error(
      `Unable to delete synthetic Auth accounts: ${response.status} ` +
        `${body.error?.message || JSON.stringify(body.errors) || "unknown"}`,
    );
  }
}

async function verifyAccountDeleted(account) {
  const { response, body } = await identity("accounts:signInWithPassword", {
    email: account.email,
    password: account.password,
    returnSecureToken: true,
  });
  if (
    response.status !== 400 ||
    !["EMAIL_NOT_FOUND", "INVALID_LOGIN_CREDENTIALS"].includes(
      body.error?.message,
    )
  ) {
    throw new Error(
      `Synthetic ${account.label} account still accepts credentials.`,
    );
  }
  steps.push({ step: `auth.deleted.${account.label}`, status: "passed" });
}

function activeMembership({
  scopeName,
  userId,
  role,
  createdAt,
}) {
  const membershipId = `group--${groupId}--${userId}`;
  return {
    schemaVersion: 1,
    membershipId,
    scopeType: "group",
    scopeId: groupId,
    scopeName,
    userId,
    role,
    status: "active",
    createdAt,
    updatedAt: createdAt,
    activeFrom: createdAt,
  };
}

function endedMembership(active, endedBy, endedAt) {
  return {
    ...active,
    status: "ended",
    updatedAt: endedAt,
    activeUntil: endedAt,
    endedBy,
  };
}

let accountA;
let accountB;
let testError = null;
let cleanupError = null;

try {
  accountA = await createAccount("manager");
  accountB = await createAccount("member");
  const createdAt = new Date().toISOString();
  const groupName = `Nudge E2E ${runId}`;

  for (const account of [accountA, accountB]) {
    await commit(account.idToken, [
      updateWrite(
        `users/${account.uid}`,
        {
          id: account.uid,
          uid: account.uid,
          email: account.email,
          nickname: `E2E ${account.label}`,
          username: `e2e_${runId}_${account.label}`,
          userRole: "individual",
          e2eMarker: runId,
          createdAt,
          updatedAt: createdAt,
        },
        null,
      ),
    ]);
  }
  steps.push({ step: "firestore.own_profiles", status: "passed" });

  await commit(
    accountB.idToken,
    [
      updateWrite(
        `users/${accountA.uid}`,
        { nickname: "unauthorized overwrite" },
        ["nickname"],
      ),
    ],
    403,
  );
  steps.push({
    step: "firestore.cross_account_profile_write_denied",
    status: "passed",
  });

  const managerMembership = activeMembership({
    scopeName: groupName,
    userId: accountA.uid,
    role: "manager",
    createdAt,
  });
  await commit(accountA.idToken, [
    updateWrite(
      `groups/${groupId}`,
      {
        schemaVersion: 1,
        name: groupName,
        ownerId: accountA.uid,
        memberIds: [accountA.uid],
        status: "active",
        e2eMarker: runId,
        createdAt,
        updatedAt: createdAt,
      },
      null,
    ),
    updateWrite(
      `relationship_memberships/${managerMembership.membershipId}`,
      managerMembership,
      null,
    ),
  ]);
  steps.push({
    step: "group.manager_atomic_create_with_membership",
    status: "passed",
  });

  await commit(
    accountB.idToken,
    [
      updateWrite(
        `groups/${groupId}`,
        { name: "unauthorized rename" },
        ["name"],
      ),
    ],
    403,
  );
  steps.push({
    step: "group.non_member_manager_action_denied",
    status: "passed",
  });

  const requestedAt = new Date().toISOString();
  await commit(accountA.idToken, [
    updateWrite(
      `group_requests/${requestId}`,
      {
        senderId: accountA.uid,
        senderNudgeId: `e2e_${runId}_manager`,
        senderNickname: "E2E manager",
        receiverId: accountB.uid,
        groupId,
        groupName,
        status: "pending",
        createdAt: requestedAt,
      },
      null,
    ),
  ]);
  steps.push({ step: "group.invitation_create", status: "passed" });

  const joinedAt = new Date().toISOString();
  const memberMembership = activeMembership({
    scopeName: groupName,
    userId: accountB.uid,
    role: "member",
    createdAt: joinedAt,
  });
  await commit(accountB.idToken, [
    updateWrite(
      `groups/${groupId}`,
      {
        memberIds: [accountA.uid, accountB.uid],
        updatedAt: joinedAt,
      },
      ["memberIds", "updatedAt"],
    ),
    updateWrite(
      `relationship_memberships/${memberMembership.membershipId}`,
      memberMembership,
      null,
    ),
    updateWrite(
      `group_requests/${requestId}`,
      { status: "accepted", updatedAt: joinedAt },
      ["status", "updatedAt"],
    ),
  ]);
  steps.push({
    step: "group.member_atomic_accept_with_membership",
    status: "passed",
  });

  await readDocument(
    accountB.idToken,
    `relationship_memberships/${memberMembership.membershipId}`,
  );
  await readDocument(
    accountA.idToken,
    `relationship_memberships/${memberMembership.membershipId}`,
  );
  steps.push({
    step: "membership.member_and_manager_visibility",
    status: "passed",
  });

  const leftAt = new Date().toISOString();
  await commit(accountB.idToken, [
    updateWrite(
      `groups/${groupId}`,
      { memberIds: [accountA.uid], updatedAt: leftAt },
      ["memberIds", "updatedAt"],
    ),
    updateWrite(
      `relationship_memberships/${memberMembership.membershipId}`,
      endedMembership(memberMembership, accountB.uid, leftAt),
    ),
  ]);
  steps.push({
    step: "group.member_atomic_leave_with_membership_end",
    status: "passed",
  });

  const closedAt = new Date().toISOString();
  await commit(accountA.idToken, [
    updateWrite(
      `relationship_memberships/${managerMembership.membershipId}`,
      endedMembership(managerMembership, accountA.uid, closedAt),
    ),
    { delete: `${firestoreResourceBase}/groups/${groupId}` },
  ]);
  steps.push({
    step: "group.manager_atomic_close_with_membership_end",
    status: "passed",
  });
} catch (error) {
  testError = error;
} finally {
  const documentsToDelete = [
    `groups/${groupId}`,
    `group_requests/${requestId}`,
    ...(accountA
      ? [
          `users/${accountA.uid}`,
          `relationship_memberships/group--${groupId}--${accountA.uid}`,
        ]
      : []),
    ...(accountB
      ? [
          `users/${accountB.uid}`,
          `relationship_memberships/group--${groupId}--${accountB.uid}`,
        ]
      : []),
  ];
  const cleanupFailures = [];
  try {
    await adminDeleteDocuments(documentsToDelete);
  } catch (error) {
    cleanupFailures.push(`documents: ${error.message}`);
  }
  try {
    await adminDeleteAccounts(accounts);
  } catch (error) {
    cleanupFailures.push(`accounts: ${error.message}`);
  }
  try {
    for (const account of accounts) await verifyAccountDeleted(account);
  } catch (error) {
    cleanupFailures.push(`verification: ${error.message}`);
  }
  if (cleanupFailures.length > 0) {
    cleanupError = new Error(cleanupFailures.join("; "));
  }
}

if (testError && cleanupError) {
  throw new Error(
    `E2E failed: ${testError.message}; cleanup also failed: ` +
      cleanupError.message,
  );
}
if (cleanupError) {
  throw new Error(`E2E cleanup failed: ${cleanupError.message}`);
}
if (testError) throw testError;

console.log(
  JSON.stringify(
    {
      projectId,
      runId,
      status: "passed",
      accountCount: accounts.length,
      steps,
      cleanup: "completed",
    },
    null,
    2,
  ),
);
