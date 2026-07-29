import { createHash } from "node:crypto";

import { HttpsError } from "firebase-functions/v2/https";

import {
  defaultNotificationChannels,
  NOTIFICATION_PREFERENCE_SCHEMA_VERSION,
} from "./notification-preference-service.js";

const PUSH_PLATFORM_KEYS = new Set(["android", "ios"]);
const INVALID_TOKEN_CODES = new Set([
  "messaging/invalid-argument",
  "messaging/invalid-registration-token",
  "messaging/registration-token-not-registered",
]);
const TERMINAL_JOB_STATUSES = new Set([
  "delivered",
  "partial",
  "skipped",
  "failed",
  "cancelled",
]);

function normalizedString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function sha256(value) {
  return createHash("sha256").update(value).digest("hex");
}

function normalizeActiveInstallationIds(value) {
  if (!Array.isArray(value)) return [];
  return [...new Set(value.map(normalizedString).filter(Boolean))].sort();
}

function installationDocumentId(userId, installationId) {
  return `${userId}--${installationId}`;
}

function inputFingerprint(input) {
  return sha256(
    JSON.stringify({
      action: input.action,
      installationId: input.installationId,
      platform: input.platform,
      tokenHash: input.token ? sha256(input.token) : "",
    }),
  );
}

export function normalizePushInstallationRequest(data) {
  const action = normalizedString(data?.action);
  const installationId = normalizedString(data?.installationId);
  const platform = normalizedString(data?.platform);
  const token = normalizedString(data?.token);
  const clientRequestId = normalizedString(data?.clientRequestId);

  if (!["register", "revoke"].includes(action)) {
    throw new HttpsError(
      "invalid-argument",
      "Push installation action must be register or revoke.",
    );
  }
  if (!/^[A-Za-z0-9_-]{8,128}$/.test(installationId)) {
    throw new HttpsError(
      "invalid-argument",
      "A valid installationId is required.",
    );
  }
  if (!/^[A-Za-z0-9_-]{8,128}$/.test(clientRequestId)) {
    throw new HttpsError(
      "invalid-argument",
      "A stable push clientRequestId is required.",
    );
  }
  if (action === "register") {
    if (!PUSH_PLATFORM_KEYS.has(platform)) {
      throw new HttpsError(
        "invalid-argument",
        "Push installation platform is invalid.",
      );
    }
    if (token.length < 32 || token.length > 4096) {
      throw new HttpsError(
        "invalid-argument",
        "A valid Firebase messaging token is required.",
      );
    }
  }

  return {
    action,
    installationId,
    platform: action === "register" ? platform : "",
    token: action === "register" ? token : "",
    clientRequestId,
  };
}

