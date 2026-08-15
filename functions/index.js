import { randomUUID } from "node:crypto";

import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { getStorage } from "firebase-admin/storage";
import { setGlobalOptions } from "firebase-functions/v2";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import {
  onDocumentCreatedWithAuthContext,
  onDocumentUpdatedWithAuthContext,
  onDocumentCreated,
} from "firebase-functions/v2/firestore";

import { ActivityLedgerService } from "./src/activity-ledger-service.js";
import { activityLedgerHttpsError } from "./src/activity-ledger-error-mapping.js";
import { FirestoreActivityLedgerStore } from "./src/firestore-activity-ledger-store.js";
import { createIngestHealthSnapshotsHandler } from "./src/ingest-health-snapshots-handler.js";
import { createRecordActivityHandler } from "./src/record-activity-handler.js";
import { createRefreshRelationshipOutcomeHandler } from "./src/relationship-outcome-service.js";
import {
  createRefreshDisciplineIdentityHandler,
  FirestoreDisciplineIdentityRepository,
} from "./src/discipline-identity-service.js";
import {
  createHealthConsentChecker,
  createRecordPrivacyConsentHandler,
} from "./src/privacy-consent-service.js";
import { createUpdateNotificationPreferencesHandler } from "./src/notification-preference-service.js";
import {
  createMarkNotificationReadHandler,
  createRelationshipRequestCreatedHandler,
  createRelationshipRequestUpdatedHandler,
} from "./src/user-notification-service.js";
import { createManageCatalogItemHandler } from "./src/catalog-management-service.js";
import { createPurchaseRewardItemHandler } from "./src/reward-purchase-service.js";
import { createEquipRewardAvatarHandler } from "./src/reward-avatar-service.js";
import {
  createDeliverPushJobHandler,
  createUpdatePushInstallationHandler,
} from "./src/push-notification-service.js";
import {
  createCancelPrivacyDataRequestHandler,
  createCleanupExpiredPrivacyExportsHandler,
  createGetPrivacyExportDownloadHandler,
  createManagePrivacyDataRequestHandler,
  createRequestPrivacyDataActionHandler,
} from "./src/privacy-data-request-service.js";
import {
  createCleanupExpiredAccountDeletionEvidenceHandler,
  createExecuteAccountDeletionHandler,
} from "./src/account-deletion-service.js";
import { FirestoreAccountDeletionRepository } from
  "./src/firestore-account-deletion-repository.js";

initializeApp();
setGlobalOptions({
  region: "asia-east1",
  maxInstances: 20,
});

const ACCOUNT_OPERATION_LEASE_MS = 3 * 60 * 1000;

async function assertAccountNotDeleting(request) {
  const userId = request.auth?.uid;
  if (!userId) return async () => {};
  const firestore = getFirestore();
  const fenceRef = firestore.collection("account_deletion_fences").doc(userId);
  const leaseRef = firestore.collection("account_operation_leases").doc(userId);
  const operationId = randomUUID();
  const startedAt = new Date();
  const expiresAt = new Date(
    startedAt.getTime() + ACCOUNT_OPERATION_LEASE_MS,
  ).toISOString();
  await firestore.runTransaction(async transaction => {
    const [fence, lease] = await Promise.all([
      transaction.get(fenceRef),
      transaction.get(leaseRef),
    ]);
    if (fence.exists) {
      throw new HttpsError(
        "failed-precondition",
        "This account is locked for verified deletion.",
      );
    }
    const operations = Object.fromEntries(
      Object.entries(lease.exists ? lease.data().operations ?? {} : {})
        .filter(([, value]) => Date.parse(value) > startedAt.getTime()),
    );
    operations[operationId] = expiresAt;
    transaction.set(leaseRef, {
      schemaVersion: 1,
      userId,
      operations,
      updatedAt: startedAt.toISOString(),
    }, { merge: false });
  });
  return async () => {
    await firestore.runTransaction(async transaction => {
      const lease = await transaction.get(leaseRef);
      if (!lease.exists) return;
      const operations = { ...(lease.data().operations ?? {}) };
      delete operations[operationId];
      if (Object.keys(operations).length === 0) {
        transaction.delete(leaseRef);
      } else {
        transaction.update(leaseRef, {
          operations,
          updatedAt: new Date().toISOString(),
        });
      }
    });
  };
}

