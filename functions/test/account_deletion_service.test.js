import assert from "node:assert/strict";
import test from "node:test";

import {
  buildAccountDeletionPlan,
  createExecuteAccountDeletionHandler,
} from "../src/account-deletion-service.js";

test("deletion plan blocks active ownership with other participants", () => {
  const plan = buildAccountDeletionPlan({
    userId: "user-one",
    groups: [
      {
        id: "group-shared",
        data: {
          ownerId: "user-one",
          memberIds: ["user-one", "user-two"],
          status: "active",
        },
      },
      {
        id: "group-solo",
        data: {
          ownerId: "user-one",
          memberIds: ["user-one"],
          status: "active",
        },
      },
    ],
    rooms: [
      {
        id: "room-shared",
        data: {
          ownerId: "user-one",
          memberIds: ["user-one", "user-three"],
          status: "active",
        },
      },
    ],
    familyLinks: [{
      id: "family-one",
      data: {
        participantIds: ["user-one", "user-four"],
        status: "active",
      },
    }],
    memberships: [
      {
        id: "group--other--user-one",
        data: { scopeType: "group", scopeId: "other", role: "member" },
      },
    ],
  });

  assert.equal(plan.ready, false);
  assert.deepEqual(
    plan.blockers.map(blocker => [blocker.code, blocker.scopeId]),
    [
      ["group_ownership_transfer_required", "group-shared"],
      ["room_ownership_transfer_required", "room-shared"],
      ["family_relationship_resolution_required", "family-one"],
    ],
  );
  assert.deepEqual(plan.operations.deleteOwnedGroupIds, ["group-solo"]);
  assert.deepEqual(plan.operations.deleteFamilyLinkIds, []);
  assert.deepEqual(plan.operations.leaveGroupIds, ["other"]);
});

test("deletion plan removes a non-owner manager and permits only solo family cleanup", () => {
  const plan = buildAccountDeletionPlan({
    userId: "user-one",
    familyLinks: [{
      id: "family-solo",
      data: { participantIds: ["user-one"], status: "ended" },
    }, {
      id: "family-ended",
      data: {
        participantIds: ["user-one", "user-two"],
        status: "ended",
      },
    }],
    memberships: [{
      id: "group--other--user-one",
      data: { scopeType: "group", scopeId: "other", role: "manager" },
    }],
  });

  assert.equal(plan.ready, true);
  assert.deepEqual(plan.operations.deleteFamilyLinkIds, ["family-solo"]);
  assert.deepEqual(
    plan.operations.redactEndedFamilyLinkIds,
    ["family-ended"],
  );
  assert.deepEqual(plan.operations.leaveGroupIds, ["other"]);
});

test("execution never erases data until cooling and ownership checks pass", async () => {
  const calls = [];
  const repository = {
    async getStaffProfile() {
      return { staffRole: "operator" };
    },
    async getDeletionRequest() {
      return {
        requestId: "user-one--privacy-delete-001",
        userId: "user-one",
        type: "account_deletion",
        status: "in_review",
        reviewAfter: "2026-08-05T00:00:00.000Z",
      };
    },
    async collectInventory() {
      return {
        groups: [{
          id: "shared",
          data: {
            ownerId: "user-one",
            memberIds: ["user-one", "other"],
            status: "active",
          },
        }],
        rooms: [],
        familyLinks: [],
        memberships: [],
      };
    },
    async recordBlockedPlan(input) {
      calls.push(["blocked", input.plan.blockers.length]);
    },
    async claimExecution() {
      calls.push(["claim"]);
    },
    async eraseAccountData() {
      calls.push(["erase"]);
    },
    async deleteAuthUser() {
      calls.push(["auth"]);
    },
    async completeExecution() {
      calls.push(["complete"]);
    },
  };
  const handler = createExecuteAccountDeletionHandler({
    repository,
    clock: () => new Date("2026-08-06T00:00:00.000Z"),
  });

  await assert.rejects(
    () =>
      handler({
        auth: { uid: "operator-one" },
        data: {
          requestId: "user-one--privacy-delete-001",
          clientRequestId: "privacy-execute-001",
          sourceSurface: "admin_web",
          caseId: "CASE-2026-0001",
          resolutionNote: "已核對關係範圍並準備執行刪除",
          confirmation: "DELETE ACCOUNT",
        },
      }),
    error =>
      error.code === "failed-precondition" &&
      error.details.blockers[0].scopeId === "shared",
  );
  assert.deepEqual(calls, [["blocked", 1]]);
});

