import { HttpsError } from "firebase-functions/v2/https";

export const NOTIFICATION_PREFERENCE_SCHEMA_VERSION = 1;
export const NOTIFICATION_CHANNEL_KEYS = Object.freeze([
  "tasks",
  "sleep",
  "rooms",
  "deadline",
]);

const DEFAULT_CHANNELS = Object.freeze({
  tasks: Object.freeze({ enabled: true, timeLabel: "20:30" }),
  sleep: Object.freeze({ enabled: true, timeLabel: "23:00" }),
  rooms: Object.freeze({ enabled: true, timeLabel: "19:30" }),
  deadline: Object.freeze({ enabled: true, timeLabel: "09:00" }),
});

function normalizedString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function normalizeChannel(key, value) {
  if (
    value === null ||
    typeof value !== "object" ||
    Array.isArray(value) ||
    typeof value.enabled !== "boolean"
  ) {
    throw new HttpsError(
      "invalid-argument",
      `Notification channel ${key} is invalid.`,
    );
  }
  const timeLabel = normalizedString(value.timeLabel);
  if (!/^(?:[01]\d|2[0-3]):[0-5]\d$/.test(timeLabel)) {
    throw new HttpsError(
      "invalid-argument",
      `Notification channel ${key} requires a valid 24-hour time.`,
    );
  }
  return { enabled: value.enabled, timeLabel };
}

export function defaultNotificationChannels() {
  return structuredClone(DEFAULT_CHANNELS);
}

export function normalizeNotificationPreferenceRequest(data) {
  const clientRequestId = normalizedString(data?.clientRequestId);
  const sourceSurface = normalizedString(data?.sourceSurface);
  if (!/^[A-Za-z0-9_-]{8,128}$/.test(clientRequestId)) {
    throw new HttpsError(
      "invalid-argument",
      "A stable notification clientRequestId is required.",
    );
  }
  if (!["app", "web"].includes(sourceSurface)) {
    throw new HttpsError(
      "invalid-argument",
      "Notification preference sourceSurface is invalid.",
    );
  }
  const channels = data?.channels;
  if (
    channels === null ||
    typeof channels !== "object" ||
    Array.isArray(channels)
  ) {
    throw new HttpsError(
      "invalid-argument",
      "Notification channels are required.",
    );
  }
  const suppliedKeys = Object.keys(channels).sort();
  const expectedKeys = [...NOTIFICATION_CHANNEL_KEYS].sort();
  if (
    suppliedKeys.length !== expectedKeys.length ||
    suppliedKeys.some((key, index) => key !== expectedKeys[index])
  ) {
    throw new HttpsError(
      "invalid-argument",
      "Notification channels must use the complete supported channel set.",
    );
  }

  return {
    clientRequestId,
    sourceSurface,
    channels: Object.fromEntries(
      NOTIFICATION_CHANNEL_KEYS.map(key => [
        key,
        normalizeChannel(key, channels[key]),
      ]),
    ),
  };
}

export function createUpdateNotificationPreferencesHandler({
  firestore,
  clock,
}) {
  return async request => {
    const userId = request.auth?.uid;
    if (!userId) {
      throw new HttpsError(
        "unauthenticated",
        "Authentication is required to update notification preferences.",
      );
    }
    const input = normalizeNotificationPreferenceRequest(request.data);
    const timestamp = clock().toISOString();
    const preferenceRef = firestore
      .collection("notification_preferences")
      .doc(userId);
    const auditRef = firestore
      .collection("audit_events")
      .doc(`notification-preferences--${userId}--${input.clientRequestId}`);

    return firestore.runTransaction(async transaction => {
      const replay = await transaction.get(auditRef);
      if (replay.exists) {
        const replayData = replay.data();
        if (
          replayData.actorUserId !== userId ||
          replayData.action !== "notifications.preferences.update"
        ) {
          throw new HttpsError(
            "already-exists",
            "The notification clientRequestId was already used.",
          );
        }
        return {
          replayed: true,
          preferences: replayData.result,
          auditEventId: auditRef.id,
        };
      }

      const result = {
        schemaVersion: NOTIFICATION_PREFERENCE_SCHEMA_VERSION,
        userId,
        channels: input.channels,
        delivery: {
          localScheduled: true,
          inApp: true,
          pushConfigured: false,
        },
        updatedAt: timestamp,
        updatedBy: userId,
      };
      transaction.set(preferenceRef, result);
      transaction.create(auditRef, {
        schemaVersion: 1,
        auditEventId: auditRef.id,
        category: "notifications",
        action: "notifications.preferences.update",
        actorUserId: userId,
        targetType: "user",
        targetId: userId,
        sourceSurface: input.sourceSurface,
        clientRequestId: input.clientRequestId,
        result,
        createdAt: timestamp,
      });
      return {
        replayed: false,
        preferences: result,
        auditEventId: auditRef.id,
      };
    });
  };
}
