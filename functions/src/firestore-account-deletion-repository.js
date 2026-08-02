import { FieldPath } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";

const PAGE_SIZE = 400;
const EXECUTION_LEASE_MS = 15 * 60 * 1000;
const EVIDENCE_RETENTION_MS = 365 * 24 * 60 * 60 * 1000;

async function querySnapshots(query) {
  const documents = [];
  let cursor = null;
  while (true) {
    let page = query.orderBy(FieldPath.documentId()).limit(PAGE_SIZE);
    if (cursor) page = page.startAfter(cursor);
    const snapshot = await page.get();
    documents.push(...snapshot.docs);
    if (snapshot.size < PAGE_SIZE) break;
    cursor = snapshot.docs.at(-1);
  }
  return documents;
}

function exportSnapshots(documents) {
  return documents.map(document => ({
    id: document.id,
    data: document.data(),
  }));
}

async function deleteReferences(firestore, references) {
  if (references.length === 0) return 0;
  const writer = firestore.bulkWriter();
  for (const reference of references) writer.delete(reference);
  await writer.close();
  return references.length;
}

async function deleteQuery(firestore, query) {
  const documents = await querySnapshots(query);
  return deleteReferences(
    firestore,
    documents.map(document => document.ref),
  );
}

function withoutUser(values, userId) {
  return [...new Set(
    (Array.isArray(values) ? values : [])
      .filter(value => typeof value === "string" && value !== userId),
  )];
}

function otherParticipants(values, userId) {
  return withoutUser(values, userId);
}

function laterIso(now, milliseconds) {
  return new Date(Date.parse(now) + milliseconds).toISOString();
}

function hasActiveAccountOperation(lease, now) {
  const nowMillis = Date.parse(now);
  return Object.values(lease?.operations ?? {})
    .some(value => Date.parse(value) > nowMillis);
}

function hasActivePushDelivery(lease, now) {
  return Date.parse(lease?.leaseUntil) > Date.parse(now);
}

export class FirestoreAccountDeletionRepository {
  constructor({ firestore, auth, bucket }) {
    this.firestore = firestore;
    this.auth = auth;
    this.bucket = bucket;
  }

  async getStaffProfile(staffUserId) {
    const snapshot = await this.firestore.collection("users").doc(staffUserId).get();
    return snapshot.exists ? snapshot.data() : null;
  }

  async getDeletionRequest(requestId) {
    const snapshot = await this.firestore
      .collection("privacy_data_requests")
      .doc(requestId)
      .get();
    return snapshot.exists ? snapshot.data() : null;
  }

  async collectInventory(userId) {
    const [groups, rooms, familyLinks, memberships] = await Promise.all([
      querySnapshots(
        this.firestore.collection("groups").where("ownerId", "==", userId),
      ),
      querySnapshots(
        this.firestore.collection("rooms").where("ownerId", "==", userId),
      ),
      querySnapshots(
        this.firestore
          .collection("family_links")
          .where("participantIds", "array-contains", userId),
      ),
      querySnapshots(
        this.firestore
          .collection("relationship_memberships")
          .where("userId", "==", userId),
      ),
    ]);
    return {
      groups: exportSnapshots(groups),
      rooms: exportSnapshots(rooms),
      familyLinks: exportSnapshots(familyLinks),
      memberships: exportSnapshots(memberships),
    };
  }

