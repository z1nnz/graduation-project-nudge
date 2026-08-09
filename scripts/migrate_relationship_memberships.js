import admin from "firebase-admin";
import { createHash, randomUUID } from "node:crypto";
import fs from "fs";
import path from "path";
import { fileURLToPath, pathToFileURL } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const LEGACY_GROUP_FIELDS = ["groupId", "groupName", "isGroupOwner"];
const LEGACY_GUARDIAN_FIELDS = [
  "webToolsState.guardianInvite",
  "webToolsState.guardianInviteStatus",
];
const USER_MIGRATION_FIELDS = [
  ...LEGACY_GROUP_FIELDS,
  "userRole",
  ...LEGACY_GUARDIAN_FIELDS,
  "relationshipProjectionMigratedAt",
  "updatedAt",
];
const RELATIONSHIP_BEFORE_IMAGE_COLLECTION =
  "relationship_migration_before_images";
const RELATIONSHIP_MIGRATION_RUN_TYPE =
  "relationship_membership_projection_cutover";
const DESTRUCTIVE_OPERATION_GUARD_ID = "destructive_operation_guard";
const BEFORE_IMAGE_RETENTION_POLICY = "until_fresh_install_acceptance";

function asRecord(doc) {
  return { id: doc.id, data: doc.data() };
}

function asIso(value, fallback) {
  if (value && typeof value.toDate === "function") {
    return value.toDate().toISOString();
  }
  const parsed = new Date(String(value || ""));
  return Number.isNaN(parsed.getTime()) ? fallback : parsed.toISOString();
}

function normalizedString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function membershipId(scopeType, scopeId, userId) {
  return `${scopeType}--${scopeId}--${userId}`;
}

function fingerprint(value) {
  function canonical(input) {
    if (Array.isArray(input)) return input.map(canonical);
    if (input && typeof input === "object") {
      return Object.fromEntries(
        Object.keys(input)
          .sort()
          .filter(key => input[key] !== undefined)
          .map(key => [key, canonical(input[key])]),
      );
    }
    return input;
  }
  return createHash("sha256")
    .update(JSON.stringify(canonical(value)))
    .digest("hex");
}

function nestedFieldState(data, fieldPath) {
  const segments = fieldPath.split(".");
  let current = data;
  for (let index = 0; index < segments.length; index += 1) {
    if (
      !current ||
      typeof current !== "object" ||
      Array.isArray(current) ||
      !Object.hasOwn(current, segments[index])
    ) {
      return { path: fieldPath, present: false };
    }
    current = current[segments[index]];
  }
  return { path: fieldPath, present: true, value: current };
}

function userMigrationFieldStates(data) {
  return USER_MIGRATION_FIELDS.map(fieldPath =>
    nestedFieldState(data, fieldPath)
  );
}

function userMigrationStateFingerprint(data) {
  return fingerprint(userMigrationFieldStates(data));
}

function appliedUserFieldStates(data, operation, appliedAt) {
  const byPath = new Map(
    userMigrationFieldStates(data).map(state => [state.path, state]),
  );
  for (const fieldPath of operation.clearFields) {
    byPath.set(fieldPath, { path: fieldPath, present: false });
  }
  for (const [fieldPath, value] of Object.entries(operation.setFields)) {
    byPath.set(fieldPath, { path: fieldPath, present: true, value });
  }
  for (const fieldPath of ["relationshipProjectionMigratedAt", "updatedAt"]) {
    byPath.set(fieldPath, { path: fieldPath, present: true, value: appliedAt });
  }
  return USER_MIGRATION_FIELDS.map(fieldPath => byPath.get(fieldPath));
}

function migrationBeforeImageRef(db, runId, entityPath) {
  return db.collection(RELATIONSHIP_BEFORE_IMAGE_COLLECTION).doc(
    `${runId}--${fingerprint(entityPath).slice(0, 32)}`,
  );
}

function assertBeforeImageIdentity(beforeImage, runId, entityPath, entityType) {
  if (
    beforeImage.migrationRunId !== runId ||
    beforeImage.entityPath !== entityPath ||
    beforeImage.entityType !== entityType
  ) {
    throw new Error(`Relationship before-image mismatch: ${entityPath}`);
  }
}

function validatedUserBeforeFields(beforeImage) {
  if (!Array.isArray(beforeImage.beforeFields)) {
    throw new Error(
      `Relationship user before-image is incomplete: ${beforeImage.entityPath}`,
    );
  }
  const byPath = new Map();
  for (const state of beforeImage.beforeFields) {
    if (
      !state ||
      !USER_MIGRATION_FIELDS.includes(state.path) ||
      typeof state.present !== "boolean" ||
      byPath.has(state.path) ||
      (state.present && !Object.hasOwn(state, "value"))
    ) {
      throw new Error(
        `Relationship user before-image is invalid: ${beforeImage.entityPath}`,
      );
    }
    byPath.set(state.path, state);
  }
  if (byPath.size !== USER_MIGRATION_FIELDS.length) {
    throw new Error(
      `Relationship user before-image fields are incomplete: ${beforeImage.entityPath}`,
    );
  }
  return USER_MIGRATION_FIELDS.map(fieldPath => byPath.get(fieldPath));
}

