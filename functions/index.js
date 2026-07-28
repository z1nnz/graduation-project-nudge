import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { setGlobalOptions } from "firebase-functions/v2";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { ActivityLedgerService } from "./src/activity-ledger-service.js";
import { activityLedgerHttpsError } from "./src/activity-ledger-error-mapping.js";
import { FirestoreActivityLedgerStore } from "./src/firestore-activity-ledger-store.js";
import { createRecordActivityHandler } from "./src/record-activity-handler.js";

initializeApp();
setGlobalOptions({
  region: "asia-east1",
  maxInstances: 20,
});

const service = new ActivityLedgerService({
  store: new FirestoreActivityLedgerStore({ firestore: getFirestore() }),
});
const handleRecordActivity = createRecordActivityHandler({ service });

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
