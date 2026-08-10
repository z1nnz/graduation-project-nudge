import admin from "firebase-admin";
import { createHash, randomUUID } from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const RELATIONSHIP_MIGRATION_RUN_TYPE =
  "relationship_membership_projection_cutover";
const ACCEPTANCE_EVIDENCE_COLLECTION = "production_acceptance_evidence";
const BEFORE_IMAGE_COLLECTION = "relationship_migration_before_images";
const GUARD_ID = "destructive_operation_guard";
const RETENTION_POLICY = "until_fresh_install_acceptance";
const MAX_ACCEPTANCE_CLOCK_SKEW_MS = 5 * 60 * 1000;

function beforeImageId(runId, entityPath) {
  const pathHash = createHash("sha256")
    .update(JSON.stringify(entityPath))
    .digest("hex");
  return `${runId}--${pathHash.slice(0, 32)}`;
}

function ownsPurgeGuard(guard, runId, acceptanceEvidenceId, ownerToken) {
  return guard?.active === true &&
    guard.operationKind === "relationship_evidence_purge" &&
    guard.operationId === runId &&
    guard.acceptanceEvidenceId === acceptanceEvidenceId &&
    (ownerToken === undefined || guard.ownerToken === ownerToken);
}

function capturedBeforeImageCount(run) {
  const membershipCount = run?.capturedMembershipBeforeImages;
  const userCount = run?.capturedUserBeforeImages;
  if (
    !Number.isSafeInteger(membershipCount) ||
    membershipCount < 0 ||
    !Number.isSafeInteger(userCount) ||
    userCount < 0
  ) {
    throw new Error("Relationship migration captured counts are invalid.");
  }
  return membershipCount + userCount;
}

function assertBeforeImage(document, runId) {
  const before = document.data();
  if (
    before.schemaVersion !== 1 ||
    before.migrationRunId !== runId ||
    !["membership", "user_projection"].includes(before.entityType) ||
    typeof before.entityPath !== "string" ||
    !before.entityPath ||
    typeof before.actorUserId !== "string" ||
    !before.actorUserId ||
    before.retentionPolicy !== RETENTION_POLICY ||
    document.id !== beforeImageId(runId, before.entityPath)
  ) {
    throw new Error(`Relationship before-image is invalid: ${document.id}`);
  }
}

function requiredString(value, label) {
  if (typeof value !== "string" || !value.trim()) {
    throw new Error(`${label} is required.`);
  }
  return value.trim();
}

function validArtifactSha256(value) {
  return typeof value === "string" && /^[a-f0-9]{64}$/i.test(value);
}

function normalizedAcceptanceEvidence(evidence) {
  return {
    schemaVersion: evidence.schemaVersion,
    acceptanceEvidenceId: evidence.acceptanceEvidenceId,
    status: evidence.status,
    environment: evidence.environment,
    projectId: evidence.projectId,
    relationshipMigrationRunId: evidence.relationshipMigrationRunId,
    realAccountE2e: {
      accepted: evidence.realAccountE2e?.accepted,
      runId: evidence.realAccountE2e?.runId,
      artifactSha256: evidence.realAccountE2e?.artifactSha256,
    },
    freshInstall: {
      ios: {
        accepted: evidence.freshInstall?.ios?.accepted,
        artifactSha256: evidence.freshInstall?.ios?.artifactSha256,
      },
      android: {
        accepted: evidence.freshInstall?.android?.accepted,
        artifactSha256: evidence.freshInstall?.android?.artifactSha256,
      },
    },
    acceptedAt: evidence.acceptedAt,
    acceptedBy: evidence.acceptedBy,
  };
}

function fingerprint(value) {
  function canonical(input) {
    if (Array.isArray(input)) return input.map(canonical);
    if (input && typeof input === "object") {
      return Object.fromEntries(
        Object.keys(input).sort().map(key => [key, canonical(input[key])]),
      );
    }
    return input;
  }
  return createHash("sha256")
    .update(JSON.stringify(canonical(value)))
    .digest("hex");
}

function assertAcceptedArtifact(value, label) {
  if (
    !value ||
    value.accepted !== true ||
    !validArtifactSha256(value.artifactSha256)
  ) {
    throw new Error(`${label} evidence is required.`);
  }
}

