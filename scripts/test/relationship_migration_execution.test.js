import assert from "node:assert/strict";
import test from "node:test";

import admin from "firebase-admin";

import {
  rollbackActiveRelationshipCutover,
  runRelationshipMigration,
} from "../migrate_relationship_memberships.js";

const emulatorAvailable = Boolean(process.env.FIRESTORE_EMULATOR_HOST);

test("relationship migration is resumable, reversible, and fails closed on drift", {
  skip: !emulatorAvailable,
}, async t => {
  const app = admin.initializeApp({
    projectId: "nudge-relationship-migration-test",
  });
  t.after(async () => app.delete());
  const db = admin.firestore();
  const now = "2026-08-02T00:00:00.000Z";

  await db.collection("family_links").doc("family-1").set({
    guardianId: "guardian",
    childId: "child",
    participantIds: ["guardian", "child"],
    status: "active",
    createdAt: now,
    updatedAt: now,
  });
  await db.collection("groups").doc("group-1").set({
    name: "晨光讀書會",
    ownerId: "guardian",
    memberIds: ["guardian", "child"],
    status: "active",
    createdAt: now,
    updatedAt: now,
  });
  await db.collection("users").doc("guardian").set({
    userRole: "group",
    groupId: "group-1",
    groupName: "晨光讀書會",
    isGroupOwner: true,
    webToolsState: {
      guardianInvite: { relativeId: "child" },
      guardianInviteStatus: { status: "accepted" },
      futureLetter: { title: "保留" },
    },
  });
  await db.collection("users").doc("child").set({ userRole: "child" });

  const maintenanceGuardRef = db.collection("system_state")
    .doc("destructive_operation_guard");
  await maintenanceGuardRef.set({
    schemaVersion: 1,
    active: true,
    operationKind: "account_deletion",
    operationId: "deletion-first",
    leaseExpiresAt: "2020-01-01T00:00:00.000Z",
  });
  await assert.rejects(
    runRelationshipMigration({ apply: true }),
    /account deletion/i,
  );
  assert.equal(
    (await db.collection("system_state")
      .doc("relationship_membership_cutover").get()).exists,
    false,
  );
  await maintenanceGuardRef.delete();

  await assert.rejects(
    runRelationshipMigration({
      apply: true,
      testFailAfterOperations: 5,
    }),
    /Injected relationship migration failure after 5 operations/,
  );

  const memberships = await db.collection("relationship_memberships").get();
  assert.equal(memberships.size, 4);
  assert.equal(
    memberships.docs.find(doc => doc.id === "family--family-1--guardian")
      .data().role,
    "guardian",
  );
  assert.equal(
    memberships.docs.find(doc => doc.id === "group--group-1--child")
      .data().role,
    "member",
  );
  const user = (await db.collection("users").doc("guardian").get()).data();
  assert.equal(user.userRole, "individual");
  assert.equal(Object.hasOwn(user, "groupId"), false);
  assert.equal(Object.hasOwn(user, "groupName"), false);
  assert.equal(Object.hasOwn(user, "isGroupOwner"), false);
  assert.deepEqual(user.webToolsState.futureLetter, { title: "保留" });
  assert.equal(Object.hasOwn(user.webToolsState, "guardianInvite"), false);
  assert.equal(
    Object.hasOwn(user.webToolsState, "guardianInviteStatus"),
    false,
  );
  const fence = (
    await db.collection("system_state")
      .doc("relationship_membership_cutover")
      .get()
  ).data();
  assert.equal(fence.active, true);
  assert.equal(fence.operation, "apply");
  assert.ok(fence.ownerToken);

  const migrationRunId = fence.runId;
  const beforeImages = await db
    .collection("relationship_migration_before_images")
    .where("migrationRunId", "==", migrationRunId)
    .get();
  assert.equal(beforeImages.size, 5);
  assert.ok(beforeImages.docs.every(document =>
    document.data().retentionPolicy === "until_fresh_install_acceptance"
  ));
  const failedApplyRun = (
    await db.collection("migration_runs").doc(migrationRunId).get()
  ).data();
  assert.equal(failedApplyRun.status, "failed");
  assert.equal(failedApplyRun.capturedMembershipBeforeImages, 4);
  assert.equal(failedApplyRun.capturedUserBeforeImages, 1);

  await db.collection("users").doc("guardian").update({
    "webToolsState.futureLetter": { title: "遷移後更新也要保留" },
    nickname: "仍可編輯的暱稱",
  });

  await assert.rejects(
    rollbackActiveRelationshipCutover({ testFailAfterRestores: 2 }),
    /Injected relationship rollback failure after 2 restores/,
  );
  const interruptedRollbackFence = (
    await db.collection("system_state")
      .doc("relationship_membership_cutover").get()
  ).data();
  assert.equal(interruptedRollbackFence.active, true);
  assert.equal(interruptedRollbackFence.operation, "rollback");
  const interruptedRollbackOwner = interruptedRollbackFence.ownerToken;
  const interruptedRollbackRun = (
    await db.collection("migration_runs").doc(migrationRunId).get()
  ).data();
  assert.equal(interruptedRollbackRun.status, "rollback_failed");
  assert.equal(interruptedRollbackRun.restoredMemberships, 2);
  assert.equal(interruptedRollbackRun.restoredUsers, 0);
  assert.equal(
    (await db.collection("relationship_migration_before_images")
      .where("migrationRunId", "==", migrationRunId).get()).size,
    3,
  );

  await rollbackActiveRelationshipCutover();

  assert.equal(
    (await db.collection("relationship_memberships").get()).size,
    0,
  );
  const restoredUser = (
    await db.collection("users").doc("guardian").get()
  ).data();
  assert.equal(restoredUser.userRole, "group");
  assert.equal(restoredUser.groupId, "group-1");
  assert.equal(restoredUser.groupName, "晨光讀書會");
  assert.equal(restoredUser.isGroupOwner, true);
  assert.deepEqual(restoredUser.webToolsState.guardianInvite, {
    relativeId: "child",
  });
  assert.deepEqual(restoredUser.webToolsState.guardianInviteStatus, {
    status: "accepted",
  });
  assert.deepEqual(restoredUser.webToolsState.futureLetter, {
    title: "遷移後更新也要保留",
  });
  assert.equal(restoredUser.nickname, "仍可編輯的暱稱");
  assert.equal(
    Object.hasOwn(restoredUser, "relationshipProjectionMigratedAt"),
    false,
  );
  assert.equal(
    (await db.collection("relationship_migration_before_images").get()).size,
    0,
  );
  const rolledBackFence = (
    await db.collection("system_state")
      .doc("relationship_membership_cutover")
      .get()
  ).data();
  assert.equal(rolledBackFence.active, false);
  assert.equal(rolledBackFence.ownerToken, null);
  assert.equal(rolledBackFence.operation, null);
  const rolledBackRun = (
    await db.collection("migration_runs").doc(migrationRunId).get()
  ).data();
  assert.equal(rolledBackRun.status, "rolled_back");
  assert.equal(rolledBackRun.restoredMemberships, 4);
  assert.equal(rolledBackRun.restoredUsers, 1);
  assert.equal(rolledBackRun.rollbackAttempts, 2);
  assert.notEqual(rolledBackRun.lastRollbackOwnerToken, interruptedRollbackOwner);

  await assert.rejects(
    runRelationshipMigration({
      apply: true,
      testFailAfterOperations: 1,
    }),
    /Injected relationship migration failure after 1 operations/,
  );
  const tamperedFenceRef = db.collection("system_state")
    .doc("relationship_membership_cutover");
  const tamperedFence = (await tamperedFenceRef.get()).data();
  const tamperedRunRef = db.collection("migration_runs").doc(
    tamperedFence.runId,
  );
  const tamperedMembership = (
    await db.collection("relationship_memberships").get()
  ).docs[0];
  const originalScopeName = tamperedMembership.data().scopeName;
  await tamperedMembership.ref.update({ scopeName: "遷移後遭到外部修改" });

  await assert.rejects(
    runRelationshipMigration({ apply: true }),
    /Membership changed after apply/,
  );
  const rejectedResumeRun = (await tamperedRunRef.get()).data();
  assert.equal(rejectedResumeRun.status, "failed");

  await assert.rejects(
    rollbackActiveRelationshipCutover(),
    /Membership changed after apply/,
  );
  const rejectedFence = (await tamperedFenceRef.get()).data();
  assert.equal(rejectedFence.active, true);
  assert.equal(rejectedFence.operation, "rollback");
  assert.ok(rejectedFence.ownerToken);
  const rejectedRun = (await tamperedRunRef.get()).data();
  assert.equal(rejectedRun.status, "rollback_failed");
  assert.ok(
    (await db.collection("relationship_migration_before_images")
      .where("migrationRunId", "==", tamperedFence.runId)
      .get()).size > 0,
  );

  await tamperedMembership.ref.update({ scopeName: originalScopeName });
  await rollbackActiveRelationshipCutover();

  await assert.rejects(
    runRelationshipMigration({
      apply: true,
      testFailAfterOperations: 5,
    }),
    /Injected relationship migration failure after 5 operations/,
  );
  const userDriftFence = (await tamperedFenceRef.get()).data();
  const userDriftRunRef = db.collection("migration_runs").doc(
    userDriftFence.runId,
  );
  const userBeforeDrift = (
    await db.collection("users").doc("guardian").get()
  ).data();
  await db.collection("users").doc("guardian").update({
    updatedAt: "2099-01-01T00:00:00.000Z",
  });
  await assert.rejects(
    runRelationshipMigration({ apply: true }),
    /user projection changed after apply/,
  );
  assert.equal((await userDriftRunRef.get()).data().status, "failed");
  await db.collection("users").doc("guardian").update({
    updatedAt: userBeforeDrift.updatedAt,
  });
  await rollbackActiveRelationshipCutover();

  await assert.rejects(
    runRelationshipMigration({
      apply: true,
      testFailAfterOperations: 1,
    }),
    /Injected relationship migration failure after 1 operations/,
  );
  const missingEvidenceFence = (await tamperedFenceRef.get()).data();
  const missingEvidence = await db
    .collection("relationship_migration_before_images")
    .where("migrationRunId", "==", missingEvidenceFence.runId)
    .get();
  assert.equal(missingEvidence.size, 1);
  await missingEvidence.docs[0].ref.delete();
  await assert.rejects(
    rollbackActiveRelationshipCutover(),
    /before-image count mismatch/,
  );
  const missingEvidenceRun = (
    await db.collection("migration_runs").doc(missingEvidenceFence.runId).get()
  ).data();
  assert.equal(missingEvidenceRun.status, "rollback_failed");
  assert.equal((await tamperedFenceRef.get()).data().active, true);
});
