import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { setGlobalOptions } from "firebase-functions/v2";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { ActivityLedgerService } from "./src/activity-ledger-service.js";
import { activityLedgerHttpsError } from "./src/activity-ledger-error-mapping.js";
import { FirestoreActivityLedgerStore } from "./src/firestore-activity-ledger-store.js";
import { createIngestHealthSnapshotsHandler } from "./src/ingest-health-snapshots-handler.js";
import { createRecordActivityHandler } from "./src/record-activity-handler.js";
import { createRefreshRelationshipOutcomeHandler } from "./src/relationship-outcome-service.js";

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
});
const handleRefreshRelationshipOutcome =
  createRefreshRelationshipOutcomeHandler({
    firestore: getFirestore(),
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
