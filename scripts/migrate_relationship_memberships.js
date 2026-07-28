import admin from "firebase-admin";
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
      clearFields,
      setFields: data.userRole === "group" ? { userRole: "individual" } : {},
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

async function commitInChunks(db, operations, applyOperation) {
  let completed = 0;
  for (let offset = 0; offset < operations.length; offset += 350) {
    const batch = db.batch();
    const chunk = operations.slice(offset, offset + 350);
    for (const operation of chunk) applyOperation(batch, operation);
    await batch.commit();
    completed += chunk.length;
  }
  return completed;
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

async function runMigration({ apply, allowIssues }) {
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
  if (plan.issues.length > 0 && !allowIssues) {
    throw new Error(
      "存在無效父關係資料；修正後重跑，或明確加入 --allow-issues。",
    );
  }

  const runRef = db.collection("migration_runs").doc();
  await runRef.set({
    type: "relationship_membership_projection_cutover",
    status: "running",
    startedAt: admin.firestore.FieldValue.serverTimestamp(),
    counts: plan.counts,
  });
  try {
    const membershipWrites = await commitInChunks(
      db,
      plan.membershipUpserts,
      (batch, operation) => {
        const payload = { ...operation.data };
        if (operation.clearEndedFields) {
          payload.activeUntil = admin.firestore.FieldValue.delete();
          payload.endedBy = admin.firestore.FieldValue.delete();
        }
        batch.set(
          db.collection("relationship_memberships").doc(operation.id),
          payload,
          { merge: true },
        );
      },
    );
    const cleanupWrites = await commitInChunks(
      db,
      plan.userProjectionCleanup,
      (batch, operation) => {
        const update = {
          ...operation.setFields,
          relationshipProjectionMigratedAt:
            admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };
        for (const field of operation.clearFields) {
          update[field] = admin.firestore.FieldValue.delete();
        }
        batch.update(db.collection("users").doc(operation.userId), update);
      },
    );
    await runRef.update({
      status: "completed",
      membershipWrites,
      cleanupWrites,
      completedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log(
      `完成：${membershipWrites} 筆 Membership、${cleanupWrites} 筆舊投影清理。`,
    );
    return plan;
  } catch (error) {
    await runRef.update({
      status: "failed",
      error: String(error?.message || error).slice(0, 500),
      failedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    throw error;
  }
}

const isDirectRun =
  process.argv[1] &&
  import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href;

if (isDirectRun) {
  runMigration({
    apply: process.argv.includes("--apply"),
    allowIssues: process.argv.includes("--allow-issues"),
  }).catch(error => {
    console.error(error.message);
    process.exitCode = 1;
  });
}
