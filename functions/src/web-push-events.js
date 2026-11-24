import { createHash } from "node:crypto";
import { buildPushDeliveryJob } from "./push-notification-service.js";
import { hasWebPushKind } from "./web-push-preferences.js";

export function createQueueWebSocialPushHandler(firestore) {
  return async event => {
    const initial = event.data?.data();
    if (!hasWebPushKind(initial?.kind) || initial.category === "relationship") return;
    const ref = firestore.collection("push_delivery_jobs").doc(event.params.notificationId);
    await firestore.runTransaction(async transaction => {
      const [notice, job] = await Promise.all([transaction.get(event.data.ref), transaction.get(ref)]);
      if (notice.exists && !job.exists) {
        transaction.create(ref, { ...buildPushDeliveryJob(notice.data()), webOnly: true });
      }
    });
  };
}

export function createFocusRoundWebPushHandler(firestore) {
  return async event => {
    const round = event.data?.after.data();
    const startAt = round?.startAt?.toMillis?.();
    if (!Number.isFinite(startAt) || startAt === event.data.before.data()?.startAt?.toMillis?.()) return;
    const roomId = event.params.roomId;
    const room = event.data.after.ref.parent.parent;
    await firestore.runTransaction(async transaction => {
      const [current, metadata, roster] = await Promise.all([
        transaction.get(event.data.after.ref), transaction.get(room),
        transaction.get(room.collection("members").where("approvalStatus", "==", "approved")),
      ]);
      if (current.data()?.startAt?.toMillis?.() !== startAt || metadata.data()?.status !== "active") return;
      const uids = new Set(metadata.data().memberIds);
      const recipients = roster.docs.filter(doc => uids.has(doc.id) && doc.id !== round.startedBy);
      const ids = recipients.map(doc => "web-focus--" + createHash("sha256")
        .update(JSON.stringify([roomId, startAt, doc.id])).digest("hex"));
      const refs = ids.map(id => firestore.collection("push_delivery_jobs").doc(id));
      const previous = await Promise.all(refs.map(ref => transaction.get(ref)));
      refs.forEach((ref, index) => {
        if (previous[index].exists) return;
        const now = new Date(startAt).toISOString();
        transaction.create(ref, {
          ...buildPushDeliveryJob({
            notificationId: ref.id, recipientUserId: recipients[index].id,
            actorUserId: round.startedBy, actorPrincipalId: round.startedBy,
            category: "social", kind: "room_focus_round", title: "房間開始了一輪專注",
            body: "開啟自律房查看同步番茄鐘。", route: "rooms", roomId,
            createdAt: now, updatedAt: now,
          }),
          webOnly: true,
        });
      });
    });
  };
}
