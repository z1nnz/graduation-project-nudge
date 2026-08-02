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
      receivedAt: "2000-01-01T00:00:00.000Z",
      submittedByUserId: "forged-user",
      unexpectedField: "must-not-persist",
    };
    await firestore.collection("rooms").doc(roomId).set({
      status: "active",
      sharingConsentRequired: true,
    });
    await firestore.collection("users").doc(actorUserId).set({
      disciplineCoins: 0,
      dailyCoinEarned: {},
      avatarSeries: "default",
      avatarExperienceLedger: {},
      avatarExperience: 0,
      avatarLevel: 1,
    });
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

    let serverNow = "2026-07-28T09:00:01.000Z";
    const firstService = new ActivityLedgerService({
      store: new FirestoreActivityLedgerStore({ firestore }),
      clock: () => new Date(serverNow),
    });
    await firstService.record(
      { kind: "user", userId: actorUserId },
      {
        ...evidence,
        eventId: `event-start-${unique}`,
        sourceRecordId: `source-start-${unique}`,
        eventType: "started",
        metricValue: 0,
        occurredAt: "2026-07-28T09:00:00.000Z",
      },
    );
    serverNow = "2026-07-28T09:25:01.000Z";
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
    const sourceReplayEventId = `event-source-replay-${unique}`;
    await restartedService.record(
      { kind: "user", userId: actorUserId },
      {
        ...evidence,
        eventId: sourceReplayEventId,
      },
    );
    const sourceReplaySnapshot = await firestore
      .collection("activity_events")
      .where("eventId", "==", sourceReplayEventId)
      .get();

    assert.equal(first.status, "settled");
    assert.equal(first.contributions.length, 1);
    assert.equal(first.receipt.rewardEligible, true);
    assert.equal(first.receipt.rewardIssued, true);
    assert.equal(first.receipt.characterExperienceIssued, true);
    assert.equal(first.rewardEntry.disciplineCoinsDelta, 1);
    assert.equal(first.rewardEntry.characterExperienceDelta, 25);
    assert.equal(replay.receipt.receiptId, first.receipt.receiptId);
    assert.equal(replay.wasDuplicate, true);
    assert.equal(sourceReplaySnapshot.size, 1);
    const rewardEntries = await firestore
      .collection("reward_ledger_entries")
      .where("actorUserId", "==", actorUserId)
      .get();
    assert.equal(rewardEntries.size, 1);
    const userProjection = (
      await firestore.collection("users").doc(actorUserId).get()
    ).data();
    assert.equal(userProjection.disciplineCoins, 1);
    assert.equal(userProjection.avatarExperience, 25);
    const persistedReplay = sourceReplaySnapshot.docs[0].data();
    assert.equal(persistedReplay.actorUserId, actorUserId);
    assert.equal(persistedReplay.evidence.eventId, sourceReplayEventId);
    assert.equal(persistedReplay.evidence.submittedByUserId, actorUserId);
    assert.equal(
      persistedReplay.evidence.receivedAt,
      "2026-07-28T09:26:00.000Z",
    );
    assert.equal("unexpectedField" in persistedReplay.evidence, false);
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
      await firestore.collection("rooms").doc(roomId).set({
        status: "active",
      });
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
      { kind: "health_adapter", adapterId: "health-connect" },
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

test(
  "concurrent replays commit one receipt",
  { skip: !emulatorEnabled },
  async () => {
    const unique = `${Date.now()}-${Math.random().toString(16).slice(2)}`;
    const app = initializeApp(
      {
        projectId: process.env.GCLOUD_PROJECT || "nudge-discipline-app",
      },
      `activity-ledger-race-${unique}`,
    );
    const firestore = getFirestore(app);
    const actorUserId = `ledger-race-user-${unique}`;
    const evidence = {
      eventId: `event-${unique}`,
      sourceRecordId: `source-${unique}`,
      sessionId: `session-${unique}`,
      activityCorrelationId: `correlation-${unique}`,
      actorUserId,
      roomIds: [],
      activityType: "focus",
      source: "app",
      eventType: "completed",
      metricValue: 25,
      metricUnit: "minutes",
      occurredAt: "2026-07-28T09:25:00.000Z",
    };
    const services = Array.from(
      { length: 8 },
      () =>
        new ActivityLedgerService({
          store: new FirestoreActivityLedgerStore({ firestore }),
          clock: () => new Date("2026-07-28T09:25:01.000Z"),
        }),
    );

    const results = await Promise.all(
      services.map(service =>
        service.record({ kind: "user", userId: actorUserId }, evidence),
      ),
    );

    assert.equal(new Set(results.map(item => item.receipt.receiptId)).size, 1);
    const receipts = await firestore
      .collection("activity_receipts")
      .where("actorUserId", "==", actorUserId)
      .get();
    assert.equal(receipts.size, 1);
    await deleteApp(app);
  },
);

