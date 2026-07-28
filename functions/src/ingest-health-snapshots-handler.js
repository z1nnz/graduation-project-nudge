import { createHash } from "node:crypto";

import {
  ActivityLedgerAuthenticationError,
  ActivityLedgerValidationError,
} from "./activity-ledger-service.js";

const PROVIDERS = new Map([
  ["healthConnect", "mobile-health-connect"],
  ["appleHealth", "mobile-apple-health"],
]);
const METRIC_UNITS = new Map([
  ["steps", "steps"],
  ["sleep", "hours"],
  ["exercise", "minutes"],
]);

function stableHash(value) {
  return createHash("sha256").update(JSON.stringify(value)).digest("hex");
}

function parseTimestamp(value, label) {
  if (typeof value !== "string") {
    throw new ActivityLedgerValidationError(`${label} must be a timestamp.`);
  }
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    throw new ActivityLedgerValidationError(`${label} must be a timestamp.`);
  }
  return parsed;
}

function normalizeSnapshot({
  snapshot,
  provider,
  userId,
  clock,
}) {
  if (
    snapshot === null ||
    typeof snapshot !== "object" ||
    Array.isArray(snapshot)
  ) {
    throw new ActivityLedgerValidationError(
      "Each health snapshot must be an object.",
    );
  }
  const activityType = snapshot.activityType;
  const expectedUnit = METRIC_UNITS.get(activityType);
  if (!expectedUnit) {
    throw new ActivityLedgerValidationError(
      "Unsupported health activity type.",
    );
  }
  if (snapshot.metricUnit !== expectedUnit) {
    throw new ActivityLedgerValidationError(
      "Health snapshot metric unit does not match its activity type.",
    );
  }
  if (
    typeof snapshot.localDate !== "string" ||
    !/^\d{4}-\d{2}-\d{2}$/.test(snapshot.localDate)
  ) {
    throw new ActivityLedgerValidationError(
      "Health snapshot local date is invalid.",
    );
  }
  const periodStart = parseTimestamp(snapshot.periodStart, "Period start");
  const periodEnd = parseTimestamp(snapshot.periodEnd, "Period end");
  const observedAt = parseTimestamp(snapshot.observedAt, "Observed time");
  if (periodEnd.getTime() <= periodStart.getTime()) {
    throw new ActivityLedgerValidationError(
      "Health snapshot period must have a positive duration.",
    );
  }
  if (periodEnd.getTime() > observedAt.getTime() + 5 * 60 * 1000) {
    throw new ActivityLedgerValidationError(
      "Health snapshot period cannot end after it was observed.",
    );
  }
  if (observedAt.getTime() > clock().getTime() + 5 * 60 * 1000) {
    throw new ActivityLedgerValidationError(
      "Health snapshot observation cannot be in the future.",
    );
  }
  const rawOrigins = snapshot.dataOrigins ?? [];
  if (
    !Array.isArray(rawOrigins) ||
    rawOrigins.some(origin => typeof origin !== "string")
  ) {
    throw new ActivityLedgerValidationError(
      "Health snapshot data origins must be strings.",
    );
  }
  const dataOrigins = [
    ...new Set(rawOrigins.map(origin => origin.trim())),
  ]
    .filter(Boolean)
    .sort();
  if (
    dataOrigins.length > 20 ||
    dataOrigins.some(origin => origin.length > 256)
  ) {
    throw new ActivityLedgerValidationError(
      "Health snapshot data origins exceed the supported limits.",
    );
  }

  const logicalHash = stableHash([
    userId,
    provider,
    activityType,
    snapshot.localDate,
  ]);
  const snapshotHash = stableHash([
    logicalHash,
    snapshot.metricValue,
    snapshot.metricUnit,
    periodStart.toISOString(),
    periodEnd.toISOString(),
    observedAt.toISOString(),
    dataOrigins,
  ]);
  const sessionId = `health_${logicalHash.slice(0, 48)}`;
  const eventId = `health_${snapshotHash.slice(0, 48)}`;
  return {
    eventId,
    sourceRecordId: eventId,
    sessionId,
    activityCorrelationId: sessionId,
    actorUserId: userId,
    roomIds: snapshot.roomIds ?? [],
    activityType,
    source: "health",
    eventType: "metricSynced",
    metricValue: snapshot.metricValue,
    metricUnit: snapshot.metricUnit,
    occurredAt: observedAt.toISOString(),
    healthContext: {
      provider,
      localDate: snapshot.localDate,
      periodStart: periodStart.toISOString(),
      periodEnd: periodEnd.toISOString(),
      dataOrigins,
    },
  };
}

export function createIngestHealthSnapshotsHandler({
  service,
  clock = () => new Date(),
}) {
  return async function ingestHealthSnapshotsRequest(request) {
    const userId = request?.auth?.uid;
    if (!userId) {
      throw new ActivityLedgerAuthenticationError(
        "An authenticated user is required.",
      );
    }
    const provider = request?.data?.provider;
    const adapterId = PROVIDERS.get(provider);
    if (!adapterId) {
      throw new ActivityLedgerValidationError(
        "Unsupported health provider.",
      );
    }
    const snapshots = request?.data?.snapshots;
    if (
      !Array.isArray(snapshots) ||
      snapshots.length === 0 ||
      snapshots.length > 12
    ) {
      throw new ActivityLedgerValidationError(
        "Health ingestion requires between 1 and 12 snapshots.",
      );
    }

    const principal = {
      kind: "health_adapter",
      adapterId,
      allowedActorUserId: userId,
    };
    const results = [];
    for (const snapshot of snapshots) {
      const evidence = normalizeSnapshot({
        snapshot,
        provider,
        userId,
        clock,
      });
      results.push(await service.record(principal, evidence));
    }
    return { accepted: results.length, results };
  };
}
