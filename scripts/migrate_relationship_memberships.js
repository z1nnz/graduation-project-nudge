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

function ownsCutover(fence, runId, ownerToken) {
  return fence?.active === true &&
    fence.runId === runId &&
    fence.ownerToken === ownerToken;
}

async function acquireCutover(db) {
  const fenceRef = db
    .collection("system_state")
    .doc("relationship_membership_cutover");
  const proposedRunRef = db.collection("migration_runs").doc();
  const ownerToken = randomUUID();
  const startedAt = new Date().toISOString();
  return db.runTransaction(async transaction => {
    const fenceSnapshot = await transaction.get(fenceRef);
    if (fenceSnapshot.exists && fenceSnapshot.data().active === true) {
      const fence = fenceSnapshot.data();
      if (typeof fence.runId !== "string" || !fence.runId) {
        throw new Error("既有 Relationship cutover fence 無法安全續跑。");
      }
      const runRef = db.collection("migration_runs").doc(fence.runId);
      transaction.update(fenceRef, { ownerToken, updatedAt: startedAt });
      transaction.set(runRef, {
        status: "running",
        resumedAt: startedAt,
      }, { merge: true });
      return { fenceRef, runRef, ownerToken };
    }
    transaction.set(fenceRef, {
      active: true,
      runId: proposedRunRef.id,
      ownerToken,
      startedAt,
      updatedAt: startedAt,
    });
    transaction.create(proposedRunRef, {
      type: "relationship_membership_projection_cutover",
      status: "running",
      startedAt,
    });
    return { fenceRef, runRef: proposedRunRef, ownerToken };
  });
}

async function applyMembershipOperation(
  db,
  fenceRef,
  runRef,
  ownerToken,
  operation,
) {
  const parentRef = db
    .collection(operation.parentCollection)
    .doc(operation.data.scopeId);
  const membershipRef = db
    .collection("relationship_memberships")
    .doc(operation.id);
  await db.runTransaction(async transaction => {
    const [fenceSnapshot, parentSnapshot, membershipSnapshot] =
      await Promise.all([
        transaction.get(fenceRef),
        transaction.get(parentRef),
        transaction.get(membershipRef),
      ]);
    if (
      !fenceSnapshot.exists ||
      !ownsCutover(fenceSnapshot.data(), runRef.id, ownerToken)
    ) {
      throw new Error("Relationship cutover ownership changed.");
    }
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
    transaction.set(membershipRef, payload, { merge: true });
    transaction.update(fenceRef, { updatedAt: new Date().toISOString() });
  });
}

async function applyUserCleanup(
  db,
  fenceRef,
  runRef,
  ownerToken,
  operation,
) {
  const userRef = db.collection("users").doc(operation.userId);
  await db.runTransaction(async transaction => {
    const [fenceSnapshot, userSnapshot] = await Promise.all([
      transaction.get(fenceRef),
      transaction.get(userRef),
    ]);
    if (
      !fenceSnapshot.exists ||
      !ownsCutover(fenceSnapshot.data(), runRef.id, ownerToken)
    ) {
      throw new Error("Relationship cutover ownership changed.");
    }
    if (!userSnapshot.exists) {
      throw new Error(`Relationship cleanup user missing: ${operation.userId}`);
    }
    if (
      legacyProjectionFingerprint(userSnapshot.data()) !==
      operation.expectedProjectionFingerprint
    ) {
      throw new Error(`Legacy relationship projection changed: ${operation.userId}`);
    }
    const update = {
      ...operation.setFields,
      relationshipProjectionMigratedAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };
    for (const field of operation.clearFields) {
      update[field] = admin.firestore.FieldValue.delete();
    }
    transaction.update(userRef, update);
    transaction.update(fenceRef, { updatedAt: new Date().toISOString() });
  });
}

async function updateOwnedRun(
  db,
  fenceRef,
  runRef,
  ownerToken,
  values,
) {
  await db.runTransaction(async transaction => {
    const fenceSnapshot = await transaction.get(fenceRef);
    if (
      !fenceSnapshot.exists ||
      !ownsCutover(fenceSnapshot.data(), runRef.id, ownerToken)
    ) {
      throw new Error("Relationship cutover ownership changed.");
    }
    transaction.set(runRef, values, { merge: true });
  });
}

export async function runRelationshipMigration({ apply }) {
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

  const { fenceRef, runRef, ownerToken } = await acquireCutover(db);
  try {
    await updateOwnedRun(
      db,
      fenceRef,
      runRef,
      ownerToken,
      { counts: plan.counts },
    );
    let membershipWrites = 0;
    for (const operation of plan.membershipUpserts) {
      await applyMembershipOperation(
        db,
        fenceRef,
        runRef,
        ownerToken,
        operation,
      );
      membershipWrites += 1;
    }
    let cleanupWrites = 0;
    for (const operation of plan.userProjectionCleanup) {
      await applyUserCleanup(
        db,
        fenceRef,
        runRef,
        ownerToken,
        operation,
      );
      cleanupWrites += 1;
    }
    await db.runTransaction(async transaction => {
      const fenceSnapshot = await transaction.get(fenceRef);
      if (
        !fenceSnapshot.exists ||
        !ownsCutover(fenceSnapshot.data(), runRef.id, ownerToken)
      ) {
        throw new Error("Relationship cutover ownership changed before release.");
      }
      const completedAt = new Date().toISOString();
      transaction.update(fenceRef, {
        active: false,
        ownerToken: null,
        completedAt,
        updatedAt: completedAt,
      });
      transaction.set(runRef, {
        status: "completed",
        membershipWrites,
        cleanupWrites,
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
        ownsCutover(fenceSnapshot.data(), runRef.id, ownerToken)
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

const isDirectRun =
  process.argv[1] &&
  import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href;

if (isDirectRun) {
  runRelationshipMigration({
    apply: process.argv.includes("--apply"),
  }).catch(error => {
    console.error(error.message);
    process.exitCode = 1;
  });
}
