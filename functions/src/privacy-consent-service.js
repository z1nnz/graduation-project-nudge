import { HttpsError } from "firebase-functions/v2/https";

export const CURRENT_PRIVACY_POLICY_VERSION = "2026-07-29";

function normalizedString(value) {
  return typeof value === "string" ? value.trim() : "";
}

export function normalizePrivacyConsentRequest(data) {
  const action = normalizedString(data?.action);
  const policyVersion = normalizedString(data?.policyVersion);
  const clientRequestId = normalizedString(data?.clientRequestId);
  const sourceSurface = normalizedString(data?.sourceSurface);
  if (!["accept", "revoke"].includes(action)) {
    throw new HttpsError("invalid-argument", "Privacy action is invalid.");
  }
  if (policyVersion !== CURRENT_PRIVACY_POLICY_VERSION) {
    throw new HttpsError(
      "failed-precondition",
      "The current privacy policy version must be acknowledged.",
    );
  }
  if (!/^[A-Za-z0-9_-]{8,128}$/.test(clientRequestId)) {
    throw new HttpsError(
      "invalid-argument",
      "A stable privacy clientRequestId is required.",
    );
  }
  if (!["app", "web"].includes(sourceSurface)) {
    throw new HttpsError(
      "invalid-argument",
      "Privacy consent sourceSurface is invalid.",
    );
  }
  return { action, policyVersion, clientRequestId, sourceSurface };
}

function consentResult({ action, policyVersion, timestamp }) {
  const accepted = action === "accept";
  return {
    status: accepted ? "accepted" : "revoked",
    policyVersion,
    scopes: {
      healthIngestion: accepted,
    },
    acceptedAt: accepted ? timestamp : null,
    revokedAt: accepted ? null : timestamp,
    updatedAt: timestamp,
  };
}

export function createRecordPrivacyConsentHandler({ firestore, clock }) {
  return async request => {
    const userId = request.auth?.uid;
    if (!userId) {
      throw new HttpsError(
        "unauthenticated",
        "Authentication is required to update privacy consent.",
      );
    }
    const input = normalizePrivacyConsentRequest(request.data);
    const timestamp = clock().toISOString();
    const consentRef = firestore.collection("privacy_consents").doc(userId);
    const auditRef = firestore
      .collection("audit_events")
      .doc(`privacy-consent--${userId}--${input.clientRequestId}`);

    return firestore.runTransaction(async transaction => {
      const replay = await transaction.get(auditRef);
      if (replay.exists) {
        const replayData = replay.data();
        if (
          replayData.actorUserId !== userId ||
          replayData.action !== `privacy.health.${input.action}` ||
          replayData.policyVersion !== input.policyVersion
        ) {
          throw new HttpsError(
            "already-exists",
            "The privacy clientRequestId was already used.",
          );
        }
        return {
          replayed: true,
          consent: replayData.result,
          auditEventId: auditRef.id,
        };
      }

      const result = consentResult({
        action: input.action,
        policyVersion: input.policyVersion,
        timestamp,
      });
      transaction.set(consentRef, {
        schemaVersion: 1,
        userId,
        ...result,
        updatedBy: userId,
      });
      transaction.create(auditRef, {
        schemaVersion: 1,
        auditEventId: auditRef.id,
        category: "privacy",
        action: `privacy.health.${input.action}`,
        actorUserId: userId,
        targetType: "user",
        targetId: userId,
        policyVersion: input.policyVersion,
        sourceSurface: input.sourceSurface,
        clientRequestId: input.clientRequestId,
        result,
        createdAt: timestamp,
      });
      return {
        replayed: false,
        consent: result,
        auditEventId: auditRef.id,
      };
    });
  };
}

export function createHealthConsentChecker({ firestore }) {
  return async userId => {
    const snapshot = await firestore
      .collection("privacy_consents")
      .doc(userId)
      .get();
    if (!snapshot.exists) return false;
    const consent = snapshot.data();
    return (
      consent.status === "accepted" &&
      consent.policyVersion === CURRENT_PRIVACY_POLICY_VERSION &&
      consent.scopes?.healthIngestion === true
    );
  };
}
