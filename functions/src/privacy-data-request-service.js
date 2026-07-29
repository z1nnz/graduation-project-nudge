import { createHash, randomUUID } from "node:crypto";
import { FieldPath } from "firebase-admin/firestore";

import { HttpsError } from "firebase-functions/v2/https";

const STAFF_ROLES = new Set(["developer", "operator", "admin"]);
const USER_ACTIONS = new Set([
  "request_export",
  "request_account_deletion",
]);
const ADMIN_ACTIONS = new Set(["start_review", "reject", "complete"]);
const SOURCE_SURFACES = new Set(["app", "web"]);
const EXPORT_RETENTION_DAYS = 7;
const DELETION_REVIEW_DELAY_DAYS = 7;
const COLLECTION_EXPORT_LIMIT = 500;
const MAX_EXPORT_BYTES = 10 * 1024 * 1024;

function normalizedString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function stableRequestId(value, label = "clientRequestId") {
  const result = normalizedString(value);
  if (!/^[A-Za-z0-9_-]{8,128}$/.test(result)) {
    throw new HttpsError(
      "invalid-argument",
      `A stable privacy ${label} is required.`,
    );
  }
  return result;
}

function validSourceSurface(value, allowed = SOURCE_SURFACES) {
  const result = normalizedString(value);
  if (!allowed.has(result)) {
    throw new HttpsError(
      "invalid-argument",
      "Privacy data sourceSurface is invalid.",
    );
  }
  return result;
}

function boundedReason(value, { required = false } = {}) {
  const result = normalizedString(value);
  if ((required && result.length < 8) || result.length > 1_000) {
    throw new HttpsError(
      "invalid-argument",
      required
        ? "A resolution note of 8 to 1000 characters is required."
        : "Privacy request reasons must be at most 1000 characters.",
    );
  }
  return result;
}

function normalizedCaseId(value, { required = false } = {}) {
  const result = normalizedString(value).toUpperCase();
  if (!result && !required) return "";
  if (!/^CASE-\d{4}-[A-Z0-9][A-Z0-9_-]{3,63}$/.test(result)) {
    throw new HttpsError(
      "invalid-argument",
      "Completion requires a structured caseId such as CASE-2026-0001.",
    );
  }
  return result;
}

function addDays(date, days) {
  return new Date(date.getTime() + days * 24 * 60 * 60 * 1_000);
}

function sha256(value) {
  return createHash("sha256").update(value).digest("hex");
}

