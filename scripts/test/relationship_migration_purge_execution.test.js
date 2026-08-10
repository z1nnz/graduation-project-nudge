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

test("purge rejects incomplete production acceptance and preserves evidence", {
  skip: !emulatorAvailable,
}, async t => {
  const app = admin.initializeApp({ projectId });
  t.after(async () => app.delete());
  const db = admin.firestore();

  await db.collection("migration_runs").doc(migrationRunId).set({
    type: "relationship_membership_projection_cutover",
    status: "completed",
    completedAt: "2026-08-10T00:30:00.000Z",
    capturedMembershipBeforeImages: 1,
    capturedUserBeforeImages: 0,
  });
  await db.collection("relationship_migration_before_images")
    .doc(beforeImageId(
      migrationRunId,
      "relationship_memberships/family--one--child",
    ))
    .set({
      schemaVersion: 1,
      migrationRunId,
      entityType: "membership",
      entityPath: "relationship_memberships/family--one--child",
      actorUserId: "child",
      retentionPolicy: "until_fresh_install_acceptance",
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
    (await db.collection("relationship_migration_before_images").get()).size,
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
  await db.collection("system_state")
    .doc("relationship_membership_cutover")
    .set({ active: false, runId: migrationRunId });

  await assert.rejects(
    purgeRelationshipMigrationBeforeImages({
      migrationRunId,
      acceptanceEvidenceId,
      testFailAfterDeletes: 1,
    }),
    /Injected Relationship evidence purge failure after 1 deletes/,
  );

  const failedRun = (
    await db.collection("migration_runs").doc(migrationRunId).get()
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
    migrationRunId,
    acceptanceEvidenceId,
  });
  assert.deepEqual(result, {
    migrationRunId,
    acceptanceEvidenceId,
    purgedCount: 1,
    auditEventId: `relationship-before-image-purge--${migrationRunId}`,
    replayed: false,
  });
  assert.equal(
    (await db.collection("relationship_migration_before_images").get()).size,
    0,
  );
  const completedRun = (
    await db.collection("migration_runs").doc(migrationRunId).get()
  ).data();
  assert.equal(completedRun.status, "completed");
  assert.equal(completedRun.purgeStatus, "completed");
  assert.equal(completedRun.purgeExpectedCount, 1);
  assert.equal(completedRun.purgedBeforeImageCount, 1);
  assert.equal(completedRun.purgeAcceptanceEvidenceId, acceptanceEvidenceId);
  const completedGuard = (
    await db.collection("system_state")
      .doc("destructive_operation_guard").get()
  ).data();
  assert.equal(completedGuard.active, false);
  const audit = (
    await db.collection("audit_events")
      .doc(`relationship-before-image-purge--${migrationRunId}`).get()
  ).data();
  assert.equal(audit.action, "migration.relationship_before_images.purged");
  assert.equal(audit.targetId, migrationRunId);
  assert.equal(audit.clientRequestId, acceptanceEvidenceId);
  assert.deepEqual(audit.result, {
    acceptanceEvidenceId,
    purgedCount: 1,
  });

  assert.deepEqual(
    await purgeRelationshipMigrationBeforeImages({
      migrationRunId,
      acceptanceEvidenceId,
    }),
    { ...result, replayed: true },
  );
});
