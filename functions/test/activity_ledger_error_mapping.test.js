import assert from "node:assert/strict";
import test from "node:test";

import {
  ActivityLedgerAuthenticationError,
  ActivityLedgerAuthorizationError,
  ActivityLedgerTemporarilyUnavailableError,
  ActivityLedgerValidationError,
} from "../src/activity-ledger-service.js";
import { activityLedgerHttpsError } from "../src/activity-ledger-error-mapping.js";

test("activity ingestion errors keep auth and retry semantics", () => {
  assert.equal(
    activityLedgerHttpsError(
      new ActivityLedgerAuthenticationError("Sign in first."),
    ).code,
    "unauthenticated",
  );
  assert.equal(
    activityLedgerHttpsError(
      new ActivityLedgerAuthorizationError("Not allowed."),
    ).code,
    "permission-denied",
  );
  assert.equal(
    activityLedgerHttpsError(
      new ActivityLedgerValidationError("Bad evidence."),
    ).code,
    "invalid-argument",
  );
  assert.equal(
    activityLedgerHttpsError(
      new ActivityLedgerTemporarilyUnavailableError("Cutover active."),
    ).code,
    "unavailable",
  );
  assert.equal(
    activityLedgerHttpsError(
      Object.assign(new Error("Retry the transaction."), { code: 10 }),
    ).code,
    "aborted",
  );
  assert.equal(
    activityLedgerHttpsError(
      Object.assign(new Error("Backend unavailable."), {
        code: "unavailable",
      }),
    ).code,
    "unavailable",
  );
  assert.equal(activityLedgerHttpsError(new Error("Unexpected.")), null);
});
