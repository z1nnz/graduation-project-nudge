import assert from "node:assert/strict";
import test from "node:test";

import { deleteApp, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

import { ActivityLedgerService } from "../src/activity-ledger-service.js";
import { FirestoreActivityLedgerStore } from "../src/firestore-activity-ledger-store.js";

const emulatorEnabled = Boolean(process.env.FIRESTORE_EMULATOR_HOST);

test(
  "Firestore persists one settlement and room contribution atomically",
  { skip: !emulatorEnabled },
  async () => {
    const unique = `${Date.now()}-${Math.random().toString(16).slice(2)}`;
    const app = initializeApp(
      {
        projectId: process.env.GCLOUD_PROJECT || "nudge-discipline-app",
      },
      `activity-ledger-${unique}`,
    );
    const firestore = getFirestore(app);
    const actorUserId = `ledger-user-${unique}`;
    const roomId = `ledger-room-${unique}`;
    const evidence = {
      eventId: `event-${unique}`,
      sourceRecordId: `source-${unique}`,
      sessionId: `session-${unique}`,
      activityCorrelationId: `correlation-${unique}`,
      actorUserId,
      roomIds: [roomId],
      activityType: "focus",
      source: "app",
      eventType: "completed",
      metricValue: 25,
      metricUnit: "minutes",
      occurredAt: "2026-07-28T09:25:00.000Z",
    };
    await firestore
      .collection("rooms")
      .doc(roomId)
      .collection("members")
      .doc(actorUserId)
      .set({
        memberId: actorUserId,
        approvalStatus: "approved",
        sharingConsented: true,
      });

    const firstService = new ActivityLedgerService({
      store: new FirestoreActivityLedgerStore({ firestore }),
      clock: () => new Date("2026-07-28T09:25:01.000Z"),
    });
    const first = await firstService.record(
      { kind: "user", userId: actorUserId },
      evidence,
    );
    const restartedService = new ActivityLedgerService({
      store: new FirestoreActivityLedgerStore({ firestore }),
      clock: () => new Date("2026-07-28T09:26:00.000Z"),
    });
    const replay = await restartedService.record(
      { kind: "user", userId: actorUserId },
      evidence,
    );

    assert.equal(first.status, "settled");
    assert.equal(first.contributions.length, 1);
    assert.equal(replay.receipt.receiptId, first.receipt.receiptId);
    assert.equal(replay.wasDuplicate, true);
    await deleteApp(app);
  },
);

test(
  "Firestore merges later eligible rooms into one persisted receipt",
  { skip: !emulatorEnabled },
  async () => {
    const unique = `${Date.now()}-${Math.random().toString(16).slice(2)}`;
    const app = initializeApp(
      {
        projectId: process.env.GCLOUD_PROJECT || "nudge-discipline-app",
      },
      `activity-ledger-merge-${unique}`,
    );
    const firestore = getFirestore(app);
    const actorUserId = `ledger-user-${unique}`;
    const roomA = `ledger-room-a-${unique}`;
    const roomB = `ledger-room-b-${unique}`;
    const evidence = {
      eventId: `event-app-${unique}`,
      sourceRecordId: `source-app-${unique}`,
      sessionId: `session-app-${unique}`,
      activityCorrelationId: `correlation-${unique}`,
      actorUserId,
      roomIds: [roomA],
      activityType: "focus",
      source: "app",
      eventType: "completed",
      metricValue: 25,
      metricUnit: "minutes",
      occurredAt: "2026-07-28T09:25:00.000Z",
    };
    for (const roomId of [roomA, roomB]) {
      await firestore
        .collection("rooms")
        .doc(roomId)
        .collection("members")
        .doc(actorUserId)
        .set({
          memberId: actorUserId,
          approvalStatus: "approved",
          sharingConsented: true,
        });
    }

    const service = new ActivityLedgerService({
      store: new FirestoreActivityLedgerStore({ firestore }),
      clock: () => new Date("2026-07-28T09:25:01.000Z"),
    });
    const first = await service.record(
      { kind: "user", userId: actorUserId },
      evidence,
    );
    const second = await service.record(
      { kind: "user", userId: actorUserId },
      {
        ...evidence,
        eventId: `event-health-${unique}`,
        sourceRecordId: `source-health-${unique}`,
        sessionId: `session-health-${unique}`,
        source: "health",
        roomIds: [roomB],
      },
    );
    const replay = await new ActivityLedgerService({
      store: new FirestoreActivityLedgerStore({ firestore }),
    }).record({ kind: "user", userId: actorUserId }, evidence);

    assert.equal(second.receipt.receiptId, first.receipt.receiptId);
    assert.deepEqual(
      second.contributions.map(item => item.roomId).sort(),
      [roomA, roomB].sort(),
    );
    assert.deepEqual(
      replay.contributions.map(item => item.roomId).sort(),
      [roomA, roomB].sort(),
    );
    const receipts = await firestore.collection("activity_receipts").get();
    assert.equal(
      receipts.docs.filter(doc => doc.id === first.receipt.receiptId).length,
      1,
    );
    await deleteApp(app);
  },
);
