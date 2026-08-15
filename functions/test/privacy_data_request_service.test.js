import assert from "node:assert/strict";
import test from "node:test";

import {
  buildRelationshipScopeExport,
  collectPrivacyExportData,
  collectQueryDocuments,
  createCancelPrivacyDataRequestHandler,
  createCleanupExpiredPrivacyExportsHandler,
  createGetPrivacyExportDownloadHandler,
  createManagePrivacyDataRequestHandler,
  createRequestPrivacyDataActionHandler,
  normalizePrivacyDataRequest,
} from "../src/privacy-data-request-service.js";

function fakeExportFirestore(seed = {}) {
  const snapshot = record => ({
    id: record.id,
    exists: true,
    data: () => structuredClone(record.data),
  });
  const queryFor = records => ({
    orderBy() {
      return {
        limit(limit) {
          return {
            async get() {
              const docs = records.slice(0, limit).map(snapshot);
              return { docs, size: docs.length };
            },
          };
        },
      };
    },
  });
  return {
    collection(name) {
      const records = seed[name] ?? [];
      return {
        ...queryFor(records),
        doc(id) {
          return {
            async get() {
              const record = records.find(item => item.id === id);
              return record
                ? snapshot(record)
                : { id, exists: false, data: () => undefined };
            },
          };
        },
        where(field, operator, value) {
          const filtered = records.filter(record => {
            if (operator === "==") return record.data[field] === value;
            if (operator === "array-contains") {
              return Array.isArray(record.data[field]) &&
                record.data[field].includes(value);
            }
            throw new Error(`Unsupported fake export operator: ${operator}`);
          });
          return queryFor(filtered);
        },
      };
    },
  };
}

function fakePagedQuery(count) {
  const source = Array.from({ length: count }, (_, index) => ({
    id: `doc-${String(index).padStart(4, "0")}`,
    data: () => ({ index }),
  }));
  return {
    orderBy() {
      return {
        limit(pageSize) {
          let cursorId = "";
          return {
            startAfter(cursor) {
              cursorId = cursor.id;
              return this;
            },
            async get() {
              const start = cursorId
                ? source.findIndex(document => document.id === cursorId) + 1
                : 0;
              const docs = source.slice(start, start + pageSize);
              return { docs, size: docs.length };
            },
          };
        },
      };
    },
  };
}

function fakeFirestore(seed = {}) {
  const documents = new Map(
    Object.entries(seed).map(([path, data]) => [path, structuredClone(data)]),
  );
  const documentReference = (collection, id) => ({
    id,
    path: `${collection}/${id}`,
    async get() {
      return snapshotFor(this);
    },
  });
  const snapshotFor = ref => ({
    id: ref.id,
    exists: documents.has(ref.path),
    data: () => structuredClone(documents.get(ref.path)),
  });
  return {
    documents,
    collection: collection => {
      const query = {
        where(field, operator, value) {
          assert.equal(operator, "<=");
          return {
            limit(limit) {
              return {
                async get() {
                  const docs = [...documents.entries()]
                    .filter(([path, data]) =>
                      path.startsWith(`${collection}/`) &&
                      !path.slice(collection.length + 1).includes("/") &&
                      data[field] <= value
                    )
                    .slice(0, limit)
                    .map(([path]) => {
                      const id = path.slice(collection.length + 1);
                      return snapshotFor(documentReference(collection, id));
                    });
                  return { docs, size: docs.length };
                },
              };
            },
          };
        },
      };
      return {
        ...query,
        doc: id => documentReference(collection, id),
      };
    },
    runTransaction: async callback =>
      callback({
        get: async ref => snapshotFor(ref),
        create: (ref, data) => {
          if (documents.has(ref.path)) throw new Error("already exists");
          documents.set(ref.path, structuredClone(data));
        },
        set: (ref, data) => documents.set(ref.path, structuredClone(data)),
        update: (ref, patch) => {
          const current = documents.get(ref.path);
          if (!current) throw new Error(`missing ${ref.path}`);
          documents.set(ref.path, { ...current, ...structuredClone(patch) });
        },
        delete: ref => documents.delete(ref.path),
      }),
  };
}