function legacyProjectionFingerprint(data) {
  const webToolsState =
    data.webToolsState &&
    typeof data.webToolsState === "object" &&
    !Array.isArray(data.webToolsState)
      ? data.webToolsState
      : {};
  return fingerprint({
    groupId: {
      present: Object.hasOwn(data, "groupId"),
      value: data.groupId,
    },
    groupName: {
      present: Object.hasOwn(data, "groupName"),
      value: data.groupName,
    },
    isGroupOwner: {
      present: Object.hasOwn(data, "isGroupOwner"),
      value: data.isGroupOwner,
    },
    userRole: {
      present: Object.hasOwn(data, "userRole"),
      value: data.userRole,
    },
    guardianInvite: {
      present: Object.hasOwn(webToolsState, "guardianInvite"),
      value: webToolsState.guardianInvite,
    },
    guardianInviteStatus: {
      present: Object.hasOwn(webToolsState, "guardianInviteStatus"),
      value: webToolsState.guardianInviteStatus,
    },
  });
}

function existingMembershipMap(existingMemberships) {
  return new Map(
    existingMemberships.map(record => [record.id, record.data || {}]),
  );
}

function buildMembership({
  scopeType,
  scopeId,
  scopeName,
  userId,
  role,
  status,
  parent,
  parentCollection,
  existing,
  now,
}) {
  const id = membershipId(scopeType, scopeId, userId);
  const parentCreatedAt = asIso(parent.createdAt, now);
  const parentUpdatedAt = asIso(parent.updatedAt, now);
  const createdAt = asIso(existing?.createdAt, parentCreatedAt);
  const activeFrom =
    existing?.status === "active"
      ? asIso(existing.activeFrom, createdAt)
      : parentCreatedAt;
  const data = {
    schemaVersion: 1,
    membershipId: id,
    scopeType,
    scopeId,
    scopeName,
    userId,
    role,
    status,
    createdAt,
    updatedAt: now,
  };
  if (status === "active") {
    data.activeFrom = activeFrom;
  } else {
    if (existing?.activeFrom) {
      data.activeFrom = asIso(existing.activeFrom, parentCreatedAt);
    }
    data.activeUntil =
      existing?.status === "ended"
        ? asIso(existing.activeUntil, parentUpdatedAt)
        : asIso(parent.endedAt, parentUpdatedAt);
    data.endedBy =
      normalizedString(existing?.endedBy) ||
      normalizedString(parent.endedBy) ||
      normalizedString(parent.ownerId) ||
      userId;
  }
  return {
    id,
    data,
    parentCollection,
    expectedParentFingerprint: fingerprint(parent),
    expectedExistingFingerprint: fingerprint(existing ?? null),
    clearEndedFields: status === "active",
  };
}