function sanitizedExportFailureCode(error) {
  const code = normalizedString(error?.code).replace(/^functions\//, "");
  return new Set([
    "resource-exhausted",
    "deadline-exceeded",
    "unavailable",
  ]).has(code)
    ? code
    : "internal";
}

function isStaffProfile(profile) {
  return profile?.developerAccess === true ||
    STAFF_ROLES.has(normalizedString(profile?.staffRole));
}

function serializeExportValue(value) {
  if (value === null || value === undefined) return value ?? null;
  if (value instanceof Date) return value.toISOString();
  if (typeof value?.toDate === "function") {
    return value.toDate().toISOString();
  }
  if (typeof value?.path === "string" && value.firestore) {
    return { documentPath: value.path };
  }
  if (Array.isArray(value)) return value.map(serializeExportValue);
  if (Buffer.isBuffer(value)) {
    return { encoding: "base64", value: value.toString("base64") };
  }
  if (typeof value === "object") {
    return Object.fromEntries(
      Object.entries(value).map(([key, item]) => [
        key,
        serializeExportValue(item),
      ]),
    );
  }
  return value;
}

function exportDocument(snapshot) {
  return {
    id: snapshot.id,
    data: serializeExportValue(snapshot.data()),
  };
}

async function readSingleDocument(firestore, collection, documentId) {
  const snapshot = await firestore.collection(collection).doc(documentId).get();
  return snapshot.exists ? [exportDocument(snapshot)] : [];
}

export async function collectQueryDocuments(query) {
  const documents = [];
  let cursor = null;

  while (true) {
    let pageQuery = query
      .orderBy(FieldPath.documentId())
      .limit(COLLECTION_EXPORT_LIMIT);
    if (cursor) pageQuery = pageQuery.startAfter(cursor);
    const snapshot = await pageQuery.get();
    documents.push(...snapshot.docs.map(exportDocument));
    if (snapshot.size < COLLECTION_EXPORT_LIMIT) break;
    cursor = snapshot.docs.at(-1);
  }

  return documents;
}

async function readSubcollection(firestore, path) {
  return {
    documents: await collectQueryDocuments(firestore.collection(path)),
  };
}

async function readQuery(firestore, collection, field, operator, value) {
  return {
    documents: await collectQueryDocuments(
      firestore.collection(collection).where(field, operator, value),
    ),
  };
}

function mergeDocuments(...groups) {
  const byId = new Map();
  for (const group of groups) {
    for (const document of group) byId.set(document.id, document);
  }
  return [...byId.values()];
}

export function buildRelationshipScopeExport(membership) {
  const data = membership.data;
  return {
    id: normalizedString(data.scopeId) || membership.id,
    data: {
      schemaVersion: 1,
      scopeType: normalizedString(data.scopeType),
      scopeId: normalizedString(data.scopeId),
      scopeName: normalizedString(data.scopeName),
      requesterRole: normalizedString(data.role),
      status: normalizedString(data.status),
      activeFrom: serializeExportValue(data.activeFrom),
      activeUntil: serializeExportValue(data.activeUntil),
    },
  };
}

export async function collectPrivacyExportData({ firestore, userId }) {
  const [
    user,
    publicProfile,
    consent,
    notificationPreferences,
    pushDeliveryState,
    friends,
    memberships,
    activityEvents,
    activityReceipts,
    activitySessions,
    roomContributions,
    rooms,
    notifications,
    sentFriendRequests,
    receivedFriendRequests,
    auditEvents,
    privacyRequests,
  ] = await Promise.all([
    readSingleDocument(firestore, "users", userId),
    readSingleDocument(firestore, "public_profiles", userId),
    readSingleDocument(firestore, "privacy_consents", userId),
    readSingleDocument(firestore, "notification_preferences", userId),
    readSingleDocument(firestore, "push_delivery_state", userId),
    readSubcollection(firestore, `users/${userId}/friends`),
    readQuery(
      firestore,
      "relationship_memberships",
      "userId",
      "==",
      userId,
    ),
    readQuery(firestore, "activity_events", "actorUserId", "==", userId),
    readQuery(firestore, "activity_receipts", "actorUserId", "==", userId),
    readQuery(firestore, "activity_sessions", "actorUserId", "==", userId),
    readQuery(firestore, "room_contributions", "actorUserId", "==", userId),
    readQuery(firestore, "rooms", "memberIds", "array-contains", userId),
    readQuery(
      firestore,
      "user_notifications",
      "recipientUserId",
      "==",
      userId,
    ),
    readQuery(firestore, "friend_requests", "senderId", "==", userId),
    readQuery(firestore, "friend_requests", "receiverId", "==", userId),
    readQuery(firestore, "audit_events", "actorUserId", "==", userId),
    readQuery(firestore, "privacy_data_requests", "userId", "==", userId),
  ]);

  const familyLinks = memberships.documents
    .filter(item => item.data.scopeType === "family")
    .map(buildRelationshipScopeExport);
  const groups = memberships.documents
    .filter(item => item.data.scopeType === "group")
    .map(buildRelationshipScopeExport);
  return {
    schemaVersion: 1,
    userId,
    collections: {
      users: user,
      public_profiles: publicProfile,
      privacy_consents: consent,
      notification_preferences: notificationPreferences,
      push_delivery_state: pushDeliveryState,
      users_friends: friends.documents,
      relationship_memberships: memberships.documents,
      family_links: familyLinks,
      groups,
      activity_events: activityEvents.documents,
      activity_receipts: activityReceipts.documents,
      activity_sessions: activitySessions.documents,
      room_contributions: roomContributions.documents,
      rooms: rooms.documents,
      user_notifications: notifications.documents,
      friend_requests: mergeDocuments(
        sentFriendRequests.documents,
        receivedFriendRequests.documents,
      ),
      audit_events: auditEvents.documents,
      privacy_data_requests: privacyRequests.documents,
    },
    excludedServerSecrets: [
      "push_installations.token",
      "push_token_claims",
      "privacy_export_access.downloadToken",
    ],
    truncatedCollections: [],
  };
}

export function normalizePrivacyDataRequest(data) {
  const action = normalizedString(data?.action);
  if (!USER_ACTIONS.has(action)) {
    throw new HttpsError(
      "invalid-argument",
      "Privacy data request action is invalid.",
    );
  }
  return {
    action,
    clientRequestId: stableRequestId(data?.clientRequestId),
    sourceSurface: validSourceSurface(data?.sourceSurface),
    reason: boundedReason(data?.reason),
  };
}

function privacyRequestAudit({
  auditEventId,
  userId,
  input,
  request,
  now,
}) {
  return {
    schemaVersion: 1,
    auditEventId,
    category: "privacy",
    action: `privacy.data.${input.action}`,
    actorUserId: userId,
    targetType: "privacy_data_request",
    targetId: request.requestId,
    sourceSurface: input.sourceSurface,
    clientRequestId: input.clientRequestId,
    result: { request },
    createdAt: now,
    updatedAt: now,
  };
}

function assertReplay(audit, { userId, action }) {
  if (
    audit.actorUserId !== userId ||
    audit.action !== `privacy.data.${action}`
  ) {
    throw new HttpsError(
      "already-exists",
      "The privacy clientRequestId was already used.",
    );
  }
}

export function createRequestPrivacyDataActionHandler({
  firestore,
  bucket,
  clock,
  randomToken = randomUUID,
  collectUserData = userId =>
    collectPrivacyExportData({ firestore, userId }),
}) {
  return async request => {
    const userId = request.auth?.uid;
    if (!userId) {
      throw new HttpsError(
        "unauthenticated",
        "Authentication is required to exercise privacy data rights.",
      );
    }
    const input = normalizePrivacyDataRequest(request.data);
    const requestId = `${userId}--${input.clientRequestId}`;
    const requestRef = firestore.collection("privacy_data_requests").doc(requestId);
    const auditRef = firestore
      .collection("audit_events")
      .doc(`privacy-data--${userId}--${input.clientRequestId}`);
    const accessRef = firestore
      .collection("privacy_export_access")
      .doc(requestId);
    const requestedAtDate = clock();
    const requestedAt = requestedAtDate.toISOString();

    if (input.action === "request_account_deletion") {
      return firestore.runTransaction(async transaction => {
        const existingAudit = await transaction.get(auditRef);
        if (existingAudit.exists) {
          const audit = existingAudit.data();
          assertReplay(audit, { userId, action: input.action });
          return {
            replayed: true,
            request: audit.result.request,
            auditEventId: auditRef.id,
          };
        }
        const privacyRequest = {
          schemaVersion: 1,
          requestId,
          userId,
          type: "account_deletion",
          status: "pending",
          sourceSurface: input.sourceSurface,
          reason: input.reason,
          requestedAt,
          reviewAfter: addDays(
            requestedAtDate,
            DELETION_REVIEW_DELAY_DAYS,
          ).toISOString(),
          updatedAt: requestedAt,
        };
        transaction.create(requestRef, privacyRequest);
        transaction.create(
          auditRef,
          privacyRequestAudit({
            auditEventId: auditRef.id,
            userId,
            input,
            request: privacyRequest,
            now: requestedAt,
          }),
        );
        return {
          replayed: false,
          request: privacyRequest,
          auditEventId: auditRef.id,
        };
      });
    }

    if (!bucket) {
      throw new HttpsError(
        "failed-precondition",
        "Privacy export storage is not configured.",
      );
    }
    const initial = await firestore.runTransaction(async transaction => {
      const existingAudit = await transaction.get(auditRef);
      if (existingAudit.exists) {
        const audit = existingAudit.data();
        assertReplay(audit, { userId, action: input.action });
        const accessSnapshot = await transaction.get(accessRef);
        return {
          replayed: true,
          request: audit.result.request,
          downloadToken: accessSnapshot.exists
            ? normalizedString(accessSnapshot.data().downloadToken)
            : "",
        };
      }
      const downloadToken = normalizedString(randomToken());
      if (downloadToken.length < 16) {
        throw new HttpsError(
          "internal",
          "Privacy export token generation failed.",
        );
      }
      const expiresAt = addDays(
        requestedAtDate,
        EXPORT_RETENTION_DAYS,
      ).toISOString();
      const storagePath = `privacy_exports/${userId}/${requestId}.json`;
      const privacyRequest = {
        schemaVersion: 1,
        requestId,
        userId,
        type: "export",
        status: "processing",
        sourceSurface: input.sourceSurface,
        requestedAt,
        updatedAt: requestedAt,
        expiresAt,
        storagePath,
        downloadTokenHash: sha256(downloadToken),
      };
      transaction.create(requestRef, privacyRequest);
      transaction.create(accessRef, {
        schemaVersion: 1,
        requestId,
        userId,
        storagePath,
        downloadToken,
        expiresAt,
        createdAt: requestedAt,
      });
      transaction.create(
        auditRef,
        privacyRequestAudit({
          auditEventId: auditRef.id,
          userId,
          input,
          request: privacyRequest,
          now: requestedAt,
        }),
      );
      return { replayed: false, request: privacyRequest, downloadToken };
    });

    if (initial.request.status === "ready") {
      return {
        replayed: true,
        request: initial.request,
        auditEventId: auditRef.id,
      };
    }
    if (!initial.downloadToken) {
      throw new HttpsError(
        "failed-precondition",
        "The privacy export access record is unavailable.",
      );
    }

    try {
      const exportData = await collectUserData(userId);
      const artifact = {
        schemaVersion: 1,
        exportType: "nudge_account_data",
        requestId,
        generatedAt: clock().toISOString(),
        ...exportData,
      };
      const body = Buffer.from(JSON.stringify(artifact, null, 2));
      if (body.byteLength > MAX_EXPORT_BYTES) {
        throw new HttpsError(
          "resource-exhausted",
          "The account export exceeds the current downloadable size limit.",
        );
      }
      await bucket.file(initial.request.storagePath).save(body, {
        resumable: false,
        metadata: {
          contentType: "application/json; charset=utf-8",
          cacheControl: "private,max-age=0,no-store",
          metadata: {
            ownerUserId: userId,
            requestId,
            expiresAt: initial.request.expiresAt,
            firebaseStorageDownloadTokens: initial.downloadToken,
          },
        },
      });
      const readyAt = clock().toISOString();
      const readyRequest = {
        ...initial.request,
        status: "ready",
        generatedAt: artifact.generatedAt,
        updatedAt: readyAt,
        exportBytes: body.byteLength,
        truncatedCollections: [],
      };
      await firestore.runTransaction(async transaction => {
        transaction.update(requestRef, {
          status: readyRequest.status,
          generatedAt: readyRequest.generatedAt,
          updatedAt: readyRequest.updatedAt,
          exportBytes: readyRequest.exportBytes,
          truncatedCollections: readyRequest.truncatedCollections,
        });
        transaction.update(auditRef, {
          result: { request: readyRequest },
          updatedAt: readyAt,
        });
      });
      return {
        replayed: initial.replayed,
        request: readyRequest,
        auditEventId: auditRef.id,
      };
    } catch (error) {
      const failedAt = clock().toISOString();
      let failedRequest = null;
      const markedFailed = await firestore.runTransaction(async transaction => {
        const currentSnapshot = await transaction.get(requestRef);
        if (
          !currentSnapshot.exists ||
          currentSnapshot.data().status !== "processing"
        ) {
          return false;
        }
        const current = currentSnapshot.data();
        failedRequest = {
          ...current,
          status: "failed",
          failureCode: sanitizedExportFailureCode(error),
          artifactExpiresAt: current.expiresAt,
          expiresAt: null,
          failedAt,
          updatedAt: failedAt,
        };
        transaction.update(requestRef, {
          status: failedRequest.status,
          failureCode: failedRequest.failureCode,
          artifactExpiresAt: failedRequest.artifactExpiresAt,
          expiresAt: failedRequest.expiresAt,
          failedAt: failedRequest.failedAt,
          updatedAt: failedRequest.updatedAt,
        });
        transaction.delete(accessRef);
        transaction.update(auditRef, {
          result: { request: failedRequest },
          updatedAt: failedAt,
        });
        return true;
      });
      if (markedFailed) {
        try {
          await bucket.file(initial.request.storagePath).delete();
        } catch (deleteError) {
          if (![404, "404"].includes(deleteError?.code)) {
            console.error("Privacy export cleanup failed", {
              requestId,
              code: deleteError?.code ?? "unknown",
            });
          }
        }
      }
      throw error;
    }
  };
}

export function createCancelPrivacyDataRequestHandler({ firestore, clock }) {
  return async request => {
    const userId = request.auth?.uid;
    if (!userId) {
      throw new HttpsError(
        "unauthenticated",
        "Authentication is required to cancel a privacy request.",
      );
    }
    const requestId = stableRequestId(request.data?.requestId, "requestId");
    const clientRequestId = stableRequestId(request.data?.clientRequestId);
    const sourceSurface = validSourceSurface(request.data?.sourceSurface);
    const requestRef = firestore.collection("privacy_data_requests").doc(requestId);
    const auditRef = firestore
      .collection("audit_events")
      .doc(`privacy-data-cancel--${userId}--${clientRequestId}`);
    const now = clock().toISOString();

    return firestore.runTransaction(async transaction => {
      const existingAudit = await transaction.get(auditRef);
      if (existingAudit.exists) {
        const audit = existingAudit.data();
        if (
          audit.actorUserId !== userId ||
          audit.targetId !== requestId
        ) {
          throw new HttpsError(
            "already-exists",
            "The privacy clientRequestId was already used.",
          );
        }
        return {
          replayed: true,
          request: audit.result.request,
          auditEventId: auditRef.id,
        };
      }
      const snapshot = await transaction.get(requestRef);
      if (!snapshot.exists || snapshot.data().userId !== userId) {
        throw new HttpsError("not-found", "The privacy request was not found.");
      }
      const current = snapshot.data();
      if (
        current.type !== "account_deletion" ||
        !["pending", "in_review"].includes(current.status)
      ) {
        throw new HttpsError(
          "failed-precondition",
          "This privacy request can no longer be cancelled.",
        );
      }
      const updated = {
        ...current,
        status: "cancelled",
        cancelledAt: now,
        updatedAt: now,
      };
      transaction.update(requestRef, {
        status: updated.status,
        cancelledAt: updated.cancelledAt,
        updatedAt: updated.updatedAt,
      });
      transaction.create(auditRef, {
        schemaVersion: 1,
        auditEventId: auditRef.id,
        category: "privacy",
        action: "privacy.data.cancel",
        actorUserId: userId,
        targetType: "privacy_data_request",
        targetId: requestId,
        sourceSurface,
        clientRequestId,
        result: { request: updated },
        createdAt: now,
      });
      return {
        replayed: false,
        request: updated,
        auditEventId: auditRef.id,
      };
    });
  };
}

function normalizeAdminCommand(data) {
  const action = normalizedString(data?.action);
  if (!ADMIN_ACTIONS.has(action)) {
    throw new HttpsError(
      "invalid-argument",
      "Privacy administration action is invalid.",
    );
  }
  const completing = action === "complete";
  return {
    action,
    requestId: stableRequestId(data?.requestId, "requestId"),
    clientRequestId: stableRequestId(data?.clientRequestId),
    sourceSurface: validSourceSurface(
      data?.sourceSurface,
      new Set(["admin_web"]),
    ),
    resolutionNote: boundedReason(data?.resolutionNote, {
      required: ["reject", "complete"].includes(action),
    }),
    caseId: normalizedCaseId(data?.caseId, { required: completing }),
  };
}

export function createManagePrivacyDataRequestHandler({ firestore, clock }) {
  return async request => {
    const staffUserId = request.auth?.uid;
    if (!staffUserId) {
      throw new HttpsError(
        "unauthenticated",
        "Authentication is required to manage privacy requests.",
      );
    }
    const input = normalizeAdminCommand(request.data);
    const staffRef = firestore.collection("users").doc(staffUserId);
    const requestRef = firestore
      .collection("privacy_data_requests")
      .doc(input.requestId);
    const auditRef = firestore
      .collection("audit_events")
      .doc(`privacy-data-admin--${staffUserId}--${input.clientRequestId}`);
    const now = clock().toISOString();

    return firestore.runTransaction(async transaction => {
      const staffSnapshot = await transaction.get(staffRef);
      if (!staffSnapshot.exists || !isStaffProfile(staffSnapshot.data())) {
        throw new HttpsError(
          "permission-denied",
          "This account cannot manage privacy requests.",
        );
      }
      const existingAudit = await transaction.get(auditRef);
      if (existingAudit.exists) {
        const audit = existingAudit.data();
        if (
          audit.actorUserId !== staffUserId ||
          audit.targetId !== input.requestId ||
          audit.action !== `privacy.data.admin.${input.action}`
        ) {
          throw new HttpsError(
            "already-exists",
            "The privacy clientRequestId was already used.",
          );
        }
        return {
          replayed: true,
          request: audit.result.request,
          auditEventId: auditRef.id,
        };
      }
      const requestSnapshot = await transaction.get(requestRef);
      if (!requestSnapshot.exists) {
        throw new HttpsError("not-found", "The privacy request was not found.");
      }
      const current = requestSnapshot.data();
      if (current.type !== "account_deletion") {
        throw new HttpsError(
          "failed-precondition",
          "Only account deletion requests require staff resolution.",
        );
      }
      const allowed =
        (input.action === "start_review" && current.status === "pending") ||
        (input.action === "reject" &&
          ["pending", "in_review"].includes(current.status)) ||
        (input.action === "complete" &&
          current.status === "in_review" &&
          Date.parse(current.reviewAfter) <= Date.parse(now));
      if (!allowed) {
        throw new HttpsError(
          "failed-precondition",
          "The privacy request cannot make this status transition.",
        );
      }
      const nextStatus = {
        start_review: "in_review",
        reject: "rejected",
        complete: "completed",
      }[input.action];
      const updated = {
        ...current,
        status: nextStatus,
        assignedStaffUserId: staffUserId,
        resolutionNote: input.resolutionNote,
        ...(input.caseId ? { caseId: input.caseId } : {}),
        updatedAt: now,
        ...(input.action === "start_review" ? { reviewStartedAt: now } : {}),
        ...(input.action === "reject" ? { rejectedAt: now } : {}),
        ...(input.action === "complete" ? { completedAt: now } : {}),
      };
      transaction.update(requestRef, {
        status: updated.status,
        assignedStaffUserId: updated.assignedStaffUserId,
        resolutionNote: updated.resolutionNote,
        ...(updated.caseId ? { caseId: updated.caseId } : {}),
        updatedAt: updated.updatedAt,
        ...(updated.reviewStartedAt
          ? { reviewStartedAt: updated.reviewStartedAt }
          : {}),
        ...(updated.rejectedAt ? { rejectedAt: updated.rejectedAt } : {}),
        ...(updated.completedAt ? { completedAt: updated.completedAt } : {}),
      });
      const profile = staffSnapshot.data();
      transaction.create(auditRef, {
        schemaVersion: 1,
        auditEventId: auditRef.id,
        category: "privacy",
        action: `privacy.data.admin.${input.action}`,
        actorUserId: staffUserId,
        actorRole:
          normalizedString(profile.staffRole) ||
          (profile.developerAccess === true ? "developer" : "staff"),
        targetType: "privacy_data_request",
        targetId: input.requestId,
        sourceSurface: input.sourceSurface,
        clientRequestId: input.clientRequestId,
        result: { request: updated },
        createdAt: now,
      });
      return {
        replayed: false,
        request: updated,
        auditEventId: auditRef.id,
      };
    });
  };
}

export function createGetPrivacyExportDownloadHandler({
  firestore,
  bucket,
  clock,
}) {
  return async request => {
    const userId = request.auth?.uid;
    if (!userId) {
      throw new HttpsError(
        "unauthenticated",
        "Authentication is required to download a privacy export.",
      );
    }
    const requestId = stableRequestId(request.data?.requestId, "requestId");
    const clientRequestId = stableRequestId(request.data?.clientRequestId);
    const sourceSurface = validSourceSurface(request.data?.sourceSurface);
    const requestRef = firestore.collection("privacy_data_requests").doc(requestId);
    const accessRef = firestore.collection("privacy_export_access").doc(requestId);
    const [requestSnapshot, accessSnapshot] = await Promise.all([
      requestRef.get(),
      accessRef.get(),
    ]);
    if (
      !requestSnapshot.exists ||
      requestSnapshot.data().userId !== userId ||
      !accessSnapshot.exists ||
      accessSnapshot.data().userId !== userId
    ) {
      throw new HttpsError("not-found", "The privacy export was not found.");
    }
    const privacyRequest = requestSnapshot.data();
    const access = accessSnapshot.data();
    if (
      privacyRequest.status !== "ready" ||
      Date.parse(privacyRequest.expiresAt) <= clock().getTime()
    ) {
      throw new HttpsError(
        "failed-precondition",
        "The privacy export is not ready or has expired.",
      );
    }
    if (
      sha256(normalizedString(access.downloadToken)) !==
      privacyRequest.downloadTokenHash
    ) {
      throw new HttpsError(
        "failed-precondition",
        "The privacy export access record is invalid.",
      );
    }
    const auditRef = firestore
      .collection("audit_events")
      .doc(`privacy-data-download--${userId}--${clientRequestId}`);
    const now = clock().toISOString();
    const result = {
      requestId,
      expiresAt: privacyRequest.expiresAt,
      downloadUrl:
        `https://firebasestorage.googleapis.com/v0/b/` +
        `${encodeURIComponent(bucket.name)}/o/` +
        `${encodeURIComponent(access.storagePath)}` +
        `?alt=media&token=${encodeURIComponent(access.downloadToken)}`,
    };
    await firestore.runTransaction(async transaction => {
      const replay = await transaction.get(auditRef);
      if (replay.exists) {
        const audit = replay.data();
        if (
          audit.actorUserId !== userId ||
          audit.action !== "privacy.data.export.download" ||
          audit.targetId !== requestId ||
          audit.sourceSurface !== sourceSurface
        ) {
          throw new HttpsError(
            "already-exists",
            "The privacy clientRequestId was already used.",
          );
        }
        return;
      }
      transaction.create(auditRef, {
        schemaVersion: 1,
        auditEventId: auditRef.id,
        category: "privacy",
        action: "privacy.data.export.download",
        actorUserId: userId,
        targetType: "privacy_data_request",
        targetId: requestId,
        sourceSurface,
        clientRequestId,
        result: {
          requestId,
          expiresAt: privacyRequest.expiresAt,
        },
        createdAt: now,
      });
    });
    return {
      ...result,
      auditEventId: auditRef.id,
    };
  };
}

export function createCleanupExpiredPrivacyExportsHandler({
  firestore,
  bucket,
  clock,
}) {
  return async () => {
    const nowDate = clock();
    const now = nowDate.toISOString();
    const snapshot = await firestore
      .collection("privacy_data_requests")
      .where("expiresAt", "<=", now)
      .limit(100)
      .get();
    let expired = 0;

    for (const document of snapshot.docs) {
      const candidate = document.data();
      if (
        candidate.type !== "export" ||
        !["processing", "ready"].includes(candidate.status) ||
        Date.parse(candidate.expiresAt) > nowDate.getTime()
      ) {
        continue;
      }
      const storagePath = normalizedString(candidate.storagePath);
      if (storagePath) {
        try {
          await bucket.file(storagePath).delete();
        } catch (error) {
          if (![404, "404"].includes(error?.code)) throw error;
        }
      }
      const requestRef = firestore
        .collection("privacy_data_requests")
        .doc(document.id);
      const accessRef = firestore
        .collection("privacy_export_access")
        .doc(document.id);
      const auditRef = firestore
        .collection("audit_events")
        .doc(`privacy-data-expire--${document.id}`);
      const didExpire = await firestore.runTransaction(async transaction => {
        const [currentSnapshot, existingAudit] = await Promise.all([
          transaction.get(requestRef),
          transaction.get(auditRef),
        ]);
        if (!currentSnapshot.exists) return false;
        const current = currentSnapshot.data();
        if (
          current.type !== "export" ||
          !["processing", "ready"].includes(current.status) ||
          Date.parse(current.expiresAt) > nowDate.getTime()
        ) {
          return false;
        }
        transaction.update(requestRef, {
          status: "expired",
          artifactExpiresAt: current.expiresAt,
          expiresAt: null,
          expiredAt: now,
          updatedAt: now,
        });
        transaction.delete(accessRef);
        if (!existingAudit.exists) {
          transaction.create(auditRef, {
            schemaVersion: 1,
            auditEventId: auditRef.id,
            category: "privacy",
            action: "privacy.data.export.expire",
            actorUserId: "system",
            targetType: "privacy_data_request",
            targetId: document.id,
            result: {
              requestId: document.id,
              status: "expired",
            },
            createdAt: now,
          });
        }
        return true;
      });
      if (didExpire) expired += 1;
    }
    return { scanned: snapshot.size, expired };
  };
}