function assertAcceptanceEvidence(
  evidence,
  { acceptanceEvidenceId, migrationRunId, projectId },
) {
  if (
    evidence?.schemaVersion !== 1 ||
    evidence.acceptanceEvidenceId !== acceptanceEvidenceId ||
    evidence.status !== "accepted" ||
    evidence.environment !== "production" ||
    evidence.projectId !== projectId ||
    evidence.relationshipMigrationRunId !== migrationRunId ||
    typeof evidence.acceptedBy !== "string" ||
    !evidence.acceptedBy.trim() ||
    typeof evidence.acceptedAt !== "string" ||
    Number.isNaN(Date.parse(evidence.acceptedAt))
  ) {
    throw new Error("Production acceptance evidence does not match this run.");
  }
  assertAcceptedArtifact(evidence.realAccountE2e, "Real-account E2E");
  if (
    typeof evidence.realAccountE2e.runId !== "string" ||
    !evidence.realAccountE2e.runId.trim()
  ) {
    throw new Error("Real-account E2E run identity is required.");
  }
  assertAcceptedArtifact(evidence.freshInstall?.ios, "iOS fresh-install");
  assertAcceptedArtifact(
    evidence.freshInstall?.android,
    "Android fresh-install",
  );
}

function assertRecordedAcceptanceEvidence(
  evidence,
  audit,
  { acceptanceEvidenceId, migrationRunId, projectId },
) {
  assertAcceptanceEvidence(evidence, {
    acceptanceEvidenceId,
    migrationRunId,
    projectId,
  });
  const expectedAuditId =
    `production-acceptance-recorded--${acceptanceEvidenceId}`;
  const expectedFingerprint = fingerprint(
    normalizedAcceptanceEvidence(evidence),
  );
  if (
    evidence.evidenceFingerprint !== expectedFingerprint ||
    evidence.recordAuditEventId !== expectedAuditId ||
    audit?.action !== "production.acceptance.recorded" ||
    audit.auditEventId !== expectedAuditId ||
    audit.targetId !== acceptanceEvidenceId ||
    audit.clientRequestId !== acceptanceEvidenceId ||
    audit.result?.evidenceFingerprint !== expectedFingerprint ||
    audit.result?.relationshipMigrationRunId !== migrationRunId
  ) {
    throw new Error("Production acceptance record or audit is invalid.");
  }
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
      projectId: serviceAccount.project_id,
    });
  }
  return admin.initializeApp({
    credential: admin.credential.applicationDefault(),
  });
}

function projectIdFor(app) {
  const firebaseConfig = (() => {
    try {
      return JSON.parse(process.env.FIREBASE_CONFIG || "{}");
    } catch {
      return {};
    }
  })();
  return requiredString(
    app.options.projectId ||
      process.env.GCLOUD_PROJECT ||
      process.env.GOOGLE_CLOUD_PROJECT ||
      firebaseConfig.projectId,
    "Firebase project id",
  );
}