export function buildRelationshipMigrationPlan({
  familyLinks = [],
  groups = [],
  users = [],
  existingMemberships = [],
  now = new Date().toISOString(),
} = {}) {
  const normalizedNow = asIso(now, new Date().toISOString());
  const existingById = existingMembershipMap(existingMemberships);
  const familyById = new Map(familyLinks.map(record => [record.id, record]));
  const groupById = new Map(groups.map(record => [record.id, record]));
  const membershipUpserts = [];
  const userProjectionCleanup = [];
  const issues = [];

  for (const record of familyLinks) {
    const data = record.data || {};
    const guardianId = normalizedString(data.guardianId);
    const childId = normalizedString(data.childId);
    const participants = new Set(
      Array.isArray(data.participantIds) ? data.participantIds : [],
    );
    if (
      !record.id ||
      !guardianId ||
      !childId ||
      guardianId === childId ||
      !participants.has(guardianId) ||
      !participants.has(childId)
    ) {
      issues.push({
        scopeType: "family",
        scopeId: record.id || null,
        reason: "invalid_family_parent",
      });
      continue;
    }
    const status = data.status === "ended" ? "ended" : "active";
    const scopeName = `家庭連結 ${record.id.slice(-8)}`;
    for (const [userId, role] of [
      [guardianId, "guardian"],
      [childId, "child"],
    ]) {
      const id = membershipId("family", record.id, userId);
      membershipUpserts.push(
        buildMembership({
          scopeType: "family",
          scopeId: record.id,
          scopeName,
          userId,
          role,
          status,
          parent: data,
          parentCollection: "family_links",
          existing: existingById.get(id),
          now: normalizedNow,
        }),
      );
    }
  }

  for (const record of groups) {
    const data = record.data || {};
    const ownerId = normalizedString(data.ownerId);
    const scopeName = normalizedString(data.name);
    const memberIds = [
      ...new Set(
        (Array.isArray(data.memberIds) ? data.memberIds : [])
          .map(normalizedString)
          .filter(Boolean),
      ),
    ];
    if (
      !record.id ||
      !ownerId ||
      !scopeName ||
      memberIds.length === 0 ||
      !memberIds.includes(ownerId)
    ) {
      issues.push({
        scopeType: "group",
        scopeId: record.id || null,
        reason: "invalid_group_parent",
      });
      continue;
    }
    const status = data.status === "active" ? "active" : "ended";
    for (const userId of memberIds) {
      const id = membershipId("group", record.id, userId);
      membershipUpserts.push(
        buildMembership({
          scopeType: "group",
          scopeId: record.id,
          scopeName,
          userId,
          role: userId === ownerId ? "manager" : "member",
          status,
          parent: data,
          parentCollection: "groups",
          existing: existingById.get(id),
          now: normalizedNow,
        }),
      );
    }
  }

  for (const record of users) {
    const data = record.data || {};
    const clearFields = [];
    if (LEGACY_GROUP_FIELDS.some(field => Object.hasOwn(data, field))) {
      clearFields.push(...LEGACY_GROUP_FIELDS);
    }
    const webToolsState =
      data.webToolsState &&
      typeof data.webToolsState === "object" &&
      !Array.isArray(data.webToolsState)
        ? data.webToolsState
        : {};
    if (Object.hasOwn(webToolsState, "guardianInvite")) {
      clearFields.push(LEGACY_GUARDIAN_FIELDS[0]);
    }
    if (Object.hasOwn(webToolsState, "guardianInviteStatus")) {
      clearFields.push(LEGACY_GUARDIAN_FIELDS[1]);
    }
    if (clearFields.length === 0 && data.userRole !== "group") continue;
    userProjectionCleanup.push({
      userId: record.id,
      expectedProjectionFingerprint: legacyProjectionFingerprint(data),
      clearFields,
      setFields: data.userRole === "group" ? { userRole: "individual" } : {},
    });
  }

  const desiredMembershipIds = new Set(
    membershipUpserts.map(operation => operation.id),
  );
  for (const record of existingMemberships) {
    const data = record.data ?? {};
    if (desiredMembershipIds.has(record.id) || data.status === "ended") {
      continue;
    }
    const scopeType = normalizedString(data.scopeType);
    const scopeId = normalizedString(data.scopeId);
    const userId = normalizedString(data.userId);
    const role = normalizedString(data.role);
    const roleMatchesScope = scopeType === "family"
      ? ["guardian", "child"].includes(role)
      : scopeType === "group"
        ? ["manager", "member"].includes(role)
        : false;
    if (
      !record.id ||
      record.id !== membershipId(scopeType, scopeId, userId) ||
      !scopeId ||
      !userId ||
      !roleMatchesScope ||
      data.status !== "active"
    ) {
      issues.push({
        scopeType: scopeType || null,
        scopeId: scopeId || null,
        reason: "invalid_existing_membership",
      });
      continue;
    }
    const parentRecord = scopeType === "family"
      ? familyById.get(scopeId)
      : groupById.get(scopeId);
    membershipUpserts.push({
      id: record.id,
      data: {
        schemaVersion: 1,
        membershipId: record.id,
        scopeType,
        scopeId,
        scopeName: normalizedString(data.scopeName) ||
          `${scopeType === "family" ? "家庭連結" : "團體"} ${scopeId}`,
        userId,
        role,
        status: "ended",
        createdAt: asIso(data.createdAt, normalizedNow),
        updatedAt: normalizedNow,
        ...(data.activeFrom
          ? { activeFrom: asIso(data.activeFrom, normalizedNow) }
          : {}),
        activeUntil: normalizedNow,
        endedBy: "relationship-migration",
      },
      parentCollection: scopeType === "family" ? "family_links" : "groups",
      expectedParentFingerprint: fingerprint(parentRecord?.data ?? null),
      expectedExistingFingerprint: fingerprint(data),
      allowMissingParent: true,
      clearEndedFields: false,
    });
  }

  membershipUpserts.sort((a, b) => a.id.localeCompare(b.id));
  userProjectionCleanup.sort((a, b) => a.userId.localeCompare(b.userId));
  return {
    generatedAt: normalizedNow,
    membershipUpserts,
    userProjectionCleanup,
    issues,
    counts: {
      familyLinks: familyLinks.length,
      groups: groups.length,
      users: users.length,
      existingMemberships: existingMemberships.length,
      membershipUpserts: membershipUpserts.length,
      userProjectionCleanup: userProjectionCleanup.length,
      issues: issues.length,
    },
  };
}

async function initializeAdmin() {
  if (admin.apps.length > 0) return admin.apps[0];
  const serviceAccountPath = path.join(
    __dirname,
    "..",
    "firebase-service-account.json",
  );
  if (fs.existsSync(serviceAccountPath)) {
    const serviceAccount = JSON.parse(
      fs.readFileSync(serviceAccountPath, "utf8"),
    );
    return admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
  }
  return admin.initializeApp({
    credential: admin.credential.applicationDefault(),
  });
}

function ownsCutover(fence, runId, ownerToken, operation) {
  return fence?.active === true &&
    fence.runId === runId &&
    fence.ownerToken === ownerToken &&
    fence.operation === operation;
}

function ownsMaintenanceGuard(guard, runId, ownerToken) {
  return guard?.active === true &&
    guard.operationKind === "relationship_cutover" &&
    guard.operationId === runId &&
    guard.ownerToken === ownerToken;
}

function hasActiveAccountDeletion(guard) {
  return guard?.active === true &&
    guard.operationKind === "account_deletion";
}

function assertOwnedCutover(fenceSnapshot, guardSnapshot, context, message) {
  if (
    !fenceSnapshot.exists ||
    !guardSnapshot.exists ||
    !ownsCutover(
      fenceSnapshot.data(),
      context.runRef.id,
      context.ownerToken,
      context.operation,
    ) ||
    !ownsMaintenanceGuard(
      guardSnapshot.data(),
      context.runRef.id,
      context.ownerToken,
    )
  ) {
    throw new Error(message);
  }
}

