(function (root) {
  "use strict";
  const labels = Object.freeze({
    room_chat_mention: "有人在自律房提及你",
    friend_invitation: "你收到好友邀請",
    buddy_invitation: "你收到自律夥伴邀請",
    buddy_reminder: "夥伴在等你",
    family_invitation: "你收到家庭邀請",
    group_invitation: "你收到團體邀請",
    room_focus_round: "自律房開始了一輪專注",
    guild_event_reminder: "團體活動即將開始",
    family_scheduled_encouragement: "你的郵箱有一封家庭鼓勵信",
  });

  function destination(data) {
    if (!Object.hasOwn(labels, data?.kind)) return null;
    if (["room_chat_mention", "room_focus_round"].includes(data.kind)) {
      if (typeof data.roomId !== "string" || !/^[^/]{1,180}$/.test(data.roomId)) return "mailbox.html";
      const page = data.kind === "room_chat_mention" ? "room-chat.html" : "rooms.html";
      return page + "?room=" + encodeURIComponent(data.roomId);
    }
    if (data.kind.startsWith("buddy_")) return "buddies.html";
    if (data.kind.endsWith("_invitation")) return "notifications.html";
    return "mailbox.html";
  }

  function notification(data) {
    const page = destination(data);
    return page ? {
      title: labels[data.kind],
      body: "開啟小鎮查看。",
      tag: data.notificationId || data.kind,
      data: { page },
    } : null;
  }

  function townUrl(scope, page) {
    // The destination is rebuilt from a set of local paths before navigation.
    const allowed = ["mailbox.html", "notifications.html", "room-chat.html", "rooms.html", "buddies.html"];
    const [stem, query = ""] = String(page || "").split("?", 2);
    const room = new URLSearchParams(query).get("room");
    const path = allowed.includes(stem)
      ? stem + (room && /^(rooms|room-chat)\.html$/.test(stem) ? "?room=" + encodeURIComponent(room) : "")
      : "mailbox.html";
    return new URL("town.html#open=" + encodeURIComponent(path), scope).href;
  }

  const api = Object.freeze({ notification, townUrl });
  if (typeof module === "object" && module.exports) module.exports = api;
  else root.NudgeWebPushCore = api;
})(globalThis);