  async recordBlockedPlan({ request, staffUserId, input, plan, now }) {
    const requestRef = this.firestore
      .collection("privacy_data_requests")
      .doc(request.requestId);
    const auditRef = this.firestore
      .collection("audit_events")
      .doc(`privacy-delete-blocked--${staffUserId}--${input.clientRequestId}`);
    await this.firestore.runTransaction(async transaction => {
      const [currentSnapshot, auditSnapshot] = await Promise.all([
        transaction.get(requestRef),
        transaction.get(auditRef),
      ]);
      if (
        !currentSnapshot.exists ||
        !["in_review", "deletion_failed"].includes(
          currentSnapshot.data().status,
        )
      ) {
        throw new HttpsError(
          "failed-precondition",
          "The account deletion request changed before blocker recording.",
        );
      }
      if (auditSnapshot.exists) {
        const audit = auditSnapshot.data();
        if (
          audit.actorUserId !== staffUserId ||
          audit.targetId !== request.requestId
        ) {
          throw new HttpsError(
            "already-exists",
            "The account deletion clientRequestId was already used.",
          );
        }
        return;
      }
      transaction.update(requestRef, {
        deletionPlan: plan,
        deletionPlanGeneratedAt: now,
        updatedAt: now,
      });
      transaction.create(auditRef, {
        schemaVersion: 1,
        auditEventId: auditRef.id,
        category: "privacy",
        action: "privacy.data.account_deletion.blocked",
        actorUserId: staffUserId,
        targetType: "privacy_data_request",
        targetId: request.requestId,
        sourceSurface: input.sourceSurface,
        clientRequestId: input.clientRequestId,
        result: { blockers: plan.blockers },
        createdAt: now,
      });
    });
  }

  async claimExecution({
    request,
    staffUserId,
    input,
    plan,
    now,
    caseId,
  }) {
    const requestRef = this.firestore
      .collection("privacy_data_requests")
      .doc(request.requestId);
    const executionRef = this.firestore
      .collection("account_deletion_executions")
      .doc(`${staffUserId}--${input.clientRequestId}`);
    const fenceRef = this.firestore
      .collection("account_deletion_fences")
      .doc(request.userId);
    const operationLeaseRef = this.firestore
      .collection("account_operation_leases")
      .doc(request.userId);
    const pushDeliveryLeaseRef = this.firestore
      .collection("push_delivery_leases")
      .doc(request.userId);
    const leaseExpiresAt = laterIso(now, EXECUTION_LEASE_MS);
    return this.firestore.runTransaction(async transaction => {
      const [
        currentSnapshot,
        executionSnapshot,
        fenceSnapshot,
        operationLeaseSnapshot,
        pushDeliveryLeaseSnapshot,
      ] = await Promise.all([
        transaction.get(requestRef),
        transaction.get(executionRef),
        transaction.get(fenceRef),
        transaction.get(operationLeaseRef),
        transaction.get(pushDeliveryLeaseRef),
      ]);
      if (
        fenceSnapshot.exists &&
        fenceSnapshot.data().requestId !== request.requestId
      ) {
        throw new HttpsError(
          "failed-precondition",
          "Another verified deletion request already owns this account.",
        );
      }
      if (hasActiveAccountOperation(operationLeaseSnapshot.data(), now)) {
        throw new HttpsError(
          "aborted",
          "The account still has an active Cloud operation.",
        );
      }
      if (hasActivePushDelivery(pushDeliveryLeaseSnapshot.data(), now)) {
        throw new HttpsError(
          "aborted",
          "The account still has an active push delivery.",
        );
      }
      if (executionSnapshot.exists) {
        const execution = executionSnapshot.data();
        if (
          execution.actorUserId !== staffUserId ||
          execution.targetId !== request.requestId ||
          execution.caseId !== caseId
        ) {
          throw new HttpsError(
            "already-exists",
            "The account deletion clientRequestId was already used.",
          );
        }
        if (execution.status === "completed") {
          return { replayed: true, result: execution.result ?? null };
        }
      }
      const current = currentSnapshot.exists ? currentSnapshot.data() : null;
      if (
        !current ||
        !["in_review", "deletion_failed", "deleting"].includes(current.status)
      ) {
        throw new HttpsError(
          "failed-precondition",
          "The account deletion request changed before execution.",
        );
      }
      if (
        current.status === "deleting" &&
        Date.parse(current.executionLeaseExpiresAt) > Date.parse(now)
      ) {
        throw new HttpsError(
          "aborted",
          "Another account deletion worker still owns the execution lease.",
        );
      }
      const previousAttemptCount = executionSnapshot.exists
        ? executionSnapshot.data().attemptCount ?? 0
        : 0;
      const attemptCount = previousAttemptCount + 1;
      const attemptAuditRef = this.firestore
        .collection("audit_events")
        .doc(
          `privacy-delete-attempt--${staffUserId}--` +
            `${input.clientRequestId}--${attemptCount}`,
        );
      transaction.delete(operationLeaseRef);
      transaction.delete(pushDeliveryLeaseRef);
      transaction.update(requestRef, {
        status: "deleting",
        caseId,
        resolutionNote: input.resolutionNote,
        deletionPlan: plan,
        deletionStartedAt: now,
        executionLeaseExpiresAt: leaseExpiresAt,
        activeDeletionExecutionId: executionRef.id,
        activeDeletionAttempt: attemptCount,
        assignedStaffUserId: staffUserId,
        executionFailureCode: null,
        updatedAt: now,
      });
      transaction.set(fenceRef, {
        schemaVersion: 1,
        status: "deleting",
        requestId: request.requestId,
        executionId: executionRef.id,
        caseId,
        leaseExpiresAt,
        updatedAt: now,
        createdAt: fenceSnapshot.exists
          ? fenceSnapshot.data().createdAt ?? now
          : now,
      }, { merge: false });
      if (executionSnapshot.exists) {
        transaction.update(executionRef, {
          status: "executing",
          resolutionNote: input.resolutionNote,
          attemptCount,
          leaseExpiresAt,
          failureCode: null,
          updatedAt: now,
        });
      } else {
        transaction.create(executionRef, {
          schemaVersion: 1,
          executionId: executionRef.id,
          actorUserId: staffUserId,
          targetId: request.requestId,
          subjectUserId: request.userId,
          sourceSurface: input.sourceSurface,
          clientRequestId: input.clientRequestId,
          caseId,
          resolutionNote: input.resolutionNote,
          status: "executing",
          attemptCount,
          leaseExpiresAt,
          createdAt: now,
          updatedAt: now,
        });
      }
      transaction.create(attemptAuditRef, {
        schemaVersion: 1,
        auditEventId: attemptAuditRef.id,
        category: "privacy",
        action: "privacy.data.account_deletion.attempt_started",
        actorUserId: staffUserId,
        targetType: "privacy_data_request",
        targetId: request.requestId,
        sourceSurface: input.sourceSurface,
        clientRequestId: input.clientRequestId,
        caseId,
        result: { attemptCount, leaseExpiresAt },
        createdAt: now,
      });
      return {
        replayed: false,
        attemptCount,
        executionId: executionRef.id,
      };
    });
  }

