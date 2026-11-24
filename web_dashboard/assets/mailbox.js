// Town mailbox (mailbox.html). Page-specific: reads the same canonical
// user_notifications that the App reads, marks letters read only through the
// audited markNotificationRead callable, and links each letter back to the
// scene where the invitation is handled. It never writes notifications or
// requests itself, and push delivery stays unaccepted until real devices are
// configured.
(function (root, factory) {
  const api = factory();
  if (typeof module === "object" && module.exports) module.exports = api;
  if (root) root.NudgeMailbox = api;
})(typeof window !== "undefined" ? window : null, function () {
  "use strict";

  const routes = Object.freeze({
    guardian: Object.freeze({ manage: "guardian.html", scene: "family-courtyard.html", label: "家庭" }),
    groups: Object.freeze({ manage: "groups.html", scene: "group-hall.html", label: "團體" }),
  });
  const requestStatusLabels = Object.freeze({
    pending: "等待你回覆",
    accepted: "已接受",
    declined: "已婉拒",
    cancelled: "對方已取消",
  });

  function unreadCount(letters) {
    return letters.filter(letter => letter.status === "unread").length;
  }

  // Whitelisted presentation. route only resolves to fixed local pages, so a
  // notification can never inject an external link.
  function presentLetter(letter, requestStatus) {
    const mention = letter.kind === "room_chat_mention" &&
      typeof letter.roomId === "string" && letter.roomId.length > 0;
    const route = routes[letter.route] || null;
    const scopeType = mention ? "room" : String(letter.sourceType || "").startsWith("family") ? "family" : "group";
    const townGoal = letter.kind === "town_goal_celebration";
    const cabinLetter = letter.kind === "friend_cabin_letter";
    const pendingInvitation = /_invitation$/.test(String(letter.kind || "")) && (requestStatus || "pending") === "pending";
    const resolved = requestStatus && requestStatus !== "pending";
    const href = mention ? `room-chat.html?room=${encodeURIComponent(letter.roomId)}` : !route ? null : pendingInvitation ? route.manage : route.scene;
    return Object.freeze({
      id: String(letter.id || letter.notificationId || ""),
      title: String(letter.title || "站內通知").slice(0, 80),
      body: String(letter.body || "").slice(0, 300),
      unread: letter.status === "unread",
      scopeType: cabinLetter ? "friend" : scopeType,
      sticker: cabinLetter && /^(cheer|study|sleep|thumbs-up|happy-tears|flex|coffee|heart|okay|wave|think|fire)$/.test(letter.stickerKey)
        ? letter.stickerKey : null,
      requestStatusLabel: requestStatus ? (requestStatusLabels[requestStatus] || "") : "",
      actionLabel: townGoal ? "前往廣場燈塔" : mention ? "開啟聊天室" : cabinLetter ? "查看小屋留言" : !route ? "" : pendingInvitation ? `前往${route.label}中心回覆` : `前往${route.label}${scopeType === "family" ? "庭院" : "會館"}`,
      href: townGoal ? "town-goals.html" : cabinLetter ? "friend-visits.html" : href,
      resolved: Boolean(resolved),
    });
  }

  function requestCollection(letter) {
    if (letter.sourceType === "family_request") return "guardian_requests";
    if (letter.sourceType === "group_request") return "group_requests";
    return null;
  }

  return Object.freeze({ routes, requestStatusLabels, unreadCount, presentLetter, requestCollection });
});