test("ready deletion executes data erasure before Auth removal and completion", async () => {
  const calls = [];
  const repository = {
    async getStaffProfile() {
      return { developerAccess: true };
    },
    async getDeletionRequest() {
      return {
        requestId: "user-one--privacy-delete-001",
        userId: "user-one",
        type: "account_deletion",
        status: "in_review",
        reviewAfter: "2026-08-05T00:00:00.000Z",
      };
    },
    async collectInventory() {
      return {
        groups: [],
        rooms: [],
        familyLinks: [],
        memberships: [],
      };
    },
    async recordBlockedPlan() {
      throw new Error("must not block");
    },
    async claimExecution(input) {
      calls.push(["claim", input.caseId]);
      return { replayed: false, attemptCount: 1 };
    },
    async freezeAuthUser(userId) {
      calls.push(["freeze", userId]);
    },
    async updateClaimedPlan(input) {
      calls.push(["plan", input.plan.ready, input.executionAttempt]);
    },
    async eraseAccountData(input) {
      calls.push(["erase", input.userId]);
      return { deletedDocuments: 42 };
    },
    async deleteAuthUser(userId) {
      calls.push(["auth", userId]);
    },
    async completeExecution(input) {
      calls.push([
        "complete",
        input.outcome.deletedDocuments,
        input.executionAttempt,
      ]);
      return {
        request: { requestId: input.request.requestId, status: "completed" },
        auditEventId: "privacy-delete-complete-001",
        replayed: false,
      };
    },
    async failExecution() {
      calls.push(["failed"]);
    },
  };
  const handler = createExecuteAccountDeletionHandler({
    repository,
    clock: () => new Date("2026-08-06T00:00:00.000Z"),
  });
  const result = await handler({
    auth: { uid: "developer-one" },
    data: {
      requestId: "user-one--privacy-delete-001",
      clientRequestId: "privacy-execute-001",
      sourceSurface: "admin_web",
      caseId: "CASE-2026-0001",
      resolutionNote: "已核對關係範圍並準備執行刪除",
      confirmation: "DELETE ACCOUNT",
    },
  });

  assert.equal(result.request.status, "completed");
  assert.deepEqual(calls, [
    ["claim", "CASE-2026-0001"],
    ["freeze", "user-one"],
    ["plan", true, 1],
    ["erase", "user-one"],
    ["erase", "user-one"],
    ["auth", "user-one"],
    ["erase", "user-one"],
    ["complete", 126, 1],
  ]);
});

test("post-claim inventory replaces a stale preflight plan and fails closed", async () => {
  const calls = [];
  let inventoryCount = 0;
  const repository = {
    async getStaffProfile() {
      return { staffRole: "operator" };
    },
    async getDeletionRequest() {
      return {
        requestId: "user-one--privacy-delete-race",
        userId: "user-one",
        type: "account_deletion",
        status: "in_review",
        reviewAfter: "2026-08-05T00:00:00.000Z",
      };
    },
    async collectInventory() {
      inventoryCount += 1;
      return {
        groups: inventoryCount === 1
          ? []
          : [{
              id: "new-shared-group",
              data: {
                ownerId: "user-one",
                memberIds: ["user-one", "other"],
              },
            }],
        rooms: [],
        familyLinks: [],
        memberships: [],
      };
    },
    async claimExecution() {
      calls.push(["claim"]);
      return { replayed: false, attemptCount: 3 };
    },
    async freezeAuthUser() {
      calls.push(["freeze"]);
    },
    async updateClaimedPlan(input) {
      calls.push(["plan", input.plan.ready, input.plan.blockers[0].scopeId]);
    },
    async eraseAccountData() {
      throw new Error("must not erase with a blocked claimed plan");
    },
    async failExecution(input) {
      calls.push(["failed", input.failureCode, input.executionAttempt]);
    },
  };
  const handler = createExecuteAccountDeletionHandler({
    repository,
    clock: () => new Date("2026-08-06T00:00:00.000Z"),
  });

  await assert.rejects(
    () =>
      handler({
        auth: { uid: "operator-one" },
        data: {
          requestId: "user-one--privacy-delete-race",
          clientRequestId: "privacy-execute-race-001",
          sourceSurface: "admin_web",
          caseId: "CASE-2026-RACE1",
          resolutionNote: "確認刪除鎖建立後重新盤點關係",
          confirmation: "DELETE ACCOUNT",
        },
      }),
    error =>
      error.code === "failed-precondition" &&
      error.details.blockers[0].scopeId === "new-shared-group",
  );
  assert.deepEqual(calls, [
    ["claim"],
    ["freeze"],
    ["plan", false, "new-shared-group"],
    ["failed", "failed-precondition", 3],
  ]);
});