async function acquireCutover(db) {
  const fenceRef = db
    .collection("system_state")
    .doc("relationship_membership_cutover");
  const proposedRunRef = db.collection("migration_runs").doc();
  const guardRef = db.collection("system_state")
    .doc(DESTRUCTIVE_OPERATION_GUARD_ID);
  const ownerToken = randomUUID();
  const startedAt = new Date().toISOString();
  return db.runTransaction(async transaction => {
    const [fenceSnapshot, guardSnapshot] = await Promise.all([
      transaction.get(fenceRef),
      transaction.get(guardRef),
    ]);
    const guard = guardSnapshot.exists ? guardSnapshot.data() : null;
    if (hasActiveAccountDeletion(guard)) {
      throw new Error(
        "Relationship cutover cannot start while account deletion is active.",
      );
    }
    if (fenceSnapshot.exists && fenceSnapshot.data().active === true) {
      const fence = fenceSnapshot.data();
      if (typeof fence.runId !== "string" || !fence.runId) {
        throw new Error("既有 Relationship cutover fence 無法安全續跑。");
      }
      if (fence.operation === "rollback") {
        throw new Error("Relationship cutover 正在回滾，不能切換回 apply。");
      }
      if (
        guard?.active === true &&
        (
          guard.operationKind !== "relationship_cutover" ||
          guard.operationId !== fence.runId
        )
      ) {
        throw new Error("另一個 destructive operation 仍持有 maintenance guard。");
      }
      const runRef = db.collection("migration_runs").doc(fence.runId);
      const runSnapshot = await transaction.get(runRef);
      if (
        !runSnapshot.exists ||
        runSnapshot.data().type !== RELATIONSHIP_MIGRATION_RUN_TYPE ||
        !["running", "failed"].includes(runSnapshot.data().status)
      ) {
        throw new Error("既有 Relationship migration run 無法安全續跑。");
      }
      transaction.update(fenceRef, {
        ownerToken,
        operation: "apply",
        updatedAt: startedAt,
      });
      transaction.set(runRef, {
        status: "running",
        resumedAt: startedAt,
      }, { merge: true });
      transaction.set(guardRef, {
        schemaVersion: 1,
        active: true,
        operationKind: "relationship_cutover",
        operationId: runRef.id,
        ownerToken,
        phase: "apply",
        updatedAt: startedAt,
      }, { merge: false });
      return {
        db,
        fenceRef,
        guardRef,
        runRef,
        ownerToken,
        operation: "apply",
      };
    }
    if (guard?.active === true) {
      throw new Error("另一個 destructive operation 仍持有 maintenance guard。");
    }
    transaction.set(fenceRef, {
      active: true,
      runId: proposedRunRef.id,
      ownerToken,
      operation: "apply",
      startedAt,
      updatedAt: startedAt,
    });
    transaction.create(proposedRunRef, {
      type: RELATIONSHIP_MIGRATION_RUN_TYPE,
      status: "running",
      startedAt,
      capturedMembershipBeforeImages: 0,
      capturedUserBeforeImages: 0,
      restoredMemberships: 0,
      restoredUsers: 0,
      rollbackAttempts: 0,
    });
    transaction.set(guardRef, {
      schemaVersion: 1,
      active: true,
      operationKind: "relationship_cutover",
      operationId: proposedRunRef.id,
      ownerToken,
      phase: "apply",
      updatedAt: startedAt,
    }, { merge: false });
    return {
      db,
      fenceRef,
      guardRef,
      runRef: proposedRunRef,
      ownerToken,
      operation: "apply",
    };
  });
}

async function applyMembershipOperation(
  context,
  operation,
) {
  const { db, fenceRef, guardRef, runRef } = context;
  const parentRef = db
    .collection(operation.parentCollection)
    .doc(operation.data.scopeId);
  const membershipRef = db
    .collection("relationship_memberships")
    .doc(operation.id);
  const entityPath = membershipRef.path;
  const beforeRef = migrationBeforeImageRef(db, runRef.id, entityPath);
  await db.runTransaction(async transaction => {
    const [
      fenceSnapshot,
      guardSnapshot,
      parentSnapshot,
      membershipSnapshot,
      beforeSnapshot,
    ] =
      await Promise.all([
        transaction.get(fenceRef),
        transaction.get(guardRef),
        transaction.get(parentRef),
        transaction.get(membershipRef),
        transaction.get(beforeRef),
      ]);
    assertOwnedCutover(
      fenceSnapshot,
      guardSnapshot,
      context,
      "Relationship cutover ownership changed.",
    );
    const currentParent = parentSnapshot.exists ? parentSnapshot.data() : null;
    if (
      (!operation.allowMissingParent && !parentSnapshot.exists) ||
      fingerprint(currentParent) !== operation.expectedParentFingerprint
    ) {
      throw new Error(`Relationship parent changed: ${operation.data.scopeId}`);
    }
    const currentMembership = membershipSnapshot.exists
      ? membershipSnapshot.data()
      : null;
    if (
      fingerprint(currentMembership) !== operation.expectedExistingFingerprint
    ) {
      throw new Error(`Relationship Membership changed: ${operation.id}`);
    }
    const payload = { ...operation.data };
    if (operation.clearEndedFields) {
      payload.activeUntil = admin.firestore.FieldValue.delete();
      payload.endedBy = admin.firestore.FieldValue.delete();
    }
    const afterData = { ...(currentMembership ?? {}), ...operation.data };
    if (operation.clearEndedFields) {
      delete afterData.activeUntil;
      delete afterData.endedBy;
    }
    const beforeImage = {
      schemaVersion: 1,
      migrationRunId: runRef.id,
      entityType: "membership",
      entityPath,
      actorUserId: operation.data.userId,
      beforeExists: membershipSnapshot.exists,
      beforeData: currentMembership,
      afterFingerprint: fingerprint(afterData),
      capturedAt: new Date().toISOString(),
      retentionPolicy: BEFORE_IMAGE_RETENTION_POLICY,
    };
    if (beforeSnapshot.exists) {
      const existingBeforeImage = beforeSnapshot.data();
      assertBeforeImageIdentity(
        existingBeforeImage,
        runRef.id,
        entityPath,
        "membership",
      );
      if (existingBeforeImage.afterFingerprint !== fingerprint(currentMembership)) {
        throw new Error(
          `Relationship Membership changed after apply: ${entityPath}`,
        );
      }
      const updatedAt = new Date().toISOString();
      transaction.update(fenceRef, { updatedAt });
      transaction.update(guardRef, { updatedAt });
      return false;
    } else {
      transaction.create(beforeRef, beforeImage);
      transaction.update(runRef, {
        capturedMembershipBeforeImages:
          admin.firestore.FieldValue.increment(1),
      });
    }
    transaction.set(membershipRef, payload, { merge: true });
    const updatedAt = new Date().toISOString();
    transaction.update(fenceRef, { updatedAt });
    transaction.update(guardRef, { updatedAt });
    return true;
  });
}

