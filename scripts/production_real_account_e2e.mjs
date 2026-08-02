import crypto from "node:crypto";

const projectId =
  process.env.NUDGE_FIREBASE_PROJECT_ID?.trim() || "nudge-discipline-app";
const apiKey = process.env.NUDGE_FIREBASE_WEB_API_KEY?.trim() || "";
const adminAccessToken =
  process.env.NUDGE_FIREBASE_ADMIN_ACCESS_TOKEN?.trim() || "";
const appCheckToken =
  process.env.NUDGE_FIREBASE_APP_CHECK_TOKEN?.trim() || "";
const functionsRegion =
  process.env.NUDGE_FIREBASE_FUNCTIONS_REGION?.trim() || "asia-east1";
const privacyPolicyVersion =
  process.env.NUDGE_PRIVACY_POLICY_VERSION?.trim() || "2026-07-29";

if (!apiKey || !adminAccessToken || !appCheckToken) {
  throw new Error(
    "NUDGE_FIREBASE_WEB_API_KEY, NUDGE_FIREBASE_ADMIN_ACCESS_TOKEN and " +
      "NUDGE_FIREBASE_APP_CHECK_TOKEN are required.",
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
const functionsBase =
  `https://${functionsRegion}-${projectId}.cloudfunctions.net`;
const steps = [];
const accounts = [];
const cleanupDocuments = new Set();

function stableHash(value) {
  return crypto.createHash("sha256").update(value).digest("hex");
}

function rememberCleanup(...names) {
  for (const name of names) {
    if (name) cleanupDocuments.add(name);
  }
}

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

async function callable(account, functionName, data) {
  const { response, body } = await jsonRequest(
    `${functionsBase}/${functionName}`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${account.idToken}`,
        "Content-Type": "application/json",
        "X-Firebase-AppCheck": appCheckToken,
      },
      body: JSON.stringify({ data }),
    },
  );
  if (!response.ok) {
    throw new Error(
      `${functionName} failed: ${response.status} ` +
        `${body.error?.status || body.error?.message || "unknown"}`,
    );
  }
  const result = body.result ?? body.data;
  if (!result || typeof result !== "object") {
    throw new Error(`${functionName} returned an invalid callable response.`);
  }
  return result;
}

async function waitForDocument(idToken, name, attempts = 20) {
  for (let attempt = 0; attempt < attempts; attempt += 1) {
    const { response, body } = await jsonRequest(`${firestoreBase}/${name}`, {
      headers: { Authorization: `Bearer ${idToken}` },
    });
    if (response.status === 200) return body;
    if (response.status !== 404 && response.status !== 403) {
      throw new Error(
        `Firestore wait ${name} failed: ${response.status} ` +
          `${body.error?.status || body.error?.message || "unknown"}`,
      );
    }
    await new Promise(resolve => setTimeout(resolve, 500));
  }
  throw new Error(`Timed out waiting for Firestore document ${name}.`);
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
  rememberCleanup(`users/${account.uid}`);
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

async function adminCommit(writes) {
  const { response, body } = await jsonRequest(`${firestoreBase}:commit`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${adminAccessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ writes }),
  });
  if (!response.ok) {
    throw new Error(
      `Admin commit failed: ${response.status} ` +
        `${body.error?.status || body.error?.message || "unknown"}`,
    );
  }
  return body;
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

  const privacyRequestId = `privacy-consent-${runId}`;
  rememberCleanup(
    `privacy_consents/${accountB.uid}`,
    `audit_events/privacy-consent--${accountB.uid}--${privacyRequestId}`,
  );
  const privacyResult = await callable(accountB, "recordPrivacyConsent", {
    action: "accept",
    policyVersion: privacyPolicyVersion,
    clientRequestId: privacyRequestId,
    sourceSurface: "app",
  });
  if (
    privacyResult.consent?.status !== "accepted" ||
    privacyResult.consent?.scopes?.healthIngestion !== true
  ) {
    throw new Error("Privacy consent was not persisted as accepted.");
  }
  await readDocument(accountB.idToken, `privacy_consents/${accountB.uid}`);
  await readDocument(
    accountB.idToken,
    `audit_events/privacy-consent--${accountB.uid}--${privacyRequestId}`,
  );
  steps.push({ step: "cloud.privacy_consent_audited", status: "passed" });

  const deletionClientRequestId = `privacy-delete-${runId}`;
  const deletionRequestId = `${accountB.uid}--${deletionClientRequestId}`;
  const deletionCancelRequestId = `privacy-cancel-${runId}`;
  rememberCleanup(
    `privacy_data_requests/${deletionRequestId}`,
    `audit_events/privacy-data--${accountB.uid}--${deletionClientRequestId}`,
    `audit_events/privacy-data-cancel--${accountB.uid}--${deletionCancelRequestId}`,
  );
  const deletionRequest = await callable(
    accountB,
    "requestPrivacyDataAction",
    {
      action: "request_account_deletion",
      clientRequestId: deletionClientRequestId,
      sourceSurface: "app",
      reason: "production-real-account-e2e",
    },
  );
  if (
    deletionRequest.request?.requestId !== deletionRequestId ||
    deletionRequest.request?.status !== "pending"
  ) {
    throw new Error("Privacy deletion request did not enter the cooling period.");
  }
  const deletionCancellation = await callable(
    accountB,
    "cancelPrivacyDataRequest",
    {
      requestId: deletionRequestId,
      clientRequestId: deletionCancelRequestId,
      sourceSurface: "app",
    },
  );
  if (deletionCancellation.request?.status !== "cancelled") {
    throw new Error("Privacy deletion request was not safely cancelled.");
  }
  await readDocument(
    accountB.idToken,
    `audit_events/privacy-data--${accountB.uid}--${deletionClientRequestId}`,
  );
  await readDocument(
    accountB.idToken,
    `audit_events/privacy-data-cancel--${accountB.uid}--${deletionCancelRequestId}`,
  );
  steps.push({
    step: "cloud.privacy_deletion_request_cancel_audited",
    status: "passed",
  });

  const notificationRequestId = `notification-${runId}`;
  rememberCleanup(
    `notification_preferences/${accountB.uid}`,
    `audit_events/notification-preferences--${accountB.uid}--${notificationRequestId}`,
  );
  const notificationResult = await callable(
    accountB,
    "updateNotificationPreferences",
    {
      clientRequestId: notificationRequestId,
      sourceSurface: "app",
      channels: {
        tasks: { enabled: true, timeLabel: "20:30" },
        sleep: { enabled: true, timeLabel: "23:00" },
        rooms: { enabled: true, timeLabel: "19:30" },
        deadline: { enabled: true, timeLabel: "09:00" },
      },
    },
  );
  if (notificationResult.preferences?.userId !== accountB.uid) {
    throw new Error("Notification preferences were written for another user.");
  }
  await readDocument(
    accountB.idToken,
    `notification_preferences/${accountB.uid}`,
  );
  await readDocument(
    accountB.idToken,
    `audit_events/notification-preferences--${accountB.uid}--${notificationRequestId}`,
  );
  steps.push({
    step: "cloud.notification_preferences_audited",
    status: "passed",
  });

  const activityCorrelationId = `e2e-focus-${runId}`;
  const activitySessionId = `session-${activityCorrelationId}`;
  const startedEventId = `event-${activityCorrelationId}-started`;
  const startedSourceRecordId = `source-${activityCorrelationId}-started`;
  const completedEventId = `event-${activityCorrelationId}-completed`;
  const completedSourceRecordId = `source-${activityCorrelationId}-completed`;
  const eventKeys = [
    JSON.stringify([accountB.uid, "app", startedEventId]),
    JSON.stringify([accountB.uid, "app", completedEventId]),
  ];
  const sourceKeys = [
    JSON.stringify(["app", accountB.uid, startedSourceRecordId]),
    JSON.stringify(["app", accountB.uid, completedSourceRecordId]),
  ];
  const activityFingerprint = JSON.stringify([
    accountB.uid,
    `correlation:${activityCorrelationId}`,
    "focus",
  ]);
  const expectedReceiptId =
    `receipt_${stableHash(activityFingerprint).slice(0, 40)}`;
  rememberCleanup(
    ...eventKeys.map(key => `activity_events/${stableHash(key)}`),
    ...sourceKeys.map(key => `activity_source_records/${stableHash(key)}`),
    `activity_sessions/${stableHash(activityFingerprint)}`,
    `activity_settlements/${stableHash(activityFingerprint)}`,
    `activity_receipts/${expectedReceiptId}`,
  );
  const baseEvidence = {
    sessionId: activitySessionId,
    activityCorrelationId,
    actorUserId: accountB.uid,
    roomIds: [],
    activityType: "focus",
    source: "app",
    metricUnit: "minutes",
  };
  const startedActivity = await callable(accountB, "recordActivity", {
    evidence: {
      ...baseEvidence,
      eventId: startedEventId,
      sourceRecordId: startedSourceRecordId,
      eventType: "started",
      metricValue: 0,
      occurredAt: new Date().toISOString(),
    },
  });
  if (startedActivity.status !== "accepted") {
    throw new Error("Activity Ledger did not accept the started lifecycle.");
  }
  const completedActivity = await callable(accountB, "recordActivity", {
    evidence: {
      ...baseEvidence,
      eventId: completedEventId,
      sourceRecordId: completedSourceRecordId,
      eventType: "completed",
      metricValue: 0,
      occurredAt: new Date().toISOString(),
    },
  });
  if (
    completedActivity.status !== "settled" ||
    completedActivity.receipt?.actorUserId !== accountB.uid ||
    completedActivity.receipt?.receiptId !== expectedReceiptId ||
    completedActivity.receipt?.rewardIssued !== false
  ) {
    throw new Error("Activity Ledger lifecycle settlement is invalid.");
  }
  steps.push({ step: "cloud.activity_ledger_lifecycle", status: "passed" });

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
  rememberCleanup(
    `groups/${groupId}`,
    `relationship_memberships/${managerMembership.membershipId}`,
  );
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
  rememberCleanup(`group_requests/${requestId}`);
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

  const pendingNotificationId = `group-request--${requestId}--pending`;
  rememberCleanup(
    `user_notifications/${pendingNotificationId}`,
    `push_delivery_jobs/${pendingNotificationId}`,
    `audit_events/notification-read--${accountB.uid}--${pendingNotificationId}`,
  );
  await waitForDocument(
    accountB.idToken,
    `user_notifications/${pendingNotificationId}`,
  );
  const readNotification = await callable(accountB, "markNotificationRead", {
    notificationId: pendingNotificationId,
  });
  if (readNotification.status !== "read") {
    throw new Error("In-app relationship notification was not marked read.");
  }
  await readDocument(
    accountB.idToken,
    `audit_events/notification-read--${accountB.uid}--${pendingNotificationId}`,
  );
  steps.push({
    step: "cloud.relationship_notification_audited",
    status: "passed",
  });

  const joinedAt = new Date().toISOString();
  const memberMembership = activeMembership({
    scopeName: groupName,
    userId: accountB.uid,
    role: "member",
    createdAt: joinedAt,
  });
  rememberCleanup(
    `relationship_memberships/${memberMembership.membershipId}`,
    `user_notifications/group-request--${requestId}--accepted`,
    `push_delivery_jobs/group-request--${requestId}--accepted`,
  );
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
  await waitForDocument(
    accountA.idToken,
    `user_notifications/group-request--${requestId}--accepted`,
  );
  steps.push({
    step: "cloud.relationship_notification_outcome",
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

  rememberCleanup(`relationship_outcomes/group--${groupId}`);
  const relationshipOutcome = await callable(
    accountB,
    "refreshRelationshipOutcome",
    { scopeType: "group", scopeId: groupId },
  );
  if (
    relationshipOutcome.outcome?.outcomeId !== `group--${groupId}` ||
    relationshipOutcome.outcome?.characterOutcome?.kind !== "group_companion"
  ) {
    throw new Error("Formal group relationship outcome is invalid.");
  }
  await readDocument(
    accountB.idToken,
    `relationship_outcomes/group--${groupId}`,
  );
  steps.push({
    step: "cloud.relationship_outcome_membership_bound",
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

  const auditedPrivacyEvent =
    `audit_events/privacy-consent--${accountB.uid}--${privacyRequestId}`;
  await readDocument(accountA.idToken, auditedPrivacyEvent, 403);
  await adminCommit([
    updateWrite(
      `users/${accountA.uid}`,
      { staffRole: "operator" },
      ["staffRole"],
    ),
  ]);
  await readDocument(accountA.idToken, auditedPrivacyEvent);
  steps.push({
    step: "admin.audit_role_boundary",
    status: "passed",
  });
} catch (error) {
  testError = error;
} finally {
  const documentsToDelete = [
    ...cleanupDocuments,
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
      functionsRegion,
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
