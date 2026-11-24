import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";

const MINUTE = 60_000;
const CHUNK = 200;

export async function removeVoiceParticipant(firestore, ref, { cutoff, joinedAt } = {}) {
  const room = ref.parent.parent;
  const capacity = room.collection("voice_state").doc("capacity");
  return firestore.runTransaction(async transaction => {
    const [participant, current] = await transaction.getAll(ref, capacity);
    if (!participant.exists) return false;
    if (joinedAt != null && participant.data().joinedAt !== joinedAt) return false;
    if (cutoff != null && !(participant.data().updatedAt?.toMillis?.() <= cutoff)) return false;
    if (current.exists) transaction.update(capacity, { uids: FieldValue.arrayRemove(ref.id) });
    transaction.delete(ref);
    return true;
  });
}

export function createCleanupRoomVoiceHandler(firestore, clock = () => Date.now()) {
  return async () => {
    const now = clock();
    const signalCutoff = Timestamp.fromMillis(now - 10 * MINUTE);
    const presenceCutoff = now - 2 * MINUTE;
    const signals = firestore.collectionGroup("voice_signals")
      .where("createdAt", "<=", signalCutoff).limit(CHUNK);
    const participants = firestore.collectionGroup("voice_participants")
      .where("updatedAt", "<=", Timestamp.fromMillis(presenceCutoff)).limit(CHUNK);

    for (;;) {
      const snapshot = await signals.get();
      if (snapshot.empty) break;
      const batch = firestore.batch();
      for (const signal of snapshot.docs) batch.delete(signal.ref);
      await batch.commit();
    }

    for (;;) {
      const snapshot = await participants.get();
      if (snapshot.empty) break;
      for (const participant of snapshot.docs) {
        await removeVoiceParticipant(firestore, participant.ref, { cutoff: presenceCutoff });
      }
    }
  };
}

export function createLeaveRoomVoiceHandler(firestore) {
  return async request => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Sign-in is required.");
    const { roomId, joinedAt } = request.data || {};
    if (typeof roomId !== "string" || !/^[^/]{1,180}$/.test(roomId) ||
        typeof joinedAt !== "string" || joinedAt.length > 30) {
      throw new HttpsError("invalid-argument", "Invalid voice presence.");
    }
    const ref = firestore.collection("rooms").doc(roomId).collection("voice_participants").doc(uid);
    return { removed: await removeVoiceParticipant(firestore, ref, { joinedAt }) };
  };
}
