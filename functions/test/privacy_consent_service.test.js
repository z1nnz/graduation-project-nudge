import assert from "node:assert/strict";
import test from "node:test";

import {
  CURRENT_PRIVACY_POLICY_VERSION,
  createHealthConsentChecker,
  createRecordPrivacyConsentHandler,
  normalizePrivacyConsentRequest,
} from "../src/privacy-consent-service.js";

function fakeFirestore() {
  const documents = new Map();
  const reference = (collection, id) => ({
    id,
    path: `${collection}/${id}`,
  });
  return {
    documents,
    collection: collection => ({
      doc: id => ({
        ...reference(collection, id),
        get: async () => ({
          exists: documents.has(`${collection}/${id}`),
          data: () => documents.get(`${collection}/${id}`),
        }),
      }),
    }),
    runTransaction: async callback =>
      callback({
        get: async ref => ({
          exists: documents.has(ref.path),
          data: () => documents.get(ref.path),
        }),
        set: (ref, data) => documents.set(ref.path, structuredClone(data)),
        create: (ref, data) => {
          if (documents.has(ref.path)) throw new Error("already exists");
          documents.set(ref.path, structuredClone(data));
        },
      }),
  };
}

test("privacy consent input requires the current policy and stable request id", () => {
  assert.deepEqual(
    normalizePrivacyConsentRequest({
      action: "accept",
      policyVersion: CURRENT_PRIVACY_POLICY_VERSION,
      clientRequestId: "privacy-request-001",
      sourceSurface: "app",
    }),
    {
      action: "accept",
      policyVersion: CURRENT_PRIVACY_POLICY_VERSION,
      clientRequestId: "privacy-request-001",
      sourceSurface: "app",
    },
  );
  assert.throws(
    () =>
      normalizePrivacyConsentRequest({
        action: "accept",
        policyVersion: "old",
        clientRequestId: "privacy-request-001",
        sourceSurface: "app",
      }),
    error => error.code === "failed-precondition",
  );
});

test("privacy handler rejects unauthenticated callers before Firestore", async () => {
  const handler = createRecordPrivacyConsentHandler({
    firestore: null,
    clock: () => new Date(),
  });
  await assert.rejects(
    () =>
      handler({
        auth: null,
        data: {
          action: "accept",
          policyVersion: CURRENT_PRIVACY_POLICY_VERSION,
          clientRequestId: "privacy-request-001",
          sourceSurface: "app",
        },
      }),
    error => error.code === "unauthenticated",
  );
});

test("health consent checker fails closed", async () => {
  const checker = createHealthConsentChecker({
    firestore: {
      collection: () => ({
        doc: userId => ({
          get: async () => ({
            exists: userId === "accepted",
            data: () => ({
              status: "accepted",
              policyVersion: CURRENT_PRIVACY_POLICY_VERSION,
              scopes: { healthIngestion: true },
            }),
          }),
        }),
      }),
    },
  });

  assert.equal(await checker("accepted"), true);
  assert.equal(await checker("missing"), false);
});

test("privacy consent writes one current state and idempotent audit event", async () => {
  const firestore = fakeFirestore();
  const handler = createRecordPrivacyConsentHandler({
    firestore,
    clock: () => new Date("2026-07-29T00:00:00.000Z"),
  });
  const request = {
    auth: { uid: "user-one" },
    data: {
      action: "accept",
      policyVersion: CURRENT_PRIVACY_POLICY_VERSION,
      clientRequestId: "privacy-request-001",
      sourceSurface: "app",
    },
  };

  const first = await handler(request);
  const replay = await handler(request);

  assert.equal(first.replayed, false);
  assert.equal(replay.replayed, true);
  assert.equal(first.consent.status, "accepted");
  assert.equal(
    firestore.documents.get("privacy_consents/user-one").status,
    "accepted",
  );
  assert.equal(
    [...firestore.documents.keys()].filter(key =>
      key.startsWith("audit_events/"),
    ).length,
    1,
  );
});