export async function recordProductionAcceptanceEvidence(evidence) {
  const app = await initializeAdmin();
  const db = admin.firestore();
  const projectId = projectIdFor(app);
  const normalized = normalizedAcceptanceEvidence(evidence ?? {});
  const acceptanceEvidenceId = requiredString(
    normalized.acceptanceEvidenceId,
    "Acceptance evidence id",
  );
  const migrationRunId = requiredString(
    normalized.relationshipMigrationRunId,
    "Relationship migration run id",
  );
  assertAcceptanceEvidence(normalized, {
    acceptanceEvidenceId,
    migrationRunId,
    projectId,
  });
  const evidenceFingerprint = fingerprint(normalized);
  const evidenceRef = db.collection(ACCEPTANCE_EVIDENCE_COLLECTION)
    .doc(acceptanceEvidenceId);
  const runRef = db.collection("migration_runs").doc(migrationRunId);
  const relationshipFenceRef = db.collection("system_state")
    .doc("relationship_membership_cutover");
  const rewardFenceRef = db.collection("system_state")
    .doc("reward_ledger_cutover");
  const guardRef = db.collection("system_state").doc(GUARD_ID);
  const auditRef = db.collection("audit_events")
    .doc(`production-acceptance-recorded--${acceptanceEvidenceId}`);
  const recordedAt = new Date().toISOString();
  if (
    Date.parse(normalized.acceptedAt) >
      Date.parse(recordedAt) + MAX_ACCEPTANCE_CLOCK_SKEW_MS
  ) {
    throw new Error("Production acceptance cannot be recorded in the future.");
  }
  const replayed = await db.runTransaction(async transaction => {
    const [
      evidenceSnapshot,
      runSnapshot,
      relationshipFenceSnapshot,
      rewardFenceSnapshot,
      guardSnapshot,
      auditSnapshot,
    ] = await Promise.all([
      transaction.get(evidenceRef),
      transaction.get(runRef),
      transaction.get(relationshipFenceRef),
      transaction.get(rewardFenceRef),
      transaction.get(guardRef),
      transaction.get(auditRef),
    ]);
    if (evidenceSnapshot.exists) {
      const stored = evidenceSnapshot.data();
      try {
        assertRecordedAcceptanceEvidence(
          stored,
          auditSnapshot.exists ? auditSnapshot.data() : null,
          { acceptanceEvidenceId, migrationRunId, projectId },
        );
      } catch {
        throw new Error("Production acceptance evidence identity conflict.");
      }
      if (stored.evidenceFingerprint !== evidenceFingerprint) {
        throw new Error("Production acceptance evidence identity conflict.");
      }
      return true;
    }
    const run = runSnapshot.exists ? runSnapshot.data() : null;
    if (
      run?.type !== RELATIONSHIP_MIGRATION_RUN_TYPE ||
      run.status !== "completed"
    ) {
      throw new Error(
        "Production acceptance requires a completed Relationship migration run.",
      );
    }
    if (
      typeof run.completedAt !== "string" ||
      Number.isNaN(Date.parse(run.completedAt)) ||
      Date.parse(normalized.acceptedAt) < Date.parse(run.completedAt)
    ) {
      throw new Error(
        "Production acceptance predates the completed migration run.",
      );
    }
    if (
      relationshipFenceSnapshot.exists &&
      relationshipFenceSnapshot.data().active === true
    ) {
      throw new Error(
        "Production acceptance cannot be recorded during a Relationship cutover.",
      );
    }
    if (
      rewardFenceSnapshot.exists &&
      rewardFenceSnapshot.data().writesPaused === true
    ) {
      throw new Error(
        "Production acceptance cannot be recorded during a Reward cutover.",
      );
    }
    if (guardSnapshot.exists && guardSnapshot.data().active === true) {
      throw new Error(
        "Production acceptance cannot be recorded during a destructive operation.",
      );
    }
    if (auditSnapshot.exists) {
      throw new Error("Production acceptance audit identity conflict.");
    }
    transaction.create(evidenceRef, {
      ...normalized,
      evidenceFingerprint,
      recordAuditEventId: auditRef.id,
      recordedAt,
    });
    transaction.create(auditRef, {
      schemaVersion: 1,
      auditEventId: auditRef.id,
      category: "operations",
      action: "production.acceptance.recorded",
      actorUserId: normalized.acceptedBy,
      targetType: "production_acceptance_evidence",
      targetId: acceptanceEvidenceId,
      sourceSurface: "release_cli",
      clientRequestId: acceptanceEvidenceId,
      result: {
        evidenceFingerprint,
        relationshipMigrationRunId: migrationRunId,
      },
      createdAt: recordedAt,
    });
    return false;
  });
  return {
    acceptanceEvidenceId,
    relationshipMigrationRunId: migrationRunId,
    evidenceFingerprint,
    auditEventId: auditRef.id,
    replayed,
  };
}

