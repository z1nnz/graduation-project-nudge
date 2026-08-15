const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const read = relativePath =>
  fs.readFileSync(path.join(root, relativePath), "utf8");

const {
  buildDeviceAssignmentCommand,
  normalizeDeviceAssignmentRecord,
  validateDeviceAssignmentDraft,
} = require("../web_dashboard/assets/admin_device_assignments.js");

test("admin device command normalizes rooms and uses a stable request id", () => {
  const draft = {
    action: "assign",
    deviceId: "nudge-desk-001",
    assignedUserId: "student-one",
    allowedRoomIds: "room-study, room-fitness\nroom-sleep",
    clientRequestId: "device-request-001",
  };

  assert.deepEqual(validateDeviceAssignmentDraft(draft), []);
  assert.deepEqual(buildDeviceAssignmentCommand(draft), {
    action: "assign",
    deviceId: "nudge-desk-001",
    assignedUserId: "student-one",
    allowedRoomIds: ["room-study", "room-fitness", "room-sleep"],
    clientRequestId: "device-request-001",
    sourceSurface: "admin_web",
  });
});

test("admin device validation rejects unsafe or duplicate input", () => {
  const errors = validateDeviceAssignmentDraft({
    action: "assign",
    deviceId: "desk",
    assignedUserId: "student-one",
    allowedRoomIds: "room-study,room-study",
    clientRequestId: "short",
  });

  assert.ok(errors.some(message => message.includes("nudge-")));
  assert.ok(errors.some(message => message.includes("重複")));
  assert.ok(errors.some(message => message.includes("請求 ID")));
});

test("admin device readback validates the canonical Cloud record", () => {
  assert.deepEqual(
    normalizeDeviceAssignmentRecord({
      schemaVersion: 1,
      assignmentId: "nudge-desk-001",
      deviceId: "nudge-desk-001",
      assignedUserId: "student-one",
      status: "active",
      allowedRoomIds: ["room-study"],
      validFrom: "2026-08-01T00:00:00.000Z",
      validUntil: null,
      updatedAt: "2026-08-15T00:00:00.000Z",
    }, "nudge-desk-001"),
    {
      deviceId: "nudge-desk-001",
      assignedUserId: "student-one",
      status: "active",
      allowedRoomIds: ["room-study"],
      validFrom: "2026-08-01T00:00:00.000Z",
      validUntil: null,
      updatedAt: "2026-08-15T00:00:00.000Z",
    },
  );
  assert.throws(
    () => normalizeDeviceAssignmentRecord({
      schemaVersion: 1,
      assignmentId: "nudge-other-1",
      deviceId: "nudge-other-1",
      assignedUserId: "student-one",
      status: "active",
      allowedRoomIds: [],
      validFrom: "2026-08-15T00:00:00.000Z",
      validUntil: null,
      updatedAt: "2026-08-15T00:00:00.000Z",
    }, "nudge-desk-001"),
    /不一致/,
  );
  assert.throws(
    () => normalizeDeviceAssignmentRecord({
      schemaVersion: 1,
      assignmentId: "nudge-desk-001",
      deviceId: "nudge-desk-001",
      assignedUserId: "student-one",
      status: "active",
      allowedRoomIds: ["room-study", "room-study"],
      validFrom: "2026-08-15T00:00:00.000Z",
      validUntil: null,
      updatedAt: "2026-08-15T00:00:00.000Z",
    }, "nudge-desk-001"),
    /房間清單/,
  );
});

test("Cloud and Admin Web expose audited assignment and revoke only", () => {
  const index = read("functions/index.js");
  const admin = read("web_dashboard/admin_dashboard.html");
  const adminDevice = read(
    "web_dashboard/assets/admin_device_assignments.js",
  );
  const rules = read("firestore.rules");

  assert.match(index, /export const manageDeviceAssignment/);
  assert.match(index, /createManageDeviceAssignmentHandler/);
  assert.match(admin, /id="device-section"/);
  assert.match(admin, /httpsCallable\(['"]manageDeviceAssignment['"]\)/);
  assert.match(admin, /id="loadDeviceAssignment"/);
  assert.match(admin, /collection\(['"]device_assignments['"]\)\.doc\(/);
  assert.match(admin, /id="deviceAssignmentReadback"/);
  assert.match(adminDevice, /['"]assign['"]/);
  assert.match(adminDevice, /['"]revoke['"]/);
  assert.doesNotMatch(
    admin,
    /collection\(['"]device_assignments['"]\)[\s\S]{0,180}\.(?:add|set|update|delete)\(/,
  );
  assert.match(
    rules,
    /match \/device_assignments\/\{deviceId\}[\s\S]*allow write: if false/,
  );
});
