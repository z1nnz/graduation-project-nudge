import { HttpsError } from "firebase-functions/v2/https";

const CUE_KEYS = new Set([
  "gentle_restart",
  "open_to_company",
  "starting_small",
  "completed_step",
]);
const RESPONSE_KEYS = new Set([
  "with_you",
  "cheer",
  "take_your_time",
]);
const ACTION_KEYS = Object.freeze({
  set_preference: new Set([
    "action",
    "roomId",
    "sourceSurface",
    "clientRequestId",
    "enabled",
  ]),
  publish: new Set([
    "action",
    "roomId",
    "sourceSurface",
    "clientRequestId",
    "cueKey",
  ]),
  acknowledge: new Set([
    "action",
    "roomId",
    "sourceSurface",
    "clientRequestId",
    "ownerUserId",
    "generationId",
    "responseKey",
  ]),
  withdraw: new Set([
    "action",
    "roomId",
    "sourceSurface",
    "clientRequestId",
  ]),
});

function normalizedString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function requireStableId(value, label, { min = 2 } = {}) {
  const normalized = normalizedString(value);
  if (
    normalized.length < min ||
    normalized.length > 128 ||
    !/^[A-Za-z0-9_-]+$/.test(normalized)
  ) {
    throw new HttpsError(
      "invalid-argument",
      `A valid ${label} is required.`,
    );
  }
  return normalized;
}

export function normalizeRoomResonanceRequest(data) {
  if (data === null || typeof data !== "object" || Array.isArray(data)) {
    throw new HttpsError(
      "invalid-argument",
      "A room resonance command is required.",
    );
  }
  const action = normalizedString(data.action);
  const allowedKeys = ACTION_KEYS[action];
  if (
    !allowedKeys ||
    Object.keys(data).some(key => !allowedKeys.has(key))
  ) {
    throw new HttpsError(
      "invalid-argument",
      "The room resonance command contains unsupported fields.",
    );
  }
  const roomId = requireStableId(data.roomId, "roomId");
  const clientRequestId = requireStableId(
    data.clientRequestId,
    "clientRequestId",
    { min: 8 },
  );
  const sourceSurface = normalizedString(data.sourceSurface);
  if (!["app", "web"].includes(sourceSurface)) {
    throw new HttpsError(
      "invalid-argument",
      "The room resonance source surface is invalid.",
    );
  }
  const normalized = {
    action,
    roomId,
    clientRequestId,
    sourceSurface,
  };
  if (action === "set_preference") {
    if (typeof data.enabled !== "boolean") {
      throw new HttpsError(
        "invalid-argument",
        "The room resonance preference must be explicit.",
      );
    }
    normalized.enabled = data.enabled;
  }
  if (action === "publish") {
    const cueKey = normalizedString(data.cueKey);
    if (!CUE_KEYS.has(cueKey)) {
      throw new HttpsError(
        "invalid-argument",
        "The room resonance cue is unsupported.",
      );
    }
    normalized.cueKey = cueKey;
  }
  if (action === "acknowledge") {
    normalized.ownerUserId = requireStableId(
      data.ownerUserId,
      "ownerUserId",
    );
    normalized.generationId = requireStableId(
      data.generationId,
      "generationId",
      { min: 8 },
    );
    const responseKey = normalizedString(data.responseKey);
    if (!RESPONSE_KEYS.has(responseKey)) {
      throw new HttpsError(
        "invalid-argument",
        "The room resonance response is unsupported.",
      );
    }
    normalized.responseKey = responseKey;
  }
  return normalized;
}

function signalDocumentId(roomId, ownerUserId) {
  return `${roomId}--${ownerUserId}`;
}

function preferenceDocumentId(roomId, userId) {
  return `${roomId}--${userId}`;
}

function acknowledgementDocumentId({
  roomId,
  ownerUserId,
  generationId,
  actorUserId,
}) {
  return [roomId, ownerUserId, generationId, actorUserId].join("--");
}

function snapshotData(snapshot) {
  return snapshot?.exists ? snapshot.data() : null;
}