export function createUpdatePushInstallationHandler({ firestore, clock }) {
  return async request => {
    const userId = request.auth?.uid;
    if (!userId) {
      throw new HttpsError(
        "unauthenticated",
        "Authentication is required to update a push installation.",
      );
    }

    const input = normalizePushInstallationRequest(request.data);
    const fingerprint = inputFingerprint(input);
    const timestamp = clock().toISOString();
    const installationRef = firestore
      .collection("push_installations")
      .doc(installationDocumentId(userId, input.installationId));
    const stateRef = firestore.collection("push_delivery_state").doc(userId);
    const preferenceRef = firestore
      .collection("notification_preferences")
      .doc(userId);
    const auditRef = firestore
      .collection("audit_events")
      .doc(`push-installation--${userId}--${input.clientRequestId}`);

    return firestore.runTransaction(async transaction => {
      const auditSnapshot = await transaction.get(auditRef);
      if (auditSnapshot.exists) {
        const audit = auditSnapshot.data();
        if (
          audit.actorUserId !== userId ||
          audit.action !== `notifications.push.${input.action}` ||
          audit.inputFingerprint !== fingerprint
        ) {
          throw new HttpsError(
            "already-exists",
            "The push clientRequestId was already used.",
          );
        }
        return {
          ...audit.result,
          auditEventId: auditRef.id,
          replayed: true,
        };
      }

      const [installationSnapshot, stateSnapshot, preferenceSnapshot] =
        await Promise.all([
          transaction.get(installationRef),
          transaction.get(stateRef),
          transaction.get(preferenceRef),
        ]);
      const activeInstallationIds = new Set(
        normalizeActiveInstallationIds(
          stateSnapshot.exists
            ? stateSnapshot.data().activeInstallationIds
            : [],
        ),
      );

      let claimRef = null;
      let claimSnapshot = null;
      let displacedInstallationRef = null;
      let displacedInstallationSnapshot = null;
      let displacedStateRef = null;
      let displacedStateSnapshot = null;
      let displacedPreferenceRef = null;
      let displacedPreferenceSnapshot = null;
      let tokenHash = "";

      if (input.action === "register") {
        tokenHash = sha256(input.token);
        claimRef = firestore.collection("push_token_claims").doc(tokenHash);
        claimSnapshot = await transaction.get(claimRef);
        if (claimSnapshot.exists) {
          const claim = claimSnapshot.data();
          const displacedUserId = normalizedString(claim.userId);
          const displacedInstallationId = normalizedString(claim.installationId);
          if (
            displacedUserId &&
            displacedInstallationId &&
            (displacedUserId !== userId ||
              displacedInstallationId !== input.installationId)
          ) {
            displacedInstallationRef = firestore
              .collection("push_installations")
              .doc(
                installationDocumentId(
                  displacedUserId,
                  displacedInstallationId,
                ),
              );
            displacedStateRef = firestore
              .collection("push_delivery_state")
              .doc(displacedUserId);
            displacedPreferenceRef = firestore
              .collection("notification_preferences")
              .doc(displacedUserId);
            [
              displacedInstallationSnapshot,
              displacedStateSnapshot,
              displacedPreferenceSnapshot,
            ] =
              await Promise.all([
                transaction.get(displacedInstallationRef),
                transaction.get(displacedStateRef),
                transaction.get(displacedPreferenceRef),
              ]);
          }
        }
      } else if (installationSnapshot.exists) {
        tokenHash = normalizedString(installationSnapshot.data().tokenHash);
        if (tokenHash) {
          claimRef = firestore.collection("push_token_claims").doc(tokenHash);
          claimSnapshot = await transaction.get(claimRef);
        }
      }

      if (displacedInstallationRef && displacedInstallationSnapshot?.exists) {
        const displaced = displacedInstallationSnapshot.data();
        transaction.set(displacedInstallationRef, {
          schemaVersion: 1,
          userId: displaced.userId,
          installationId: displaced.installationId,
          platform: displaced.platform,
          tokenHash: displaced.tokenHash,
          status: "revoked",
          revokedReason: "token_reassigned",
          revokedAt: timestamp,
          updatedAt: timestamp,
        });
        const displacedActiveIds = new Set(
          normalizeActiveInstallationIds(
            displacedStateSnapshot?.exists
              ? displacedStateSnapshot.data().activeInstallationIds
              : [],
          ),
        );
        displacedActiveIds.delete(displaced.installationId);
        if (displaced.userId === userId) {
          activeInstallationIds.delete(displaced.installationId);
        }
        transaction.set(displacedStateRef, {
          schemaVersion: 1,
          userId: displaced.userId,
          activeInstallationIds: [...displacedActiveIds].sort(),
          configured: displacedActiveIds.size > 0,
          updatedAt: timestamp,
        });
        if (displacedPreferenceSnapshot?.exists) {
          transaction.update(displacedPreferenceRef, {
            "delivery.pushConfigured": displacedActiveIds.size > 0,
            "delivery.updatedAt": timestamp,
          });
        }
      }

      if (input.action === "register") {
        activeInstallationIds.add(input.installationId);
        transaction.set(installationRef, {
          schemaVersion: 1,
          userId,
          installationId: input.installationId,
          platform: input.platform,
          token: input.token,
          tokenHash,
          status: "active",
          registeredAt: installationSnapshot.exists
            ? installationSnapshot.data().registeredAt || timestamp
            : timestamp,
          updatedAt: timestamp,
        });
        transaction.set(claimRef, {
          schemaVersion: 1,
          userId,
          installationId: input.installationId,
          tokenHash,
          updatedAt: timestamp,
        });
      } else {
        activeInstallationIds.delete(input.installationId);
        if (installationSnapshot.exists) {
          const existing = installationSnapshot.data();
          transaction.set(installationRef, {
            schemaVersion: 1,
            userId,
            installationId: input.installationId,
            platform: normalizedString(existing.platform),
            tokenHash: normalizedString(existing.tokenHash),
            status: "revoked",
            revokedReason: "user_action",
            revokedAt: timestamp,
            updatedAt: timestamp,
          });
        }
        if (
          claimRef &&
          claimSnapshot?.exists &&
          claimSnapshot.data().userId === userId &&
          claimSnapshot.data().installationId === input.installationId
        ) {
          transaction.delete(claimRef);
        }
      }

      const configured = activeInstallationIds.size > 0;
      transaction.set(stateRef, {
        schemaVersion: 1,
        userId,
        activeInstallationIds: [...activeInstallationIds].sort(),
        configured,
        updatedAt: timestamp,
      });
      if (preferenceSnapshot.exists) {
        transaction.update(preferenceRef, {
          "delivery.pushConfigured": configured,
          "delivery.updatedAt": timestamp,
        });
      } else if (input.action === "register") {
        transaction.set(preferenceRef, {
          schemaVersion: NOTIFICATION_PREFERENCE_SCHEMA_VERSION,
          userId,
          channels: defaultNotificationChannels(),
          delivery: {
            localScheduled: true,
            inApp: true,
            pushConfigured: configured,
            updatedAt: timestamp,
          },
          updatedAt: timestamp,
          updatedBy: userId,
        });
      }

      const result = {
        action: input.action,
        installationId: input.installationId,
        configured,
        activeInstallationCount: activeInstallationIds.size,
      };
      transaction.create(auditRef, {
        schemaVersion: 1,
        auditEventId: auditRef.id,
        category: "notifications",
        action: `notifications.push.${input.action}`,
        actorUserId: userId,
        targetType: "push_installation",
        targetId: input.installationId,
        clientRequestId: input.clientRequestId,
        inputFingerprint: fingerprint,
        result,
        createdAt: timestamp,
      });
      return {
        ...result,
        auditEventId: auditRef.id,
        replayed: false,
      };
    });
  };
}