async function applyUserCleanup(
  context,
  operation,
) {
  const { db, fenceRef, guardRef, runRef } = context;
  const userRef = db.collection("users").doc(operation.userId);
  const entityPath = userRef.path;
  const beforeRef = migrationBeforeImageRef(db, runRef.id, entityPath);
  await db.runTransaction(async transaction => {
    const [fenceSnapshot, guardSnapshot, userSnapshot, beforeSnapshot] =
      await Promise.all([
      transaction.get(fenceRef),
      transaction.get(guardRef),
      transaction.get(userRef),
      transaction.get(beforeRef),
    ]);
    assertOwnedCutover(
      fenceSnapshot,
      guardSnapshot,
      context,
      "Relationship cutover ownership changed.",
    );
    if (!userSnapshot.exists) {
      throw new Error(`Relationship cleanup user missing: ${operation.userId}`);
    }
    if (
      legacyProjectionFingerprint(userSnapshot.data()) !==
      operation.expectedProjectionFingerprint
    ) {
      throw new Error(`Legacy relationship projection changed: ${operation.userId}`);
    }
    const appliedAt = new Date().toISOString();
    const currentUser = userSnapshot.data();
    const update = {
      ...operation.setFields,
      relationshipProjectionMigratedAt: appliedAt,
      updatedAt: appliedAt,
    };
    for (const field of operation.clearFields) {
      update[field] = admin.firestore.FieldValue.delete();
    }
    const beforeImage = {
      schemaVersion: 1,
      migrationRunId: runRef.id,
      entityType: "user_projection",
      entityPath,
      actorUserId: operation.userId,
      beforeFields: userMigrationFieldStates(currentUser),
      afterFingerprint: fingerprint(
        appliedUserFieldStates(currentUser, operation, appliedAt),
      ),
      capturedAt: appliedAt,
      retentionPolicy: BEFORE_IMAGE_RETENTION_POLICY,
    };
    if (beforeSnapshot.exists) {
      const existingBeforeImage = beforeSnapshot.data();
      assertBeforeImageIdentity(
        existingBeforeImage,
        runRef.id,
        entityPath,
        "user_projection",
      );
      if (
        existingBeforeImage.afterFingerprint !==
          userMigrationStateFingerprint(currentUser)
      ) {
        throw new Error(
          `Relationship user projection changed after apply: ${entityPath}`,
        );
      }
      transaction.update(fenceRef, { updatedAt: appliedAt });
      transaction.update(guardRef, { updatedAt: appliedAt });
      return false;
    } else {
      transaction.create(beforeRef, beforeImage);
      transaction.update(runRef, {
        capturedUserBeforeImages: admin.firestore.FieldValue.increment(1),
      });
    }
    transaction.update(userRef, update);
    transaction.update(fenceRef, { updatedAt: appliedAt });
    transaction.update(guardRef, { updatedAt: appliedAt });
    return true;
  });
}

async function updateOwnedRun(
  context,
  values,
) {
  const { db, fenceRef, guardRef, runRef } = context;
  await db.runTransaction(async transaction => {
    const [fenceSnapshot, guardSnapshot] = await Promise.all([
      transaction.get(fenceRef),
      transaction.get(guardRef),
    ]);
    assertOwnedCutover(
      fenceSnapshot,
      guardSnapshot,
      context,
      "Relationship cutover ownership changed.",
    );
    transaction.set(runRef, values, { merge: true });
  });
}

