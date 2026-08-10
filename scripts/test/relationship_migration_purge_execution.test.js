import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import test from "node:test";

import admin from "firebase-admin";

import {
  purgeRelationshipMigrationBeforeImages,
  recordProductionAcceptanceEvidence,
} from "../purge_relationship_migration_before_images.js";

const emulatorAvailable = Boolean(process.env.FIRESTORE_EMULATOR_HOST);

const projectId = "nudge-relationship-purge-test";
const migrationRunId = "relationship-run-accepted";
const acceptanceEvidenceId = "acceptance-incomplete";

function beforeImageId(runId, entityPath) {
  const pathHash = createHash("sha256").update(JSON.stringify(entityPath))
    .digest("hex");
  return `${runId}--${pathHash.slice(0, 32)}`;
}

function acceptedEvidence({ runId, evidenceId, acceptedAt }) {
  return {
    schemaVersion: 1,
    acceptanceEvidenceId: evidenceId,
    status: "accepted",
    environment: "production",
    projectId,
    relationshipMigrationRunId: runId,
    realAccountE2e: {
      accepted: true,
      runId: `real-account-e2e--${runId}`,
      artifactSha256: "a".repeat(64),
    },
    freshInstall: {
      ios: {
        accepted: true,
        artifactSha256: "b".repeat(64),
      },
      android: {
        accepted: true,
        artifactSha256: "c".repeat(64),
      },
    },
    acceptedAt,
    acceptedBy: "release-owner",
  };
}

async function seedReleaseOwner(db) {
  await db.collection("users").doc("release-owner").set({
    staffRole: "operator",
  });
}

async function seedCompletedRun(db, { runId, entityPath }) {
  await db.collection("migration_runs").doc(runId).set({
    type: "relationship_membership_projection_cutover",
    status: "completed",
    completedAt: "2026-08-10T00:30:00.000Z",
    capturedMembershipBeforeImages: 1,
    capturedUserBeforeImages: 0,
  });
  await db.collection("relationship_migration_before_images")
    .doc(beforeImageId(runId, entityPath))
    .set({
      schemaVersion: 1,
      migrationRunId: runId,
      entityType: "membership",
      entityPath,
      actorUserId: "child",
      retentionPolicy: "until_fresh_install_acceptance",
    });
}