export function buildPushDeliveryJob(notification) {
  return {
    schemaVersion: 1,
    jobId: notification.notificationId,
    notificationId: notification.notificationId,
    recipientUserId: notification.recipientUserId,
    actorUserId: notification.actorUserId,
    actorPrincipalId: notification.actorPrincipalId,
    category: notification.category,
    kind: notification.kind,
    title: notification.title,
    body: notification.body,
    route: notification.route,
    status: "pending",
    attemptCount: 0,
    createdAt: notification.createdAt,
    updatedAt: notification.updatedAt,
  };
}

function pushCategoryEnabled(preferences, category) {
  if (!preferences) return false;
  if (category === "relationship") {
    return preferences.categories?.relationshipUpdates !== false;
  }
  return true;
}

function errorCodeOf(error) {
  return normalizedString(error?.code);
}

function safeErrorMessage(error) {
  const message = normalizedString(error?.message);
  return message ? message.slice(0, 500) : "Unknown push delivery error.";
}

function timestampMillis(value) {
  if (value && typeof value.toDate === "function") {
    return value.toDate().getTime();
  }
  const parsed = Date.parse(value);
  return Number.isFinite(parsed) ? parsed : 0;
}

async function releasePushDeliveryLeases({
  firestore,
  userIds,
  jobId,
}) {
  if (!Array.isArray(userIds) || userIds.length === 0) return;
  await firestore.runTransaction(async transaction => {
    const references = userIds.map(userId =>
      firestore.collection("push_delivery_leases").doc(userId)
    );
    const snapshots = await Promise.all(
      references.map(reference => transaction.get(reference)),
    );
    snapshots.forEach((snapshot, index) => {
      if (snapshot.exists && snapshot.data().jobId === jobId) {
        transaction.delete(references[index]);
      }
    });
  });
}

function pushDeliveryAudit({ auditEventId, jobId, recipientUserId, result, now }) {
  return {
    schemaVersion: 1,
    auditEventId,
    category: "notifications",
    action: "notifications.push.deliver",
    actorUserId: "system",
    targetType: "push_delivery_job",
    targetId: jobId,
    result: {
      recipientUserId,
      ...result,
    },
    createdAt: now,
  };
}