async function withAccountOperation(request, operation) {
  const release = await assertAccountNotDeleting(request);
  try {
    return await operation();
  } finally {
    try {
      await release();
    } catch (error) {
      console.error("Account operation lease release failed", {
        code: error?.code ?? "unknown",
      });
    }
  }
}

const service = new ActivityLedgerService({
  store: new FirestoreActivityLedgerStore({ firestore: getFirestore() }),
});
const handleRecordActivity = createRecordActivityHandler({ service });
const handleIngestHealthSnapshots = createIngestHealthSnapshotsHandler({
  service,
  requireHealthConsent: createHealthConsentChecker({
    firestore: getFirestore(),
  }),
});
const handleRefreshRelationshipOutcome =
  createRefreshRelationshipOutcomeHandler({
    firestore: getFirestore(),
  });
const handleRefreshDisciplineIdentity =
  createRefreshDisciplineIdentityHandler({
    repository: new FirestoreDisciplineIdentityRepository({
      firestore: getFirestore(),
    }),
  });
const handleRecordPrivacyConsent = createRecordPrivacyConsentHandler({
  firestore: getFirestore(),
  clock: () => new Date(),
});
const handleUpdateNotificationPreferences =
  createUpdateNotificationPreferencesHandler({
    firestore: getFirestore(),
    clock: () => new Date(),
  });
const handleMarkNotificationRead = createMarkNotificationReadHandler({
  firestore: getFirestore(),
  clock: () => new Date(),
});
const handleManageCatalogItem = createManageCatalogItemHandler({
  firestore: getFirestore(),
  clock: () => new Date(),
});
const handlePurchaseRewardItem = createPurchaseRewardItemHandler({
  firestore: getFirestore(),
  clock: () => new Date(),
});
const handleEquipRewardAvatar = createEquipRewardAvatarHandler({
  firestore: getFirestore(),
  clock: () => new Date(),
});
const handleUpdatePushInstallation = createUpdatePushInstallationHandler({
  firestore: getFirestore(),
  clock: () => new Date(),
});
const handleDeliverPushJob = createDeliverPushJobHandler({
  firestore: getFirestore(),
  messaging: getMessaging(),
  clock: () => new Date(),
});
const privacyExportBucket = getStorage().bucket();
const handleRequestPrivacyDataAction =
  createRequestPrivacyDataActionHandler({
    firestore: getFirestore(),
    bucket: privacyExportBucket,
    clock: () => new Date(),
  });
const handleCancelPrivacyDataRequest =
  createCancelPrivacyDataRequestHandler({
    firestore: getFirestore(),
    clock: () => new Date(),
  });
const handleGetPrivacyExportDownload =
  createGetPrivacyExportDownloadHandler({
    firestore: getFirestore(),
    bucket: privacyExportBucket,
    clock: () => new Date(),
  });
const handleManagePrivacyDataRequest =
  createManagePrivacyDataRequestHandler({
    firestore: getFirestore(),
    clock: () => new Date(),
  });
const handleCleanupExpiredPrivacyExports =
  createCleanupExpiredPrivacyExportsHandler({
    firestore: getFirestore(),
    bucket: privacyExportBucket,
    clock: () => new Date(),
  });
const handleExecuteAccountDeletion = createExecuteAccountDeletionHandler({
  repository: new FirestoreAccountDeletionRepository({
    firestore: getFirestore(),
    auth: getAuth(),
    bucket: privacyExportBucket,
  }),
  clock: () => new Date(),
});
const handleCleanupExpiredAccountDeletionEvidence =
  createCleanupExpiredAccountDeletionEvidenceHandler({
    repository: new FirestoreAccountDeletionRepository({
      firestore: getFirestore(),
      auth: getAuth(),
      bucket: privacyExportBucket,
    }),
    clock: () => new Date(),
  });
const handleGuardianRequestCreated = createRelationshipRequestCreatedHandler({
  firestore: getFirestore(),
  scopeType: "family",
});
const handleGuardianRequestUpdated = createRelationshipRequestUpdatedHandler({
  firestore: getFirestore(),
  scopeType: "family",
});
const handleGroupRequestCreated = createRelationshipRequestCreatedHandler({
  firestore: getFirestore(),
  scopeType: "group",
});
const handleGroupRequestUpdated = createRelationshipRequestUpdatedHandler({
  firestore: getFirestore(),
  scopeType: "group",
});

