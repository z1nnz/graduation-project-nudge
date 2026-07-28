import { createHash } from "node:crypto";

const ACTIVITY_TYPES = new Set([
  "focus",
  "study",
  "exercise",
  "steps",
  "sleep",
  "custom",
]);
const ACTIVITY_SOURCES = new Set(["app", "health", "device", "web"]);
const ACTIVITY_EVENT_TYPES = new Set([
  "started",
  "paused",
  "resumed",
  "completed",
  "metricSynced",
]);

export class ActivityLedgerAuthorizationError extends Error {
  constructor(message) {
    super(message);
    this.name = "ActivityLedgerAuthorizationError";
  }
}

export class ActivityLedgerValidationError extends Error {
  constructor(message) {
    super(message);
    this.name = "ActivityLedgerValidationError";
  }
}

function stableHash(value) {
  return createHash("sha256").update(value).digest("hex");
}

function evidenceSignature(evidence) {
  const { eventId: _eventId, ...signatureFields } = evidence;
  return JSON.stringify({
    ...signatureFields,
    roomIds: [...new Set(evidence.roomIds)].sort(),
  });
}

function sourceRecordKey(evidence) {
  return JSON.stringify([
    evidence.source,
    evidence.actorUserId,
    evidence.activityType,
    evidence.eventType,
    evidence.sourceRecordId,
  ]);
}

function activityFingerprint(evidence) {
  const sessionNamespace = evidence.activityCorrelationId
    ? `correlation:${evidence.activityCorrelationId}`
    : `local:${evidence.source}:${evidence.actorUserId}:${evidence.sessionId}`;
  return JSON.stringify([
    evidence.actorUserId,
    sessionNamespace,
    evidence.activityType,
  ]);
}

function clone(value) {
  return structuredClone(value);
}

function membershipAllowsContribution(membership, occurredAt) {
  if (!membership || membership.sharingConsented === false) {
    return false;
  }
  const isActive =
    membership.status === "active" ||
    membership.approvalStatus === "approved";
  if (!isActive) {
    return false;
  }
  const occurred = new Date(occurredAt).getTime();
  if (
    membership.activeFrom &&
    occurred < new Date(membership.activeFrom).getTime()
  ) {
    return false;
  }
  if (
    membership.activeUntil &&
    occurred >= new Date(membership.activeUntil).getTime()
  ) {
    return false;
  }
  return true;
}

export class InMemoryActivityLedgerStore {
  #events = new Map();
  #receipts = new Map();
  #memberships = new Map();
  #sourceRecords = new Map();
  #settlements = new Map();
  #sessions = new Map();

  constructor({ roomMemberships = [] } = {}) {
    for (const membership of roomMemberships) {
      this.#memberships.set(
        `${membership.roomId}:${membership.userId}`,
        clone(membership),
      );
    }
  }

  get receiptCount() {
    return this.#receipts.size;
  }

  async runTransaction(callback) {
    return callback(this);
  }

  async getEvent(eventId) {
    const value = this.#events.get(eventId);
    return value ? clone(value) : null;
  }

  async getRoomMembership(roomId, userId) {
    const value = this.#memberships.get(`${roomId}:${userId}`);
    return value ? clone(value) : null;
  }

  async getSourceRecord(key) {
    const value = this.#sourceRecords.get(key);
    return value ? clone(value) : null;
  }

  async getSettlement(fingerprint) {
    const value = this.#settlements.get(fingerprint);
    return value ? clone(value) : null;
  }

  async getSession(fingerprint) {
    const value = this.#sessions.get(fingerprint);
    return value ? clone(value) : null;
  }

  async rememberDuplicateEvent(eventId, event, sourceKey = null) {
    this.#events.set(eventId, clone(event));
    if (sourceKey) {
      this.#sourceRecords.set(sourceKey, clone(event));
    }
  }

  async createSettlement({
    eventId,
    event,
    receipt,
    sourceKey,
    fingerprint,
    session,
  }) {
    this.#events.set(eventId, clone(event));
    this.#receipts.set(receipt.receiptId, clone(receipt));
    this.#sourceRecords.set(sourceKey, clone(event));
    this.#settlements.set(fingerprint, clone(event));
    this.#sessions.set(fingerprint, clone(session));
  }

  async createActivityEvent({
    eventId,
    event,
    sourceKey,
    fingerprint,
    session,
  }) {
    this.#events.set(eventId, clone(event));
    this.#sourceRecords.set(sourceKey, clone(event));
    this.#sessions.set(fingerprint, clone(session));
  }

  async mergeSettlement({
    fingerprint,
    primaryEvent,
    duplicateEventId,
    duplicateEvent,
    sourceKey,
    receipt,
    primaryResult,
  }) {
    const updatedPrimaryEvent = {
      ...clone(primaryEvent),
      result: clone(primaryResult),
    };
    this.#settlements.set(fingerprint, updatedPrimaryEvent);
    this.#events.set(primaryEvent.evidence.eventId, updatedPrimaryEvent);
    this.#events.set(duplicateEventId, clone(duplicateEvent));
    this.#sourceRecords.set(sourceKey, clone(duplicateEvent));
    this.#receipts.set(receipt.receiptId, clone(receipt));
  }
}

