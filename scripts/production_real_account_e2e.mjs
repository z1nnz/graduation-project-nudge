import crypto from "node:crypto";
import cleanupHelpers from "./production_e2e_cleanup.cjs";

const {
  buildCleanupDocumentNames,
  chunkCleanupDocumentNames,
} = cleanupHelpers;

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
const familyId = `E2E-FAMILY-${runId}`;
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

async function adminReadDocument(name, expectedStatus = 200) {
  const { response, body } = await jsonRequest(`${firestoreBase}/${name}`, {
    headers: { Authorization: `Bearer ${adminAccessToken}` },
  });
  if (response.status !== expectedStatus) {
    throw new Error(
      `Admin Firestore read ${name} expected ${expectedStatus}, received ` +
        `${response.status}: ${body.error?.status || body.error?.message || "unknown"}`,
    );
  }
  return body;
}

async function waitForAdminDocument(name, attempts = 20) {
  for (let attempt = 0; attempt < attempts; attempt += 1) {
    const { response, body } = await jsonRequest(`${firestoreBase}/${name}`, {
      headers: { Authorization: `Bearer ${adminAccessToken}` },
    });
    if (response.status === 200) return body;
    if (response.status !== 404) {
      throw new Error(
        `Admin Firestore wait ${name} failed: ${response.status} ` +
          `${body.error?.status || body.error?.message || "unknown"}`,
      );
    }
    await new Promise(resolve => setTimeout(resolve, 500));
  }
  throw new Error(`Timed out waiting for admin Firestore document ${name}.`);
}

