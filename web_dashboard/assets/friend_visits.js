// Friend visit scene for friend-visits.html. Page-specific: it reuses the
// shared Firebase handles from app.js (db, firebase) and never edits app.js.
//
// Contract (see firestore.rules):
//   friend_visit_settings/{uid}   host-owned { allowVisits, sceneKey }
//   friend_visits/{host}--{visitor}--{YYYY-MM-DD}  one real visit per day
// A visit carries only a fixed reaction and an optional fixed host response.
// It never reads a friend's tasks, activity, health or focus values and never
// grants coins, XP or prosperity.
(function (root, factory) {
  const api = factory();
  if (typeof module === "object" && module.exports) module.exports = api;
  if (root) root.NudgeFriendVisits = api;
})(typeof window !== "undefined" ? window : null, function () {
  "use strict";

  const scenes = Object.freeze({
    cabin: Object.freeze({ label: "我的小屋", glyph: "🏡" }),
    garden: Object.freeze({ label: "專注花園", glyph: "🌿" }),
    study_corner: Object.freeze({ label: "讀書角落", glyph: "📚" }),
  });
  const reactions = Object.freeze({
    cheer: "👏 替你加油",
    wave: "👋 來打個招呼",
    proud: "🌟 以你為榮",
    rest_well: "🌙 記得好好休息",
  });
  const responses = Object.freeze({
    thanks: "謝謝你來",
    see_you: "下次見",
    heart: "💛",
  });

  function dateKey(now = new Date()) {
    const year = now.getFullYear();
    const month = String(now.getMonth() + 1).padStart(2, "0");
    const day = String(now.getDate()).padStart(2, "0");
    return `${year}-${month}-${day}`;
  }

  function visitId(hostId, visitorId, key) {
    return `${hostId}--${visitorId}--${key}`;
  }

  function buildSettings({ userId, allowVisits, sceneKey, now = new Date() }) {
    if (!userId) throw new Error("請先登入");
    if (!scenes[sceneKey]) throw new Error("請選擇可公開的場景");
    return {
      schemaVersion: 1,
      userId,
      allowVisits: allowVisits === true,
      sceneKey,
      updatedAt: now.toISOString(),
    };
  }

  function buildVisit({ hostId, visitorId, sceneKey, reactionKey, now = new Date() }) {
    if (!hostId || !visitorId || hostId === visitorId) throw new Error("只能拜訪其他好友");
    if (!scenes[sceneKey]) throw new Error("好友目前沒有公開場景");
    if (!reactions[reactionKey]) throw new Error("請選擇固定的鼓勵");
    const key = dateKey(now);
    return {
      id: visitId(hostId, visitorId, key),
      data: {
        schemaVersion: 1,
        hostId,
        visitorId,
        dateKey: key,
        sceneKey,
        reactionKey,
        responseKey: null,
        createdAt: now.toISOString(),
        respondedAt: null,
      },
    };
  }

  // Only the fields a visit card may show. Anything else in the document is
  // ignored so a malformed or future field can never reach the DOM.
  function presentVisit(visit, viewerId, names = {}) {
    const incoming = visit.hostId === viewerId;
    const otherId = incoming ? visit.visitorId : visit.hostId;
    return Object.freeze({
      id: String(visit.id || ""),
      incoming,
      otherId,
      otherName: String(names[otherId] || "好友").slice(0, 40),
      sceneLabel: scenes[visit.sceneKey]?.label || "公開場景",
      reaction: reactions[visit.reactionKey] || "",
      response: responses[visit.responseKey] || "",
      canRespond: incoming && !visit.responseKey,
      dateKey: String(visit.dateKey || ""),
    });
  }

  return Object.freeze({ scenes, reactions, responses, dateKey, visitId, buildSettings, buildVisit, presentVisit });
});

