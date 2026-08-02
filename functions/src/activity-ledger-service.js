import { createHash } from "node:crypto";

const ACTIVITY_TYPES = new Set([
  "focus",
  "study",
  "exercise",
  "steps",
  "sleep",
  "task",
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
const ACTIVITY_POLICIES = new Map([
  ["focus", { unit: "minutes", maximum: 1440, rewardable: true }],
  ["study", { unit: "minutes", maximum: 1440, rewardable: true }],
  ["exercise", { unit: "minutes", maximum: 1440, rewardable: true }],
  ["steps", { unit: "steps", maximum: 200000, rewardable: true }],
  ["sleep", { unit: "hours", maximum: 24, rewardable: true }],
  ["task", { unit: "completion", maximum: 1, rewardable: false }],
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
    evidence.healthContext,
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
  if (evidence.source === "health" && evidence.eventType === "metricSynced") {
    return false;
  }
  const policy = ACTIVITY_POLICIES.get(evidence.activityType);
  if (!policy?.rewardable || evidence.metricValue <= 0) {
    return false;
  }
  return (
    evidence.metricUnit === policy.unit &&
    evidence.metricValue <= policy.maximum
  );
}

function stableTaskKey(value) {
  let hash = 14695981039346656037n;
  const prime = 1099511628211n;
  for (let index = 0; index < value.length; index += 1) {
    hash ^= BigInt(value.charCodeAt(index));
    hash = BigInt.asUintN(64, hash * prime);
  }
  return hash.toString(16).padStart(16, "0");
}

function taipeiTaskDateKey(occurredAt) {
  const shifted = new Date(occurredAt.getTime() + 3 * 60 * 60 * 1000);
  return shifted.toISOString().slice(0, 10);
}

function isMutableMetricCorrection(existingSettlement, evidence) {
  const isHealthCorrection =
    existingSettlement.evidence.source === "health" &&
    existingSettlement.evidence.eventType === "metricSynced" &&
    evidence.source === "health" &&
    ["metricSynced", "completed"].includes(evidence.eventType);
  const isTaskCorrection =
    existingSettlement.evidence.activityType === "task" &&
    existingSettlement.evidence.eventType === "metricSynced" &&
    evidence.activityType === "task" &&
    ["app", "web"].includes(evidence.source) &&
    evidence.eventType === "metricSynced";
  return (
    isHealthCorrection ||
    isTaskCorrection
  );
}

function normalizeHealthContext(rawContext) {
  if (rawContext === null || rawContext === undefined) {
    return null;
  }
  if (typeof rawContext !== "object" || Array.isArray(rawContext)) {
    throw new ActivityLedgerValidationError(
      "Health context must be an object.",
    );
  }
  const provider = rawContext.provider;
  const localDate = rawContext.localDate;
  const periodStart = rawContext.periodStart;
  const periodEnd = rawContext.periodEnd;
  const rawOrigins = Array.isArray(rawContext.dataOrigins)
    ? rawContext.dataOrigins
    : [];
  if (
    rawOrigins.some(origin => typeof origin !== "string")
  ) {
    throw new ActivityLedgerValidationError(
      "Health data origins must be strings.",
    );
  }
  const dataOrigins = [
    ...new Set(rawOrigins.map(origin => origin.trim())),
  ].sort();
  if (!["healthConnect", "appleHealth"].includes(provider)) {
    throw new ActivityLedgerValidationError("Unsupported health provider.");
  }
  if (
    typeof localDate !== "string" ||
    !/^\d{4}-\d{2}-\d{2}$/.test(localDate)
  ) {
    throw new ActivityLedgerValidationError(
      "Health context requires a local date.",
    );
  }
  const start = new Date(periodStart);
  const end = new Date(periodEnd);
  if (
    typeof periodStart !== "string" ||
    typeof periodEnd !== "string" ||
    Number.isNaN(start.getTime()) ||
    Number.isNaN(end.getTime()) ||
    end.getTime() <= start.getTime()
  ) {
    throw new ActivityLedgerValidationError(
      "Health context requires a valid period.",
    );
  }
  if (
    dataOrigins.length > 20 ||
    dataOrigins.some(origin => origin.length === 0 || origin.length > 256)
  ) {
    throw new ActivityLedgerValidationError(
      "Health data origins exceed the supported limits.",
    );
  }
  return {
    provider,
    localDate,
    periodStart: start.toISOString(),
    periodEnd: end.toISOString(),
    dataOrigins,
  };
}

export class InMemoryActivityLedgerStore {
  #events = new Map();
  #receipts = new Map();
  #memberships = new Map();
  #sourceRecords = new Map();
  #settlements = new Map();
  #sessions = new Map();
  #userTasks = new Map();

  constructor({ roomMemberships = [], userTasks = {} } = {}) {
    for (const membership of roomMemberships) {
      this.#memberships.set(
        `${membership.roomId}:${membership.userId}`,
        clone(membership),
      );
    }
    for (const [userId, tasks] of Object.entries(userTasks)) {
      this.#userTasks.set(userId, clone(tasks));
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

  async getTaskProjection(userId, taskId) {
    const task = (this.#userTasks.get(userId) ?? []).find(
      candidate => candidate.id === taskId,
    );
    return task ? clone(task) : null;
  }

  async updateTaskProjection(userId, taskId, completed, occurredAt) {
    const tasks = this.#userTasks.get(userId) ?? [];
    const index = tasks.findIndex(task => task.id === taskId);
    if (index < 0) return null;
    tasks[index] = {
      ...tasks[index],
      done: completed,
      isDone: completed,
      completedAt: completed ? occurredAt : null,
      updatedAt: occurredAt,
    };
    this.#userTasks.set(userId, tasks);
    return clone(tasks[index]);
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

  async createCorrectionSettlement({
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
        if (isMutableMetricCorrection(existingSettlement, evidence)) {
          if (
            new Date(evidence.occurredAt).getTime() <
            new Date(existingSettlement.evidence.occurredAt).getTime()
          ) {
            const result = {
              ...clone(existingSettlement.result),
              status: "superseded",
              acknowledgedEventId: evidence.eventId,
              acknowledgedSourceRecordId: evidence.sourceRecordId,
              wasDuplicate: false,
            };
            await transaction.rememberDuplicateEvent(
              eventKey,
              { signature, evidence, result },
              sourceKey,
            );
            return clone(result);
          }
          const existingSession = await transaction.getSession(fingerprint);
          const session = this.#transitionSession(existingSession, evidence);
          const verifiedAt = this.clock().toISOString();
          const previousReceipt = existingSettlement.result.receipt;
          const receiptId = `receipt_${stableHash(
            `${fingerprint}:${sourceKey}`,
          ).slice(0, 40)}`;
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
            correctionOfReceiptId: previousReceipt.receiptId,
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
              correctionOfReceiptId: previousReceipt.receiptId,
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
          if (evidence.activityType === "task") {
            const projected = await transaction.updateTaskProjection(
              evidence.actorUserId,
              evidence.taskId,
              evidence.metricValue === 1,
              evidence.occurredAt,
            );
            if (!projected) {
              throw new ActivityLedgerValidationError(
                "Task activity requires an existing canonical task projection.",
              );
            }
          }
          await transaction.createCorrectionSettlement({
            eventKey,
            event: { signature, evidence, result },
            receipt,
            sourceKey,
            fingerprint,
            session,
          });
          return clone(result);
        }
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
      if (evidence.activityType === "task") {
        const projected = await transaction.updateTaskProjection(
          evidence.actorUserId,
          evidence.taskId,
          evidence.metricValue === 1,
          evidence.occurredAt,
        );
        if (!projected) {
          throw new ActivityLedgerValidationError(
            "Task activity requires an existing canonical task projection.",
          );
        }
      }
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
        evidence.eventType !== "completed")
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
        session.status = "completed";
        session.endedAt = evidence.occurredAt;
        session.metricValue = evidence.metricValue;
        session.metricUnit = evidence.metricUnit;
        break;
      case "metricSynced":
        session.status = "active";
        session.endedAt = null;
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
      taskId: rawEvidence.taskId ?? null,
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
      healthContext: isHealthAdapter
        ? normalizeHealthContext(rawEvidence.healthContext)
        : null,
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
    if (
      isHealthAdapter &&
      typeof principal.allowedActorUserId === "string" &&
      principal.allowedActorUserId !== evidence.actorUserId
    ) {
      throw new ActivityLedgerAuthorizationError(
        "The health adapter can only submit its assigned actor.",
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
    const rewardPolicy = ACTIVITY_POLICIES.get(evidence.activityType);
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
      evidence.activityType === "task" &&
      (evidence.eventType !== "metricSynced" ||
        ![0, 1].includes(evidence.metricValue))
    ) {
      throw new ActivityLedgerValidationError(
        "Task activity must synchronize a binary completion metric.",
      );
    }
    if (
      evidence.activityType === "task" &&
      (evidence.roomIds.length > 0 ||
        !evidence.activityCorrelationId?.startsWith(
          `task:${evidence.actorUserId}:`,
        ))
    ) {
      throw new ActivityLedgerValidationError(
        "Task activity must remain personal and use its daily correlation.",
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
    if (evidence.activityType === "task") {
      const taskId = typeof evidence.taskId === "string"
        ? evidence.taskId.trim()
        : "";
      const expectedCorrelation = taskId && taskId.length <= 256
        ? `task:${evidence.actorUserId}:${stableTaskKey(taskId)}:${taipeiTaskDateKey(occurredAt)}`
        : null;
      if (
        !expectedCorrelation ||
        evidence.activityCorrelationId !== expectedCorrelation ||
        evidence.sessionId !== expectedCorrelation
      ) {
        throw new ActivityLedgerValidationError(
          "Task activity must use its verified task, session and 05:00 daily correlation.",
        );
      }
      evidence.taskId = taskId;
    } else if (evidence.taskId !== null) {
      throw new ActivityLedgerValidationError(
        "Only task activity can include a task identifier.",
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
