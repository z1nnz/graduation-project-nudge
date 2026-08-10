import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import test from "node:test";

import { deleteApp, initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";

import { createExecuteAccountDeletionHandler } from
  "../src/account-deletion-service.js";
import { FirestoreAccountDeletionRepository } from
  "../src/firestore-account-deletion-repository.js";
import { createCancelPrivacyDataRequestHandler } from
  "../src/privacy-data-request-service.js";

const emulatorEnabled = Boolean(
  process.env.FIRESTORE_EMULATOR_HOST &&
  process.env.FIREBASE_AUTH_EMULATOR_HOST,
);
const projectId = "nudge-discipline-app";

function relationshipBeforeImageId(runId, entityPath) {
  const digest = createHash("sha256")
    .update(JSON.stringify(entityPath))
    .digest("hex");
  return `${runId}--${digest.slice(0, 32)}`;
}

test(
  "account deletion atomically records removed Relationship rollback evidence",
  { skip: !emulatorEnabled, timeout: 30_000 },
  async () => {
    const suffix = `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
    const subjectUserId = `privacy-before-image-${suffix}`;
    const requestId = `${subjectUserId}--privacy-delete-before-image-${suffix}`;
    const runId = `relationship-run-${suffix}`;
    const entityPath =
      `relationship_memberships/family--privacy--${subjectUserId}`;
    const beforeImageDocumentId = relationshipBeforeImageId(runId, entityPath);
    const app = initializeApp(
      { projectId },
      `account-deletion-before-image-${suffix}`,
    );
    const firestore = getFirestore(app);
    const repository = new FirestoreAccountDeletionRepository({
      firestore,
      auth: getAuth(app),
      bucket: null,
    });
    const plan = {
      operations: {
        leaveGroupIds: [],
        deleteOwnedRoomIds: [],
        deleteFamilyLinkIds: [],
        redactEndedFamilyLinkIds: [],
        deleteOwnedGroupIds: [],
      },
    };
    const beforeRef = firestore
      .collection("relationship_migration_before_images")
      .doc(beforeImageDocumentId);
    try {
      await Promise.all([
        firestore.collection("users").doc(subjectUserId)
          .set({ nickname: "remove" }),
        firestore.collection("migration_runs").doc(runId).set({
          type: "relationship_membership_projection_cutover",
          status: "completed",
          capturedMembershipBeforeImages: 1,
          capturedUserBeforeImages: 0,
        }),
        beforeRef.set({
          schemaVersion: 1,
          migrationRunId: runId,
          entityType: "membership",
          entityPath,
          actorUserId: subjectUserId,
          retentionPolicy: "until_fresh_install_acceptance",
        }),
      ]);

      const input = {
        userId: subjectUserId,
        request: { requestId },
        plan,
        now: "2026-08-10T00:45:00.000Z",
      };
      await repository.eraseAccountData(input);
      await repository.eraseAccountData(input);

      assert.equal((await beforeRef.get()).exists, false);
      const run = (
        await firestore.collection("migration_runs").doc(runId).get()
      ).data();
      assert.equal(run.privacyDeletedBeforeImageCount, 1);
      const evidence = (
        await firestore
          .collection("relationship_before_image_privacy_deletions")
          .doc(beforeImageDocumentId)
          .get()
      ).data();
      assert.equal(evidence.migrationRunId, runId);
      assert.equal(evidence.beforeImageId, beforeImageDocumentId);
      assert.equal(Object.hasOwn(evidence, "actorUserId"), false);
      assert.equal(Object.hasOwn(evidence, "deletionRequestId"), false);
      assert.equal(
        Object.hasOwn(evidence, "deletionRequestFingerprint"),
        false,
      );
      assert.equal(
        Object.values(evidence).some(value =>
          typeof value === "string" && value.includes(subjectUserId)
        ),
        false,
      );
    } finally {
      await Promise.all([
        firestore.collection("migration_runs").doc(runId).delete()
          .catch(() => {}),
        firestore
          .collection("relationship_before_image_privacy_deletions")
          .doc(beforeImageDocumentId)
          .delete()
          .catch(() => {}),
      ]);
      await deleteApp(app);
    }
  },
);

test(
  "account deletion executor removes Auth, Ledger and relationship data",
  { skip: !emulatorEnabled, timeout: 30_000 },
  async () => {
    const suffix = `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
    const staffUserId = `delete-staff-${suffix}`;
    const subjectUserId = `delete-subject-${suffix}`;
    const otherUserId = `delete-other-${suffix}`;
    const requestId = `${subjectUserId}--privacy-delete-001`;
    const familyLinkId = `family-delete-${suffix}`;
    const endedFamilyLinkId = `family-ended-${suffix}`;
    const groupId = `group-delete-${suffix}`;
    const roomId = `room-delete-${suffix}`;
    const leftRoomId = `room-left-${suffix}`;
    const membershipId = `group--${groupId}--${subjectUserId}`;
    const eventId = `activity-delete-${suffix}`;
    const outcomeId = `group--${groupId}`;
    const oldExportRequestId = `${subjectUserId}--privacy-export-old`;
    const oldExportAuditId = `privacy-export-audit-${suffix}`;
    const friendMessageId = `friend-message-${suffix}`;
    const notificationId = `notification-${suffix}`;
    const preservedStaffAuditId = `staff-audit-${suffix}`;
    const recipientAuditId = `recipient-audit-${suffix}`;
    const principalAuditId = `principal-audit-${suffix}`;
    const app = initializeApp(
      { projectId },
      `account-deletion-execution-${suffix}`,
    );
    const firestore = getFirestore(app);
    const auth = getAuth(app);
    try {
      await Promise.all([
        auth.createUser({ uid: staffUserId }),
        auth.createUser({ uid: subjectUserId }),
      ]);
      await Promise.all([
        firestore.collection("users").doc(staffUserId).set({
          staffRole: "operator",
        }),
        firestore.collection("users").doc(subjectUserId).set({
          nickname: "刪除對象",
        }),
        firestore.collection("public_profiles").doc(subjectUserId).set({
          userId: subjectUserId,
          nickname: "刪除對象",
        }),
        firestore.collection("privacy_data_requests").doc(requestId).set({
          schemaVersion: 1,
          requestId,
          userId: subjectUserId,
          type: "account_deletion",
          status: "in_review",
          reviewAfter: "2026-07-01T00:00:00.000Z",
          updatedAt: "2026-07-01T00:00:00.000Z",
        }),
        firestore.collection("activity_events").doc(eventId).set({
          schemaVersion: 1,
          actorUserId: subjectUserId,
        }),
        firestore.collection("activity_source_records").doc(eventId).set({
          schemaVersion: 1,
          eventPath: `activity_events/${eventId}`,
        }),
        firestore.collection("groups").doc(groupId).set({
          ownerId: otherUserId,
          memberIds: [otherUserId, subjectUserId],
          status: "active",
        }),
        firestore.collection("relationship_memberships").doc(membershipId).set({
          scopeType: "group",
          scopeId: groupId,
          userId: subjectUserId,
          role: "manager",
          status: "active",
        }),
        firestore.collection("family_links").doc(familyLinkId).set({
          participantIds: [subjectUserId],
          guardianId: subjectUserId,
          childId: subjectUserId,
          status: "active",
        }),
        firestore
          .collection("relationship_memberships")
          .doc(`family--${familyLinkId}--${subjectUserId}`)
          .set({
            scopeType: "family",
            scopeId: familyLinkId,
            userId: subjectUserId,
            role: "child",
            status: "active",
          }),
        firestore.collection("family_links").doc(endedFamilyLinkId).set({
          participantIds: [subjectUserId, otherUserId],
          guardianId: otherUserId,
          childId: subjectUserId,
          status: "ended",
        }),
        firestore
          .collection("family_links")
          .doc(endedFamilyLinkId)
          .collection("goals")
          .doc("old-goal")
          .set({
            proposedBy: otherUserId,
            decisionBy: subjectUserId,
            title: "private",
          }),
        firestore
          .collection("relationship_memberships")
          .doc(`family--${endedFamilyLinkId}--${subjectUserId}`)
          .set({
            scopeType: "family",
            scopeId: endedFamilyLinkId,
            userId: subjectUserId,
            role: "child",
            status: "ended",
          }),
        firestore
          .collection("relationship_memberships")
          .doc(`family--${endedFamilyLinkId}--${otherUserId}`)
          .set({
            scopeType: "family",
            scopeId: endedFamilyLinkId,
            userId: otherUserId,
            role: "guardian",
            status: "ended",
          }),
        firestore
          .collection("groups")
          .doc(groupId)
          .collection("member_summaries")
          .doc(subjectUserId)
          .set({
            memberId: subjectUserId,
            displayName: "刪除對象",
          }),
        firestore
          .collection("groups")
          .doc(groupId)
          .collection("challenges")
          .doc("current")
          .collection("participants")
          .doc(subjectUserId)
          .set({ memberId: subjectUserId }),
        firestore.collection("relationship_outcomes").doc(outcomeId).set({
          scopeType: "group",
          scopeId: groupId,
          participantIds: [otherUserId, subjectUserId],
        }),
        firestore
          .collection("relationship_outcomes")
          .doc(outcomeId)
          .collection("memories")
          .doc("memory-one")
          .set({ actorId: subjectUserId }),
        firestore.collection("rooms").doc(roomId).set({
          ownerId: otherUserId,
          memberIds: [otherUserId, subjectUserId],
          status: "active",
        }),
        firestore
          .collection("rooms")
          .doc(roomId)
          .collection("members")
          .doc(subjectUserId)
          .set({ memberId: subjectUserId }),
        firestore
          .collection("rooms")
          .doc(roomId)
          .collection("messages")
          .doc("message-one")
          .set({ senderId: subjectUserId, text: "private" }),
        firestore
          .collection("rooms")
          .doc(roomId)
          .collection("events")
          .doc("event-one")
          .set({ actorId: subjectUserId, text: "private" }),
        firestore
          .collection("rooms")
          .doc(roomId)
          .collection("activity_sessions")
          .doc("session-one")
          .set({ actorId: subjectUserId }),
        firestore.collection("rooms").doc(leftRoomId).set({
          ownerId: otherUserId,
          memberIds: [otherUserId],
          status: "active",
        }),
        firestore
          .collection("rooms")
          .doc(leftRoomId)
          .collection("messages")
          .doc("historical-message")
          .set({ senderId: subjectUserId, text: "historical private" }),
        firestore
          .collection("rooms")
          .doc(leftRoomId)
          .collection("events")
          .doc("historical-event")
          .set({ actorId: subjectUserId, text: "historical private" }),
        firestore.collection("friend_messages").doc(friendMessageId).set({
          senderId: subjectUserId,
          receiverId: otherUserId,
          senderName: "刪除對象",
          content: "private",
        }),
        firestore.collection("user_notifications").doc(notificationId).set({
          recipientUserId: otherUserId,
          actorUserId: subjectUserId,
          actorPrincipalId: subjectUserId,
          body: "刪除對象邀請你建立連結",
        }),
        firestore.collection("push_delivery_jobs").doc(notificationId).set({
          notificationId,
          recipientUserId: otherUserId,
          status: "pending",
        }),
        firestore.collection("privacy_export_access").doc("export-one").set({
          userId: subjectUserId,
          downloadToken: "must-be-revoked",
        }),
        firestore
          .collection("privacy_data_requests")
          .doc(oldExportRequestId)
          .set({
            schemaVersion: 1,
            requestId: oldExportRequestId,
            userId: subjectUserId,
            type: "export",
            status: "ready",
            storagePath: `privacy_exports/${subjectUserId}/old.json`,
          }),
        firestore.collection("audit_events").doc(oldExportAuditId).set({
          actorUserId: staffUserId,
          targetId: oldExportRequestId,
          action: "privacy.data.review",
        }),
        firestore.collection("audit_events").doc(preservedStaffAuditId).set({
          actorUserId: subjectUserId,
          targetId: `other-case-${suffix}`,
          action: "privacy.data.account_deletion.completed",
          sourceSurface: "admin_web",
        }),
        firestore.collection("audit_events").doc(recipientAuditId).set({
          actorUserId: otherUserId,
          actorPrincipalId: otherUserId,
          result: { recipientUserId: subjectUserId },
          action: "relationship.family.invitation.created",
        }),
        firestore.collection("audit_events").doc(principalAuditId).set({
          actorUserId: otherUserId,
          actorPrincipalId: subjectUserId,
          result: { recipientUserId: otherUserId },
          action: "relationship.family.invitation.accepted",
        }),
      ]);

      const handler = createExecuteAccountDeletionHandler({
        repository: new FirestoreAccountDeletionRepository({
          firestore,
          auth,
          bucket: null,
        }),
        clock: () => new Date("2026-08-06T00:00:00.000Z"),
      });
      const result = await handler({
        auth: { uid: staffUserId },
        data: {
          requestId,
          clientRequestId: "privacy-execute-integration-001",
          sourceSurface: "admin_web",
          caseId: "CASE-2026-INTEG1",
          resolutionNote: "已完成整合測試刪除前核對",
          confirmation: "DELETE ACCOUNT",
        },
      });

      assert.equal(result.request.status, "completed");
      await assert.rejects(
        () => auth.getUser(subjectUserId),
        error => error.code === "auth/user-not-found",
      );
      for (const path of [
        `users/${subjectUserId}`,
        `public_profiles/${subjectUserId}`,
        `activity_events/${eventId}`,
        `activity_source_records/${eventId}`,
        `family_links/${familyLinkId}`,
        `relationship_memberships/${membershipId}`,
        `relationship_memberships/family--${familyLinkId}--${subjectUserId}`,
        `relationship_memberships/family--${endedFamilyLinkId}--${subjectUserId}`,
        `family_links/${endedFamilyLinkId}/goals/old-goal`,
        `groups/${groupId}/member_summaries/${subjectUserId}`,
        `groups/${groupId}/challenges/current/participants/${subjectUserId}`,
        `relationship_outcomes/${outcomeId}`,
        `rooms/${roomId}/members/${subjectUserId}`,
        `rooms/${roomId}/messages/message-one`,
        `rooms/${roomId}/events/event-one`,
        `rooms/${roomId}/activity_sessions/session-one`,
        `rooms/${leftRoomId}/messages/historical-message`,
        `rooms/${leftRoomId}/events/historical-event`,
        `friend_messages/${friendMessageId}`,
        `user_notifications/${notificationId}`,
        `push_delivery_jobs/${notificationId}`,
        "privacy_export_access/export-one",
        `privacy_data_requests/${oldExportRequestId}`,
        `audit_events/${oldExportAuditId}`,
        `audit_events/${recipientAuditId}`,
        `audit_events/${principalAuditId}`,
      ]) {
        assert.equal((await firestore.doc(path).get()).exists, false, path);
      }
      assert.deepEqual(
        (await firestore.collection("groups").doc(groupId).get()).data().memberIds,
        [otherUserId],
      );
      assert.deepEqual(
        (await firestore.collection("rooms").doc(roomId).get()).data().memberIds,
        [otherUserId],
      );
      const endedFamilyLink = (
        await firestore.collection("family_links").doc(endedFamilyLinkId).get()
      ).data();
      assert.deepEqual(endedFamilyLink.participantIds, [otherUserId]);
      assert.equal(endedFamilyLink.childId, "");
      assert.equal(
        (
          await firestore
            .collection("relationship_memberships")
            .doc(`family--${endedFamilyLinkId}--${otherUserId}`)
            .get()
        ).exists,
        true,
      );
      const tombstone = (
        await firestore.collection("privacy_data_requests").doc(requestId).get()
      ).data();
      assert.equal(tombstone.status, "completed");
      assert.equal("userId" in tombstone, false);
      assert.match(tombstone.retentionExpiresAt, /^2027-/);
      assert.equal(
        (
          await firestore
            .collection("account_deletion_fences")
            .doc(subjectUserId)
            .get()
        ).data().status,
        "completed",
      );
      assert.equal(
        (
          await firestore
            .collection("audit_events")
            .doc(result.auditEventId)
            .get()
        ).data().action,
        "privacy.data.account_deletion.completed",
      );
      assert.equal(
        (
          await firestore
            .collection("audit_events")
            .doc(preservedStaffAuditId)
            .get()
        ).exists,
        true,
      );
      assert.equal((await auth.getUser(staffUserId)).uid, staffUserId);
    } finally {
      await auth.deleteUser(staffUserId).catch(() => {});
      await deleteApp(app);
    }
  },
);

test(
  "stale deletion leases are reclaimable and partial failures cannot cancel",
  { skip: !emulatorEnabled, timeout: 30_000 },
  async () => {
    const suffix = `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
    const staffUserId = `lease-staff-${suffix}`;
    const subjectUserId = `lease-subject-${suffix}`;
    const requestId = `${subjectUserId}--privacy-delete-001`;
    const clientRequestId = "privacy-execute-lease-001";
    const executionId = `${staffUserId}--${clientRequestId}`;
    const app = initializeApp(
      { projectId },
      `account-deletion-lease-${suffix}`,
    );
    const firestore = getFirestore(app);
    const auth = getAuth(app);
    const repository = new FirestoreAccountDeletionRepository({
      firestore,
      auth,
      bucket: null,
    });
    const input = {
      clientRequestId,
      sourceSurface: "admin_web",
      caseId: "CASE-2026-LEASE1",
      resolutionNote: "重新接管逾時的正式刪除工作",
    };
    const plan = {
      schemaVersion: 1,
      userId: subjectUserId,
      ready: true,
      blockers: [],
      operations: {
        deleteOwnedGroupIds: [],
        deleteOwnedRoomIds: [],
        deleteFamilyLinkIds: [],
        leaveGroupIds: [],
        membershipDocumentIds: [],
      },
    };
    try {
      await firestore.collection("privacy_data_requests").doc(requestId).set({
        schemaVersion: 1,
        requestId,
        userId: subjectUserId,
        type: "account_deletion",
        status: "deleting",
        caseId: input.caseId,
        activeDeletionExecutionId: executionId,
        activeDeletionAttempt: 1,
        executionLeaseExpiresAt: "2026-08-06T00:10:00.000Z",
      });
      await firestore
        .collection("account_deletion_executions")
        .doc(executionId)
        .set({
        executionId,
        actorUserId: staffUserId,
        targetId: requestId,
        subjectUserId,
        caseId: input.caseId,
        status: "executing",
        attemptCount: 1,
      });

      await assert.rejects(
        () =>
          repository.claimExecution({
            request: { requestId, userId: subjectUserId },
            staffUserId,
            input,
            plan,
            now: "2026-08-06T00:05:00.000Z",
            caseId: input.caseId,
          }),
        error => error.code === "aborted",
      );

      await firestore.collection("system_state")
        .doc("relationship_membership_cutover")
        .set({ active: true, runId: `relationship-${suffix}` });
      await assert.rejects(
        () =>
          repository.claimExecution({
            request: { requestId, userId: subjectUserId },
            staffUserId,
            input,
            plan,
            now: "2026-08-06T00:11:00.000Z",
            caseId: input.caseId,
          }),
        error => error.code === "aborted",
      );
      await firestore.collection("system_state")
        .doc("relationship_membership_cutover")
        .delete();

      await firestore.collection("system_state")
        .doc("reward_ledger_cutover")
        .set({ writesPaused: true, runId: `reward-${suffix}` });
      await assert.rejects(
        () =>
          repository.claimExecution({
            request: { requestId, userId: subjectUserId },
            staffUserId,
            input,
            plan,
            now: "2026-08-06T00:11:00.000Z",
            caseId: input.caseId,
          }),
        error => error.code === "aborted",
      );
      await firestore.collection("system_state")
        .doc("reward_ledger_cutover")
        .delete();

      await firestore
        .collection("account_operation_leases")
        .doc(subjectUserId)
        .set({
          operations: {
            "active-operation": "2026-08-06T00:12:00.000Z",
          },
        });
      await assert.rejects(
        () =>
          repository.claimExecution({
            request: { requestId, userId: subjectUserId },
            staffUserId,
            input,
            plan,
            now: "2026-08-06T00:11:00.000Z",
            caseId: input.caseId,
          }),
        error => error.code === "aborted",
      );
      await firestore
        .collection("account_operation_leases")
        .doc(subjectUserId)
        .delete();
      await firestore
        .collection("push_delivery_leases")
        .doc(subjectUserId)
        .set({
          jobId: "push-in-flight",
          leaseUntil: "2026-08-06T00:12:00.000Z",
        });
      await assert.rejects(
        () =>
          repository.claimExecution({
            request: { requestId, userId: subjectUserId },
            staffUserId,
            input,
            plan,
            now: "2026-08-06T00:11:00.000Z",
            caseId: input.caseId,
          }),
        error => error.code === "aborted",
      );
      await firestore
        .collection("push_delivery_leases")
        .doc(subjectUserId)
        .delete();
      await firestore
        .collection("account_deletion_fences")
        .doc(subjectUserId)
        .set({
          requestId: "another-account-deletion-request",
          executionId: "another-execution",
          status: "deleting",
        });
      await assert.rejects(
        () =>
          repository.claimExecution({
            request: { requestId, userId: subjectUserId },
            staffUserId,
            input,
            plan,
            now: "2026-08-06T00:11:00.000Z",
            caseId: input.caseId,
          }),
        error => error.code === "failed-precondition",
      );
      await firestore
        .collection("account_deletion_fences")
        .doc(subjectUserId)
        .delete();

      const claim = await repository.claimExecution({
        request: { requestId, userId: subjectUserId },
        staffUserId,
        input,
        plan,
        now: "2026-08-06T00:11:00.000Z",
        caseId: input.caseId,
      });
      assert.equal(claim.replayed, false);
      assert.equal(
        (
          await firestore
            .collection("account_deletion_executions")
            .doc(executionId)
            .get()
        )
          .data().attemptCount,
        2,
      );
      const attemptAuditRef = firestore
        .collection("audit_events")
        .doc(
          `privacy-delete-attempt--${staffUserId}--${clientRequestId}--2`,
        );
      const attemptAuditBeforeFailure = (await attemptAuditRef.get()).data();
      assert.equal(
        attemptAuditBeforeFailure.action,
        "privacy.data.account_deletion.attempt_started",
      );

      await repository.failExecution({
        request: { requestId, userId: subjectUserId },
        staffUserId,
        input,
        executionAttempt: 2,
        failureCode: "unavailable",
        now: "2026-08-06T00:12:00.000Z",
      });
      assert.equal(
        (
          await firestore.collection("privacy_data_requests").doc(requestId).get()
        ).data().status,
        "deletion_failed",
      );
      assert.deepEqual(
        (await attemptAuditRef.get()).data(),
        attemptAuditBeforeFailure,
      );
      assert.equal(
        (
          await firestore
            .collection("audit_events")
            .doc(
              `privacy-delete-failed--${staffUserId}--` +
                `${clientRequestId}--2`,
            )
            .get()
        ).data().action,
        "privacy.data.account_deletion.failed",
      );
      assert.equal(
        (
          await firestore
            .collection("account_deletion_fences")
            .doc(subjectUserId)
            .get()
        ).data().status,
        "deletion_failed",
      );

      const cancel = createCancelPrivacyDataRequestHandler({
        firestore,
        clock: () => new Date("2026-08-06T00:13:00.000Z"),
      });
      await assert.rejects(
        () =>
          cancel({
            auth: { uid: subjectUserId },
            data: {
              requestId,
              clientRequestId: "privacy-cancel-after-failure-001",
              sourceSurface: "app",
            },
          }),
        error => error.code === "failed-precondition",
      );
    } finally {
      await firestore.collection("privacy_data_requests").doc(requestId)
        .delete().catch(() => {});
      await firestore.collection("account_deletion_executions").doc(executionId)
        .delete().catch(() => {});
      await firestore.collection("account_deletion_fences").doc(subjectUserId)
        .delete().catch(() => {});
      await deleteApp(app);
    }
  },
);

test(
  "owned scopes are revalidated before recursive deletion",
  { skip: !emulatorEnabled, timeout: 30_000 },
  async () => {
    const suffix = `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
    const subjectUserId = `race-subject-${suffix}`;
    const otherUserId = `race-other-${suffix}`;
    const groupId = `race-group-${suffix}`;
    const app = initializeApp(
      { projectId },
      `account-deletion-race-${suffix}`,
    );
    const firestore = getFirestore(app);
    const repository = new FirestoreAccountDeletionRepository({
      firestore,
      auth: getAuth(app),
      bucket: null,
    });
    await firestore.collection("groups").doc(groupId).set({
      ownerId: subjectUserId,
      memberIds: [subjectUserId, otherUserId],
      status: "active",
    });
    try {
      await assert.rejects(
        () =>
          repository.eraseAccountData({
            userId: subjectUserId,
            request: { requestId: "privacy-delete-race-001" },
            plan: {
              operations: {
                deleteOwnedGroupIds: [groupId],
                deleteOwnedRoomIds: [],
                deleteFamilyLinkIds: [],
                leaveGroupIds: [],
              },
            },
            now: "2026-08-06T00:00:00.000Z",
          }),
        error => error.code === "failed-precondition",
      );
      assert.equal(
        (await firestore.collection("groups").doc(groupId).get()).exists,
        true,
      );
    } finally {
      await firestore.recursiveDelete(
        firestore.collection("groups").doc(groupId),
      );
      await deleteApp(app);
    }
  },
);

test(
  "deletion fence blocks an existing client token and Auth is disabled",
  { skip: !emulatorEnabled, timeout: 30_000 },
  async () => {
    const suffix = `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
    const email = `fenced-${suffix}@example.test`;
    const password = "correct-horse-battery-staple";
    const signUpResponse = await fetch(
      `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}` +
        "/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-key",
      {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ email, password, returnSecureToken: true }),
      },
    );
    assert.equal(signUpResponse.status, 200);
    const account = await signUpResponse.json();
    const app = initializeApp(
      { projectId },
      `account-deletion-fence-${suffix}`,
    );
    const firestore = getFirestore(app);
    const auth = getAuth(app);
    const repository = new FirestoreAccountDeletionRepository({
      firestore,
      auth,
      bucket: null,
    });
    const documentUrl =
      `http://${process.env.FIRESTORE_EMULATOR_HOST}/v1/projects/${projectId}` +
      `/databases/(default)/documents/users/${account.localId}`;
    try {
      await firestore.collection("users").doc(account.localId).set({
        nickname: "before",
      });
      let response = await fetch(documentUrl, {
        headers: { authorization: `Bearer ${account.idToken}` },
      });
      assert.equal(response.status, 200);

      await firestore
        .collection("account_deletion_fences")
        .doc(account.localId)
        .set({ status: "deleting" });
      response = await fetch(documentUrl, {
        method: "PATCH",
        headers: {
          authorization: `Bearer ${account.idToken}`,
          "content-type": "application/json",
        },
        body: JSON.stringify({
          fields: { nickname: { stringValue: "after" } },
        }),
      });
      assert.equal(response.status, 403);

      await repository.freezeAuthUser(account.localId);
      const signInResponse = await fetch(
        `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}` +
          "/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword" +
          "?key=fake-key",
        {
          method: "POST",
          headers: { "content-type": "application/json" },
          body: JSON.stringify({ email, password, returnSecureToken: true }),
        },
      );
      assert.equal(signInResponse.status, 400);
      assert.match(await signInResponse.text(), /USER_DISABLED/);
    } finally {
      await auth.deleteUser(account.localId).catch(() => {});
      await deleteApp(app);
    }
  },
);