(function () {
  "use strict";
  if (typeof window === "undefined" || typeof document === "undefined") return;
  if (document.body?.dataset.page !== "friend-visits") return;
  const contract = window.NudgeFriendVisits;
  const subs = [];
  let started = false;
  let userId = null;
  let settings = null;
  let friends = [];
  let friendSettings = {};
  let names = {};
  let visits = { incoming: [], outgoing: [] };
  let pending = false;

  const $ = (selector, rootNode = document) => rootNode.querySelector(selector);
  const esc = value => String(value ?? "").replace(/[&<>"']/g, ch => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;",
  })[ch]);
  const firestore = () => (typeof db !== "undefined" ? db : null);
  const say = message => (typeof toast === "function" ? toast(message) : console.info(message));

  function stopAll() {
    while (subs.length) {
      try { subs.pop()(); } catch (_) { /* already stopped */ }
    }
    started = false;
    userId = null;
    settings = null;
    friends = [];
    friendSettings = {};
    names = {};
    visits = { incoming: [], outgoing: [] };
    render();
  }

  async function run(task, fallback) {
    if (pending) return;
    pending = true;
    render();
    try {
      await task();
    } catch (error) {
      console.warn(fallback, error);
      say(error?.code === "permission-denied" ? "權限已變更，請重新整理" : (error.message || fallback));
    } finally {
      pending = false;
      render();
    }
  }

  function renderSettings() {
    const toggle = $("[data-visit-allow]");
    const scene = $("[data-visit-scene]");
    const status = $("[data-visit-setting-status]");
    if (!toggle || !scene) return;
    toggle.checked = settings?.allowVisits === true;
    toggle.disabled = !userId || pending;
    scene.value = settings?.sceneKey || "cabin";
    scene.disabled = !userId || pending;
    if (status) {
      status.textContent = !userId
        ? "登入後可設定。"
        : settings?.allowVisits
          ? `好友可以拜訪你的「${contract.scenes[settings.sceneKey]?.label}」。關閉後立即撤回。`
          : "目前不開放拜訪；好友看不到你的場景。";
    }
  }

  function renderFriends() {
    const list = $("[data-visit-friends]");
    if (!list) return;
    if (!userId) {
      list.innerHTML = `<p class="visit-empty">登入後顯示正式好友。</p>`;
      return;
    }
    if (!friends.length) {
      list.innerHTML = `<p class="visit-empty">還沒有好友。到「好友列表」送出邀請，對方接受後才能互相拜訪。</p>`;
      return;
    }
    const today = contract.dateKey();
    list.innerHTML = friends.map(friendId => {
      const open = friendSettings[friendId];
      const visited = visits.outgoing.some(v => v.hostId === friendId && v.dateKey === today);
      const scene = open ? contract.scenes[open.sceneKey] : null;
      const actions = !open
        ? `<p class="visit-closed">對方目前沒有開放拜訪。</p>`
        : visited
          ? `<p class="visit-done">今天已拜訪過，明天可以再來。</p>`
          : `<div class="visit-reactions" role="group" aria-label="送給 ${esc(names[friendId] || "好友")} 的鼓勵">${
            Object.entries(contract.reactions).map(([key, label]) =>
              `<button type="button" data-visit-host="${esc(friendId)}" data-visit-reaction="${esc(key)}" ${pending ? "disabled" : ""}>${esc(label)}</button>`,
            ).join("")}</div>`;
      return `<article class="visit-friend-card${open ? " is-open" : ""}">
        <div class="visit-scene" aria-hidden="true">${scene ? esc(scene.glyph) : "🔒"}</div>
        <div><strong>${esc(names[friendId] || "好友")}</strong><small>${scene ? esc(scene.label) : "未公開"}</small></div>
        ${actions}
      </article>`;
    }).join("");
  }

  function renderVisits(kind, selector) {
    const list = $(selector);
    if (!list) return;
    const items = visits[kind]
      .slice()
      .sort((a, b) => String(b.createdAt || "").localeCompare(String(a.createdAt || "")))
      .slice(0, 30)
      .map(visit => contract.presentVisit(visit, userId, names));
    if (!items.length) {
      list.innerHTML = `<li class="visit-empty">${kind === "incoming" ? "還沒有好友來訪。" : "你還沒有拜訪好友。"}</li>`;
      return;
    }
    list.innerHTML = items.map(item => `<li>
      <strong>${esc(item.incoming ? `${item.otherName} 拜訪了你的${item.sceneLabel}` : `你拜訪了 ${item.otherName} 的${item.sceneLabel}`)}</strong>
      <span>${esc(item.reaction)}${item.response ? ` · 回應：${esc(item.response)}` : ""} · ${esc(item.dateKey)}</span>
      ${item.canRespond ? `<div class="visit-reactions" role="group" aria-label="回應 ${esc(item.otherName)}">${
        Object.entries(contract.responses).map(([key, label]) =>
          `<button type="button" data-visit-respond="${esc(item.id)}" data-visit-response="${esc(key)}" ${pending ? "disabled" : ""}>${esc(label)}</button>`,
        ).join("")}</div>` : ""}
    </li>`).join("");
  }

  function render() {
    renderSettings();
    renderFriends();
    renderVisits("incoming", "[data-visit-incoming]");
    renderVisits("outgoing", "[data-visit-outgoing]");
    const count = $("[data-visit-today-count]");
    if (count) {
      const today = contract.dateKey();
      count.textContent = String(visits.incoming.filter(v => v.dateKey === today).length);
    }
  }

  async function saveSettings() {
    const store = firestore();
    const doc = contract.buildSettings({
      userId,
      allowVisits: $("[data-visit-allow]").checked,
      sceneKey: $("[data-visit-scene]").value,
    });
    await store.collection("friend_visit_settings").doc(userId).set(doc);
    say(doc.allowVisits ? "已開放好友拜訪" : "已撤回拜訪權限");
  }

  async function visit(hostId, reactionKey) {
    const open = friendSettings[hostId];
    const built = contract.buildVisit({ hostId, visitorId: userId, sceneKey: open?.sceneKey, reactionKey });
    await firestore().collection("friend_visits").doc(built.id).set(built.data);
    say("已留下拜訪足跡");
  }

  async function respond(id, responseKey) {
    await firestore().collection("friend_visits").doc(id).update({
      responseKey,
      respondedAt: new Date().toISOString(),
    });
  }

  function watchFriendSettings(friendId) {
    // Each friend's visibility is read through Rules: a closed or revoked
    // setting is simply denied, which the scene shows as "not open".
    subs.push(firestore().collection("friend_visit_settings").doc(friendId).onSnapshot(
      snap => {
        const data = snap.exists ? snap.data() : null;
        friendSettings[friendId] = data?.allowVisits ? data : null;
        render();
      },
      () => { friendSettings[friendId] = null; render(); },
    ));
    firestore().collection("public_profiles").doc(friendId).get()
      .then(snap => { names[friendId] = snap.exists ? (snap.data().nickname || "好友") : "好友"; render(); })
      .catch(() => {});
  }

  function start(uid) {
    const store = firestore();
    if (!store || !uid || started) return;
    started = true;
    userId = uid;
    subs.push(store.collection("friend_visit_settings").doc(uid).onSnapshot(
      snap => { settings = snap.exists ? snap.data() : null; render(); },
      error => console.warn("Visit settings sync failed:", error),
    ));
    subs.push(store.collection("users").doc(uid).collection("friends").onSnapshot(snapshot => {
      const next = snapshot.docs.map(doc => doc.id).filter(id => id !== uid);
      for (const id of next) if (!(id in friendSettings)) { friendSettings[id] = null; watchFriendSettings(id); }
      friends = next;
      render();
    }, error => console.warn("Friend list sync failed:", error)));
    for (const [field, kind] of [["hostId", "incoming"], ["visitorId", "outgoing"]]) {
      subs.push(store.collection("friend_visits").where(field, "==", uid).onSnapshot(snapshot => {
        visits[kind] = snapshot.docs.map(doc => ({ ...doc.data(), id: doc.id }));
        for (const item of visits[kind]) {
          const other = kind === "incoming" ? item.visitorId : item.hostId;
          if (!names[other]) {
            names[other] = "好友";
            store.collection("public_profiles").doc(other).get()
              .then(snap => { if (snap.exists) names[other] = snap.data().nickname || "好友"; render(); })
              .catch(() => {});
          }
        }
        render();
      }, error => console.warn("Visit history sync failed:", error)));
    }
    render();
  }

  function bind() {
    $("[data-visit-allow]")?.addEventListener("change", () => run(saveSettings, "拜訪設定失敗"));
    $("[data-visit-scene]")?.addEventListener("change", () => run(saveSettings, "拜訪設定失敗"));
    document.addEventListener("click", event => {
      const react = event.target.closest("[data-visit-reaction]");
      if (react) run(() => visit(react.dataset.visitHost, react.dataset.visitReaction), "拜訪失敗");
      const answer = event.target.closest("[data-visit-response]");
      if (answer) run(() => respond(answer.dataset.visitRespond, answer.dataset.visitResponse), "回應失敗");
    });
  }

  bind();
  render();
  document.addEventListener("firebase-ready", () => {
    const user = firebase.auth().currentUser;
    if (user && !user.isAnonymous) start(user.uid);
    firebase.auth().onAuthStateChanged(next => {
      if (!next) stopAll();
      else if (next.uid !== userId) { stopAll(); start(next.uid); }
    });
  });
})();