async function validateAppliedBeforeImages(context) {
  const { db, fenceRef, guardRef, runRef } = context;
  const [beforeSnapshot, runSnapshot] = await Promise.all([
    db.collection(RELATIONSHIP_BEFORE_IMAGE_COLLECTION)
      .where("migrationRunId", "==", runRef.id)
      .get(),
    runRef.get(),
  ]);
  if (
    !runSnapshot.exists ||
    runSnapshot.data().type !== RELATIONSHIP_MIGRATION_RUN_TYPE ||
    beforeSnapshot.size !==
      (
        runSnapshot.data().capturedMembershipBeforeImages +
        runSnapshot.data().capturedUserBeforeImages
      )
  ) {
    throw new Error("Relationship apply before-image count mismatch.");
  }
  for (const beforeDocument of beforeSnapshot.docs) {
    await db.runTransaction(async transaction => {
      const [fenceSnapshot, guardSnapshot, latestBefore] = await Promise.all([
        transaction.get(fenceRef),
        transaction.get(guardRef),
        transaction.get(beforeDocument.ref),
      ]);
      assertOwnedCutover(
        fenceSnapshot,
        guardSnapshot,
        context,
        "Relationship cutover ownership changed during validation.",
      );
      if (!latestBefore.exists) {
        throw new Error(
          `Relationship apply before-image disappeared: ${beforeDocument.id}`,
        );
      }
      const before = latestBefore.data();
      if (
        before.schemaVersion !== 1 ||
        beforeDocument.id !==
          migrationBeforeImageRef(db, runRef.id, before.entityPath).id
      ) {
        throw new Error(
          `Relationship before-image id is invalid: ${beforeDocument.id}`,
        );
      }
      assertBeforeImageIdentity(
        before,
        runRef.id,
        before.entityPath,
        before.entityType,
      );
      const pathSegments = String(before.entityPath || "").split("/");
      if (
        pathSegments.length !== 2 ||
        !["relationship_memberships", "users"].includes(pathSegments[0])
      ) {
        throw new Error(
          `Relationship apply target is invalid: ${before.entityPath}`,
        );
      }
      const targetSnapshot = await transaction.get(db.doc(before.entityPath));
      if (before.entityType === "membership") {
        if (
          pathSegments[0] !== "relationship_memberships" ||
          !targetSnapshot.exists ||
          before.actorUserId !== targetSnapshot.data().userId ||
          targetSnapshot.data().membershipId !== pathSegments[1] ||
          fingerprint(targetSnapshot.data()) !== before.afterFingerprint
        ) {
          throw new Error(
            `Relationship Membership changed after apply: ${before.entityPath}`,
          );
        }
      } else if (before.entityType === "user_projection") {
        if (
          pathSegments[0] !== "users" ||
          before.actorUserId !== pathSegments[1] ||
          !targetSnapshot.exists ||
          userMigrationStateFingerprint(targetSnapshot.data()) !==
            before.afterFingerprint
        ) {
          throw new Error(
            `Relationship user projection changed after apply: ${before.entityPath}`,
          );
        }
      } else {
        throw new Error(
          `Unknown Relationship before-image type: ${before.entityType}`,
        );
      }
    });
  }
}

export async function runRelationshipMigration({
  apply,
  testFailAfterOperations = null,
}) {
  await initializeAdmin();
  const db = admin.firestore();
  const [familySnapshot, groupSnapshot, userSnapshot, membershipSnapshot] =
    await Promise.all([
      db.collection("family_links").get(),
      db.collection("groups").get(),
      db.collection("users").get(),
      db.collection("relationship_memberships").get(),
    ]);
  const plan = buildRelationshipMigrationPlan({
    familyLinks: familySnapshot.docs.map(asRecord),
    groups: groupSnapshot.docs.map(asRecord),
    users: userSnapshot.docs.map(asRecord),
    existingMemberships: membershipSnapshot.docs.map(asRecord),
  });

  console.log(`${apply ? "APPLY" : "DRY RUN"} relationship migration`);
  console.log(JSON.stringify(plan.counts, null, 2));
  if (plan.issues.length > 0) {
    console.log("Issues:");
    console.log(JSON.stringify(plan.issues, null, 2));
  }
  if (!apply) {
    console.log(
      "未寫入資料。確認 issues 為 0 後執行：npm run migrate:relationships:apply",
    );
    return plan;
  }
  if (plan.issues.length > 0) {
    throw new Error("存在無效父關係資料；修正後才能執行 migration。");
  }

  const context = await acquireCutover(db);
  const { fenceRef, guardRef, runRef, ownerToken } = context;
  try {
    await updateOwnedRun(context, { counts: plan.counts });
    let processedOperations = 0;
    const injectFailureIfRequested = () => {
      if (
        Number.isSafeInteger(testFailAfterOperations) &&
        testFailAfterOperations > 0 &&
        processedOperations >= testFailAfterOperations
      ) {
        throw new Error(
          `Injected relationship migration failure after ` +
            `${processedOperations} operations.`,
        );
      }
    };
    let membershipWrites = 0;
    for (const operation of plan.membershipUpserts) {
      await applyMembershipOperation(context, operation);
      membershipWrites += 1;
      processedOperations += 1;
      injectFailureIfRequested();
    }
    let cleanupWrites = 0;
    for (const operation of plan.userProjectionCleanup) {
      await applyUserCleanup(context, operation);
      cleanupWrites += 1;
      processedOperations += 1;
      injectFailureIfRequested();
    }
    await validateAppliedBeforeImages(context);
    await db.runTransaction(async transaction => {
      const [fenceSnapshot, guardSnapshot, runSnapshot] = await Promise.all([
        transaction.get(fenceRef),
        transaction.get(guardRef),
        transaction.get(runRef),
      ]);
      assertOwnedCutover(
        fenceSnapshot,
        guardSnapshot,
        context,
        "Relationship cutover ownership changed before release.",
      );
      if (
        !runSnapshot.exists ||
        runSnapshot.data().type !== RELATIONSHIP_MIGRATION_RUN_TYPE
      ) {
        throw new Error("Relationship migration run changed before release.");
      }
      const completedAt = new Date().toISOString();
      transaction.update(fenceRef, {
        active: false,
        ownerToken: null,
        operation: null,
        completedAt,
        updatedAt: completedAt,
      });
      transaction.set(guardRef, {
        schemaVersion: 1,
        active: false,
        operationKind: null,
        operationId: null,
        ownerToken: null,
        phase: null,
        updatedAt: completedAt,
      }, { merge: false });
      const run = runSnapshot.data();
      transaction.set(runRef, {
        status: "completed",
        membershipWrites: run.capturedMembershipBeforeImages ?? membershipWrites,
        cleanupWrites: run.capturedUserBeforeImages ?? cleanupWrites,
        completedAt,
      }, { merge: true });
    });
    console.log(
      `完成：${membershipWrites} 筆 Membership、${cleanupWrites} 筆舊投影清理。`,
    );
    return plan;
  } catch (error) {
    await db.runTransaction(async transaction => {
      const fenceSnapshot = await transaction.get(fenceRef);
      if (
        fenceSnapshot.exists &&
        ownsCutover(fenceSnapshot.data(), runRef.id, ownerToken, "apply")
      ) {
        transaction.set(runRef, {
          status: "failed",
          error: String(error?.message || error).slice(0, 500),
          failedAt: new Date().toISOString(),
        }, { merge: true });
      }
    });
    throw error;
  }
}

