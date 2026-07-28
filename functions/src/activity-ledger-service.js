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
  "discarded",
]);
const REWARD_POLICIES = new Map([
  ["focus", { unit: "minutes", maximum: 1440 }],
  ["study", { unit: "minutes", maximum: 1440 }],
  ["exercise", { unit: "minutes", maximum: 1440 }],
  ["steps", { unit: "steps", maximum: 200000 }],
  ["sleep", { unit: "hours", maximum: 24 }],
]);

export class ActivityLedgerAuthenticationError extends Error {
  constructor(message) {
    super(message);
    this.name = "ActivityLedgerAuthenticationError";
  }
}

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
  return JSON.stringify([
    evidence.sourceRecordId,
    evidence.sessionId,
    evidence.activityCorrelationId,
    evidence.submittedByUserId,
    evidence.submittedByServiceId,
    evidence.actorUserId,
    [...new Set(evidence.roomIds)].sort(),
    evidence.activityType,
    evidence.source,
    evidence.eventType,
    evidence.metricValue,
    evidence.metricUnit,
    evidence.occurredAt,
    evidence.deviceId,
  ]);
}

function sourceRecordKey(evidence) {
  return JSON.stringify([
    evidence.source,
    evidence.actorUserId,
    evidence.sourceRecordId,
  ]);
}