test(
  "Firestore preserves health correction receipts and the latest session",
  { skip: !emulatorEnabled },
  async () => {
    const unique = `${Date.now()}-${Math.random().toString(16).slice(2)}`;
    const app = initializeApp(
      {
        projectId: process.env.GCLOUD_PROJECT || "nudge-discipline-app",
      },
      `activity-ledger-health-${unique}`,
    );
    const firestore = getFirestore(app);
    const actorUserId = `health-user-${unique}`;
    const principal = {
      kind: "health_adapter",
      adapterId: "mobile-health-connect",
      allowedActorUserId: actorUserId,
    };
    const evidence = {
      eventId: `health-first-${unique}`,
      sourceRecordId: `health-source-first-${unique}`,
      sessionId: `health-session-${unique}`,
      activityCorrelationId: `health-session-${unique}`,
      actorUserId,
      roomIds: [],
      activityType: "steps",
      source: "health",
      eventType: "metricSynced",
      metricValue: 1200,
      metricUnit: "steps",
      occurredAt: "2026-07-28T09:00:00.000Z",
      healthContext: {
        provider: "healthConnect",
        localDate: "2026-07-28",
        periodStart: "2026-07-27T16:00:00.000Z",
        periodEnd: "2026-07-28T09:00:00.000Z",
        dataOrigins: ["android"],
      },
    };
    const service = new ActivityLedgerService({
      store: new FirestoreActivityLedgerStore({ firestore }),
      clock: () => new Date("2026-07-28T12:00:00.000Z"),
    });
    await firestore.collection("users").doc(actorUserId).set({
      disciplineCoins: 0,
      dailyCoinEarned: {},
      avatarSeries: "default",
      avatarExperienceLedger: {},
      avatarExperience: 0,
      avatarLevel: 1,
    });

    const first = await service.record(principal, evidence);
    const corrected = await service.record(principal, {
      ...evidence,
      eventId: `health-corrected-${unique}`,
      sourceRecordId: `health-source-corrected-${unique}`,
      metricValue: 1800,
      occurredAt: "2026-07-28T10:00:00.000Z",
      healthContext: {
        ...evidence.healthContext,
        periodEnd: "2026-07-28T10:00:00.000Z",
      },
    });
    const finalized = await service.record(principal, {
      ...evidence,
      eventId: `health-final-${unique}`,
      sourceRecordId: `health-source-final-${unique}`,
      eventType: "completed",
      metricValue: 1800,
      occurredAt: "2026-07-28T11:00:00.000Z",
      healthContext: {
        ...evidence.healthContext,
        periodEnd: "2026-07-28T11:00:00.000Z",
      },
    });

    const receipts = await firestore
      .collection("activity_receipts")
      .where("actorUserId", "==", actorUserId)
      .get();
    const sessions = await firestore
      .collection("activity_sessions")
      .where("actorUserId", "==", actorUserId)
      .get();
    const finalEvent = await firestore
      .collection("activity_events")
      .where("eventId", "==", `health-final-${unique}`)
      .get();

    assert.equal(receipts.size, 3);
    assert.equal(
      corrected.receipt.correctionOfReceiptId,
      first.receipt.receiptId,
    );
    assert.equal(
      finalized.receipt.correctionOfReceiptId,
      corrected.receipt.receiptId,
    );
    assert.equal(sessions.size, 1);
    assert.equal(sessions.docs[0].data().status, "completed");
    assert.equal(sessions.docs[0].data().metricValue, 1800);
    assert.equal(finalEvent.size, 1);
    assert.deepEqual(
      finalEvent.docs[0].data().evidence.healthContext.dataOrigins,
      ["android"],
    );
    await deleteApp(app);
  },
);
