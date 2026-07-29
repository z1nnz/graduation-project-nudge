import { HttpsError } from "firebase-functions/v2/https";

const STAFF_ROLES = new Set(["developer", "operator", "admin"]);
const CONFIRMATION = "DELETE ACCOUNT";
const EXECUTABLE_STATUSES = new Set([
  "in_review",
  "deleting",
  "deletion_failed",
]);

function normalizedString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function stableId(value, label) {
  const result = normalizedString(value);
  if (!/^[A-Za-z0-9_-]{8,128}$/.test(result)) {
    throw new HttpsError(
      "invalid-argument",
      `A stable account deletion ${label} is required.`,
    );
  }
  return result;
}

function caseId(value) {
  const result = normalizedString(value).toUpperCase();
  if (!/^CASE-\d{4}-[A-Z0-9][A-Z0-9_-]{3,63}$/.test(result)) {
    throw new HttpsError(
      "invalid-argument",
      "Account deletion requires a structured caseId.",
    );
  }
  return result;
}

function resolutionNote(value) {
  const result = normalizedString(value);
  if (result.length < 8 || result.length > 2000) {
    throw new HttpsError(
      "invalid-argument",
      "Account deletion requires an 8 to 2000 character resolutionNote.",
    );
  }
  return result;
}

function isStaff(profile) {
  return profile?.developerAccess === true ||
    STAFF_ROLES.has(normalizedString(profile?.staffRole));
}

function sortedUnique(values) {
  return [...new Set(values.filter(Boolean))].sort();
}

function otherParticipants(data, userId) {
  const memberIds = Array.isArray(data?.memberIds) ? data.memberIds : [];
  return sortedUnique(
    memberIds
      .map(value => normalizedString(value))
      .filter(value => value && value !== userId),
  );
}

export function buildAccountDeletionPlan({
  userId,
  groups = [],
  rooms = [],
  familyLinks = [],
  memberships = [],
}) {
  const blockers = [];
  const deleteOwnedGroupIds = [];
  for (const group of groups) {
    const others = otherParticipants(group.data, userId);
    if (others.length > 0) {
      blockers.push({
        code: "group_ownership_transfer_required",
        scopeType: "group",
        scopeId: group.id,
        otherParticipantCount: others.length,
      });
    } else {
      deleteOwnedGroupIds.push(group.id);
    }
  }
  const deleteOwnedRoomIds = [];
  for (const room of rooms) {
    const others = otherParticipants(room.data, userId);
    if (others.length > 0) {
      blockers.push({
        code: "room_ownership_transfer_required",
        scopeType: "room",
        scopeId: room.id,
        otherParticipantCount: others.length,
      });
    } else {
      deleteOwnedRoomIds.push(room.id);
    }
  }

  const deleteFamilyLinkIds = [];
  const redactEndedFamilyLinkIds = [];
  for (const familyLink of familyLinks) {
    const participantIds = Array.isArray(familyLink.data?.participantIds)
      ? familyLink.data.participantIds
      : [];
    const others = sortedUnique(
      participantIds
        .map(value => normalizedString(value))
        .filter(value => value && value !== userId),
    );
    if (familyLink.data?.status === "ended" && others.length > 0) {
      redactEndedFamilyLinkIds.push(familyLink.id);
    } else if (others.length > 0) {
      blockers.push({
        code: "family_relationship_resolution_required",
        scopeType: "family",
        scopeId: familyLink.id,
        otherParticipantCount: others.length,
      });
    } else {
      deleteFamilyLinkIds.push(familyLink.id);
    }
  }

  const leaveGroupIds = memberships
    .filter(item =>
      item.data?.scopeType === "group" &&
      !deleteOwnedGroupIds.includes(item.data?.scopeId)
    )
    .map(item => normalizedString(item.data?.scopeId));

  return {
    schemaVersion: 1,
    userId,
    ready: blockers.length === 0,
    blockers,
    operations: {
      deleteOwnedGroupIds: sortedUnique(deleteOwnedGroupIds),
      deleteOwnedRoomIds: sortedUnique(deleteOwnedRoomIds),
      deleteFamilyLinkIds: sortedUnique(deleteFamilyLinkIds),
      redactEndedFamilyLinkIds: sortedUnique(redactEndedFamilyLinkIds),
      leaveGroupIds: sortedUnique(leaveGroupIds),
      membershipDocumentIds: sortedUnique(memberships.map(item => item.id)),
    },
  };
}

function normalizeExecutionInput(data) {
  if (normalizedString(data?.sourceSurface) !== "admin_web") {
    throw new HttpsError(
      "invalid-argument",
      "Account deletion execution is restricted to the admin Web.",
    );
  }
  if (normalizedString(data?.confirmation) !== CONFIRMATION) {
    throw new HttpsError(
      "invalid-argument",
      `Account deletion confirmation must equal ${CONFIRMATION}.`,
    );
  }
  return {
    requestId: stableId(data?.requestId, "requestId"),
    clientRequestId: stableId(data?.clientRequestId, "clientRequestId"),
    caseId: caseId(data?.caseId),
    resolutionNote: resolutionNote(data?.resolutionNote),
    sourceSurface: "admin_web",
  };
}