test(
  "expired account deletion evidence and request-targeted audits are purged",
  { skip: !emulatorEnabled, timeout: 30_000 },
  async () => {
    const suffix = `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
    const requestId = `expired-delete-${suffix}`;
    const auditId = `expired-delete-audit-${suffix}`;
    const subjectUserId = `expired-subject-${suffix}`;
    const executionId = `expired-execution-${suffix}`;
    const app = initializeApp(
      { projectId },
      `account-deletion-retention-${suffix}`,
    );
    const firestore = getFirestore(app);
    const repository = new FirestoreAccountDeletionRepository({
      firestore,
      auth: getAuth(app),
      bucket: null,
    });
    await Promise.all([
      firestore.collection("privacy_data_requests").doc(requestId).set({
        schemaVersion: 1,
        requestId,
        type: "account_deletion",
        status: "completed",
        retentionExpiresAt: "2026-08-01T00:00:00.000Z",
      }),
      firestore.collection("audit_events").doc(auditId).set({
        targetId: requestId,
        action: "privacy.data.account_deletion.execute",
      }),
      firestore.collection("account_deletion_executions").doc(executionId).set({
        targetId: requestId,
        subjectUserId,
        status: "completed",
      }),
      firestore.collection("account_deletion_fences").doc(subjectUserId).set({
        requestId,
        executionId,
        status: "completed",
      }),
    ]);
    try {
      const result = await repository.cleanupExpiredEvidence(
        "2026-08-06T00:00:00.000Z",
      );
      assert.deepEqual(result, {
        deletedRequests: 1,
        deletedAudits: 1,
        deletedExecutions: 1,
        deletedFences: 1,
      });
      assert.equal(
        (
          await firestore.collection("privacy_data_requests").doc(requestId).get()
        ).exists,
        false,
      );
      assert.equal(
        (await firestore.collection("audit_events").doc(auditId).get()).exists,
        false,
      );
      assert.equal(
        (
          await firestore
            .collection("account_deletion_executions")
            .doc(executionId)
            .get()
        ).exists,
        false,
      );
      assert.equal(
        (
          await firestore
            .collection("account_deletion_fences")
            .doc(subjectUserId)
            .get()
        ).exists,
        false,
      );
    } finally {
      await deleteApp(app);
    }
  },
);
