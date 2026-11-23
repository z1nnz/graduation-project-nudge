import { createHash } from "node:crypto";

export function createRoomChatMentionHandler(firestore) {
  return async event => {
    const messageRef = event.data?.ref;
    const initial = event.data?.data();
    if (!initial?.mentionUid || !messageRef) return;
    const room = messageRef.parent.parent;
    const id = "room-mention--" + createHash("sha256").update(messageRef.path).digest("hex");
    const ref = firestore.collection("user_notifications").doc(id);

    await firestore.runTransaction(async transaction => {
      const [notification, message, roomSnapshot, sender, recipient, senderFence, recipientFence] =
        await transaction.getAll(
          ref, messageRef, room,
          room.collection("members").doc(initial.senderId),
          room.collection("members").doc(initial.mentionUid),
          firestore.collection("account_deletion_fences").doc(initial.senderId),
          firestore.collection("account_deletion_fences").doc(initial.mentionUid),
        );
      const data = message.data();
      const roomData = roomSnapshot.data();
      if (notification.exists || data?.mentionUid !== initial.mentionUid ||
          senderFence.exists || recipientFence.exists || roomData?.status !== "active" ||
          !roomData.memberIds.includes(data.senderId) || !roomData.memberIds.includes(data.mentionUid) ||
          sender.data()?.approvalStatus !== "approved" ||
          recipient.data()?.approvalStatus !== "approved") return;

      const now = new Date().toISOString();
      transaction.create(ref, {
        schemaVersion: 1,
        notificationId: id,
        recipientUserId: data.mentionUid,
        category: "social",
        kind: "room_chat_mention",
        sourceType: "room_message",
        sourceId: messageRef.id,
        actorUserId: data.senderId,
        actorPrincipalId: data.senderId,
        title: "有夥伴在聊天室提及你",
        body: "開啟自律房聊天室查看對話。",
        route: "room-chat",
        roomId: room.id,
        status: "unread",
        createdAt: now,
        updatedAt: now,
      });
    });
  };
}