export class ActivityLedgerService {
  constructor({ store, clock = () => new Date() }) {
    this.store = store;
    this.clock = clock;
  }

  async record(principal, rawEvidence) {
    const evidence = this.#validateAndNormalize(principal, rawEvidence);
    const signature = evidenceSignature(evidence);
    const sourceKey = sourceRecordKey(evidence);

    return this.store.runTransaction(async transaction => {
      const existing = await transaction.getEvent(evidence.eventId);
      if (existing) {
        if (existing.signature !== signature) {
          throw new ActivityLedgerValidationError(
            "The event ID is already used by different activity evidence.",
          );
        }
        return { ...clone(existing.result), wasDuplicate: true };
      }
      const existingSourceRecord = await transaction.getSourceRecord(sourceKey);
      if (existingSourceRecord) {
        if (existingSourceRecord.signature !== signature) {
          throw new ActivityLedgerValidationError(
            "The source record is already used by different activity evidence.",
          );
        }
        const result = {
          ...clone(existingSourceRecord.result),
          acknowledgedEventId: evidence.eventId,
          acknowledgedSourceRecordId: evidence.sourceRecordId,
          wasDuplicate: true,
        };
        await transaction.rememberDuplicateEvent(evidence.eventId, {
          ...existingSourceRecord,
          result,
        });
        return result;
      }

      const fingerprint = activityFingerprint(evidence);
      const existingSettlement = await transaction.getSettlement(fingerprint);
      if (existingSettlement) {
        const receipt = existingSettlement.result.receipt;
        if (
          receipt.acceptedMetric !== evidence.metricValue ||
          receipt.metricUnit !== evidence.metricUnit
        ) {
          throw new ActivityLedgerValidationError(
            "The activity settlement conflicts with its existing receipt.",
          );
        }
        const contributions = clone(existingSettlement.result.contributions);
        const contributedRoomIds = new Set(
          contributions.map(contribution => contribution.roomId),
        );
        const newContributions = [];
        const createdAt = this.clock().toISOString();
        for (const roomId of new Set(evidence.roomIds)) {
          if (contributedRoomIds.has(roomId)) {
            continue;
          }
          const membership = await transaction.getRoomMembership(
            roomId,
            evidence.actorUserId,
          );
          if (!membershipAllowsContribution(membership, evidence.occurredAt)) {
            continue;
          }
          const contribution = {
            contributionId: `${receipt.receiptId}_${stableHash(roomId).slice(0, 24)}`,
            receiptId: receipt.receiptId,
            roomId,
            actorUserId: evidence.actorUserId,
            metricValue: receipt.acceptedMetric,
            metricUnit: receipt.metricUnit,
            createdAt,
          };
          contributions.push(contribution);
          newContributions.push(contribution);
        }
        const result = {
          ...clone(existingSettlement.result),
          acknowledgedEventId: evidence.eventId,
          acknowledgedSourceRecordId: evidence.sourceRecordId,
          contributions,
          wasDuplicate: true,
        };
        if (newContributions.length > 0) {
          const primaryResult = {
            ...clone(result),
            acknowledgedEventId: existingSettlement.evidence.eventId,
            acknowledgedSourceRecordId:
              existingSettlement.evidence.sourceRecordId,
            wasDuplicate: false,
          };
          await transaction.mergeSettlement({
            fingerprint,
            primaryEvent: existingSettlement,
            duplicateEventId: evidence.eventId,
            duplicateEvent: { signature, evidence, result },
            sourceKey,
            receipt,
            newContributions,
            primaryResult,
          });
        } else {
          await transaction.rememberDuplicateEvent(
            evidence.eventId,
            { signature, evidence, result },
            sourceKey,
          );
        }
        return result;
      }

      const existingSession = await transaction.getSession(fingerprint);
      const session = this.#transitionSession(existingSession, evidence);
      const isSettlement = ["completed", "metricSynced"].includes(
        evidence.eventType,
      );
      if (!isSettlement) {
        const result = {
          status: "accepted",
          acknowledgedEventId: evidence.eventId,
          acknowledgedSourceRecordId: evidence.sourceRecordId,
          canonicalSessionId: session.activitySessionId,
          receipt: null,
          contributions: [],
          session,
          wasDuplicate: false,
        };
        await transaction.createActivityEvent({
          eventId: evidence.eventId,
          event: { signature, evidence, result },
          sourceKey,
          fingerprint,
          session,
        });
        return clone(result);
      }

      const verifiedAt = this.clock().toISOString();
      const receiptId = `receipt_${stableHash(fingerprint).slice(0, 40)}`;
      const receipt = {
        receiptId,
        eventId: evidence.eventId,
        sourceRecordId: evidence.sourceRecordId,
        sessionId: evidence.activityCorrelationId ?? evidence.sessionId,
        actorUserId: evidence.actorUserId,
        activityType: evidence.activityType,
        activityFingerprint: fingerprint,
        acceptedMetric: evidence.metricValue,
        metricUnit: evidence.metricUnit,
        personalRewardIssued: true,
        characterExperienceIssued: true,
        verifiedAt,
        correctionOfReceiptId: null,
      };
      const contributions = [];
      for (const roomId of new Set(evidence.roomIds)) {
        const membership = await transaction.getRoomMembership(
          roomId,
          evidence.actorUserId,
        );
        if (!membershipAllowsContribution(membership, evidence.occurredAt)) {
          continue;
        }
        contributions.push({
          contributionId: `${receiptId}_${stableHash(roomId).slice(0, 24)}`,
          receiptId,
          roomId,
          actorUserId: evidence.actorUserId,
          metricValue: evidence.metricValue,
          metricUnit: evidence.metricUnit,
          createdAt: verifiedAt,
        });
      }
      const result = {
        status: "settled",
        acknowledgedEventId: evidence.eventId,
        acknowledgedSourceRecordId: evidence.sourceRecordId,
        canonicalSessionId: receipt.sessionId,
        receipt,
        contributions,
        session,
        wasDuplicate: false,
      };
      await transaction.createSettlement({
        eventId: evidence.eventId,
        event: { signature, evidence, result },
        receipt,
        sourceKey,
        fingerprint,
        session,
      });
      return clone(result);
    });
  }

