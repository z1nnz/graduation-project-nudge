import { createHash } from "node:crypto";

function documentId(value) {
  return createHash("sha256").update(value).digest("hex");
}

function timestampToIso(value) {
  return value && typeof value.toDate === "function"
    ? value.toDate().toISOString()
    : value;
}

class FirestoreActivityLedgerTransaction {
  constructor(firestore, transaction) {
    this.firestore = firestore;
    this.transaction = transaction;
  }

  #eventRef(eventKey) {
    return this.firestore.collection("activity_events").doc(documentId(eventKey));
  }

  #sourceRecordRef(sourceKey) {
    return this.firestore
      .collection("activity_source_records")
      .doc(documentId(sourceKey));
  }

  #settlementRef(fingerprint) {
    return this.firestore
      .collection("activity_settlements")
      .doc(documentId(fingerprint));
  }

  #sessionRef(fingerprint) {
    return this.firestore
      .collection("activity_sessions")
      .doc(documentId(fingerprint));
  }

  async #getReferencedEvent(claimSnapshot) {
    if (!claimSnapshot.exists) {
      return null;
    }
    const eventPath = claimSnapshot.data().eventPath;
    if (typeof eventPath !== "string" || eventPath.length === 0) {
      return null;
    }
    const eventSnapshot = await this.transaction.get(
      this.firestore.doc(eventPath),
    );
    return eventSnapshot.exists ? eventSnapshot.data() : null;
  }

  async getEvent(eventKey) {
    const snapshot = await this.transaction.get(this.#eventRef(eventKey));
    return snapshot.exists ? snapshot.data() : null;
  }

  async getRoomMembership(roomId, userId) {
    const roomRef = this.firestore.collection("rooms").doc(roomId);
    const roomSnapshot = await this.transaction.get(roomRef);
    const memberSnapshot = await this.transaction.get(
      roomRef.collection("members").doc(userId),
    );
    if (!roomSnapshot.exists || !memberSnapshot.exists) {
      return null;
    }
    const data = memberSnapshot.data();
    const roomData = roomSnapshot.data();
    return {
      ...data,
      roomStatus: roomData.status,
      sharingConsentRequired:
        roomData.sharingConsentRequired === true ||
        roomData.sharingPolicy === "required",
      activeFrom: timestampToIso(data.activeFrom),
      activeUntil: timestampToIso(data.activeUntil),
    };
  }

  async getSourceRecord(sourceKey) {
    const claim = await this.transaction.get(this.#sourceRecordRef(sourceKey));
    return this.#getReferencedEvent(claim);
  }

  async getSettlement(fingerprint) {
    const claim = await this.transaction.get(this.#settlementRef(fingerprint));
    return this.#getReferencedEvent(claim);
  }

  async getSession(fingerprint) {
    const snapshot = await this.transaction.get(this.#sessionRef(fingerprint));
    return snapshot.exists ? snapshot.data() : null;
  }

  async rememberDuplicateEvent(eventKey, event, sourceKey = null) {
    const eventRef = this.#eventRef(eventKey);
    this.transaction.create(eventRef, {
      schemaVersion: 1,
      ...event,
      eventId: event.evidence.eventId,
      actorUserId: event.evidence.actorUserId,
      eventType: event.evidence.eventType,
      occurredAt: event.evidence.occurredAt,
      receivedAt: event.evidence.receivedAt,
    });
    if (sourceKey) {
      this.transaction.create(this.#sourceRecordRef(sourceKey), {
        schemaVersion: 1,
        eventPath: eventRef.path,
        sourceKey,
      });
    }
  }

  async createActivityEvent({
    eventKey,
    eventId,
    event,
    sourceKey,
    fingerprint,
    session,
  }) {
    const eventRef = this.#eventRef(eventKey);
    this.transaction.create(eventRef, {
      schemaVersion: 1,
      ...event,
      eventId,
      actorUserId: event.evidence.actorUserId,
      eventType: event.evidence.eventType,
      occurredAt: event.evidence.occurredAt,
      receivedAt: event.evidence.receivedAt,
    });
    this.transaction.create(this.#sourceRecordRef(sourceKey), {
      schemaVersion: 1,
      eventPath: eventRef.path,
      sourceKey,
    });
    this.transaction.set(this.#sessionRef(fingerprint), {
      schemaVersion: 1,
      ...session,
      activityFingerprint: fingerprint,
      updatedAt: event.evidence.occurredAt,
    });
  }

  async createSettlement({
    eventKey,
    eventId,
    event,
    receipt,
    sourceKey,
    fingerprint,
    session,
  }) {
    const eventRef = this.#eventRef(eventKey);
    this.transaction.create(eventRef, {
      schemaVersion: 1,
      ...event,
      eventId,
      actorUserId: event.evidence.actorUserId,
      eventType: event.evidence.eventType,
      occurredAt: event.evidence.occurredAt,
      receivedAt: event.evidence.receivedAt,
    });
    this.transaction.create(this.#sourceRecordRef(sourceKey), {
      schemaVersion: 1,
      eventPath: eventRef.path,
      sourceKey,
    });
    this.transaction.create(this.#settlementRef(fingerprint), {
      schemaVersion: 1,
      eventPath: eventRef.path,
      receiptId: receipt.receiptId,
      activityFingerprint: fingerprint,
    });
    this.transaction.create(
      this.firestore.collection("activity_receipts").doc(receipt.receiptId),
      {
        schemaVersion: 1,
        ...receipt,
        contributionIds: event.result.contributions.map(
          contribution => contribution.contributionId,
        ),
      },
    );
    this.transaction.set(this.#sessionRef(fingerprint), {
      schemaVersion: 1,
      ...session,
      activityFingerprint: fingerprint,
      updatedAt: receipt.verifiedAt,
    });
    for (const contribution of event.result.contributions) {
      this.transaction.create(
        this.firestore
          .collection("room_contributions")
          .doc(contribution.contributionId),
        {
          schemaVersion: 1,
          ...contribution,
        },
      );
    }
  }

  async createCorrectionSettlement({
    eventKey,
    event,
    receipt,
    sourceKey,
    fingerprint,
    session,
  }) {
    const eventRef = this.#eventRef(eventKey);
    this.transaction.create(eventRef, {
      schemaVersion: 1,
      ...event,
      eventId: event.evidence.eventId,
      actorUserId: event.evidence.actorUserId,
      eventType: event.evidence.eventType,
      occurredAt: event.evidence.occurredAt,
      receivedAt: event.evidence.receivedAt,
    });
    this.transaction.create(this.#sourceRecordRef(sourceKey), {
      schemaVersion: 1,
      eventPath: eventRef.path,
      sourceKey,
    });
    this.transaction.update(this.#settlementRef(fingerprint), {
      eventPath: eventRef.path,
      receiptId: receipt.receiptId,
      updatedAt: receipt.verifiedAt,
    });
    this.transaction.create(
      this.firestore.collection("activity_receipts").doc(receipt.receiptId),
      {
        schemaVersion: 1,
        ...receipt,
        contributionIds: event.result.contributions.map(
          contribution => contribution.contributionId,
        ),
      },
    );
    this.transaction.set(this.#sessionRef(fingerprint), {
      schemaVersion: 1,
      ...session,
      activityFingerprint: fingerprint,
      updatedAt: receipt.verifiedAt,
    });
    for (const contribution of event.result.contributions) {
      this.transaction.create(
        this.firestore
          .collection("room_contributions")
          .doc(contribution.contributionId),
        {
          schemaVersion: 1,
          ...contribution,
        },
      );
    }
  }

  async mergeSettlement({
    fingerprint,
    primaryEventKey,
    primaryEvent,
    duplicateEventKey,
    duplicateEventId,
    duplicateEvent,
    sourceKey,
    receipt,
    newContributions,
    primaryResult,
  }) {
    const primaryEventRef = this.#eventRef(primaryEventKey);
    const duplicateEventRef = this.#eventRef(duplicateEventKey);
    this.transaction.update(primaryEventRef, { result: primaryResult });
    this.transaction.create(duplicateEventRef, {
      schemaVersion: 1,
      ...duplicateEvent,
      eventId: duplicateEventId,
      actorUserId: duplicateEvent.evidence.actorUserId,
      eventType: duplicateEvent.evidence.eventType,
      occurredAt: duplicateEvent.evidence.occurredAt,
      receivedAt: duplicateEvent.evidence.receivedAt,
    });
    this.transaction.create(this.#sourceRecordRef(sourceKey), {
      schemaVersion: 1,
      eventPath: duplicateEventRef.path,
      sourceKey,
    });
    this.transaction.update(
      this.firestore.collection("activity_receipts").doc(receipt.receiptId),
      {
        contributionIds: primaryResult.contributions.map(
          contribution => contribution.contributionId,
        ),
      },
    );
    this.transaction.update(this.#settlementRef(fingerprint), {
      updatedAt: newContributions.at(-1).createdAt,
    });
    for (const contribution of newContributions) {
      this.transaction.create(
        this.firestore
          .collection("room_contributions")
          .doc(contribution.contributionId),
        {
          schemaVersion: 1,
          ...contribution,
        },
      );
    }
  }
}

export class FirestoreActivityLedgerStore {
  constructor({ firestore }) {
    this.firestore = firestore;
  }

  async runTransaction(callback) {
    return this.firestore.runTransaction(transaction =>
      callback(
        new FirestoreActivityLedgerTransaction(this.firestore, transaction),
      ),
    );
  }
}
