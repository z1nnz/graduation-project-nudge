import { ActivityLedgerAuthenticationError } from "./activity-ledger-service.js";

export function createRecordActivityHandler({ service }) {
  return async function recordActivityRequest(request) {
    const userId = request?.auth?.uid;
    if (!userId) {
      throw new ActivityLedgerAuthenticationError(
        "An authenticated user is required.",
      );
    }
    return service.record(
      { kind: "user", userId },
      request?.data?.evidence,
    );
  };
}