test("purge rejects incomplete production acceptance and preserves evidence", {
  skip: !emulatorAvailable,
}, async t => {
  const app = admin.initializeApp({ projectId });
  t.after(async () => app.delete());
  const db = admin.firestore();

  await seedReleaseOwner(db);
  await seedCompletedRun(db, {
    runId: migrationRunId,
    entityPath: "relationship_memberships/family--one--child",
  });
  const incompleteEvidence = {
    schemaVersion: 1,
    acceptanceEvidenceId,
    status: "accepted",
    environment: "production",
    projectId,
    relationshipMigrationRunId: migrationRunId,
    realAccountE2e: {
      accepted: true,
      runId: "real-account-e2e-1",
      artifactSha256: "a".repeat(64),
    },
    freshInstall: {
      ios: {
        accepted: true,
        artifactSha256: "b".repeat(64),
      },
    },
    acceptedAt: "2026-08-10T00:00:00.000Z",
    acceptedBy: "release-owner",
  };

  await assert.rejects(
    recordProductionAcceptanceEvidence(incompleteEvidence),
    /Android fresh-install evidence is required/,
  );

  assert.equal(
    (await db.collection("production_acceptance_evidence")
      .doc(acceptanceEvidenceId).get()).exists,
    false,
  );
  assert.equal(
    (await db.collection("audit_events")
      .doc(`relationship-before-image-purge--${migrationRunId}`).get()).exists,
    false,
  );
  let evidence = {
    ...incompleteEvidence,
    freshInstall: {
      ...incompleteEvidence.freshInstall,
      android: {
        accepted: true,
        artifactSha256: "c".repeat(64),
      },
    },
  };
  const futureEvidence = {
    ...evidence,
    acceptanceEvidenceId: "acceptance-from-the-future",
    acceptedAt: "2999-01-01T00:00:00.000Z",
  };
  await assert.rejects(
    recordProductionAcceptanceEvidence(futureEvidence),
    /future/i,
  );
  assert.equal(
    (await db.collection("production_acceptance_evidence")
      .doc(futureEvidence.acceptanceEvidenceId).get()).exists,
    false,
  );
  await assert.rejects(
    recordProductionAcceptanceEvidence(evidence),
    /predates the completed migration/,
  );
  evidence = {
    ...evidence,
    acceptedAt: "2026-08-10T01:00:00.000Z",
  };
  await assert.rejects(
    recordProductionAcceptanceEvidence({
      ...evidence,
      acceptanceEvidenceId: "acceptance-unknown-operator",
      acceptedBy: "unknown-release-operator",
    }),
    /authorized release operator/i,
  );
  const recorded = await recordProductionAcceptanceEvidence(evidence);
  assert.equal(recorded.acceptanceEvidenceId, acceptanceEvidenceId);
  assert.equal(recorded.auditEventId,
    `production-acceptance-recorded--${acceptanceEvidenceId}`);
  assert.equal(recorded.replayed, false);
  assert.deepEqual(
    await recordProductionAcceptanceEvidence(evidence),
    { ...recorded, replayed: true },
  );
  const acceptanceAuditRef = db.collection("audit_events")
    .doc(`production-acceptance-recorded--${acceptanceEvidenceId}`);
  await acceptanceAuditRef.update({
    "result.evidenceFingerprint": "d".repeat(64),
  });
  await assert.rejects(
    recordProductionAcceptanceEvidence(evidence),
    /identity conflict/,
  );
  await acceptanceAuditRef.update({
    "result.evidenceFingerprint": recorded.evidenceFingerprint,
  });
  await db.collection("system_state")
    .doc("relationship_membership_cutover")
    .set({ active: true, runId: migrationRunId });
  await assert.rejects(
    purgeRelationshipMigrationBeforeImages({
      migrationRunId,
      acceptanceEvidenceId,
    }),
    /active Relationship cutover/,
  );
  assert.equal(
    (await db.collection("relationship_migration_before_images")
      .where("migrationRunId", "==", migrationRunId).get()).size,
    1,
  );
  await db.collection("system_state")
    .doc("relationship_membership_cutover")
    .set({ active: false, runId: migrationRunId });
});