  #transitionSession(existingSession, evidence) {
    if (
      !existingSession &&
      ["paused", "resumed"].includes(evidence.eventType)
    ) {
      throw new ActivityLedgerValidationError(
        "The activity session is not active.",
      );
    }
    const session = existingSession
      ? clone(existingSession)
      : {
          activitySessionId:
            evidence.activityCorrelationId ?? evidence.sessionId,
          actorUserId: evidence.actorUserId,
          activityType: evidence.activityType,
          status: "active",
          startedAt: evidence.occurredAt,
          endedAt: null,
          metricValue: 0,
          metricUnit: evidence.metricUnit,
          sourceSessionIds: [],
        };
    if (
      session.status === "completed" &&
      !["completed", "metricSynced"].includes(evidence.eventType)
    ) {
      throw new ActivityLedgerValidationError(
        "A completed activity session cannot change state.",
      );
    }
    session.sourceSessionIds = [
      ...new Set([...session.sourceSessionIds, evidence.sessionId]),
    ];
    switch (evidence.eventType) {
      case "started":
        break;
      case "paused":
        session.status = "paused";
        session.metricValue = evidence.metricValue;
        session.metricUnit = evidence.metricUnit;
        break;
      case "resumed":
        session.status = "active";
        session.metricValue = evidence.metricValue;
        session.metricUnit = evidence.metricUnit;
        break;
      case "completed":
      case "metricSynced":
        session.status = "completed";
        session.endedAt = evidence.occurredAt;
        session.metricValue = evidence.metricValue;
        session.metricUnit = evidence.metricUnit;
        break;
      default:
        throw new ActivityLedgerValidationError(
          "Unsupported activity event type.",
        );
    }
    return session;
  }

  #validateAndNormalize(principal, rawEvidence) {
    if (!principal || principal.kind !== "user" || !principal.userId) {
      throw new ActivityLedgerAuthorizationError(
        "An authenticated user is required.",
      );
    }
    if (
      rawEvidence === null ||
      typeof rawEvidence !== "object" ||
      Array.isArray(rawEvidence)
    ) {
      throw new ActivityLedgerValidationError(
        "Activity evidence must be an object.",
      );
    }
    const evidence = {
      ...rawEvidence,
      roomIds: Array.isArray(rawEvidence?.roomIds) ? rawEvidence.roomIds : [],
    };
    if (principal.userId !== evidence.actorUserId) {
      throw new ActivityLedgerAuthorizationError(
        "Only the actor can control this activity.",
      );
    }
    if (evidence.source === "device") {
      throw new ActivityLedgerAuthorizationError(
        "User ingestion cannot submit device evidence.",
      );
    }
    const requiredStrings = [
      evidence.eventId,
      evidence.sourceRecordId,
      evidence.sessionId,
      evidence.actorUserId,
      evidence.activityType,
      evidence.source,
      evidence.eventType,
      evidence.metricUnit,
      evidence.occurredAt,
    ];
    if (
      requiredStrings.some(
        value => typeof value !== "string" || value.trim().length === 0,
      )
    ) {
      throw new ActivityLedgerValidationError(
        "Activity identifiers and metric units cannot be empty.",
      );
    }
    if (!ACTIVITY_TYPES.has(evidence.activityType)) {
      throw new ActivityLedgerValidationError(
        "Unsupported activity type.",
      );
    }
    if (!ACTIVITY_SOURCES.has(evidence.source)) {
      throw new ActivityLedgerValidationError(
        "Unsupported activity source.",
      );
    }
    if (
      evidence.activityCorrelationId !== null &&
      evidence.activityCorrelationId !== undefined &&
      (typeof evidence.activityCorrelationId !== "string" ||
        evidence.activityCorrelationId.trim().length === 0)
    ) {
      throw new ActivityLedgerValidationError(
        "Activity correlation ID must be a non-empty string.",
      );
    }
    if (
      evidence.roomIds.some(
        roomId => typeof roomId !== "string" || roomId.trim().length === 0,
      )
    ) {
      throw new ActivityLedgerValidationError(
        "Room IDs must be non-empty strings.",
      );
    }
    if (
      typeof evidence.metricValue !== "number" ||
      !Number.isFinite(evidence.metricValue) ||
      evidence.metricValue < 0
    ) {
      throw new ActivityLedgerValidationError(
        "Activity metrics must be finite and non-negative.",
      );
    }
    if (
      !ACTIVITY_EVENT_TYPES.has(evidence.eventType)
    ) {
      throw new ActivityLedgerValidationError(
        "Unsupported activity event type.",
      );
    }
    const occurredAt = new Date(evidence.occurredAt);
    if (Number.isNaN(occurredAt.getTime())) {
      throw new ActivityLedgerValidationError(
        "Activity occurrence time must be a valid timestamp.",
      );
    }
    return {
      ...evidence,
      occurredAt: occurredAt.toISOString(),
      activityCorrelationId: evidence.activityCorrelationId?.trim() ?? null,
      roomIds: [...new Set(evidence.roomIds.map(roomId => roomId.trim()))],
    };
  }
}