function assertApprovedMember({ room, member, userId }) {
  if (
    !room ||
    room.status !== "active" ||
    !Array.isArray(room.memberIds) ||
    !room.memberIds.includes(userId) ||
    !member ||
    member.memberId !== userId ||
    member.approvalStatus !== "approved"
  ) {
    throw new HttpsError(
      "permission-denied",
      "An approved active room membership is required.",
    );
  }
}

function assertReplay({ replay, userId, input }) {
  if (
    replay.actorUserId !== userId ||
    replay.action !== `room.resonance.${input.action}` ||
    replay.targetId !== input.roomId
  ) {
    throw new HttpsError(
      "already-exists",
      "The room resonance clientRequestId was already used.",
    );
  }
  return { replayed: true, ...replay.result };
}

export function createManageRoomResonanceHandler({ firestore, clock }) {
  return async request => {
    const userId = request.auth?.uid;
    if (!userId) {
      throw new HttpsError(
        "unauthenticated",
        "Authentication is required to manage room resonance.",
      );
    }
    const input = normalizeRoomResonanceRequest(request.data);
    if (input.action === "acknowledge" && input.ownerUserId === userId) {
      throw new HttpsError(
        "permission-denied",
        "A member cannot acknowledge their own resonance cue.",
      );
    }
    const now = clock();
    if (!(now instanceof Date) || Number.isNaN(now.getTime())) {
      throw new HttpsError("internal", "The room resonance clock is invalid.");
    }
    const timestamp = now.toISOString();
    const roomRef = firestore.collection("rooms").doc(input.roomId);
    const memberRef = roomRef.collection("members").doc(userId);
    const preferenceRef = firestore
      .collection("room_resonance_preferences")
      .doc(preferenceDocumentId(input.roomId, userId));
    const ownerUserId = input.action === "acknowledge"
      ? input.ownerUserId
      : userId;
    const signalRef = firestore
      .collection("room_resonance_signals")
      .doc(signalDocumentId(input.roomId, ownerUserId));
    const ownerMemberRef = roomRef.collection("members").doc(ownerUserId);
    const acknowledgementRef = input.action === "acknowledge"
      ? firestore.collection("room_resonance_acknowledgements").doc(
          acknowledgementDocumentId({
            roomId: input.roomId,
            ownerUserId,
            generationId: input.generationId,
            actorUserId: userId,
          }),
        )
      : null;
    const auditRef = firestore.collection("audit_events").doc(
      `room-resonance--${input.roomId}--${userId}--${input.clientRequestId}`,
    );

    return firestore.runTransaction(async transaction => {
      const reads = [
        transaction.get(auditRef),
        transaction.get(roomRef),
        transaction.get(memberRef),
      ];
      if (["set_preference", "publish"].includes(input.action)) {
        reads.push(transaction.get(preferenceRef));
      }
      if (["set_preference", "publish", "withdraw", "acknowledge"]
        .includes(input.action)) {
        reads.push(transaction.get(signalRef));
      }
      if (input.action === "acknowledge") {
        reads.push(transaction.get(ownerMemberRef));
        reads.push(transaction.get(acknowledgementRef));
      }
      const snapshots = await Promise.all(reads);
      let cursor = 0;
      const auditSnapshot = snapshots[cursor++];
      const room = snapshotData(snapshots[cursor++]);
      const member = snapshotData(snapshots[cursor++]);
      assertApprovedMember({ room, member, userId });
      if (auditSnapshot.exists) {
        return assertReplay({
          replay: auditSnapshot.data(),
          userId,
          input,
        });
      }

      let preference = null;
      if (["set_preference", "publish"].includes(input.action)) {
        preference = snapshotData(snapshots[cursor++]);
      }
      let signal = null;
      if (["set_preference", "publish", "withdraw", "acknowledge"]
        .includes(input.action)) {
        signal = snapshotData(snapshots[cursor++]);
      }
      let ownerMember = null;
      let acknowledgement = null;
      if (input.action === "acknowledge") {
        ownerMember = snapshotData(snapshots[cursor++]);
        acknowledgement = snapshotData(snapshots[cursor++]);
        assertApprovedMember({ room, member: ownerMember, userId: ownerUserId });
      }

      let result;
      if (input.action === "set_preference") {
        preference = {
          schemaVersion: 1,
          preferenceId: preferenceDocumentId(input.roomId, userId),
          roomId: input.roomId,
          userId,
          enabled: input.enabled,
          audience: "room_members_only",
          shareMode: "cue_only",
          updatedAt: timestamp,
        };
        transaction.set(preferenceRef, preference);
        if (!input.enabled && signal?.status === "active") {
          signal = {
            ...signal,
            status: "withdrawn",
            withdrawnAt: timestamp,
            updatedAt: timestamp,
          };
          transaction.set(signalRef, signal);
        }
        result = { preference, signal };
      } else if (input.action === "publish") {
        if (preference?.enabled !== true) {
          throw new HttpsError(
            "failed-precondition",
            "Room resonance sharing must be enabled before publishing.",
          );
        }
        signal = {
          schemaVersion: 1,
          signalId: signalDocumentId(input.roomId, userId),
          roomId: input.roomId,
          ownerUserId: userId,
          generationId: input.clientRequestId,
          cueKey: input.cueKey,
          status: "active",
          visibility: "room_members_only",
          acknowledgementCount: 0,
          createdAt: timestamp,
          updatedAt: timestamp,
          expiresAt: new Date(now.getTime() + 24 * 60 * 60 * 1000)
            .toISOString(),
          withdrawnAt: null,
        };
        transaction.set(signalRef, signal);
        result = { signal };
      } else if (input.action === "withdraw") {
        if (!signal || signal.ownerUserId !== userId) {
          throw new HttpsError(
            "not-found",
            "The room resonance cue was not found.",
          );
        }
        if (signal.status === "active") {
          signal = {
            ...signal,
            status: "withdrawn",
            withdrawnAt: timestamp,
            updatedAt: timestamp,
          };
          transaction.set(signalRef, signal);
        }
        result = { signal };
      } else {
        const expiresAt = Date.parse(signal?.expiresAt);
        const acknowledgementCount = signal?.acknowledgementCount;
        if (
          !signal ||
          signal.roomId !== input.roomId ||
          signal.ownerUserId !== ownerUserId ||
          signal.generationId !== input.generationId ||
          signal.status !== "active" ||
          !Number.isFinite(expiresAt) ||
          expiresAt <= now.getTime() ||
          !Number.isInteger(acknowledgementCount) ||
          acknowledgementCount < 0
        ) {
          throw new HttpsError(
            "failed-precondition",
            "The room resonance cue is no longer active.",
          );
        }
        if (acknowledgement) {
          result = { signal, acknowledgement };
        } else {
          acknowledgement = {
            schemaVersion: 1,
            acknowledgementId: acknowledgementRef.id,
            roomId: input.roomId,
            signalId: signal.signalId,
            signalOwnerUserId: ownerUserId,
            generationId: input.generationId,
            actorUserId: userId,
            responseKey: input.responseKey,
            createdAt: timestamp,
          };
          signal = {
            ...signal,
            acknowledgementCount: acknowledgementCount + 1,
            updatedAt: timestamp,
          };
          transaction.create(acknowledgementRef, acknowledgement);
          transaction.set(signalRef, signal);
          result = { signal, acknowledgement };
        }
      }

      transaction.create(auditRef, {
        schemaVersion: 1,
        auditEventId: auditRef.id,
        category: "room_resonance",
        action: `room.resonance.${input.action}`,
        actorUserId: userId,
        actorPrincipalId: userId,
        targetType: "room",
        targetId: input.roomId,
        sourceSurface: input.sourceSurface,
        clientRequestId: input.clientRequestId,
        result,
        createdAt: timestamp,
      });
      return { replayed: false, ...result, auditEventId: auditRef.id };
    });
  };
}