test("purge resumes after interruption and writes one immutable audit", {
  skip: !emulatorAvailable,
}, async t => {
  const app = admin.initializeApp({ projectId });
  t.after(async () => app.delete());
  const db = admin.firestore();
  const runId = "relationship-run-resume";
  const evidenceId = "acceptance-resume";
  await seedReleaseOwner(db);
  await seedCompletedRun(db, {
    runId,
    entityPath: "relationship_memberships/family--resume--child",
  });
  const evidence = acceptedEvidence({
    runId,
    evidenceId,
    acceptedAt: "2026-08-10T01:00:00.000Z",
  });
  await recordProductionAcceptanceEvidence(evidence);
  await db.collection("system_state")
    .doc("relationship_membership_cutover")
    .set({ active: false, runId });

  await assert.rejects(
    purgeRelationshipMigrationBeforeImages({
      migrationRunId: runId,
      acceptanceEvidenceId: evidenceId,
      testFailAfterDeletes: 1,
    }),
    /Injected Relationship evidence purge failure after 1 deletes/,
  );

  const failedRun = (
    await db.collection("migration_runs").doc(runId).get()
  ).data();
  assert.equal(failedRun.purgeStatus, "failed");
  assert.equal(failedRun.purgedBeforeImageCount, 1);
  const failedGuard = (
    await db.collection("system_state")
      .doc("destructive_operation_guard").get()
  ).data();
  assert.equal(failedGuard.active, true);
  assert.equal(failedGuard.operationKind, "relationship_evidence_purge");

  const result = await purgeRelationshipMigrationBeforeImages({
    migrationRunId: runId,
    acceptanceEvidenceId: evidenceId,
  });
  assert.deepEqual(result, {
    migrationRunId: runId,
    acceptanceEvidenceId: evidenceId,
    purgedCount: 1,
    auditEventId: `relationship-before-image-purge--${runId}`,
    replayed: false,
  });
  assert.equal(
    (await db.collection("relationship_migration_before_images")
      .where("migrationRunId", "==", runId).get()).size,
    0,
  );
  const completedRun = (
    await db.collection("migration_runs").doc(runId).get()
  ).data();
  assert.equal(completedRun.status, "completed");
  assert.equal(completedRun.purgeStatus, "completed");
  assert.equal(completedRun.purgeExpectedCount, 1);
  assert.equal(completedRun.purgedBeforeImageCount, 1);
  assert.equal(completedRun.purgeAcceptanceEvidenceId, evidenceId);
  const completedGuard = (
    await db.collection("system_state")
      .doc("destructive_operation_guard").get()
  ).data();
  assert.equal(completedGuard.active, false);
  const audit = (
    await db.collection("audit_events")
      .doc(`relationship-before-image-purge--${runId}`).get()
  ).data();
  assert.equal(audit.action, "migration.relationship_before_images.purged");
  assert.equal(audit.targetId, runId);
  assert.equal(audit.clientRequestId, evidenceId);
  assert.deepEqual(audit.result, {
    acceptanceEvidenceId: evidenceId,
    capturedCount: 1,
    privacyDeletedCount: 0,
    purgedCount: 1,
  });

  assert.deepEqual(
    await purgeRelationshipMigrationBeforeImages({
      migrationRunId: runId,
      acceptanceEvidenceId: evidenceId,
    }),
    { ...result, replayed: true },
  );

  await assert.rejects(
    recordProductionAcceptanceEvidence(acceptedEvidence({
      runId,
      evidenceId: "acceptance-resume-alternate",
      acceptedAt: "2026-08-10T01:30:00.000Z",
    })),
    /already bound/i,
  );
  const unchangedRun = (
    await db.collection("migration_runs").doc(runId).get()
  ).data();
  const unchangedGuard = (
    await db.collection("system_state")
      .doc("destructive_operation_guard").get()
  ).data();
  assert.equal(unchangedRun.purgeStatus, "completed");
  assert.equal(unchangedRun.purgeAcceptanceEvidenceId, evidenceId);
  assert.equal(unchangedGuard.active, false);

  const purgeAuditRef = db.collection("audit_events")
    .doc(`relationship-before-image-purge--${runId}`);
  await purgeAuditRef.update({ "result.purgedCount": 2 });
  await assert.rejects(
    purgeRelationshipMigrationBeforeImages({
      migrationRunId: runId,
      acceptanceEvidenceId: evidenceId,
    }),
    /purge audit/i,
  );
  await purgeAuditRef.update({ "result.purgedCount": 1 });
  await purgeAuditRef.update({
    "result.acceptanceEvidenceId": "wrong-evidence",
  });
  await assert.rejects(
    purgeRelationshipMigrationBeforeImages({
      migrationRunId: runId,
      acceptanceEvidenceId: evidenceId,
    }),
    /purge audit/i,
  );
  await purgeAuditRef.update({ "result.acceptanceEvidenceId": evidenceId });
  const runRef = db.collection("migration_runs").doc(runId);
  await runRef.update({ purgeAuditEventId: "wrong-audit" });
  await assert.rejects(
    purgeRelationshipMigrationBeforeImages({
      migrationRunId: runId,
      acceptanceEvidenceId: evidenceId,
    }),
    /purge audit/i,
  );
  await runRef.update({ purgeAuditEventId: result.auditEventId });
  await runRef.update({ capturedMembershipBeforeImages: 2 });
  await assert.rejects(
    purgeRelationshipMigrationBeforeImages({
      migrationRunId: runId,
      acceptanceEvidenceId: evidenceId,
    }),
    /purge audit/i,
  );
  await runRef.update({ capturedMembershipBeforeImages: 1 });
});