export const recordActivity = onCall(
  {
    enforceAppCheck: true,
    timeoutSeconds: 30,
    memory: "256MiB",
  },
  async request => {
    try {
      return await withAccountOperation(
        request,
        () => handleRecordActivity(request),
      );
    } catch (error) {
      const mappedError = activityLedgerHttpsError(error);
      if (mappedError) {
        throw mappedError;
      }
      console.error("recordActivity failed", error);
      throw new HttpsError(
        "internal",
        "The activity could not be recorded.",
      );
    }
  },
);

export const ingestHealthSnapshots = onCall(
  {
    enforceAppCheck: true,
    timeoutSeconds: 60,
    memory: "256MiB",
  },
  async request => {
    try {
      return await withAccountOperation(
        request,
        () => handleIngestHealthSnapshots(request),
      );
    } catch (error) {
      const mappedError = activityLedgerHttpsError(error);
      if (mappedError) {
        throw mappedError;
      }
      console.error("ingestHealthSnapshots failed", error);
      throw new HttpsError(
        "internal",
        "The health snapshots could not be ingested.",
      );
    }
  },
);

export const refreshRelationshipOutcome = onCall(
  {
    enforceAppCheck: true,
    timeoutSeconds: 30,
    memory: "256MiB",
  },
  async request => {
    try {
      return await withAccountOperation(
        request,
        () => handleRefreshRelationshipOutcome(request),
      );
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      console.error("refreshRelationshipOutcome failed", error);
      throw new HttpsError(
        "internal",
        "The relationship outcome could not be refreshed.",
      );
    }
  },
);

export const refreshDisciplineIdentity = onCall(
  {
    enforceAppCheck: true,
    timeoutSeconds: 30,
    memory: "256MiB",
  },
  async request => {
    try {
      return await withAccountOperation(
        request,
        () => handleRefreshDisciplineIdentity(request),
      );
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      console.error("refreshDisciplineIdentity failed", error);
      throw new HttpsError(
        "internal",
        "The discipline identity could not be refreshed.",
      );
    }
  },
);

export const recordPrivacyConsent = onCall(
  {
    enforceAppCheck: true,
    timeoutSeconds: 30,
    memory: "256MiB",
  },
  async request => {
    try {
      return await withAccountOperation(
        request,
        () => handleRecordPrivacyConsent(request),
      );
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      console.error("recordPrivacyConsent failed", error);
      throw new HttpsError(
        "internal",
        "The privacy consent could not be recorded.",
      );
    }
  },
);

export const updateNotificationPreferences = onCall(
  {
    enforceAppCheck: true,
    timeoutSeconds: 30,
    memory: "256MiB",
  },
  async request => {
    try {
      return await withAccountOperation(
        request,
        () => handleUpdateNotificationPreferences(request),
      );
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      console.error("updateNotificationPreferences failed", error);
      throw new HttpsError(
        "internal",
        "The notification preferences could not be updated.",
      );
    }
  },
);

export const markNotificationRead = onCall(
  {
    enforceAppCheck: true,
    timeoutSeconds: 30,
    memory: "256MiB",
  },
  async request => {
    try {
      return await withAccountOperation(
        request,
        () => handleMarkNotificationRead(request),
      );
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      console.error("markNotificationRead failed", error);
      throw new HttpsError(
        "internal",
        "The notification could not be updated.",
      );
    }
  },
);

export const manageCatalogItem = onCall(
  {
    enforceAppCheck: true,
    timeoutSeconds: 60,
    memory: "256MiB",
  },
  async request => {
    try {
      return await handleManageCatalogItem(request);
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      console.error("manageCatalogItem failed", error);
      throw new HttpsError(
        "internal",
        "The catalog item could not be updated.",
      );
    }
  },
);

export const purchaseRewardItem = onCall(
  {
    enforceAppCheck: true,
    timeoutSeconds: 30,
    memory: "256MiB",
  },
  async request => {
    try {
      return await withAccountOperation(
        request,
        () => handlePurchaseRewardItem(request),
      );
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      console.error("purchaseRewardItem failed", error);
      throw new HttpsError("internal", "The reward item could not be purchased.");
    }
  },
);

export const equipRewardAvatar = onCall(
  {
    enforceAppCheck: true,
    timeoutSeconds: 30,
    memory: "256MiB",
  },
  async request => {
    try {
      return await withAccountOperation(
        request,
        () => handleEquipRewardAvatar(request),
      );
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      console.error("equipRewardAvatar failed", error);
      throw new HttpsError("internal", "The avatar equipment could not be saved.");
    }
  },
);