(function () {
  "use strict";
  if (typeof window === "undefined" || typeof document === "undefined") return;
  if (document.body?.dataset.page !== "mailbox") return;
  const api = window.NudgeMailbox;
  const $ = selector => document.querySelector(selector);
  const esc = value => String(value ?? "").replace(/[&<>"']/g, ch => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;",
  })[ch]);
  const say = message => (typeof toast === "function" ? toast(message) : console.info(message));
  const subs = [];
  const state = { userId: null, letters: [], requestStatus: {}, pending: new Set(), offline: !navigator.onLine, error: "" };

  function stopAll() {
    while (subs.length) { try { subs.pop()(); } catch (_) { /* stopped */ } }
    state.userId = null;
    state.letters = [];
    state.requestStatus = {};
    render();
  }

  function render() {
    const list = $("[data-mailbox-letters]");
    const badge = $("[data-mailbox-unread]");
    const note = $("[data-mailbox-status]");
    if (!list) return;
    const unread = api.unreadCount(state.letters);
    if (badge) badge.textContent = String(unread);
    if (note) {
      note.textContent = state.offline
        ? "目前離線：顯示的是最後同步的信件，標示已讀會在連線後再試。"
        : state.error || (unread ? `你有 ${unread} 封未讀信件。` : "所有信件都已讀。");
    }
    if (!state.userId) { list.innerHTML = `<li class="visit-empty">登入後打開你的信箱。</li>`; return; }
    if (!state.letters.length) {
      list.innerHTML = `<li class="visit-empty">信箱是空的。</li>`;
      return;
    }
    list.innerHTML = state.letters.slice(0, 50).map(raw => {
      const letter = api.presentLetter(raw, state.requestStatus[raw.id]);
      const busy = state.pending.has(letter.id) || state.offline ? "disabled" : "";
      return `<li class="mailbox-letter${letter.unread ? " is-unread" : ""}">
        <div class="mailbox-letter-head">
          <strong>${esc(letter.title)}</strong>
          <span class="social-badge${letter.unread ? "" : " is-muted"}">${letter.unread ? "未讀" : "已讀"}</span>
          ${letter.requestStatusLabel ? `<span class="social-badge is-muted">${esc(letter.requestStatusLabel)}</span>` : ""}
        </div>
        <p>${esc(letter.body)}</p>
        ${letter.sticker ? `<img src="assets/chat_stickers/${esc(letter.sticker)}.png" width="96" height="96" alt="好友的鼓勵貼圖" style="image-rendering:pixelated" />` : ""}
        <div class="social-actions">
          ${letter.unread ? `<button type="button" data-mailbox-read="${esc(letter.id)}" ${busy}>標示已讀</button>` : ""}
          ${letter.href ? `<a class="secondary-btn" href="${esc(letter.href)}">${esc(letter.actionLabel)}</a>` : ""}
        </div>
      </li>`;
    }).join("");
  }

  async function markRead(id) {
    if (state.pending.has(id)) return;
    state.pending.add(id);
    render();
    try {
      const response = await functions.httpsCallable("markNotificationRead")({ notificationId: id });
      const result = response?.data;
      if (result?.notificationId !== id || result?.status !== "read" || !result?.auditEventId) {
        throw new Error("已讀結果無法驗證");
      }
    } catch (error) {
      console.warn("Mark read failed:", error);
      say(error.message || "標示已讀失敗");
    } finally {
      state.pending.delete(id);
      render();
    }
  }

  function watchRequest(letter) {
    const collection = api.requestCollection(letter);
    if (!collection || !letter.sourceId || letter.id in state.requestStatus) return;
    state.requestStatus[letter.id] = null;
    subs.push(db.collection(collection).doc(letter.sourceId).onSnapshot(
      snap => { state.requestStatus[letter.id] = snap.exists ? snap.data().status : "cancelled"; render(); },
      () => { state.requestStatus[letter.id] = null; render(); },
    ));
  }

  function start(uid) {
    if (typeof db === "undefined" || !db || state.userId) return;
    state.userId = uid;
    subs.push(db.collection("user_notifications")
      .where("recipientUserId", "==", uid)
      .orderBy("createdAt", "desc")
      .limit(100)
      .onSnapshot(snapshot => {
        state.error = "";
        state.letters = snapshot.docs.map(doc => ({ ...doc.data(), id: doc.id }));
        state.letters.forEach(watchRequest);
        render();
      }, error => {
        console.warn("Mailbox sync failed:", error);
        state.error = "信箱暫時無法同步，請稍後重試。";
        render();
      }));
    render();
  }

  window.addEventListener("online", () => { state.offline = false; render(); });
  window.addEventListener("offline", () => { state.offline = true; render(); });
  document.addEventListener("click", event => {
    const button = event.target.closest("[data-mailbox-read]");
    if (button) markRead(button.dataset.mailboxRead);
  });
  render();
  document.addEventListener("firebase-ready", () => {
    const user = firebase.auth().currentUser;
    if (user && !user.isAnonymous) start(user.uid);
    firebase.auth().onAuthStateChanged(next => {
      if (!next) stopAll();
      else if (next.uid !== state.userId) { stopAll(); start(next.uid); }
    });
  });
})();