export function createDeliverPushJobHandler({
  firestore,
  messaging,
  clock,
  maxAttempts = 5,
}) {
  return async event => {
    const snapshot = event.data;
    if (!snapshot?.exists) return null;
    const jobId = event.params.jobId;
    const jobRef = firestore.collection("push_delivery_jobs").doc(jobId);
    const attemptStartedAt = clock();
    const leaseUntil = new Date(
      attemptStartedAt.getTime() + 2 * 60 * 1000,
    ).toISOString();
    const job = await firestore.runTransaction(async transaction => {
      const currentSnapshot = await transaction.get(jobRef);
      if (!currentSnapshot.exists) return null;
      const current = currentSnapshot.data();
      const notificationId =
        normalizedString(current.notificationId) || jobId;
      const notificationSnapshot = await transaction.get(
        firestore.collection("user_notifications").doc(notificationId),
      );
      const notification = notificationSnapshot.exists
        ? notificationSnapshot.data()
        : null;
      const identityIds = [...new Set([
        normalizedString(current.recipientUserId),
        normalizedString(current.actorUserId),
        normalizedString(current.actorPrincipalId),
        normalizedString(notification?.actorUserId),
        normalizedString(notification?.actorPrincipalId),
      ].filter(Boolean))];
      const deletionFences = await Promise.all(
        identityIds.map(userId =>
          transaction.get(
            firestore.collection("account_deletion_fences").doc(userId),
          )
        ),
      );
      if (deletionFences.some(snapshot => snapshot.exists)) {
        transaction.delete(jobRef);
        return { terminal: true, status: "cancelled_account_deletion" };
      }
      if (TERMINAL_JOB_STATUSES.has(current.status)) {
        return { terminal: true, ...current };
      }
      if (
        current.status === "sending" &&
        timestampMillis(current.leaseUntil) > attemptStartedAt.getTime()
      ) {
        throw new Error("Push delivery job already has an active lease.");
      }
      const deliveryLeaseRefs = identityIds.map(userId =>
        firestore.collection("push_delivery_leases").doc(userId)
      );
      const deliveryLeases = await Promise.all(
        deliveryLeaseRefs.map(reference => transaction.get(reference)),
      );
      if (
        deliveryLeases.some(lease =>
          lease.exists &&
          lease.data().jobId !== jobId &&
          timestampMillis(lease.data().leaseUntil) > attemptStartedAt.getTime()
        )
      ) {
        throw new Error("An account already has an active push delivery.");
      }
      const claimed = {
        ...current,
        actorUserId:
          normalizedString(current.actorUserId) ||
          normalizedString(notification?.actorUserId),
        actorPrincipalId:
          normalizedString(current.actorPrincipalId) ||
          normalizedString(notification?.actorPrincipalId),
        deliveryLeaseUserIds: identityIds,
        status: "sending",
        attemptCount: (current.attemptCount || 0) + 1,
        leaseUntil,
        updatedAt: attemptStartedAt.toISOString(),
      };
      transaction.update(jobRef, {
        status: claimed.status,
        attemptCount: claimed.attemptCount,
        leaseUntil: claimed.leaseUntil,
        updatedAt: claimed.updatedAt,
      });
      deliveryLeaseRefs.forEach((reference, index) => {
        transaction.set(reference, {
          schemaVersion: 1,
          userId: identityIds[index],
          jobId,
          leaseUntil,
          updatedAt: claimed.updatedAt,
        }, { merge: false });
      });
      return claimed;
    });
    if (!job || job.terminal) return job;

    const recipientUserId = normalizedString(job.recipientUserId);
    const stateRef = firestore
      .collection("push_delivery_state")
      .doc(recipientUserId);
    const preferenceRef = firestore
      .collection("notification_preferences")
      .doc(recipientUserId);
    const [stateSnapshot, preferenceSnapshot] = await Promise.all([
      stateRef.get(),
      preferenceRef.get(),
    ]);
    const state = stateSnapshot.exists ? stateSnapshot.data() : null;
    const preferences = preferenceSnapshot.exists
      ? preferenceSnapshot.data()
      : null;
    const installationIds = normalizeActiveInstallationIds(
      state?.activeInstallationIds,
    );

    if (
      !state?.configured ||
      installationIds.length === 0 ||
      !pushCategoryEnabled(preferences, job.category)
    ) {
      const reason = !preferences
        ? "preferences_missing"
        : !pushCategoryEnabled(preferences, job.category)
          ? "category_disabled"
          : "no_active_installation";
      const completedAt = clock().toISOString();
      const result = {
        status: "skipped",
        reason,
        successCount: 0,
        failureCount: 0,
      };
      const auditRef = firestore
        .collection("audit_events")
        .doc(`push-delivery--${jobId}`);
      await firestore.runTransaction(async transaction => {
        transaction.update(jobRef, {
          ...result,
          attemptCount: job.attemptCount,
          leaseUntil: null,
          completedAt,
          updatedAt: completedAt,
        });
        transaction.set(
          auditRef,
          pushDeliveryAudit({
            auditEventId: auditRef.id,
            jobId,
            recipientUserId,
            result,
            now: completedAt,
          }),
        );
      });
      await releasePushDeliveryLeases({
        firestore,
        userIds: job.deliveryLeaseUserIds,
        jobId,
      });
      return result;
    }

    const installations = (
      await Promise.all(
        installationIds.map(async installationId => {
          const ref = firestore
            .collection("push_installations")
            .doc(installationDocumentId(recipientUserId, installationId));
          const installationSnapshot = await ref.get();
          return {
            ref,
            installationId,
            data: installationSnapshot.exists
              ? installationSnapshot.data()
              : null,
          };
        }),
      )
    ).filter(
      installation =>
        installation.data?.status === "active" &&
        normalizedString(installation.data?.token),
    );

    const identityIds = [...new Set([
      recipientUserId,
      normalizedString(job.actorUserId),
      normalizedString(job.actorPrincipalId),
    ].filter(Boolean))];
    const deletionFences = await Promise.all(
      identityIds.map(userId =>
        firestore.collection("account_deletion_fences").doc(userId).get()
      ),
    );
    if (deletionFences.some(snapshot => snapshot.exists)) {
      await jobRef.delete();
      await releasePushDeliveryLeases({
        firestore,
        userIds: job.deliveryLeaseUserIds,
        jobId,
      });
      return {
        status: "skipped",
        reason: "account_deletion_in_progress",
        successCount: 0,
        failureCount: 0,
      };
    }

    if (installations.length === 0) {
      const completedAt = clock().toISOString();
      const result = {
        status: "skipped",
        reason: "no_deliverable_token",
        successCount: 0,
        failureCount: 0,
      };
      await firestore.runTransaction(async transaction => {
        const [latestStateSnapshot, latestPreferenceSnapshot] =
          await Promise.all([
            transaction.get(stateRef),
            transaction.get(preferenceRef),
          ]);
        const latestActiveIds = normalizeActiveInstallationIds(
          latestStateSnapshot.exists
            ? latestStateSnapshot.data().activeInstallationIds
            : [],
        ).filter(id => !installationIds.includes(id));
        transaction.set(stateRef, {
          schemaVersion: 1,
          userId: recipientUserId,
          activeInstallationIds: latestActiveIds,
          configured: latestActiveIds.length > 0,
          updatedAt: completedAt,
        });
        if (latestPreferenceSnapshot.exists) {
          transaction.update(preferenceRef, {
            "delivery.pushConfigured": latestActiveIds.length > 0,
            "delivery.updatedAt": completedAt,
          });
        }
        transaction.update(jobRef, {
          ...result,
          attemptCount: job.attemptCount,
          leaseUntil: null,
          completedAt,
          updatedAt: completedAt,
        });
        const auditRef = firestore
          .collection("audit_events")
          .doc(`push-delivery--${jobId}`);
        transaction.set(
          auditRef,
          pushDeliveryAudit({
            auditEventId: auditRef.id,
            jobId,
            recipientUserId,
            result,
            now: completedAt,
          }),
        );
      });
      await releasePushDeliveryLeases({
        firestore,
        userIds: job.deliveryLeaseUserIds,
        jobId,
      });
      return result;
    }

    let response;
    try {
      response = await messaging.sendEachForMulticast({
        tokens: installations.map(installation => installation.data.token),
        notification: {
          title: normalizedString(job.title),
          body: normalizedString(job.body),
        },
        data: {
          notificationId: normalizedString(job.notificationId),
          category: normalizedString(job.category),
          kind: normalizedString(job.kind),
          route: normalizedString(job.route),
        },
        android: {
          priority: "high",
          notification: {
            channelId: "nudge_relationship_updates",
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
            },
          },
        },
      });
    } catch (error) {
      const attemptedAt = clock().toISOString();
      const attemptCount = job.attemptCount;
      const terminal = attemptCount >= maxAttempts;
      const errorPatch = {
        status: terminal ? "failed" : "pending",
        attemptCount,
        lastErrorCode: errorCodeOf(error) || "messaging/unknown",
        lastErrorMessage: safeErrorMessage(error),
        ...(terminal ? { completedAt: attemptedAt } : {}),
        leaseUntil: null,
        updatedAt: attemptedAt,
      };
      if (terminal) {
        const failureResult = {
          status: "failed",
          reason: "messaging_error",
          successCount: 0,
          failureCount: installations.length,
        };
        const auditRef = firestore
          .collection("audit_events")
          .doc(`push-delivery--${jobId}`);
        await firestore.runTransaction(async transaction => {
          transaction.update(jobRef, errorPatch);
          transaction.set(
            auditRef,
            pushDeliveryAudit({
              auditEventId: auditRef.id,
              jobId,
              recipientUserId,
              result: failureResult,
              now: attemptedAt,
            }),
          );
        });
      } else {
        await jobRef.update(errorPatch);
      }
      await releasePushDeliveryLeases({
        firestore,
        userIds: job.deliveryLeaseUserIds,
        jobId,
      });
      if (!terminal) throw error;
      return {
        status: "failed",
        reason: "messaging_error",
        successCount: 0,
        failureCount: installations.length,
      };
    }

    const invalidInstallations = [];
    response.responses.forEach((item, index) => {
      if (!item.success && INVALID_TOKEN_CODES.has(errorCodeOf(item.error))) {
        invalidInstallations.push(installations[index]);
      }
    });
    const completedAt = clock().toISOString();
    const status =
      response.failureCount === 0
        ? "delivered"
        : response.successCount > 0
          ? "partial"
          : "failed";
    const result = {
      status,
      reason: response.failureCount === 0 ? "sent" : "messaging_response",
      successCount: response.successCount,
      failureCount: response.failureCount,
    };
    const auditRef = firestore
      .collection("audit_events")
      .doc(`push-delivery--${jobId}`);

    await firestore.runTransaction(async transaction => {
      const invalidSnapshots = await Promise.all(
        invalidInstallations.map(async invalid => {
          const currentInstallation = await transaction.get(invalid.ref);
          const claimRef = normalizedString(invalid.data.tokenHash)
            ? firestore
                .collection("push_token_claims")
                .doc(normalizedString(invalid.data.tokenHash))
            : null;
          const claimSnapshot = claimRef
            ? await transaction.get(claimRef)
            : null;
          return {
            ...invalid,
            currentInstallation,
            claimRef,
            claimSnapshot,
          };
        }),
      );
      const [latestStateSnapshot, latestPreferenceSnapshot] =
        await Promise.all([
          transaction.get(stateRef),
          transaction.get(preferenceRef),
        ]);
      const confirmedInvalid = invalidSnapshots.filter(invalid => {
        if (!invalid.currentInstallation.exists) return false;
        const current = invalid.currentInstallation.data();
        return (
          current.status === "active" &&
          normalizedString(current.tokenHash) ===
            normalizedString(invalid.data.tokenHash)
        );
      });
      const confirmedInvalidIds = new Set(
        confirmedInvalid.map(invalid => invalid.installationId),
      );
      const latestRemainingIds = normalizeActiveInstallationIds(
        latestStateSnapshot.exists
          ? latestStateSnapshot.data().activeInstallationIds
          : [],
      ).filter(id => !confirmedInvalidIds.has(id));

      for (const invalid of confirmedInvalid) {
        transaction.set(invalid.ref, {
          schemaVersion: 1,
          userId: recipientUserId,
          installationId: invalid.installationId,
          platform: normalizedString(invalid.data.platform),
          tokenHash: normalizedString(invalid.data.tokenHash),
          status: "revoked",
          revokedReason: "messaging_token_invalid",
          revokedAt: completedAt,
          updatedAt: completedAt,
        });
        if (
          invalid.claimRef &&
          invalid.claimSnapshot?.exists &&
          invalid.claimSnapshot.data().userId === recipientUserId &&
          invalid.claimSnapshot.data().installationId ===
            invalid.installationId
        ) {
          transaction.delete(invalid.claimRef);
        }
      }
      transaction.set(stateRef, {
        schemaVersion: 1,
        userId: recipientUserId,
        activeInstallationIds: latestRemainingIds,
        configured: latestRemainingIds.length > 0,
        updatedAt: completedAt,
      });
      if (latestPreferenceSnapshot.exists) {
        transaction.update(preferenceRef, {
          "delivery.pushConfigured": latestRemainingIds.length > 0,
          "delivery.updatedAt": completedAt,
        });
      }
      transaction.update(jobRef, {
        ...result,
        invalidInstallationCount: confirmedInvalid.length,
        attemptCount: job.attemptCount,
        leaseUntil: null,
        completedAt,
        updatedAt: completedAt,
      });
      transaction.set(
        auditRef,
        pushDeliveryAudit({
          auditEventId: auditRef.id,
          jobId,
          recipientUserId,
          result: {
            ...result,
          invalidInstallationCount: confirmedInvalid.length,
          },
          now: completedAt,
        }),
      );
    });
    await releasePushDeliveryLeases({
      firestore,
      userIds: job.deliveryLeaseUserIds,
      jobId,
    });
    return result;
  };
}