function fakeBucket() {
  const files = new Map();
  return {
    name: "nudge-test.appspot.com",
    files,
    file: path => ({
      async save(body, options) {
        files.set(path, {
          body: body.toString(),
          metadata: structuredClone(options.metadata),
        });
      },
      async delete() {
        files.delete(path);
      },
    }),
  };
}

test("privacy data requests validate action, surface and stable request id", () => {
  assert.deepEqual(
    normalizePrivacyDataRequest({
      action: "request_export",
      clientRequestId: "privacy-data-001",
      sourceSurface: "app",
    }),
    {
      action: "request_export",
      clientRequestId: "privacy-data-001",
      sourceSurface: "app",
      reason: "",
    },
  );
  assert.throws(
    () =>
      normalizePrivacyDataRequest({
        action: "delete_now",
        clientRequestId: "privacy-data-001",
        sourceSurface: "app",
      }),
    error => error.code === "invalid-argument",
  );
});

test("privacy export queries paginate until every document is collected", async () => {
  const documents = await collectQueryDocuments(fakePagedQuery(1_001));
  assert.equal(documents.length, 1_001);
  assert.equal(documents[0].id, "doc-0000");
  assert.equal(documents.at(-1).id, "doc-1000");
});

test("relationship export DTO omits other participants and private fields", () => {
  const exported = buildRelationshipScopeExport({
    id: "group--study--user-one",
    data: {
      scopeType: "group",
      scopeId: "study",
      scopeName: "讀書會",
      userId: "user-one",
      role: "member",
      status: "active",
      activeFrom: "2026-07-01T00:00:00.000Z",
      memberIds: ["user-one", "other-user"],
      ownerId: "other-user",
      inviteCode: "private-code",
    },
  });

  assert.deepEqual(exported, {
    id: "study",
    data: {
      schemaVersion: 1,
      scopeType: "group",
      scopeId: "study",
      scopeName: "讀書會",
      requesterRole: "member",
      status: "active",
      activeFrom: "2026-07-01T00:00:00.000Z",
      activeUntil: null,
    },
  });
  assert.equal(JSON.stringify(exported).includes("other-user"), false);
  assert.equal(JSON.stringify(exported).includes("private-code"), false);
});

test("privacy export includes only the requester's relationship migration before-images", async () => {
  const firestore = fakeExportFirestore({
    relationship_migration_before_images: [
      {
        id: "run--owned",
        data: {
          migrationRunId: "run-1",
          actorUserId: "user-one",
          entityType: "user_projection",
          beforeFields: [{ path: "groupId", present: true, value: "group-1" }],
        },
      },
      {
        id: "run--other",
        data: {
          migrationRunId: "run-1",
          actorUserId: "other-user",
          entityType: "membership",
        },
      },
    ],
  });

  const result = await collectPrivacyExportData({
    firestore,
    userId: "user-one",
  });

  assert.deepEqual(
    result.collections.relationship_migration_before_images,
    [
      {
        id: "run--owned",
        data: {
          migrationRunId: "run-1",
          actorUserId: "user-one",
          entityType: "user_projection",
          beforeFields: [{ path: "groupId", present: true, value: "group-1" }],
        },
      },
    ],
  );
});

test("privacy export includes the requester's private discipline identity", async () => {
  const firestore = fakeExportFirestore({
    discipline_identity_snapshots: [
      {
        id: "user-one",
        data: {
          schemaVersion: 1,
          userId: "user-one",
          visibility: "private",
          personaKey: "steady_builder",
          evidenceWindowDays: 28,
        },
      },
      {
        id: "other-user",
        data: {
          schemaVersion: 1,
          userId: "other-user",
          visibility: "private",
          personaKey: "pathfinder",
          evidenceWindowDays: 28,
        },
      },
    ],
  });

  const result = await collectPrivacyExportData({
    firestore,
    userId: "user-one",
  });

  assert.deepEqual(result.collections.discipline_identity_snapshots, [
    {
      id: "user-one",
      data: {
        schemaVersion: 1,
        userId: "user-one",
        visibility: "private",
        personaKey: "steady_builder",
        evidenceWindowDays: 28,
      },
    },
  ]);
});