  async updateClaimedPlan({
    request,
    staffUserId,
    input,
    executionAttempt,
    plan,
    now,
  }) {
    const requestRef = this.firestore
      .collection("privacy_data_requests")
      .doc(request.requestId);
    const executionRef = this.firestore
      .collection("account_deletion_executions")
      .doc(`${staffUserId}--${input.clientRequestId}`);
    const fenceRef = this.firestore
      .collection("account_deletion_fences")
      .doc(request.userId);
    await this.firestore.runTransaction(async transaction => {
      const [current, execution, fence] = await Promise.all([
        transaction.get(requestRef),
        transaction.get(executionRef),
        transaction.get(fenceRef),
      ]);
      if (
        !current.exists ||
        current.data().status !== "deleting" ||
        current.data().activeDeletionExecutionId !== executionRef.id ||
        current.data().activeDeletionAttempt !== executionAttempt ||
        !execution.exists ||
        execution.data().status !== "executing" ||
        execution.data().attemptCount !== executionAttempt ||
        !fence.exists ||
        fence.data().requestId !== request.requestId ||
        fence.data().executionId !== executionRef.id
      ) {
        throw new HttpsError(
          "failed-precondition",
          "The account deletion execution lease is no longer owned.",
        );
      }
      transaction.update(requestRef, {
        deletionPlan: plan,
        deletionPlanGeneratedAt: now,
        updatedAt: now,
      });
      transaction.update(executionRef, {
        deletionPlan: plan,
        updatedAt: now,
      });
    });
  }