function failureCode(error) {
  const code = normalizedString(error?.code).replace(/^functions\//, "");
  return new Set([
    "aborted",
    "deadline-exceeded",
    "failed-precondition",
    "resource-exhausted",
    "unavailable",
  ]).has(code)
    ? code
    : "internal";
}

export function createExecuteAccountDeletionHandler({ repository, clock }) {
  return async request => {
    const staffUserId = request.auth?.uid;
    if (!staffUserId) {
      throw new HttpsError(
        "unauthenticated",
        "Authentication is required to execute account deletion.",
      );
    }
    const input = normalizeExecutionInput(request.data);
    const staff = await repository.getStaffProfile(staffUserId);
    if (!isStaff(staff)) {
      throw new HttpsError(
        "permission-denied",
        "This account cannot execute account deletion.",
      );
    }
    const deletionRequest = await repository.getDeletionRequest(
      input.requestId,
    );
    if (
      deletionRequest?.status === "completed" &&
      deletionRequest.caseId === input.caseId &&
      normalizedString(deletionRequest.executionAuditEventId)
    ) {
      return {
        request: deletionRequest,
        auditEventId: deletionRequest.executionAuditEventId,
        replayed: true,
      };
    }
    if (
      !deletionRequest ||
      deletionRequest.type !== "account_deletion" ||
      !EXECUTABLE_STATUSES.has(deletionRequest.status)
    ) {
      throw new HttpsError(
        "failed-precondition",
        "The account deletion request is not ready for execution.",
      );
    }
    if (deletionRequest.userId === staffUserId) {
      throw new HttpsError(
        "failed-precondition",
        "Staff cannot execute their own account deletion.",
      );
    }
    const now = clock();
    const reviewAfter = Date.parse(deletionRequest.reviewAfter);
    if (!Number.isFinite(reviewAfter) || reviewAfter > now.getTime()) {
      throw new HttpsError(
        "failed-precondition",
        "The account deletion cooling period has not ended.",
      );
    }

    const inventory = await repository.collectInventory(
      deletionRequest.userId,
    );
    const plan = buildAccountDeletionPlan({
      userId: deletionRequest.userId,
      ...inventory,
    });
    if (!plan.ready) {
      await repository.recordBlockedPlan({
        request: deletionRequest,
        staffUserId,
        input,
        plan,
        now: now.toISOString(),
      });
      throw new HttpsError(
        "failed-precondition",
        "Account deletion requires ownership transfer first.",
        { blockers: plan.blockers },
      );
    }

    const claim = await repository.claimExecution({
      request: deletionRequest,
      staffUserId,
      input,
      plan,
      now: now.toISOString(),
      caseId: input.caseId,
    });
    if (claim?.replayed) return claim.result;

    try {
      try {
        await repository.freezeAuthUser(deletionRequest.userId);
      } catch (error) {
        if (!["auth/user-not-found", "user-not-found"].includes(error?.code)) {
          throw error;
        }
      }
      const claimedInventory = await repository.collectInventory(
        deletionRequest.userId,
      );
      const claimedPlan = buildAccountDeletionPlan({
        userId: deletionRequest.userId,
        ...claimedInventory,
      });
      await repository.updateClaimedPlan({
        request: deletionRequest,
        staffUserId,
        input,
        executionAttempt: claim.attemptCount,
        plan: claimedPlan,
        now: clock().toISOString(),
      });
      if (!claimedPlan.ready) {
        throw new HttpsError(
          "failed-precondition",
          "Account relationships changed during deletion claim.",
          { blockers: claimedPlan.blockers },
        );
      }
      const firstPass = await repository.eraseAccountData({
        userId: deletionRequest.userId,
        request: deletionRequest,
        staffUserId,
        input,
        plan: claimedPlan,
        now: clock().toISOString(),
      });
      const finalPass = await repository.eraseAccountData({
        userId: deletionRequest.userId,
        request: deletionRequest,
        staffUserId,
        input,
        plan: claimedPlan,
        now: clock().toISOString(),
      });
      const outcome = {
        ...firstPass,
        deletedDocuments:
          firstPass.deletedDocuments + finalPass.deletedDocuments,
        deletedScopes: [
          ...new Set([
            ...(firstPass.deletedScopes ?? []),
            ...(finalPass.deletedScopes ?? []),
          ]),
        ],
        finalDrainCompletedAt: finalPass.completedAt,
      };
      try {
        await repository.deleteAuthUser(deletionRequest.userId);
      } catch (error) {
        if (!["auth/user-not-found", "user-not-found"].includes(error?.code)) {
          throw error;
        }
      }
      const postAuthPass = await repository.eraseAccountData({
        userId: deletionRequest.userId,
        request: deletionRequest,
        staffUserId,
        input,
        plan: claimedPlan,
        now: clock().toISOString(),
      });
      outcome.deletedDocuments += postAuthPass.deletedDocuments;
      outcome.deletedScopes = [
        ...new Set([
          ...outcome.deletedScopes,
          ...(postAuthPass.deletedScopes ?? []),
        ]),
      ];
      outcome.postAuthDrainCompletedAt = postAuthPass.completedAt;
      return await repository.completeExecution({
        request: deletionRequest,
        staffUserId,
        input,
        plan: claimedPlan,
        executionAttempt: claim.attemptCount,
        outcome,
        now: clock().toISOString(),
      });
    } catch (error) {
      await repository.failExecution({
        request: deletionRequest,
        staffUserId,
        input,
        executionAttempt: claim.attemptCount,
        failureCode: failureCode(error),
        now: clock().toISOString(),
      });
      throw error;
    }
  };
}

export function createCleanupExpiredAccountDeletionEvidenceHandler({
  repository,
  clock,
}) {
  return () => repository.cleanupExpiredEvidence(clock().toISOString());
}
