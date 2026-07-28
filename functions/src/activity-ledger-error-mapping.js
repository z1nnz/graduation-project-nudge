import { HttpsError } from "firebase-functions/v2/https";

import {
  ActivityLedgerAuthenticationError,
  ActivityLedgerAuthorizationError,
  ActivityLedgerValidationError,
} from "./activity-ledger-service.js";

const GRPC_RETRYABLE_CODES = new Map([
  [4, "deadline-exceeded"],
  [8, "resource-exhausted"],
  [10, "aborted"],
  [14, "unavailable"],
]);
const RETRYABLE_CODES = new Set([
  "aborted",
  "deadline-exceeded",
  "resource-exhausted",
  "unavailable",
]);

function retryableCode(error) {
  if (GRPC_RETRYABLE_CODES.has(error?.code)) {
    return GRPC_RETRYABLE_CODES.get(error.code);
  }
  if (typeof error?.code !== "string") {
    return null;
  }
  const code = error.code
    .replace(/^firestore\//, "")
    .replace(/^functions\//, "");
  return RETRYABLE_CODES.has(code) ? code : null;
}

export function activityLedgerHttpsError(error) {
  if (error instanceof ActivityLedgerAuthenticationError) {
    return new HttpsError("unauthenticated", error.message);
  }
  if (error instanceof ActivityLedgerAuthorizationError) {
    return new HttpsError("permission-denied", error.message);
  }
  if (error instanceof ActivityLedgerValidationError) {
    return new HttpsError("invalid-argument", error.message);
  }
  const code = retryableCode(error);
  if (code) {
    return new HttpsError(
      code,
      "The activity ledger is temporarily unavailable. Retry this event.",
    );
  }
  return null;
}
