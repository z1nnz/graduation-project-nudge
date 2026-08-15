import assert from "node:assert/strict";
import test from "node:test";

import {
  createManageDeviceAssignmentHandler,
  normalizeDeviceAssignmentCommand,
} from "../src/device-assignment-service.js";

function fakeFirestore(seed = {}) {
  const documents = new Map(Object.entries(seed));
  const ref = (collection, id) => ({ path: `${collection}/${id}`, id });
  return {
    documents,
    doc: path => ({ path, id: path.split("/").at(-1) }),
    collection: collection => ({ doc: id => ref(collection, id) }),
    runTransaction: async callback => callback({
      get: async document => ({
        exists: documents.has(document.path),
        id: document.id,
        data: () => structuredClone(documents.get(document.path)),
      }),
      set: (document, data) => documents.set(
        document.path,
        structuredClone(data),
      ),
    }),
  };
}

const command = {
  action: "assign",
  deviceId: "nudge-a1b2c3",
  assignedUserId: "student-one",
  allowedRoomIds: ["room-study"],
  clientRequestId: "device-request-001",
  sourceSurface: "admin_web",
};

test("device assignment command accepts only bounded admin input", () => {
  assert.deepEqual(normalizeDeviceAssignmentCommand(command), command);
  assert.throws(
    () => normalizeDeviceAssignmentCommand({ ...command, deviceId: "desk" }),
    error => error.code === "invalid-argument",
  );
  assert.throws(
    () => normalizeDeviceAssignmentCommand({
      ...command,
      allowedRoomIds: ["room-study", "room-study"],
    }),
    error => error.code === "invalid-argument",
  );
});

test("staff assignment validates the user and room membership atomically", async () => {
  const firestore = fakeFirestore({
    "users/admin-one": { staffRole: "operator" },
    "users/student-one": { nickname: "Student" },
    "rooms/room-study": { status: "active" },
    "rooms/room-study/members/student-one": {
      memberId: "student-one",
      approvalStatus: "approved",
    },
  });
  const handler = createManageDeviceAssignmentHandler({
    firestore,
    clock: () => new Date("2026-08-15T11:00:00.000Z"),
  });
  const request = { auth: { uid: "admin-one" }, data: command };

  const first = await handler(request);
  const replay = await handler(request);
  const assignment = firestore.documents.get(
    "device_assignments/nudge-a1b2c3",
  );

  assert.equal(first.replayed, false);
  assert.equal(
    first.auditEventId,
    "device-command--admin-one--device-request-001",
  );
  assert.equal(replay.replayed, true);
  assert.equal(assignment.assignedUserId, "student-one");
  assert.equal(assignment.status, "active");
  assert.deepEqual(assignment.allowedRoomIds, ["room-study"]);
  assert.equal(
    firestore.documents.get(
      "audit_events/device-command--admin-one--device-request-001",
    ).action,
    "device.assignment.assign",
  );
  assert.equal(
    firestore.documents.get(
      "audit_events/device-command--admin-one--device-request-001",
    ).category,
    "device",
  );
});

test("non-staff and non-member room assignment fail closed", async () => {
  const firestore = fakeFirestore({
    "users/member-one": { staffRole: "member" },
    "users/admin-one": { staffRole: "admin" },
    "users/student-one": {},
    "rooms/room-study": { status: "active" },
  });
  const handler = createManageDeviceAssignmentHandler({ firestore });

  await assert.rejects(
    () => handler({ auth: { uid: "member-one" }, data: command }),
    error => error.code === "permission-denied",
  );
  await assert.rejects(
    () => handler({ auth: { uid: "admin-one" }, data: command }),
    error => error.code === "failed-precondition",
  );
});

test("assignment refuses an account with an active deletion fence", async () => {
  const firestore = fakeFirestore({
    "users/admin-one": { staffRole: "admin" },
    "users/student-one": {},
    "rooms/room-study": { status: "active" },
    "rooms/room-study/members/student-one": {
      approvalStatus: "approved",
    },
    "account_deletion_fences/student-one": { status: "deleting" },
  });
  const handler = createManageDeviceAssignmentHandler({ firestore });

  await assert.rejects(
    () => handler({ auth: { uid: "admin-one" }, data: command }),
    error => error.code === "failed-precondition",
  );
});