export async function rollbackActiveRelationshipCutover({
  testFailAfterRestores = null,
} = {}) {
  await initializeAdmin();
  const db = admin.firestore();
  const fenceRef = db
    .collection("system_state")
    .doc("relationship_membership_cutover");
  const guardRef = db.collection("system_state")
    .doc(DESTRUCTIVE_OPERATION_GUARD_ID);
  const ownerToken = randomUUID();
  const { runRef, runId } = await db.runTransaction(async transaction => {
    const [fenceSnapshot, guardSnapshot] = await Promise.all([
      transaction.get(fenceRef),
      transaction.get(guardRef),
    ]);
    const fence = fenceSnapshot.exists ? fenceSnapshot.data() : null;
    const guard = guardSnapshot.exists ? guardSnapshot.data() : null;
    if (
      fence?.active !== true ||
      typeof fence.runId !== "string" ||
      !fence.runId
    ) {
      throw new Error(
        "目前沒有可回滾的 active Relationship cutover fence。",
      );
    }
    if (
      !guardSnapshot.exists ||
      guard?.active !== true ||
      guard.operationKind !== "relationship_cutover" ||
      guard.operationId !== fence.runId
    ) {
      throw new Error(
        "Relationship maintenance guard 不屬於 active cutover run。",
      );
    }
    const activeRunRef = db.collection("migration_runs").doc(fence.runId);
    const runSnapshot = await transaction.get(activeRunRef);
    if (!runSnapshot.exists) {
      throw new Error("Relationship cutover migration run 不存在。");
    }
    const run = runSnapshot.data();
    if (
      run.type !== RELATIONSHIP_MIGRATION_RUN_TYPE ||
      !["running", "failed", "rolling_back", "rollback_failed"].includes(
        run.status,
      )
    ) {
      throw new Error("Relationship cutover migration run 狀態不可回滾。");
    }
    const rollbackStartedAt = new Date().toISOString();
    transaction.update(fenceRef, {
      ownerToken,
      operation: "rollback",
      updatedAt: rollbackStartedAt,
    });
    transaction.set(guardRef, {
      schemaVersion: 1,
      active: true,
      operationKind: "relationship_cutover",
      operationId: fence.runId,
      ownerToken,
      phase: "rollback",
      updatedAt: rollbackStartedAt,
    }, { merge: false });
    transaction.update(activeRunRef, {
      status: "rolling_back",
      rollbackStartedAt,
      rollbackAttempts: admin.firestore.FieldValue.increment(1),
      lastRollbackOwnerToken: ownerToken,
      restoredMemberships: Number.isSafeInteger(run.restoredMemberships)
        ? run.restoredMemberships
        : 0,
      restoredUsers: Number.isSafeInteger(run.restoredUsers)
        ? run.restoredUsers
        : 0,
    });
    return { runRef: activeRunRef, runId: fence.runId };
  });

  const context = {
    db,
    fenceRef,
    guardRef,
    runRef,
    ownerToken,
    operation: "rollback",
  };

  try {
    const beforeSnapshot = await db
      .collection(RELATIONSHIP_BEFORE_IMAGE_COLLECTION)
      .where("migrationRunId", "==", runId)
      .get();
    const beforeDocuments = [...beforeSnapshot.docs].sort((left, right) =>
      left.id.localeCompare(right.id)
    );
    let restoredThisAttempt = 0;
    for (const beforeDocument of beforeDocuments) {
      await db.runTransaction(async transaction => {
        const [latestFence, latestGuard, latestBefore] = await Promise.all([
          transaction.get(fenceRef),
          transaction.get(guardRef),
          transaction.get(beforeDocument.ref),
        ]);
        assertOwnedCutover(
          latestFence,
          latestGuard,
          context,
          "Relationship cutover rollback ownership changed.",
        );
        if (!latestBefore.exists) {
          throw new Error(
            `Relationship rollback before-image disappeared: ${beforeDocument.id}`,
          );
        }
        const before = latestBefore.data();
        if (
          before.schemaVersion !== 1 ||
          beforeDocument.id !==
            migrationBeforeImageRef(db, runId, before.entityPath).id
        ) {
          throw new Error(
            `Relationship before-image id is invalid: ${beforeDocument.id}`,
          );
        }
        assertBeforeImageIdentity(
          before,
          runId,
          before.entityPath,
          before.entityType,
        );
        const pathSegments = String(before.entityPath || "").split("/");
        if (
          pathSegments.length !== 2 ||
          !["relationship_memberships", "users"].includes(pathSegments[0])
        ) {
          throw new Error(
            `Relationship rollback target is invalid: ${before.entityPath}`,
          );
        }
        const targetRef = db.doc(before.entityPath);
        const targetSnapshot = await transaction.get(targetRef);
        if (before.entityType === "membership") {
          if (
            pathSegments[0] !== "relationship_memberships" ||
            before.actorUserId !== targetSnapshot.data()?.userId ||
            targetSnapshot.data()?.membershipId !== pathSegments[1] ||
            fingerprint(targetSnapshot.exists ? targetSnapshot.data() : null) !==
              before.afterFingerprint
          ) {
            throw new Error(
              `Relationship Membership changed after apply: ${before.entityPath}`,
            );
          }
          if (before.beforeExists === true) {
            if (
              !before.beforeData ||
              typeof before.beforeData !== "object" ||
              Array.isArray(before.beforeData)
            ) {
              throw new Error(
                `Relationship Membership before-image is invalid: ${before.entityPath}`,
              );
            }
            transaction.set(targetRef, before.beforeData, { merge: false });
          } else {
            transaction.delete(targetRef);
          }
          transaction.update(runRef, {
            restoredMemberships: admin.firestore.FieldValue.increment(1),
          });
        } else if (before.entityType === "user_projection") {
          if (
            pathSegments[0] !== "users" ||
            before.actorUserId !== pathSegments[1] ||
            !targetSnapshot.exists ||
            userMigrationStateFingerprint(targetSnapshot.data()) !==
              before.afterFingerprint
          ) {
            throw new Error(
              `Relationship user projection changed after apply: ${before.entityPath}`,
            );
          }
          const updateArguments = [];
          for (const state of validatedUserBeforeFields(before)) {
            updateArguments.push(
              state.path,
              state.present
                ? state.value
                : admin.firestore.FieldValue.delete(),
            );
          }
          transaction.update(targetRef, ...updateArguments);
          transaction.update(runRef, {
            restoredUsers: admin.firestore.FieldValue.increment(1),
          });
        } else {
          throw new Error(
            `Unknown Relationship before-image type: ${before.entityType}`,
          );
        }
        transaction.delete(beforeDocument.ref);
        const updatedAt = new Date().toISOString();
        transaction.update(fenceRef, { updatedAt });
        transaction.update(guardRef, { updatedAt });
      });
      restoredThisAttempt += 1;
      if (
        Number.isSafeInteger(testFailAfterRestores) &&
        testFailAfterRestores > 0 &&
        restoredThisAttempt >= testFailAfterRestores
      ) {
        throw new Error(
          `Injected relationship rollback failure after ` +
            `${restoredThisAttempt} restores.`,
        );
      }
    }

    const remainingBeforeImages = await db
      .collection(RELATIONSHIP_BEFORE_IMAGE_COLLECTION)
      .where("migrationRunId", "==", runId)
      .get();
    if (!remainingBeforeImages.empty) {
      throw new Error("Relationship rollback 尚有 before-image 未還原。");
    }
    await db.runTransaction(async transaction => {
      const [latestFence, latestGuard, latestRun] = await Promise.all([
        transaction.get(fenceRef),
        transaction.get(guardRef),
        transaction.get(runRef),
      ]);
      assertOwnedCutover(
        latestFence,
        latestGuard,
        context,
        "Relationship cutover fence ownership changed during rollback.",
      );
      if (
        !latestRun.exists ||
        latestRun.data().type !== RELATIONSHIP_MIGRATION_RUN_TYPE ||
        latestRun.data().capturedMembershipBeforeImages !==
          latestRun.data().restoredMemberships ||
        latestRun.data().capturedUserBeforeImages !==
          latestRun.data().restoredUsers
      ) {
        throw new Error("Relationship rollback before-image count mismatch.");
      }
      const rolledBackAt = new Date().toISOString();
      transaction.update(fenceRef, {
        active: false,
        ownerToken: null,
        operation: null,
        rolledBackAt,
        updatedAt: rolledBackAt,
      });
      transaction.set(guardRef, {
        schemaVersion: 1,
        active: false,
        operationKind: null,
        operationId: null,
        ownerToken: null,
        phase: null,
        updatedAt: rolledBackAt,
      }, { merge: false });
      transaction.update(runRef, {
        status: "rolled_back",
        rolledBackAt,
      });
    });
    console.log("Relationship cutover 已還原並解除 fence。");
  } catch (error) {
    await db.runTransaction(async transaction => {
      const latestFence = await transaction.get(fenceRef);
      if (
        latestFence.exists &&
        ownsCutover(
          latestFence.data(),
          runId,
          ownerToken,
          "rollback",
        )
      ) {
        transaction.update(runRef, {
          status: "rollback_failed",
          error: String(error?.message || error).slice(0, 500),
          failedAt: new Date().toISOString(),
        });
      }
    });
    throw error;
  }
}

const isDirectRun =
  process.argv[1] &&
  import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href;

if (isDirectRun) {
  const action = process.argv.includes("--rollback")
    ? rollbackActiveRelationshipCutover()
    : runRelationshipMigration({
        apply: process.argv.includes("--apply"),
      });
  action.catch(error => {
    console.error(error.message);
    process.exitCode = 1;
  });
}
