import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { setGlobalOptions } from "firebase-functions/v2";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import {
  onDocumentCreatedWithAuthContext,
  onDocumentUpdatedWithAuthContext,
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