test("assignment refuses a device that still requires a verified wipe", async () => {
  const firestore = fakeFirestore({
    "users/admin-one": { staffRole: "admin" },
    "users/student-one": {},
    "rooms/room-study": { status: "active" },
    "rooms/room-study/members/student-one": {
      approvalStatus: "approved",
    },
    "device_transfer_locks/nudge-a1b2c3": {
      schemaVersion: 1,
      deviceId: "nudge-a1b2c3",
      status: "wipe_required",
      reason: "account_deletion",
      lockedAt: "2026-08-15T10:00:00.000Z",
      updatedAt: "2026-08-15T10:00:00.000Z",
    },
  });
  const handler = createManageDeviceAssignmentHandler({ firestore });

  await assert.rejects(
    () => handler({ auth: { uid: "admin-one" }, data: command }),
    error => error.code === "failed-precondition",
  );
});

test("assignment cannot transfer a device to another user without a verified wipe", async () => {
  const firestore = fakeFirestore({
    "users/admin-one": { staffRole: "admin" },
    "users/student-one": {},
    "users/student-two": {},
    "device_assignments/nudge-a1b2c3": {
      schemaVersion: 1,
      assignmentId: "nudge-a1b2c3",
      deviceId: "nudge-a1b2c3",
      assignedUserId: "student-one",
      status: "revoked",
      allowedRoomIds: [],
      validFrom: "2026-08-01T00:00:00.000Z",
      validUntil: "2026-08-14T00:00:00.000Z",
      updatedAt: "2026-08-14T00:00:00.000Z",
    },
  });
  const handler = createManageDeviceAssignmentHandler({ firestore });

  await assert.rejects(
    () => handler({
      auth: { uid: "admin-one" },
      data: {
        ...command,
        assignedUserId: "student-two",
        allowedRoomIds: [],
      },
    }),
    error => error.code === "failed-precondition",
  );
});

test("same-user unchanged room scope preserves the assignment validity window", async () => {
  const firestore = fakeFirestore({
    "users/admin-one": { staffRole: "admin" },
    "users/student-one": {},
    "rooms/room-study": { status: "active" },
    "rooms/room-study/members/student-one": {
      approvalStatus: "approved",
    },
    "device_assignments/nudge-a1b2c3": {
      schemaVersion: 1,
      assignmentId: "nudge-a1b2c3",
      deviceId: "nudge-a1b2c3",
      assignedUserId: "student-one",
      status: "active",
      allowedRoomIds: ["room-study"],
      validFrom: "2026-08-01T00:00:00.000Z",
      validUntil: null,
      updatedAt: "2026-08-14T00:00:00.000Z",
    },
  });
  const handler = createManageDeviceAssignmentHandler({
    firestore,
    clock: () => new Date("2026-08-15T11:00:00.000Z"),
  });

  await handler({ auth: { uid: "admin-one" }, data: command });

  assert.equal(
    firestore.documents.get("device_assignments/nudge-a1b2c3").validFrom,
    "2026-08-01T00:00:00.000Z",
  );
});

test("active assignment rejects a room scope change without a verified empty queue", async () => {
  const firestore = fakeFirestore({
    "users/admin-one": { staffRole: "admin" },
    "users/student-one": {},
    "rooms/room-study": { status: "active" },
    "rooms/room-study/members/student-one": {
      approvalStatus: "approved",
    },
    "device_assignments/nudge-a1b2c3": {
      schemaVersion: 1,
      assignmentId: "nudge-a1b2c3",
      deviceId: "nudge-a1b2c3",
      assignedUserId: "student-one",
      status: "active",
      allowedRoomIds: [],
      validFrom: "2026-08-01T00:00:00.000Z",
      validUntil: null,
      updatedAt: "2026-08-14T00:00:00.000Z",
    },
  });
  const handler = createManageDeviceAssignmentHandler({ firestore });

  await assert.rejects(
    () => handler({ auth: { uid: "admin-one" }, data: command }),
    error => error.code === "failed-precondition",
  );
});

test("same-user reassignment after revoke requires a verified wipe", async () => {
  const firestore = fakeFirestore({
    "users/admin-one": { staffRole: "admin" },
    "users/student-one": {},
    "rooms/room-study": { status: "active" },
    "rooms/room-study/members/student-one": {
      approvalStatus: "approved",
    },
    "device_assignments/nudge-a1b2c3": {
      schemaVersion: 1,
      assignmentId: "nudge-a1b2c3",
      deviceId: "nudge-a1b2c3",
      assignedUserId: "student-one",
      status: "revoked",
      allowedRoomIds: [],
      validFrom: "2026-08-01T00:00:00.000Z",
      validUntil: "2026-08-14T00:00:00.000Z",
      updatedAt: "2026-08-14T00:00:00.000Z",
    },
  });
  const handler = createManageDeviceAssignmentHandler({
    firestore,
    clock: () => new Date("2026-08-15T11:00:00.000Z"),
  });

  await assert.rejects(
    () => handler({ auth: { uid: "admin-one" }, data: command }),
    error => error.code === "failed-precondition",
  );
});