  async eraseAccountData({ userId, request, plan, now }) {
    let deletedDocuments = 0;
    const deletedScopes = [];

    for (const [collection, field] of [
      ["messages", "senderId"],
      ["events", "actorId"],
      ["activity_sessions", "actorId"],
    ]) {
      deletedDocuments += await deleteQuery(
        this.firestore,
        this.firestore.collectionGroup(collection).where(field, "==", userId),
      );
    }

    for (const groupId of plan.operations.leaveGroupIds) {
      const ref = this.firestore.collection("groups").doc(groupId);
      const summaryRef = ref.collection("member_summaries").doc(userId);
      const participationRef = ref
        .collection("challenges")
        .doc("current")
        .collection("participants")
        .doc(userId);
      await this.firestore.runTransaction(async transaction => {
        const snapshot = await transaction.get(ref);
        if (!snapshot.exists) {
          transaction.delete(summaryRef);
          transaction.delete(participationRef);
          return;
        }
        const data = snapshot.data();
        if (data.ownerId === userId) {
          throw new HttpsError(
            "failed-precondition",
            "Group ownership changed; regenerate the deletion plan.",
          );
        }
        transaction.update(ref, {
          memberIds: withoutUser(data.memberIds, userId),
          updatedAt: now,
        });
        transaction.delete(summaryRef);
        transaction.delete(participationRef);
      });
      deletedDocuments += 2;
      deletedDocuments += await this.#deleteRelationshipOutcomes(
        "group",
        groupId,
      );
    }

    const joinedRooms = await querySnapshots(
      this.firestore.collection("rooms").where(
        "memberIds",
        "array-contains",
        userId,
      ),
    );
    for (const room of joinedRooms) {
      if (plan.operations.deleteOwnedRoomIds.includes(room.id)) continue;
      await this.firestore.runTransaction(async transaction => {
        const current = await transaction.get(room.ref);
        if (!current.exists) return;
        const data = current.data();
        if (data.ownerId === userId) {
          throw new HttpsError(
            "failed-precondition",
            "Room ownership changed; regenerate the deletion plan.",
          );
        }
        transaction.update(room.ref, {
          memberIds: withoutUser(data.memberIds, userId),
          updatedAt: now,
        });
        transaction.delete(room.ref.collection("members").doc(userId));
        transaction.delete(room.ref.collection("participants").doc(userId));
      });
    }