test("pre-existing purge audit fails before evidence is deleted", {
  skip: !emulatorAvailable,
}, async t => {
  const app = admin.initializeApp({ projectId });
  t.after(async () => app.delete());
  const db = admin.firestore();
  const runId = "relationship-run-audit-collision";
  const evidenceId = "acceptance-audit-collision";
  const entityPath = "relationship_memberships/family--collision--child";
  await seedReleaseOwner(db);
  await seedCompletedRun(db, { runId, entityPath });
  await recordProductionAcceptanceEvidence(acceptedEvidence({
    runId,
    evidenceId,
    acceptedAt: "2026-08-10T01:00:00.000Z",
  }));
  await db.collection("audit_events")
    .doc(`relationship-before-image-purge--${runId}`)
    .set({
      action: "unexpected.preexisting.audit",
      targetId: runId,
    });

  await assert.rejects(
    purgeRelationshipMigrationBeforeImages({
      migrationRunId: runId,
      acceptanceEvidenceId: evidenceId,
    }),
    /purge audit already exists/i,
  );

  assert.equal(
    (await db.collection("relationship_migration_before_images")
      .doc(beforeImageId(runId, entityPath)).get()).exists,
    true,
  );
  const run = (await db.collection("migration_runs").doc(runId).get()).data();
  const guard = (await db.collection("system_state")
    .doc("destructive_operation_guard").get()).data();
  assert.equal(run.purgeStatus, undefined);
  assert.notEqual(guard?.active, true);
});

test("privacy-deleted before-images reconcile with the final purge audit", {
  skip: !emulatorAvailable,
}, async t => {
  const app = admin.initializeApp({ projectId });
  t.after(async () => app.delete());
  const db = admin.firestore();
  const runId = "relationship-run-privacy-delete";
  const evidenceId = "acceptance-after-privacy-delete";
  const subjectUserId = "privacy-delete-subject";
  const entityPath = `relationship_memberships/family--privacy--${subjectUserId}`;
  const deletionRequestId = "privacy-delete-request-001";
  await seedReleaseOwner(db);
  await seedCompletedRun(db, { runId, entityPath });
  const beforeRef = db.collection("relationship_migration_before_images")
    .doc(beforeImageId(runId, entityPath));
  await beforeRef.update({ actorUserId: subjectUserId });
  const privacyEvidenceRef = db
    .collection("relationship_before_image_privacy_deletions")
    .doc(beforeRef.id);
  await db.runTransaction(async transaction => {
    transaction.delete(beforeRef);
    transaction.create(privacyEvidenceRef, {
      schemaVersion: 1,
      evidenceId: privacyEvidenceRef.id,
      migrationRunId: runId,
      beforeImageId: beforeRef.id,
      deletionRequestId,
      deletedAt: "2026-08-10T00:45:00.000Z",
    });
    transaction.update(db.collection("migration_runs").doc(runId), {
      privacyDeletedBeforeImageCount: 1,
    });
  });

  assert.equal((await beforeRef.get()).exists, false);
  const migrationRunAfterDeletion = (
    await db.collection("migration_runs").doc(runId).get()
  ).data();
  assert.equal(migrationRunAfterDeletion.privacyDeletedBeforeImageCount, 1);
  const deletionEvidence = await db
    .collection("relationship_before_image_privacy_deletions")
    .where("migrationRunId", "==", runId)
    .get();
  assert.equal(deletionEvidence.size, 1);
  assert.equal(deletionEvidence.docs[0].data().deletionRequestId,
    deletionRequestId);

  await recordProductionAcceptanceEvidence(acceptedEvidence({
    runId,
    evidenceId,
    acceptedAt: "2026-08-10T01:00:00.000Z",
  }));
  const result = await purgeRelationshipMigrationBeforeImages({
    migrationRunId: runId,
    acceptanceEvidenceId: evidenceId,
  });
  assert.equal(result.purgedCount, 0);
  const audit = (
    await db.collection("audit_events")
      .doc(`relationship-before-image-purge--${runId}`).get()
  ).data();
  assert.deepEqual(audit.result, {
    acceptanceEvidenceId: evidenceId,
    capturedCount: 1,
    privacyDeletedCount: 1,
    purgedCount: 0,
  });
  const completedRun = (
    await db.collection("migration_runs").doc(runId).get()
  ).data();
  assert.equal(completedRun.purgeCapturedCount, 1);
  assert.equal(completedRun.purgePrivacyDeletedCount, 1);
  assert.equal(completedRun.purgeExpectedCount, 0);
});