test("export request creates a private artifact, owner state and immutable audit", async () => {
  const firestore = fakeFirestore();
  const bucket = fakeBucket();
  const handler = createRequestPrivacyDataActionHandler({
    firestore,
    bucket,
    clock: () => new Date("2026-07-29T03:00:00.000Z"),
    randomToken: () => "download-token-12345678",
    collectUserData: async userId => ({
      schemaVersion: 1,
      userId,
      collections: {
        account: [{ id: userId, data: { nickname: "小樹" } }],
      },
      truncatedCollections: [],
    }),
  });
  const request = {
    auth: { uid: "user-one" },
    data: {
      action: "request_export",
      clientRequestId: "privacy-data-001",
      sourceSurface: "app",
    },
  };

  const first = await handler(request);
  const replay = await handler(request);

  assert.equal(first.replayed, false);
  assert.equal(replay.replayed, true);
  assert.equal(first.request.type, "export");
  assert.equal(first.request.status, "ready");
  assert.equal(first.request.userId, "user-one");
  assert.equal(first.request.downloadTokenHash.length, 64);
  assert.equal("downloadToken" in first.request, false);
  assert.equal(bucket.files.size, 1);
  const [storagePath, stored] = [...bucket.files.entries()][0];
  assert.match(storagePath, /^privacy_exports\/user-one\//);
  assert.equal(stored.metadata.metadata.ownerUserId, "user-one");
  assert.match(stored.body, /"nickname": "小樹"/);
  assert.equal(
    firestore.documents.get(
      "privacy_data_requests/user-one--privacy-data-001",
    ).status,
    "ready",
  );
  assert.equal(
    firestore.documents.get(
      "privacy_export_access/user-one--privacy-data-001",
    ).downloadToken,
    "download-token-12345678",
  );
  assert.equal(
    [...firestore.documents.keys()].filter(path =>
      path.startsWith("audit_events/"),
    ).length,
    1,
  );
});

test("export generation failure revokes its token and records a terminal state", async () => {
  const firestore = fakeFirestore();
  const bucket = fakeBucket();
  const handler = createRequestPrivacyDataActionHandler({
    firestore,
    bucket,
    clock: () => new Date("2026-07-29T03:00:00.000Z"),
    randomToken: () => "download-token-12345678",
    collectUserData: async () => {
      throw new Error("simulated export failure with private detail");
    },
  });

  await assert.rejects(() =>
    handler({
      auth: { uid: "user-one" },
      data: {
        action: "request_export",
        clientRequestId: "privacy-data-failed-001",
        sourceSurface: "app",
      },
    })
  );

  const request = firestore.documents.get(
    "privacy_data_requests/user-one--privacy-data-failed-001",
  );
  const audit = firestore.documents.get(
    "audit_events/privacy-data--user-one--privacy-data-failed-001",
  );
  assert.equal(request.status, "failed");
  assert.equal(request.expiresAt, null);
  assert.equal(
    firestore.documents.has(
      "privacy_export_access/user-one--privacy-data-failed-001",
    ),
    false,
  );
  assert.equal(audit.result.request.status, "failed");
  assert.equal(
    JSON.stringify(audit).includes("private detail"),
    false,
  );
});

test("account deletion request is pending, review-delayed and cancellable", async () => {
  const firestore = fakeFirestore();
  const bucket = fakeBucket();
  const handler = createRequestPrivacyDataActionHandler({
    firestore,
    bucket,
    clock: () => new Date("2026-07-29T03:00:00.000Z"),
  });

  const created = await handler({
    auth: { uid: "user-one" },
    data: {
      action: "request_account_deletion",
      clientRequestId: "privacy-delete-001",
      sourceSurface: "web",
      reason: "不再使用",
    },
  });

  assert.equal(created.request.type, "account_deletion");
  assert.equal(created.request.status, "pending");
  assert.equal(
    created.request.reviewAfter,
    "2026-08-05T03:00:00.000Z",
  );

  const cancel = createCancelPrivacyDataRequestHandler({
    firestore,
    clock: () => new Date("2026-07-30T03:00:00.000Z"),
  });
  const cancelled = await cancel({
    auth: { uid: "user-one" },
    data: {
      requestId: created.request.requestId,
      clientRequestId: "privacy-cancel-001",
      sourceSurface: "app",
    },
  });

  assert.equal(cancelled.request.status, "cancelled");
  assert.equal(cancelled.auditEventId.endsWith("privacy-cancel-001"), true);
});

test("export download returns an expiring artifact URL without auditing its token", async () => {
  const requestId = "user-one--privacy-data-001";
  const token = "private-download-token-12345678";
  const firestore = fakeFirestore({
    [`privacy_data_requests/${requestId}`]: {
      schemaVersion: 1,
      requestId,
      userId: "user-one",
      type: "export",
      status: "ready",
      storagePath: `privacy_exports/user-one/${requestId}.json`,
      expiresAt: "2026-08-05T03:00:00.000Z",
      downloadTokenHash:
        "aa2d45aa36f9193f5da4b50f1e56d3a88279a3195fd930e7fc1aef2a7f0d93aa",
    },
    [`privacy_export_access/${requestId}`]: {
      requestId,
      userId: "user-one",
      storagePath: `privacy_exports/user-one/${requestId}.json`,
      expiresAt: "2026-08-05T03:00:00.000Z",
      downloadToken: token,
    },
  });
  // Keep the fixture hash coupled to the actual token without exposing a
  // production implementation helper.
  const { createHash } = await import("node:crypto");
  firestore.documents.get(
    `privacy_data_requests/${requestId}`,
  ).downloadTokenHash = createHash("sha256").update(token).digest("hex");
  const handler = createGetPrivacyExportDownloadHandler({
    firestore,
    bucket: fakeBucket(),
    clock: () => new Date("2026-07-30T03:00:00.000Z"),
  });

  const result = await handler({
    auth: { uid: "user-one" },
    data: {
      requestId,
      clientRequestId: "privacy-download-001",
      sourceSurface: "web",
    },
  });

  assert.match(result.downloadUrl, /firebasestorage\.googleapis\.com/);
  assert.match(result.downloadUrl, /private-download-token-12345678/);
  const audit = firestore.documents.get(
    "audit_events/privacy-data-download--user-one--privacy-download-001",
  );
  assert.equal(JSON.stringify(audit).includes(token), false);

  const secondRequestId = "user-one--privacy-data-002";
  const secondToken = "second-download-token-12345678";
  firestore.documents.set(`privacy_data_requests/${secondRequestId}`, {
    ...firestore.documents.get(`privacy_data_requests/${requestId}`),
    requestId: secondRequestId,
    storagePath: `privacy_exports/user-one/${secondRequestId}.json`,
    downloadTokenHash: createHash("sha256").update(secondToken).digest("hex"),
  });
  firestore.documents.set(`privacy_export_access/${secondRequestId}`, {
    requestId: secondRequestId,
    userId: "user-one",
    storagePath: `privacy_exports/user-one/${secondRequestId}.json`,
    expiresAt: "2026-08-05T03:00:00.000Z",
    downloadToken: secondToken,
  });
  await assert.rejects(
    () =>
      handler({
        auth: { uid: "user-one" },
        data: {
          requestId: secondRequestId,
          clientRequestId: "privacy-download-001",
          sourceSurface: "web",
        },
      }),
    error => error.code === "already-exists",
  );
});

test("expired exports are deleted and their access tokens are revoked", async () => {
  const requestId = "user-one--privacy-data-001";
  const storagePath = `privacy_exports/user-one/${requestId}.json`;
  const firestore = fakeFirestore({
    [`privacy_data_requests/${requestId}`]: {
      schemaVersion: 1,
      requestId,
      userId: "user-one",
      type: "export",
      status: "ready",
      storagePath,
      expiresAt: "2026-07-29T02:00:00.000Z",
    },
    [`privacy_export_access/${requestId}`]: {
      requestId,
      userId: "user-one",
      storagePath,
      downloadToken: "private-download-token-12345678",
    },
  });
  const bucket = fakeBucket();
  bucket.files.set(storagePath, { body: "{}", metadata: {} });
  const cleanup = createCleanupExpiredPrivacyExportsHandler({
    firestore,
    bucket,
    clock: () => new Date("2026-07-30T03:00:00.000Z"),
  });

  const result = await cleanup();

  assert.deepEqual(result, { scanned: 1, expired: 1 });
  assert.equal(bucket.files.has(storagePath), false);
  assert.equal(
    firestore.documents.get(`privacy_data_requests/${requestId}`).status,
    "expired",
  );
  assert.equal(
    firestore.documents.get(`privacy_data_requests/${requestId}`).expiresAt,
    null,
  );
  assert.equal(
    firestore.documents.has(`privacy_export_access/${requestId}`),
    false,
  );
  assert.equal(
    firestore.documents.has(`audit_events/privacy-data-expire--${requestId}`),
    true,
  );
});

test("staff management handles review and rejection but cannot fake completion", async () => {
  const requestId = "user-one--privacy-delete-001";
  const initialRequest = {
    schemaVersion: 1,
    requestId,
    userId: "user-one",
    type: "account_deletion",
    status: "pending",
    requestedAt: "2026-07-29T03:00:00.000Z",
    reviewAfter: "2026-08-05T03:00:00.000Z",
    updatedAt: "2026-07-29T03:00:00.000Z",
  };
  const firestore = fakeFirestore({
    "users/member-one": { staffRole: "member" },
    "users/operator-one": { staffRole: "operator" },
    [`privacy_data_requests/${requestId}`]: initialRequest,
  });
  const handler = createManagePrivacyDataRequestHandler({
    firestore,
    clock: () => new Date("2026-07-30T03:00:00.000Z"),
  });

  await assert.rejects(
    () =>
      handler({
        auth: { uid: "member-one" },
        data: {
          action: "start_review",
          requestId,
          clientRequestId: "privacy-admin-001",
          sourceSurface: "admin_web",
          resolutionNote: "",
        },
      }),
    error => error.code === "permission-denied",
  );

  const reviewed = await handler({
    auth: { uid: "operator-one" },
    data: {
      action: "start_review",
      requestId,
      clientRequestId: "privacy-admin-002",
      sourceSurface: "admin_web",
      resolutionNote: "已驗證帳號持有人",
    },
  });
  assert.equal(reviewed.request.status, "in_review");
  assert.equal(reviewed.request.assignedStaffUserId, "operator-one");

  await assert.rejects(
    () =>
      handler({
        auth: { uid: "operator-one" },
        data: {
          action: "complete",
          requestId,
          clientRequestId: "privacy-admin-003",
          sourceSurface: "admin_web",
          resolutionNote: "不得用人工狀態取代正式刪除",
        },
      }),
    error => error.code === "invalid-argument",
  );

  const rejected = await handler({
    auth: { uid: "operator-one" },
    data: {
      action: "reject",
      requestId,
      clientRequestId: "privacy-admin-004",
      sourceSurface: "admin_web",
      resolutionNote: "帳號持有人驗證資料不完整",
    },
  });
  assert.equal(rejected.request.status, "rejected");
});