    for (const familyLinkId of plan.operations.deleteFamilyLinkIds) {
      await this.#lockFamilyLinkForDeletion(familyLinkId, userId, now);
      deletedDocuments += await this.#deleteScopeMemberships(
        "family",
        familyLinkId,
      );
      deletedDocuments += await this.#deleteRelationshipOutcomes(
        "family",
        familyLinkId,
      );
      await this.firestore.recursiveDelete(
        this.firestore.collection("family_links").doc(familyLinkId),
      );
      deletedScopes.push(`family:${familyLinkId}`);
    }
    for (const familyLinkId of
      plan.operations.redactEndedFamilyLinkIds ?? []) {
      deletedDocuments += await this.#redactEndedFamilyLink(
        familyLinkId,
        userId,
        now,
      );
      deletedScopes.push(`family-redacted:${familyLinkId}`);
    }
    for (const groupId of plan.operations.deleteOwnedGroupIds) {
      await this.#lockOwnedScopeForDeletion("groups", groupId, userId, now);
      deletedDocuments += await this.#deleteScopeMemberships("group", groupId);
      deletedDocuments += await this.#deleteRelationshipOutcomes(
        "group",
        groupId,
      );
      await this.firestore.recursiveDelete(
        this.firestore.collection("groups").doc(groupId),
      );
      deletedScopes.push(`group:${groupId}`);
    }
    for (const roomId of plan.operations.deleteOwnedRoomIds) {
      await this.#lockOwnedScopeForDeletion("rooms", roomId, userId, now);
      await this.firestore.recursiveDelete(
        this.firestore.collection("rooms").doc(roomId),
      );
      deletedScopes.push(`room:${roomId}`);
    }

    const eventDocuments = await querySnapshots(
      this.firestore
        .collection("activity_events")
        .where("actorUserId", "==", userId),
    );
    for (const event of eventDocuments) {
      for (const collection of [
        "activity_source_records",
        "activity_settlements",
      ]) {
        deletedDocuments += await deleteQuery(
          this.firestore,
          this.firestore
            .collection(collection)
            .where("eventPath", "==", event.ref.path),
        );
      }
    }

    const personalPrivacyRequests = await querySnapshots(
      this.firestore
        .collection("privacy_data_requests")
        .where("userId", "==", userId),
    );
    for (const personalRequest of personalPrivacyRequests) {
      if (personalRequest.id === request.requestId) continue;
      deletedDocuments += await deleteQuery(
        this.firestore,
        this.firestore
          .collection("audit_events")
          .where("targetId", "==", personalRequest.id),
      );
      await personalRequest.ref.delete();
      deletedDocuments += 1;
    }

    const authoredNotifications = [];
    for (const field of ["actorUserId", "actorPrincipalId"]) {
      authoredNotifications.push(
        ...await querySnapshots(
          this.firestore
            .collection("user_notifications")
            .where(field, "==", userId),
        ),
      );
    }
    deletedDocuments += await deleteReferences(
      this.firestore,
      [...new Set(authoredNotifications.map(document => document.id))]
        .map(notificationId =>
          this.firestore.collection("push_delivery_jobs").doc(notificationId)
        ),
    );

    const actorAudits = await querySnapshots(
      this.firestore
        .collection("audit_events")
        .where("actorUserId", "==", userId),
    );
    deletedDocuments += await deleteReferences(
      this.firestore,
      actorAudits
        .filter(document => document.data().sourceSurface !== "admin_web")
        .map(document => document.ref),
    );

    const querySpecs = [
      ["activity_events", "actorUserId"],
      ["activity_receipts", "actorUserId"],
      ["reward_ledger_entries", "actorUserId"],
      ["reward_migration_before_images", "actorUserId"],
      ["activity_sessions", "actorUserId"],
      ["room_contributions", "actorUserId"],
      ["push_installations", "userId"],
      ["push_token_claims", "userId"],
      ["privacy_export_access", "userId"],
      ["relationship_memberships", "userId"],
      ["user_notifications", "recipientUserId"],
      ["user_notifications", "actorUserId"],
      ["user_notifications", "actorPrincipalId"],
      ["push_delivery_jobs", "recipientUserId"],
      ["push_delivery_jobs", "actorUserId"],
      ["push_delivery_jobs", "actorPrincipalId"],
      ["friend_messages", "senderId"],
      ["friend_messages", "receiverId"],
      ["friend_requests", "senderId"],
      ["friend_requests", "receiverId"],
      ["guardian_requests", "senderId"],
      ["guardian_requests", "receiverId"],
      ["group_requests", "senderId"],
      ["group_requests", "receiverId"],
      ["audit_events", "actorPrincipalId"],
      ["audit_events", "result.recipientUserId"],
    ];
    for (const [collection, field] of querySpecs) {
      deletedDocuments += await deleteQuery(
        this.firestore,
        this.firestore.collection(collection).where(field, "==", userId),
      );
    }

    const relationshipOutcomes = await querySnapshots(
      this.firestore
        .collection("relationship_outcomes")
        .where("participantIds", "array-contains", userId),
    );
    for (const outcome of relationshipOutcomes) {
      await this.firestore.recursiveDelete(outcome.ref);
      deletedDocuments += 1;
    }

    const directCollections = [
      "public_profiles",
      "privacy_consents",
      "notification_preferences",
      "push_delivery_state",
      "account_operation_leases",
      "push_delivery_leases",
    ];
    deletedDocuments += await deleteReferences(
      this.firestore,
      directCollections.map(collection =>
        this.firestore.collection(collection).doc(userId)
      ),
    );

    const friends = await querySnapshots(
      this.firestore.collection("users").doc(userId).collection("friends"),
    );
    deletedDocuments += await deleteReferences(
      this.firestore,
      friends.map(friend =>
        this.firestore
          .collection("users")
          .doc(friend.id)
          .collection("friends")
          .doc(userId)
      ),
    );
    await this.firestore.recursiveDelete(
      this.firestore.collection("users").doc(userId),
    );
    deletedScopes.push("user:subject");

    if (this.bucket) {
      try {
        await this.bucket.deleteFiles({ prefix: `privacy_exports/${userId}/` });
      } catch (error) {
        if (![404, "404"].includes(error?.code)) throw error;
      }
    }
    return {
      schemaVersion: 1,
      deletedDocuments,
      deletedScopes,
      completedAt: now,
    };
  }

  async deleteAuthUser(userId) {
    await this.auth.deleteUser(userId);
  }

  async freezeAuthUser(userId) {
    await this.auth.updateUser(userId, { disabled: true });
    await this.auth.revokeRefreshTokens(userId);
  }

  async #deleteScopeMemberships(scopeType, scopeId) {
    const candidates = await querySnapshots(
      this.firestore
        .collection("relationship_memberships")
        .where("scopeId", "==", scopeId),
    );
    return deleteReferences(
      this.firestore,
      candidates
        .filter(document => document.data().scopeType === scopeType)
        .map(document => document.ref),
    );
  }

  async #deleteRelationshipOutcomes(scopeType, scopeId) {
    const candidates = await querySnapshots(
      this.firestore
        .collection("relationship_outcomes")
        .where("scopeId", "==", scopeId),
    );
    let deleted = 0;
    for (const document of candidates) {
      if (document.data().scopeType !== scopeType) continue;
      await this.firestore.recursiveDelete(document.ref);
      deleted += 1;
    }
    return deleted;
  }

  async #redactEndedFamilyLink(familyLinkId, userId, now) {
    const reference = this.firestore
      .collection("family_links")
      .doc(familyLinkId);
    await this.firestore.runTransaction(async transaction => {
      const snapshot = await transaction.get(reference);
      if (!snapshot.exists) return;
      const data = snapshot.data();
      const participantIds = Array.isArray(data.participantIds)
        ? data.participantIds
        : [];
      if (data.status !== "ended") {
        throw new HttpsError(
          "failed-precondition",
          "Ended family relationship changed; regenerate the deletion plan.",
        );
      }
      transaction.update(reference, {
        participantIds: withoutUser(participantIds, userId),
        guardianId: data.guardianId === userId ? "" : data.guardianId ?? "",
        childId: data.childId === userId ? "" : data.childId ?? "",
        consentScopes: {
          summary: false,
          weeklyReport: false,
          taskCategories: false,
          healthTrends: false,
        },
        accountDeletionRedactedAt: now,
        updatedAt: now,
      });
    });
    let deleted = 0;
    for (const collection of [
      "bond_events",
      "goals",
      "encouragements",
      "summaries",
    ]) {
      deleted += await deleteQuery(
        this.firestore,
        reference.collection(collection),
      );
    }
    deleted += await this.#deleteRelationshipOutcomes(
      "family",
      familyLinkId,
    );
    const memberships = await querySnapshots(
      this.firestore
        .collection("relationship_memberships")
        .where("scopeId", "==", familyLinkId),
    );
    deleted += await deleteReferences(
      this.firestore,
      memberships
        .filter(document =>
          document.data().scopeType === "family" &&
          document.data().userId === userId
        )
        .map(document => document.ref),
    );
    return deleted;
  }

  async #lockOwnedScopeForDeletion(collection, scopeId, userId, now) {
    const reference = this.firestore.collection(collection).doc(scopeId);
    await this.firestore.runTransaction(async transaction => {
      const snapshot = await transaction.get(reference);
      if (!snapshot.exists) return;
      const data = snapshot.data();
      if (data.ownerId !== userId) {
        throw new HttpsError(
          "failed-precondition",
          `${collection} ownership changed; regenerate the deletion plan.`,
        );
      }
      if (otherParticipants(data.memberIds, userId).length > 0) {
        throw new HttpsError(
          "failed-precondition",
          `${collection} gained another participant; transfer ownership first.`,
        );
      }
      transaction.update(reference, {
        status: collection === "rooms" ? "closed" : "deleting",
        accountDeletionLockedAt: now,
        updatedAt: now,
      });
    });
  }

  async #lockFamilyLinkForDeletion(familyLinkId, userId, now) {
    const reference = this.firestore
      .collection("family_links")
      .doc(familyLinkId);
    await this.firestore.runTransaction(async transaction => {
      const snapshot = await transaction.get(reference);
      if (!snapshot.exists) return;
      const participantIds = snapshot.data().participantIds;
      if (
        !Array.isArray(participantIds) ||
        !participantIds.includes(userId) ||
        otherParticipants(participantIds, userId).length > 0
      ) {
        throw new HttpsError(
          "failed-precondition",
          "Family relationship changed; resolve it before account deletion.",
        );
      }
      transaction.update(reference, {
        status: "ended",
        accountDeletionLockedAt: now,
        updatedAt: now,
      });
    });
  }

  async completeExecution({
    request,
    staffUserId,
    input,
    executionAttempt,
    outcome,
    now,
  }) {
    const requestRef = this.firestore
      .collection("privacy_data_requests")
      .doc(request.requestId);
    const executionRef = this.firestore
      .collection("account_deletion_executions")
      .doc(`${staffUserId}--${input.clientRequestId}`);
    const completionAuditRef = this.firestore
      .collection("audit_events")
      .doc(`privacy-delete-completed--${staffUserId}--${input.clientRequestId}`);
    const fenceRef = this.firestore
      .collection("account_deletion_fences")
      .doc(request.userId);
    return this.firestore.runTransaction(async transaction => {
      const [currentSnapshot, executionSnapshot, fenceSnapshot] =
        await Promise.all([
        transaction.get(requestRef),
        transaction.get(executionRef),
        transaction.get(fenceRef),
      ]);
      if (!currentSnapshot.exists) {
        throw new HttpsError(
          "not-found",
          "The account deletion request evidence is missing.",
        );
      }
      const current = currentSnapshot.data();
      const execution = executionSnapshot.exists
        ? executionSnapshot.data()
        : null;
      if (
        current.status !== "deleting" ||
        current.activeDeletionExecutionId !== executionRef.id ||
        current.activeDeletionAttempt !== executionAttempt ||
        current.caseId !== input.caseId ||
        !execution ||
        execution.status !== "executing" ||
        execution.attemptCount !== executionAttempt ||
        !fenceSnapshot.exists ||
        fenceSnapshot.data().requestId !== request.requestId ||
        fenceSnapshot.data().executionId !== executionRef.id
      ) {
        throw new HttpsError(
          "failed-precondition",
          "The account deletion execution lease is no longer owned.",
        );
      }
      const retentionExpiresAt = laterIso(now, EVIDENCE_RETENTION_MS);
      const completedRequest = {
        schemaVersion: 1,
        requestId: request.requestId,
        type: "account_deletion",
        status: "completed",
        sourceSurface: request.sourceSurface ?? "app",
        requestedAt: request.requestedAt ?? null,
        reviewAfter: request.reviewAfter ?? null,
        assignedStaffUserId: staffUserId,
        resolutionNote: input.resolutionNote,
        caseId: input.caseId,
        completedAt: now,
        updatedAt: now,
        executionOutcome: outcome,
        executionAuditEventId: completionAuditRef.id,
        retentionExpiresAt,
      };
      transaction.set(requestRef, completedRequest, { merge: false });
      const result = {
        request: completedRequest,
        auditEventId: completionAuditRef.id,
        replayed: false,
      };
      transaction.update(executionRef, {
        status: "completed",
        result,
        retentionExpiresAt,
        updatedAt: now,
      });
      transaction.set(fenceRef, {
        schemaVersion: 1,
        status: "completed",
        requestId: request.requestId,
        executionId: executionRef.id,
        caseId: input.caseId,
        retentionExpiresAt,
        updatedAt: now,
        createdAt: execution.createdAt ?? now,
      }, { merge: false });
      transaction.create(completionAuditRef, {
        schemaVersion: 1,
        auditEventId: completionAuditRef.id,
        category: "privacy",
        action: "privacy.data.account_deletion.completed",
        actorUserId: staffUserId,
        targetType: "privacy_data_request",
        targetId: request.requestId,
        sourceSurface: input.sourceSurface,
        clientRequestId: input.clientRequestId,
        caseId: input.caseId,
        result: { executionAttempt, outcome },
        retentionExpiresAt,
        createdAt: now,
      });
      return result;
    });
  }

  async failExecution({
    request,
    staffUserId,
    input,
    executionAttempt,
    failureCode,
    now,
  }) {
    const requestRef = this.firestore
      .collection("privacy_data_requests")
      .doc(request.requestId);
    const executionRef = this.firestore
      .collection("account_deletion_executions")
      .doc(`${staffUserId}--${input.clientRequestId}`);
    const failureAuditRef = this.firestore
      .collection("audit_events")
      .doc(
        `privacy-delete-failed--${staffUserId}--` +
          `${input.clientRequestId}--${executionAttempt}`,
      );
    const fenceRef = this.firestore
      .collection("account_deletion_fences")
      .doc(request.userId);
    await this.firestore.runTransaction(async transaction => {
      const [current, execution, failureAudit, fence] = await Promise.all([
        transaction.get(requestRef),
        transaction.get(executionRef),
        transaction.get(failureAuditRef),
        transaction.get(fenceRef),
      ]);
      if (
        current.exists &&
        current.data().status === "deleting" &&
        current.data().activeDeletionExecutionId === executionRef.id &&
        current.data().activeDeletionAttempt === executionAttempt &&
        execution.exists &&
        execution.data().status === "executing" &&
        execution.data().attemptCount === executionAttempt &&
        fence.exists &&
        fence.data().requestId === request.requestId &&
        fence.data().executionId === executionRef.id
      ) {
        transaction.update(requestRef, {
          status: "deletion_failed",
          executionFailureCode: failureCode,
          executionFailedAt: now,
          executionLeaseExpiresAt: null,
          updatedAt: now,
        });
        transaction.update(executionRef, {
          status: "failed",
          failureCode,
          leaseExpiresAt: null,
          updatedAt: now,
        });
        transaction.update(fenceRef, {
          status: "deletion_failed",
          leaseExpiresAt: null,
          failureCode,
          updatedAt: now,
        });
      }
      if (!failureAudit.exists) {
        transaction.create(failureAuditRef, {
          schemaVersion: 1,
          auditEventId: failureAuditRef.id,
          category: "privacy",
          action: "privacy.data.account_deletion.failed",
          actorUserId: staffUserId,
          targetType: "privacy_data_request",
          targetId: request.requestId,
          sourceSurface: input.sourceSurface,
          clientRequestId: input.clientRequestId,
          caseId: input.caseId,
          result: { executionAttempt, failureCode },
          createdAt: now,
        });
      }
    });
  }

  async cleanupExpiredEvidence(now) {
    let deletedRequests = 0;
    let deletedAudits = 0;
    let deletedExecutions = 0;
    let deletedFences = 0;
    let cursor = null;
    while (true) {
      let query = this.firestore
        .collection("privacy_data_requests")
        .where("retentionExpiresAt", "<=", now)
        .orderBy("retentionExpiresAt")
        .orderBy(FieldPath.documentId())
        .limit(PAGE_SIZE);
      if (cursor) query = query.startAfter(cursor);
      const expired = await query.get();
      for (const request of expired.docs) {
        const data = request.data();
        if (data.type !== "account_deletion" || data.status !== "completed") {
          continue;
        }
        deletedAudits += await deleteQuery(
          this.firestore,
          this.firestore
            .collection("audit_events")
            .where("targetId", "==", request.id),
        );
        const executions = await querySnapshots(
          this.firestore
            .collection("account_deletion_executions")
            .where("targetId", "==", request.id),
        );
        for (const execution of executions) {
          const subjectUserId = execution.data().subjectUserId;
          if (typeof subjectUserId === "string" && subjectUserId) {
            const fenceRef = this.firestore
              .collection("account_deletion_fences")
              .doc(subjectUserId);
            const fenceDeleted = await this.firestore.runTransaction(
              async transaction => {
                const fence = await transaction.get(fenceRef);
                if (
                  !fence.exists ||
                  fence.data().requestId !== request.id ||
                  fence.data().executionId !== execution.id
                ) {
                  return false;
                }
                transaction.delete(fenceRef);
                return true;
              },
            );
            if (fenceDeleted) deletedFences += 1;
          }
          await execution.ref.delete();
          deletedExecutions += 1;
        }
        await request.ref.delete();
        deletedRequests += 1;
      }
      if (expired.size < PAGE_SIZE) break;
      cursor = expired.docs.at(-1);
    }
    return {
      deletedRequests,
      deletedAudits,
      deletedExecutions,
      deletedFences,
    };
  }
}