export const updatePushInstallation = onCall(
  {
    enforceAppCheck: true,
    timeoutSeconds: 30,
    memory: "256MiB",
  },
  async request => {
    try {
      return await withAccountOperation(
        request,
        () => handleUpdatePushInstallation(request),
      );
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      console.error("updatePushInstallation failed", error);
      throw new HttpsError(
        "internal",
        "The push installation could not be updated.",
      );
    }
  },
);

export const requestPrivacyDataAction = onCall(
  {
    enforceAppCheck: true,
    timeoutSeconds: 120,
    memory: "512MiB",
  },
  async request => {
    try {
      return await withAccountOperation(
        request,
        () => handleRequestPrivacyDataAction(request),
      );
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      console.error("requestPrivacyDataAction failed", error);
      throw new HttpsError(
        "internal",
        "The privacy data request could not be created.",
      );
    }
  },
);

export const cancelPrivacyDataRequest = onCall(
  {
    enforceAppCheck: true,
    timeoutSeconds: 30,
    memory: "256MiB",
  },
  async request => {
    try {
      return await withAccountOperation(
        request,
        () => handleCancelPrivacyDataRequest(request),
      );
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      console.error("cancelPrivacyDataRequest failed", error);
      throw new HttpsError(
        "internal",
        "The privacy data request could not be cancelled.",
      );
    }
  },
);

export const getPrivacyExportDownload = onCall(
  {
    enforceAppCheck: true,
    timeoutSeconds: 30,
    memory: "256MiB",
  },
  async request => {
    try {
      return await withAccountOperation(
        request,
        () => handleGetPrivacyExportDownload(request),
      );
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      console.error("getPrivacyExportDownload failed", error);
      throw new HttpsError(
        "internal",
        "The privacy export could not be downloaded.",
      );
    }
  },
);

export const managePrivacyDataRequest = onCall(
  {
    enforceAppCheck: true,
    timeoutSeconds: 30,
    memory: "256MiB",
  },
  async request => {
    try {
      return await handleManagePrivacyDataRequest(request);
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      console.error("managePrivacyDataRequest failed", error);
      throw new HttpsError(
        "internal",
        "The privacy data request could not be managed.",
      );
    }
  },
);

export const executeAccountDeletion = onCall(
  {
    enforceAppCheck: true,
    timeoutSeconds: 540,
    memory: "1GiB",
  },
  async request => {
    try {
      return await handleExecuteAccountDeletion(request);
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      console.error("executeAccountDeletion failed", error);
      throw new HttpsError(
        "internal",
        "The account deletion execution did not complete.",
      );
    }
  },
);

export const cleanupExpiredPrivacyExports = onSchedule(
  {
    schedule: "every day 03:00",
    timeZone: "Asia/Taipei",
    timeoutSeconds: 120,
    memory: "256MiB",
  },
  async () => {
    try {
      return await handleCleanupExpiredPrivacyExports();
    } catch (error) {
      console.error("cleanupExpiredPrivacyExports failed", error);
      throw error;
    }
  },
);

export const cleanupExpiredAccountDeletionEvidence = onSchedule(
  {
    schedule: "every day 03:30",
    timeZone: "Asia/Taipei",
    timeoutSeconds: 120,
    memory: "256MiB",
  },
  async () => {
    try {
      return await handleCleanupExpiredAccountDeletionEvidence();
    } catch (error) {
      console.error("cleanupExpiredAccountDeletionEvidence failed", error);
      throw error;
    }
  },
);

export const notifyGuardianRequestCreated =
  onDocumentCreatedWithAuthContext(
    "guardian_requests/{requestId}",
    handleGuardianRequestCreated,
  );

export const notifyGuardianRequestUpdated =
  onDocumentUpdatedWithAuthContext(
    "guardian_requests/{requestId}",
    handleGuardianRequestUpdated,
  );

export const notifyGroupRequestCreated =
  onDocumentCreatedWithAuthContext(
    "group_requests/{requestId}",
    handleGroupRequestCreated,
  );

export const notifyGroupRequestUpdated =
  onDocumentUpdatedWithAuthContext(
    "group_requests/{requestId}",
    handleGroupRequestUpdated,
  );

export const deliverPushNotification = onDocumentCreated(
  {
    document: "push_delivery_jobs/{jobId}",
    retry: true,
    timeoutSeconds: 60,
    memory: "256MiB",
  },
  handleDeliverPushJob,
);
