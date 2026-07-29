import { initializeApp } from "firebase-admin/app";
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

initializeApp();
setGlobalOptions({
  region: "asia-east1",
  maxInstances: 20,
});

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
      return await handleRecordActivity(request);
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
      return await handleIngestHealthSnapshots(request);
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
      return await handleRefreshRelationshipOutcome(request);
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

export const recordPrivacyConsent = onCall(
  {
    enforceAppCheck: true,
    timeoutSeconds: 30,
    memory: "256MiB",
  },
  async request => {
    try {
      return await handleRecordPrivacyConsent(request);
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
      return await handleUpdateNotificationPreferences(request);
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
      return await handleMarkNotificationRead(request);
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

export const updatePushInstallation = onCall(
  {
    enforceAppCheck: true,
    timeoutSeconds: 30,
    memory: "256MiB",
  },
  async request => {
    try {
      return await handleUpdatePushInstallation(request);
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
      return await handleRequestPrivacyDataAction(request);
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
      return await handleCancelPrivacyDataRequest(request);
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
      return await handleGetPrivacyExportDownload(request);
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