async function adminDeleteDocuments(names) {
  const uniqueNames = buildCleanupDocumentNames(names);
  for (const chunk of chunkCleanupDocumentNames(uniqueNames)) {
    await adminCommit(
      chunk.map(name => ({
        delete: `${firestoreResourceBase}/${name}`,
      })),
    );
  }
  for (const name of uniqueNames) {
    await adminReadDocument(name, 404);
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
  scopeType,
  scopeId,
  scopeName,
  userId,
  role,
  createdAt,
}) {
  const membershipId = `${scopeType}--${scopeId}--${userId}`;
  return {
    schemaVersion: 1,
    membershipId,
    scopeType,
    scopeId,
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
    scopeType: "group",
    scopeId: groupId,
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
  rememberCleanup(
    `group_requests/${requestId}`,
    `audit_events/group-request--${requestId}--created`,
    `audit_events/group-request--${requestId}--accepted`,
  );
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
    scopeType: "group",
    scopeId: groupId,
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
    relationshipOutcome.outcome?.growth?.kind !== "group_planet" ||
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

  await commit(
    accountB.idToken,
    [
      updateWrite(
        `groups/${groupId}`,
        { name: "member cannot rename" },
        ["name"],
      ),
    ],
    403,
  );
  steps.push({
    step: "group.member_manager_action_denied",
    status: "passed",
  });

  const familyScopeName = `家庭連結 ${familyId.slice(-8)}`;
  const familyRequestedAt = new Date().toISOString();
  const familyPendingNotificationId =
    `family-request--${familyId}--pending`;
  const familyAcceptedNotificationId =
    `family-request--${familyId}--accepted`;
  rememberCleanup(
    `guardian_requests/${familyId}`,
    `family_links/${familyId}`,
    `user_notifications/${familyPendingNotificationId}`,
    `push_delivery_jobs/${familyPendingNotificationId}`,
    `user_notifications/${familyAcceptedNotificationId}`,
    `push_delivery_jobs/${familyAcceptedNotificationId}`,
    `audit_events/family-request--${familyId}--created`,
    `audit_events/family-request--${familyId}--accepted`,
    `audit_events/notification-read--${accountB.uid}--${familyPendingNotificationId}`,
  );
  await commit(accountA.idToken, [
    updateWrite(
      `guardian_requests/${familyId}`,
      {
        senderId: accountA.uid,
        senderNudgeId: `e2e_${runId}_guardian`,
        senderNickname: "E2E guardian",
        senderRole: "guardian",
        receiverId: accountB.uid,
        receiverNudgeId: `e2e_${runId}_child`,
        receiverRole: "child",
        status: "pending",
        createdAt: familyRequestedAt,
        updatedAt: familyRequestedAt,
      },
      null,
    ),
  ]);
  steps.push({ step: "family.invitation_create", status: "passed" });

  await waitForDocument(
    accountB.idToken,
    `user_notifications/${familyPendingNotificationId}`,
  );
  const familyCreatedAudit = await waitForAdminDocument(
    `audit_events/family-request--${familyId}--created`,
  );
  if (
    familyCreatedAudit.fields?.action?.stringValue !==
      "relationship.family.invitation.created" ||
    familyCreatedAudit.fields?.targetId?.stringValue !== familyId
  ) {
    throw new Error("The family invitation-created audit is invalid.");
  }
  const familyReadNotification = await callable(
    accountB,
    "markNotificationRead",
    { notificationId: familyPendingNotificationId },
  );
  if (familyReadNotification.status !== "read") {
    throw new Error("The family invitation notification was not marked read.");
  }
  await readDocument(
    accountB.idToken,
    `audit_events/notification-read--${accountB.uid}--${familyPendingNotificationId}`,
  );
  steps.push({ step: "family.notification_audited", status: "passed" });

  const familyAcceptedAt = new Date().toISOString();
  const guardianMembership = activeMembership({
    scopeType: "family",
    scopeId: familyId,
    scopeName: familyScopeName,
    userId: accountA.uid,
    role: "guardian",
    createdAt: familyAcceptedAt,
  });
  const childMembership = activeMembership({
    scopeType: "family",
    scopeId: familyId,
    scopeName: familyScopeName,
    userId: accountB.uid,
    role: "child",
    createdAt: familyAcceptedAt,
  });
  rememberCleanup(
    `relationship_memberships/family--${familyId}--${accountA.uid}`,
    `relationship_memberships/family--${familyId}--${accountB.uid}`,
  );
  await commit(accountB.idToken, [
    updateWrite(
      `guardian_requests/${familyId}`,
      { status: "accepted", updatedAt: familyAcceptedAt },
      ["status", "updatedAt"],
    ),
    updateWrite(
      `family_links/${familyId}`,
      {
        schemaVersion: 1,
        guardianId: accountA.uid,
        childId: accountB.uid,
        participantIds: [accountA.uid, accountB.uid],
        status: "active",
        consentScopes: {
          summary: false,
          weeklyReport: false,
          taskCategories: false,
          healthTrends: false,
        },
        createdAt: familyAcceptedAt,
        updatedAt: familyAcceptedAt,
      },
      null,
    ),
    updateWrite(
      `relationship_memberships/${guardianMembership.membershipId}`,
      guardianMembership,
      null,
    ),
    updateWrite(
      `relationship_memberships/${childMembership.membershipId}`,
      childMembership,
      null,
    ),
  ]);
  await waitForDocument(
    accountA.idToken,
    `user_notifications/${familyAcceptedNotificationId}`,
  );
  const familyAcceptedAudit = await waitForAdminDocument(
    `audit_events/family-request--${familyId}--accepted`,
  );
  if (
    familyAcceptedAudit.fields?.action?.stringValue !==
      "relationship.family.invitation.accepted" ||
    familyAcceptedAudit.fields?.targetId?.stringValue !== familyId
  ) {
    throw new Error("The family invitation-accepted audit is invalid.");
  }
  steps.push({
    step: "family.child_atomic_accept_with_memberships",
    status: "passed",
  });

  for (const [account, membershipPaths] of [
    [accountA, [managerMembership.membershipId, guardianMembership.membershipId]],
    [accountB, [memberMembership.membershipId, childMembership.membershipId]],
  ]) {
    for (const membershipPath of membershipPaths) {
      await readDocument(
        account.idToken,
        `relationship_memberships/${membershipPath}`,
      );
    }
  }
  steps.push({
    step: "membership.family_and_group_coexist",
    status: "passed",
  });

  const encouragementId = `encouragement-${runId}`;
  const encouragementAt = new Date().toISOString();
  rememberCleanup(
    `family_links/${familyId}/encouragements/${encouragementId}`,
    `family_links/${familyId}/bond_events/encouragement_${encouragementId}`,
  );
  await commit(accountA.idToken, [
    updateWrite(
      `family_links/${familyId}/encouragements/${encouragementId}`,
      {
        schemaVersion: 1,
        senderId: accountA.uid,
        recipientId: accountB.uid,
        title: "今天也辛苦了",
        message: "慢慢來就好",
        status: "sent",
        createdAt: encouragementAt,
      },
      null,
    ),
  ]);
  await commit(
    accountA.idToken,
    [
      updateWrite(
        `family_links/${familyId}/encouragements/${encouragementId}`,
        { status: "acknowledged", acknowledgedAt: new Date().toISOString() },
        ["status", "acknowledgedAt"],
      ),
      updateWrite(
        `family_links/${familyId}/bond_events/encouragement_${encouragementId}`,
        {
          schemaVersion: 1,
          type: "acknowledgement",
          sourceId: encouragementId,
          actorId: accountA.uid,
          points: 3,
          createdAt: new Date().toISOString(),
        },
        null,
      ),
    ],
    403,
  );
  steps.push({
    step: "family.guardian_acknowledgement_denied",
    status: "passed",
  });
  await commit(accountB.idToken, [
    updateWrite(
      `family_links/${familyId}/encouragements/${encouragementId}`,
      { status: "acknowledged", acknowledgedAt: new Date().toISOString() },
      ["status", "acknowledgedAt"],
    ),
    updateWrite(
      `family_links/${familyId}/bond_events/encouragement_${encouragementId}`,
      {
        schemaVersion: 1,
        type: "acknowledgement",
        sourceId: encouragementId,
        actorId: accountB.uid,
        points: 3,
        createdAt: new Date().toISOString(),
      },
      null,
    ),
  ]);
  steps.push({
    step: "family.encouragement_acknowledged",
    status: "passed",
  });

  const familyGoalId = `goal-${runId}`;
  const goalProposedAt = new Date().toISOString();
  rememberCleanup(
    `family_links/${familyId}/goals/${familyGoalId}`,
    `family_links/${familyId}/bond_events/goal_${familyGoalId}`,
  );
  await commit(accountA.idToken, [
    updateWrite(
      `family_links/${familyId}/goals/${familyGoalId}`,
      {
        schemaVersion: 1,
        title: "每天專注 30 分鐘",
        message: "一起建立節奏",
        status: "proposed",
        proposedBy: accountA.uid,
        decisionBy: accountB.uid,
        createdAt: goalProposedAt,
        updatedAt: goalProposedAt,
      },
      null,
    ),
  ]);
  await commit(
    accountA.idToken,
    [
      updateWrite(
        `family_links/${familyId}/goals/${familyGoalId}`,
        {
          status: "accepted",
          acceptedAt: goalProposedAt,
          updatedAt: goalProposedAt,
        },
        ["status", "acceptedAt", "updatedAt"],
      ),
    ],
    403,
  );
  steps.push({
    step: "family.guardian_goal_decision_denied",
    status: "passed",
  });
  const goalAcceptedAt = new Date().toISOString();
  await commit(accountB.idToken, [
    updateWrite(
      `family_links/${familyId}/goals/${familyGoalId}`,
      {
        status: "accepted",
        acceptedAt: goalAcceptedAt,
        updatedAt: goalAcceptedAt,
      },
      ["status", "acceptedAt", "updatedAt"],
    ),
  ]);
  const goalCompletedAt = new Date().toISOString();
  await commit(accountB.idToken, [
    updateWrite(
      `family_links/${familyId}/goals/${familyGoalId}`,
      {
        status: "completed",
        completedAt: goalCompletedAt,
        updatedAt: goalCompletedAt,
      },
      ["status", "completedAt", "updatedAt"],
    ),
    updateWrite(
      `family_links/${familyId}/bond_events/goal_${familyGoalId}`,
      {
        schemaVersion: 1,
        type: "goalCompleted",
        sourceId: familyGoalId,
        actorId: accountB.uid,
        points: 10,
        createdAt: goalCompletedAt,
      },
      null,
    ),
  ]);
  steps.push({ step: "family.goal_completed", status: "passed" });

  rememberCleanup(
    `relationship_outcomes/family--${familyId}`,
    `relationship_outcomes/family--${familyId}/memories/encouragement_ack--encouragement_${encouragementId}`,
    `relationship_outcomes/family--${familyId}/memories/goal_completed--goal_${familyGoalId}`,
  );
  const familyOutcome = await callable(
    accountB,
    "refreshRelationshipOutcome",
    { scopeType: "family", scopeId: familyId },
  );
  const familyMemoryTypes = new Set(
    (familyOutcome.memories || []).map(familyMemory => {
      rememberCleanup(
        `relationship_outcomes/family--${familyId}/memories/${familyMemory.memoryId}`,
      );
      return familyMemory.memoryType;
    }),
  );
  if (
    familyOutcome.outcome?.outcomeId !== `family--${familyId}` ||
    familyOutcome.outcome?.growth?.kind !== "family_tree" ||
    familyOutcome.outcome?.characterOutcome?.kind !== "family_companion" ||
    !familyMemoryTypes.has("encouragement_ack") ||
    !familyMemoryTypes.has("goal_completed")
  ) {
    throw new Error("Formal family outcome or shared memories are invalid.");
  }
  await readDocument(
    accountA.idToken,
    `relationship_outcomes/family--${familyId}`,
  );
  for (const expectedMemory of [
    {
      memoryId: `encouragement_ack--encouragement_${encouragementId}`,
      memoryType: "encouragement_ack",
      sourceId: `encouragement_${encouragementId}`,
    },
    {
      memoryId: `goal_completed--goal_${familyGoalId}`,
      memoryType: "goal_completed",
      sourceId: `goal_${familyGoalId}`,
    },
  ]) {
    const memoryDocument = await readDocument(
      accountA.idToken,
      `relationship_outcomes/family--${familyId}/memories/${expectedMemory.memoryId}`,
    );
    if (
      memoryDocument.fields?.memoryId?.stringValue !== expectedMemory.memoryId ||
      memoryDocument.fields?.scopeId?.stringValue !== familyId ||
      memoryDocument.fields?.memoryType?.stringValue !== expectedMemory.memoryType ||
      memoryDocument.fields?.sourceId?.stringValue !== expectedMemory.sourceId ||
      !memoryDocument.fields?.actorId?.stringValue
    ) {
      throw new Error(
        `Persisted family memory ${expectedMemory.memoryId} is invalid.`,
      );
    }
  }
  steps.push({
    step: "cloud.family_outcome_and_memories",
    status: "passed",
  });

  const familyEndedAt = new Date().toISOString();
  await commit(accountA.idToken, [
    updateWrite(
      `family_links/${familyId}`,
      {
        status: "ended",
        endedBy: accountA.uid,
        endedAt: familyEndedAt,
        updatedAt: familyEndedAt,
      },
      ["status", "endedBy", "endedAt", "updatedAt"],
    ),
    updateWrite(
      `guardian_requests/${familyId}`,
      { status: "ended", updatedAt: familyEndedAt },
      ["status", "updatedAt"],
    ),
    updateWrite(
      `relationship_memberships/${guardianMembership.membershipId}`,
      endedMembership(guardianMembership, accountA.uid, familyEndedAt),
      null,
    ),
    updateWrite(
      `relationship_memberships/${childMembership.membershipId}`,
      endedMembership(childMembership, accountA.uid, familyEndedAt),
      null,
    ),
  ]);
  steps.push({
    step: "family.atomic_end_with_membership_end",
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
  const documentsToDelete = buildCleanupDocumentNames(
    cleanupDocuments,
    accountA
      ? [
          `users/${accountA.uid}`,
          `relationship_memberships/group--${groupId}--${accountA.uid}`,
          `relationship_memberships/family--${familyId}--${accountA.uid}`,
        ]
      : [],
    accountB
      ? [
          `users/${accountB.uid}`,
          `relationship_memberships/group--${groupId}--${accountB.uid}`,
          `relationship_memberships/family--${familyId}--${accountB.uid}`,
        ]
      : [],
  );
  const cleanupFailures = [];
  let documentsCleaned = false;
  try {
    await adminDeleteDocuments(documentsToDelete);
    documentsCleaned = true;
  } catch (error) {
    cleanupFailures.push(`documents: ${error.message}`);
  }
  if (documentsCleaned) {
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
  } else {
    cleanupFailures.push(
      "accounts: skipped to preserve recoverability after document cleanup failed",
    );
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