function activityEventKey(evidence) {
  return JSON.stringify([
    evidence.actorUserId,
    evidence.source,
    evidence.eventId,
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
  if (
    membership.sharingConsentRequired === true &&
    membership.sharingConsented !== true
  ) {
    return false;
  }
  if (
    Object.hasOwn(membership, "roomStatus") &&
    membership.roomStatus !== "active"
  ) {
    return false;
  }
  const hasStatus = membership.status !== undefined;
  const hasApproval = membership.approvalStatus !== undefined;
  if (
    (!hasStatus && !hasApproval) ||
    (hasStatus && membership.status !== "active") ||
    (hasApproval && membership.approvalStatus !== "approved")
  ) {
    return false;
  }
  const occurred = new Date(occurredAt).getTime();
  if (membership.activeFrom) {
    const activeFrom = new Date(membership.activeFrom).getTime();
    if (Number.isNaN(activeFrom) || occurred < activeFrom) {
      return false;
    }
  }
  if (membership.activeUntil) {
    const activeUntil = new Date(membership.activeUntil).getTime();
    if (Number.isNaN(activeUntil) || occurred >= activeUntil) {
      return false;
    }
  }
  return true;
}

function rewardEligibility(evidence) {
  const policy = REWARD_POLICIES.get(evidence.activityType);
  if (!policy || evidence.metricValue <= 0) {
    return false;
  }
  return (
    evidence.metricUnit === policy.unit &&
    evidence.metricValue <= policy.maximum
  );
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

  async getEvent(eventKey) {
    const value = this.#events.get(eventKey);
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

  async rememberDuplicateEvent(eventKey, event, sourceKey = null) {
    this.#events.set(eventKey, clone(event));
    if (sourceKey) {
      this.#sourceRecords.set(sourceKey, clone(event));
    }
  }

  async createSettlement({
    eventKey,
    event,
    receipt,
    sourceKey,
    fingerprint,
    session,
  }) {
    this.#events.set(eventKey, clone(event));
    this.#receipts.set(receipt.receiptId, clone(receipt));
    this.#sourceRecords.set(sourceKey, clone(event));
    this.#settlements.set(fingerprint, clone(event));
    this.#sessions.set(fingerprint, clone(session));
  }

  async createActivityEvent({
    eventKey,
    event,
    sourceKey,
    fingerprint,
    session,
  }) {
    this.#events.set(eventKey, clone(event));
    this.#sourceRecords.set(sourceKey, clone(event));
    this.#sessions.set(fingerprint, clone(session));
  }

  async mergeSettlement({
    fingerprint,
    primaryEventKey,
    primaryEvent,
    duplicateEventKey,
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
    this.#events.set(primaryEventKey, updatedPrimaryEvent);
    this.#events.set(duplicateEventKey, clone(duplicateEvent));
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
    const eventKey = activityEventKey(evidence);

    return this.store.runTransaction(async transaction => {
      const existing = await transaction.getEvent(eventKey);
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
        await transaction.rememberDuplicateEvent(
          eventKey,
          { signature, evidence, result },
        );
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
          if (
            !membershipAllowsContribution(
              membership,
              existingSettlement.evidence.occurredAt,
            )
          ) {
            continue;
          }
          const contribution = {
            contributionId: `${receipt.receiptId}_${stableHash(roomId).slice(0, 24)}`,
            receiptId: receipt.receiptId,
            roomId,
            actorUserId: evidence.actorUserId,
            metricValue: receipt.acceptedMetric,
            metricUnit: receipt.metricUnit,
            occurredAt: existingSettlement.evidence.occurredAt,
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
            primaryEventKey: activityEventKey(existingSettlement.evidence),
            primaryEvent: existingSettlement,
            duplicateEventKey: eventKey,
            duplicateEventId: evidence.eventId,
            duplicateEvent: { signature, evidence, result },
            sourceKey,
            receipt,
            newContributions,
            primaryResult,
          });
        } else {
          await transaction.rememberDuplicateEvent(
            eventKey,
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
          eventKey,
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
      const isRewardEligible = rewardEligibility(evidence);
      const receipt = {
        receiptId,
        eventId: evidence.eventId,
        sourceRecordId: evidence.sourceRecordId,
        activitySessionId:
          evidence.activityCorrelationId ?? evidence.sessionId,
        actorUserId: evidence.actorUserId,
        activityType: evidence.activityType,
        activityFingerprint: fingerprint,
        acceptedMetric: evidence.metricValue,
        metricUnit: evidence.metricUnit,
        rewardEligible: isRewardEligible,
        rewardIssued: false,
        characterExperienceEligible: isRewardEligible,
        characterExperienceIssued: false,
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
          occurredAt: evidence.occurredAt,
          createdAt: verifiedAt,
        });
      }
      const result = {
        status: "settled",
        acknowledgedEventId: evidence.eventId,
        acknowledgedSourceRecordId: evidence.sourceRecordId,
        canonicalSessionId: receipt.activitySessionId,
        receipt,
        contributions,
        session,
        wasDuplicate: false,
      };
      await transaction.createSettlement({
        eventKey,
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
          activityCorrelationId: evidence.activityCorrelationId,
          roomIds: evidence.roomIds,
          source: evidence.source,
          sourceDeviceId: evidence.deviceId,
          evidenceRef: evidence.sourceRecordId,
          status: "active",
          startedAt: evidence.occurredAt,
          endedAt: null,
          metricValue: 0,
          metricUnit: evidence.metricUnit,
          sourceSessionIds: [],
        };
    if (
      session.status === "discarded" ||
      (session.status === "completed" &&
        !["completed", "metricSynced"].includes(evidence.eventType))
    ) {
      throw new ActivityLedgerValidationError(
        `A ${session.status} activity session cannot change state.`,
      );
    }
    session.sourceSessionIds = [
      ...new Set([...session.sourceSessionIds, evidence.sessionId]),
    ];
    session.roomIds = [
      ...new Set([...(session.roomIds ?? []), ...evidence.roomIds]),
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
      case "discarded":
        session.status = "discarded";
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
    const isUser =
      principal?.kind === "user" &&
      typeof principal.userId === "string" &&
      principal.userId.length > 0;
    const isHealthAdapter =
      principal?.kind === "health_adapter" &&
      typeof principal.adapterId === "string" &&
      principal.adapterId.length > 0;
    if (!principal) {
      throw new ActivityLedgerAuthenticationError(
        "An authenticated principal is required.",
      );
    }
    if (!isUser && !isHealthAdapter) {
      throw new ActivityLedgerAuthorizationError(
        "The ingestion principal is not trusted.",
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
      eventId: rawEvidence.eventId,
      sourceRecordId: rawEvidence.sourceRecordId,
      sessionId: rawEvidence.sessionId,
      activityCorrelationId: rawEvidence.activityCorrelationId ?? null,
      submittedByUserId: isUser ? principal.userId : null,
      submittedByServiceId: isHealthAdapter ? principal.adapterId : null,
      actorUserId: rawEvidence.actorUserId,
      roomIds: Array.isArray(rawEvidence?.roomIds) ? rawEvidence.roomIds : [],
      activityType: rawEvidence.activityType,
      source: rawEvidence.source,
      eventType: rawEvidence.eventType,
      metricValue: rawEvidence.metricValue,
      metricUnit: rawEvidence.metricUnit,
      occurredAt: rawEvidence.occurredAt,
      receivedAt: this.clock().toISOString(),
      deviceId: null,
    };
    if (isUser && principal.userId !== evidence.actorUserId) {
      throw new ActivityLedgerAuthorizationError(
        "Only the actor can control this activity.",
      );
    }
    if (isUser && !["app", "web"].includes(evidence.source)) {
      throw new ActivityLedgerAuthorizationError(
        `User ingestion cannot submit ${String(evidence.source)} evidence.`,
      );
    }
    if (isHealthAdapter && evidence.source !== "health") {
      throw new ActivityLedgerAuthorizationError(
        "A health adapter can only submit health evidence.",
      );
    }
    if (rawEvidence.deviceId !== null && rawEvidence.deviceId !== undefined) {
      throw new ActivityLedgerAuthorizationError(
        "User ingestion cannot submit device identifiers.",
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
    const boundedIdentifiers = [
      evidence.eventId,
      evidence.sourceRecordId,
      evidence.sessionId,
      evidence.actorUserId,
      evidence.activityCorrelationId,
    ].filter(value => value !== null);
    if (
      boundedIdentifiers.some(value => value.length > 256) ||
      evidence.metricUnit.length > 64 ||
      evidence.roomIds.length > 20 ||
      evidence.roomIds.some(roomId => roomId.length > 256)
    ) {
      throw new ActivityLedgerValidationError(
        "Activity evidence exceeds the supported identifier limits.",
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
    const rewardPolicy = REWARD_POLICIES.get(evidence.activityType);
    if (
      (rewardPolicy &&
        (evidence.metricUnit !== rewardPolicy.unit ||
          evidence.metricValue > rewardPolicy.maximum)) ||
      (!rewardPolicy && evidence.metricValue > 1_000_000_000)
    ) {
      throw new ActivityLedgerValidationError(
        "Activity metric unit or range is invalid for this activity type.",
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
    const receivedAt = new Date(evidence.receivedAt);
    if (occurredAt.getTime() > receivedAt.getTime() + 5 * 60 * 1000) {
      throw new ActivityLedgerValidationError(
        "Activity occurrence time cannot be in the future.",
      );
    }
    return {
      ...evidence,
      eventId: evidence.eventId.trim(),
      sourceRecordId: evidence.sourceRecordId.trim(),
      sessionId: evidence.sessionId.trim(),
      actorUserId: evidence.actorUserId.trim(),
      activityType: evidence.activityType.trim(),
      source: evidence.source.trim(),
      eventType: evidence.eventType.trim(),
      metricUnit: evidence.metricUnit.trim(),
      occurredAt: occurredAt.toISOString(),
      activityCorrelationId: evidence.activityCorrelationId?.trim() ?? null,
      roomIds: [...new Set(evidence.roomIds.map(roomId => roomId.trim()))],
    };
  }
}