export async function purgeRelationshipMigrationBeforeImages({
  migrationRunId,
  acceptanceEvidenceId,
  testFailAfterDeletes = null,
}) {
  const normalizedRunId = requiredString(migrationRunId, "Migration run id");
  const normalizedEvidenceId = requiredString(
    acceptanceEvidenceId,
    "Acceptance evidence id",
  );
  const app = await initializeAdmin();
  const db = admin.firestore();
  const projectId = projectIdFor(app);
  const runRef = db.collection("migration_runs").doc(normalizedRunId);
  const evidenceRef = db.collection(ACCEPTANCE_EVIDENCE_COLLECTION)
    .doc(normalizedEvidenceId);
  const relationshipFenceRef = db.collection("system_state")
    .doc("relationship_membership_cutover");
  const rewardFenceRef = db.collection("system_state")
    .doc("reward_ledger_cutover");
  const guardRef = db.collection("system_state").doc(GUARD_ID);
  const auditRef = db.collection("audit_events")
    .doc(`relationship-before-image-purge--${normalizedRunId}`);
  const acceptanceAuditRef = db.collection("audit_events")
    .doc(`production-acceptance-recorded--${normalizedEvidenceId}`);
  const ownerToken = randomUUID();
  const claimedAt = new Date().toISOString();
  const claim = await db.runTransaction(async transaction => {
    const [
      runSnapshot,
      evidenceSnapshot,
      relationshipFenceSnapshot,
      rewardFenceSnapshot,
      guardSnapshot,
      auditSnapshot,
      acceptanceAuditSnapshot,
    ] = await Promise.all([
      transaction.get(runRef),
      transaction.get(evidenceRef),
      transaction.get(relationshipFenceRef),
      transaction.get(rewardFenceRef),
      transaction.get(guardRef),
      transaction.get(auditRef),
      transaction.get(acceptanceAuditRef),
    ]);
    const run = runSnapshot.exists ? runSnapshot.data() : null;
    if (
      auditSnapshot.exists &&
      run?.type === RELATIONSHIP_MIGRATION_RUN_TYPE &&
      run.status === "completed" &&
      run.purgeStatus === "completed" &&
      run.purgeAcceptanceEvidenceId === normalizedEvidenceId
    ) {
      const audit = auditSnapshot.data();
      if (!evidenceSnapshot.exists) {
        throw new Error("Production acceptance evidence is missing.");
      }
      assertRecordedAcceptanceEvidence(
        evidenceSnapshot.data(),
        acceptanceAuditSnapshot.exists ? acceptanceAuditSnapshot.data() : null,
        {
          acceptanceEvidenceId: normalizedEvidenceId,
          migrationRunId: normalizedRunId,
          projectId,
        },
      );
      if (
        audit.action !== "migration.relationship_before_images.purged" ||
        audit.targetId !== normalizedRunId ||
        audit.clientRequestId !== normalizedEvidenceId ||
        !Number.isSafeInteger(audit.result?.purgedCount)
      ) {
        throw new Error("Relationship purge audit identity is invalid.");
      }
      return { replayed: true, purgedCount: audit.result.purgedCount };
    }
    if (
      run?.type !== RELATIONSHIP_MIGRATION_RUN_TYPE ||
      run.status !== "completed"
    ) {
      throw new Error("Only a completed Relationship migration run can be purged.");
    }
    if (!evidenceSnapshot.exists) {
      throw new Error("Production acceptance evidence is missing.");
    }
    assertRecordedAcceptanceEvidence(
      evidenceSnapshot.data(),
      acceptanceAuditSnapshot.exists ? acceptanceAuditSnapshot.data() : null,
      {
        acceptanceEvidenceId: normalizedEvidenceId,
        migrationRunId: normalizedRunId,
        projectId,
      },
    );
    if (
      relationshipFenceSnapshot.exists &&
      relationshipFenceSnapshot.data().active === true
    ) {
      throw new Error("Purge is blocked by an active Relationship cutover.");
    }
    if (
      rewardFenceSnapshot.exists &&
      rewardFenceSnapshot.data().writesPaused === true
    ) {
      throw new Error("Purge is blocked by an active Reward cutover.");
    }
    const guard = guardSnapshot.exists ? guardSnapshot.data() : null;
    if (
      guard?.active === true &&
      !ownsPurgeGuard(
        guard,
        normalizedRunId,
        normalizedEvidenceId,
      )
    ) {
      throw new Error("Purge is blocked by an active destructive operation.");
    }
    const expectedCount = Number.isSafeInteger(run.purgeExpectedCount)
      ? run.purgeExpectedCount
      : capturedBeforeImageCount(run);
    if (expectedCount !== capturedBeforeImageCount(run)) {
      throw new Error("Relationship purge expected count changed.");
    }
    const purgedCount = Number.isSafeInteger(run.purgedBeforeImageCount)
      ? run.purgedBeforeImageCount
      : 0;
    if (purgedCount < 0 || purgedCount > expectedCount) {
      throw new Error("Relationship purge progress is invalid.");
    }
    transaction.set(guardRef, {
      schemaVersion: 1,
      active: true,
      operationKind: "relationship_evidence_purge",
      operationId: normalizedRunId,
      acceptanceEvidenceId: normalizedEvidenceId,
      ownerToken,
      phase: "purge",
      updatedAt: claimedAt,
    }, { merge: false });
    transaction.set(runRef, {
      purgeStatus: "running",
      purgeExpectedCount: expectedCount,
      purgedBeforeImageCount: purgedCount,
      purgeAcceptanceEvidenceId: normalizedEvidenceId,
      purgeStartedAt: run.purgeStartedAt ?? claimedAt,
      purgeResumedAt: run.purgeStartedAt ? claimedAt : null,
    }, { merge: true });
    return { replayed: false, expectedCount, purgedCount };
  });
  const result = {
    migrationRunId: normalizedRunId,
    acceptanceEvidenceId: normalizedEvidenceId,
    purgedCount: claim.purgedCount,
    auditEventId: auditRef.id,
    replayed: claim.replayed,
  };
  if (claim.replayed) return result;

  try {
    const beforeSnapshot = await db.collection(BEFORE_IMAGE_COLLECTION)
      .where("migrationRunId", "==", normalizedRunId)
      .get();
    if (beforeSnapshot.size + claim.purgedCount !== claim.expectedCount) {
      throw new Error("Relationship purge before-image count mismatch.");
    }
    let deletedThisAttempt = 0;
    for (const beforeDocument of [...beforeSnapshot.docs].sort((left, right) =>
      left.id.localeCompare(right.id)
    )) {
      await db.runTransaction(async transaction => {
        const [guardSnapshot, runSnapshot, latestBefore] = await Promise.all([
          transaction.get(guardRef),
          transaction.get(runRef),
          transaction.get(beforeDocument.ref),
        ]);
        if (
          !guardSnapshot.exists ||
          !ownsPurgeGuard(
            guardSnapshot.data(),
            normalizedRunId,
            normalizedEvidenceId,
            ownerToken,
          ) ||
          !runSnapshot.exists ||
          runSnapshot.data().purgeStatus !== "running"
        ) {
          throw new Error("Relationship purge ownership changed.");
        }
        if (!latestBefore.exists) {
          throw new Error(
            `Relationship before-image disappeared: ${beforeDocument.id}`,
          );
        }
        assertBeforeImage(latestBefore, normalizedRunId);
        transaction.delete(beforeDocument.ref);
        transaction.update(runRef, {
          purgedBeforeImageCount: admin.firestore.FieldValue.increment(1),
        });
        transaction.update(guardRef, {
          updatedAt: new Date().toISOString(),
        });
      });
      deletedThisAttempt += 1;
      if (
        Number.isSafeInteger(testFailAfterDeletes) &&
        testFailAfterDeletes > 0 &&
        deletedThisAttempt >= testFailAfterDeletes
      ) {
        throw new Error(
          `Injected Relationship evidence purge failure after ` +
            `${deletedThisAttempt} deletes.`,
        );
      }
    }

    const remaining = await db.collection(BEFORE_IMAGE_COLLECTION)
      .where("migrationRunId", "==", normalizedRunId)
      .get();
    if (!remaining.empty) {
      throw new Error("Relationship purge still has before-images.");
    }
    const completedAt = new Date().toISOString();
    const purgedCount = await db.runTransaction(async transaction => {
      const [
        guardSnapshot,
        runSnapshot,
        evidenceSnapshot,
        auditSnapshot,
        acceptanceAuditSnapshot,
      ] =
        await Promise.all([
          transaction.get(guardRef),
          transaction.get(runRef),
          transaction.get(evidenceRef),
          transaction.get(auditRef),
          transaction.get(acceptanceAuditRef),
        ]);
      if (
        !guardSnapshot.exists ||
        !ownsPurgeGuard(
          guardSnapshot.data(),
          normalizedRunId,
          normalizedEvidenceId,
          ownerToken,
        ) ||
        !runSnapshot.exists
      ) {
        throw new Error("Relationship purge ownership changed before release.");
      }
      assertRecordedAcceptanceEvidence(
        evidenceSnapshot.data(),
        acceptanceAuditSnapshot.exists ? acceptanceAuditSnapshot.data() : null,
        {
          acceptanceEvidenceId: normalizedEvidenceId,
          migrationRunId: normalizedRunId,
          projectId,
        },
      );
      const run = runSnapshot.data();
      if (
        run.purgeExpectedCount !== claim.expectedCount ||
        run.purgedBeforeImageCount !== claim.expectedCount
      ) {
        throw new Error("Relationship purge final count mismatch.");
      }
      if (auditSnapshot.exists) {
        throw new Error("Relationship purge audit already exists unexpectedly.");
      }
      transaction.create(auditRef, {
        schemaVersion: 1,
        auditEventId: auditRef.id,
        category: "operations",
        action: "migration.relationship_before_images.purged",
        actorUserId: evidenceSnapshot.data().acceptedBy,
        targetType: "migration_run",
        targetId: normalizedRunId,
        sourceSurface: "release_cli",
        clientRequestId: normalizedEvidenceId,
        result: {
          acceptanceEvidenceId: normalizedEvidenceId,
          purgedCount: claim.expectedCount,
        },
        createdAt: completedAt,
      });
      transaction.set(runRef, {
        purgeStatus: "completed",
        purgedBeforeImageCount: claim.expectedCount,
        purgeAcceptanceEvidenceId: normalizedEvidenceId,
        purgeAuditEventId: auditRef.id,
        beforeImagesPurgedAt: completedAt,
      }, { merge: true });
      transaction.set(guardRef, {
        schemaVersion: 1,
        active: false,
        operationKind: null,
        operationId: null,
        acceptanceEvidenceId: null,
        ownerToken: null,
        phase: null,
        updatedAt: completedAt,
      }, { merge: false });
      return claim.expectedCount;
    });
    console.log(
      `Purged ${purgedCount} Relationship before-images for ${normalizedRunId}.`,
    );
    return { ...result, purgedCount, replayed: false };
  } catch (error) {
    await db.runTransaction(async transaction => {
      const [guardSnapshot, runSnapshot] = await Promise.all([
        transaction.get(guardRef),
        transaction.get(runRef),
      ]);
      if (
        guardSnapshot.exists &&
        ownsPurgeGuard(
          guardSnapshot.data(),
          normalizedRunId,
          normalizedEvidenceId,
          ownerToken,
        ) &&
        runSnapshot.exists
      ) {
        transaction.set(runRef, {
          purgeStatus: "failed",
          purgeError: String(error?.message || error).slice(0, 500),
          purgeFailedAt: new Date().toISOString(),
        }, { merge: true });
      }
    });
    throw error;
  }
}

function argumentValue(name) {
  const prefix = `--${name}=`;
  const argument = process.argv.find(value => value.startsWith(prefix));
  return argument?.slice(prefix.length) ?? "";
}

const isDirectRun =
  process.argv[1] &&
  import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href;

if (isDirectRun) {
  const action = process.argv.includes("--record-acceptance")
    ? Promise.resolve().then(() => {
        const manifestPath = requiredString(
          argumentValue("manifest"),
          "Acceptance manifest path",
        );
        return recordProductionAcceptanceEvidence(
          JSON.parse(fs.readFileSync(path.resolve(manifestPath), "utf8")),
        );
      })
    : purgeRelationshipMigrationBeforeImages({
        migrationRunId: argumentValue("run-id"),
        acceptanceEvidenceId: argumentValue("acceptance-evidence-id"),
      });
  action
    .then(result => console.log(JSON.stringify(result, null, 2)))
    .catch(error => {
      console.error(error.message);
      process.exitCode = 1;
    });
}
