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

  const taipeiDate = new Intl.DateTimeFormat("en-CA", { timeZone: "Asia/Taipei", dateStyle: "short" });
  function dateKey(now = new Date()) {
    return taipeiDate.format(now);
  }

  function visitId(hostId, visitorId, key) {
    return `${hostId}--${visitorId}--${key}`;
  }

  function buildSettings({ userId, allowVisits, sceneKey, shareCabin, now = new Date() }) {
    if (!userId) throw new Error("請先登入");
    if (!scenes[sceneKey]) throw new Error("請選擇可公開的場景");
    return {
      schemaVersion: 1,
      userId,
      allowVisits: allowVisits === true,
      ...(shareCabin === undefined ? {} : { shareCabin: shareCabin === true }),
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
  const notes = {
    cheer: "今天也替你加油！", step: "慢慢來，每一步都算數。",
    steady: "照自己的節奏就好。", rest: "休息一下也很重要。",
    proud: "為你今天的努力感到開心！", hello: "路過小屋，來打聲招呼。",
    focus: "祝你今天專注又順利。", brave: "開始就是值得鼓勵的一步。",
    together: "下次再一起努力！", progress: "一點一滴都在進步。",
    tomorrow: "明天也是新的開始。", thanks: "謝謝你一直這麼努力。",
  };
  const stickers = {
    cheer: "歡呼", study: "讀書", sleep: "睡覺", "thumbs-up": "讚",
    "happy-tears": "喜極而泣", flex: "加油", coffee: "喝咖啡", heart: "愛心",
    okay: "沒問題", wave: "招呼", think: "思考", fire: "火力全開",
  };
  let activeCabin = null;
  let requestedCabin = new URLSearchParams(location.search).get("friend");
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
    if (activeCabin) $("[data-friend-cabin-dialog]").close();
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
    const cabin = $("[data-visit-cabin]");
    cabin.checked = settings?.shareCabin === true;
    cabin.disabled = !userId || pending || !settings?.allowVisits;
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
      const actions = open?.shareCabin
        ? `<button type="button" class="w-btn" data-visit-cabin-open="${esc(friendId)}">進入小屋</button>`
        : !open
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
      .filter(visit => !visit.removed)
      .sort((a, b) => String(b.createdAt || "").localeCompare(String(a.createdAt || "")))
      .slice(0, 30)
      .map(visit => ({
        ...contract.presentVisit(visit, userId, names),
        cabinLetter: visit.schemaVersion === 2,
        note: notes[visit.noteKey], sticker: Object.hasOwn(stickers, visit.stickerKey) ? visit.stickerKey : null,
      }));
    if (!items.length) {
      list.innerHTML = `<li class="visit-empty">${kind === "incoming" ? "還沒有好友來訪。" : "你還沒有拜訪好友。"}</li>`;
      return;
    }
    list.innerHTML = items.map(item => `<li>
      <strong>${esc(item.incoming ? `${item.otherName} 拜訪了你的${item.sceneLabel}` : `你拜訪了 ${item.otherName} 的${item.sceneLabel}`)}</strong>
      ${item.cabinLetter ? `<span>${esc(item.note)} · ${esc(item.dateKey)}</span>
        ${item.sticker ? `<img class="friend-cabin-sticker" src="assets/chat_stickers/${esc(item.sticker)}.png" alt="${esc(stickers[item.sticker])}" width="96" height="96" />` : ""}
        ${item.incoming ? `<button type="button" class="w-btn" data-visit-cabin-remove="${esc(item.id)}">刪除留言</button><button type="button" class="w-btn" data-safety-report-visit="${esc(item.id)}">檢舉留言</button>` : ""}`
      : `<span>${esc(item.reaction)}${item.response ? ` · 回應：${esc(item.response)}` : ""} · ${esc(item.dateKey)}</span>`}
      ${!item.cabinLetter && item.canRespond ? `<div class="visit-reactions" role="group" aria-label="回應 ${esc(item.otherName)}">${
        Object.entries(contract.responses).map(([key, label]) =>
          `<button type="button" data-visit-respond="${esc(item.id)}" data-visit-response="${esc(key)}" ${pending ? "disabled" : ""}>${esc(label)}</button>`,
        ).join("")}</div>` : ""}
    </li>`).join("");
  }

  function render() {
    renderSettings();
    renderFriends();
    if (requestedCabin && friends.includes(requestedCabin) && friendSettings[requestedCabin]?.shareCabin && !activeCabin) {
      const hostId = requestedCabin;
      const opener = [...document.querySelectorAll("[data-visit-cabin-open]")].find(button =>
        button.dataset.visitCabinOpen === hostId);
      if (opener) {
        requestedCabin = null;
        const url = new URL(location.href);
        url.searchParams.delete("friend");
        history.replaceState(null, "", url);
        void openCabin(hostId, opener);
      }
    }
    renderVisits("incoming", "[data-visit-incoming]");
    renderVisits("outgoing", "[data-visit-outgoing]");
    const count = $("[data-visit-today-count]");
    if (count) {
      const today = contract.dateKey();
      count.textContent = String(visits.incoming.filter(v => v.dateKey === today).length);
    }
  }

  function saveSettings() {
    if (!userId) return;
    const doc = contract.buildSettings({
      userId,
      allowVisits: $("[data-visit-allow]").checked,
      sceneKey: $("[data-visit-scene]").value,
      shareCabin: $("[data-visit-cabin]").checked,
    });
    return run(async () => {
      await firestore().collection("friend_visit_settings").doc(doc.userId).set(doc);
      say(doc.allowVisits ? "已開放好友拜訪" : "已撤回拜訪權限");
    }, "拜訪設定失敗");
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
        if (activeCabin?.hostId === friendId && !friendSettings[friendId]?.shareCabin) {
          $("[data-friend-cabin-dialog]").close();
        }
        render();
      },
      () => {
        friendSettings[friendId] = null;
        if (activeCabin?.hostId === friendId) $("[data-friend-cabin-dialog]").close();
        render();
      },
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
      if (activeCabin && !next.includes(activeCabin.hostId)) $("[data-friend-cabin-dialog]").close();
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

  function callCabin(data) {
    return functions.httpsCallable("manageFriendCabinVisit")(data).then(result => result.data);
  }

  function drawCabin(stage, layout, cabin) {
    const core = window.NudgeCabinCore;
    function picture(src, rect, z) {
      const img = document.createElement("img");
      img.src = src;
      img.alt = "";
      const [x, y, w, h] = rect;
      Object.assign(img.style, {
        left: x * 100 + "%", top: y * 100 + "%", width: w * 100 + "%",
        height: h * 100 + "%", zIndex: String(z),
      });
      return img;
    }
    stage.style.aspectRatio = String(layout.aspect);
    stage.replaceChildren(picture(layout.baseImage, [0, 0, 1, 1], 0));
    for (const layer of core.decorLayers(layout, cabin.homeDecor)) {
      stage.append(picture(layer.src, layer.rect, layer.z));
    }
    stage.append(picture(core.characterSprite(cabin), layout.character.rect, layout.character.z || 10));
    stage.hidden = false;
  }

  async function openCabin(hostId, opener) {
    const dialog = $("[data-friend-cabin-dialog]");
    const status = $("[data-friend-cabin-status]");
    const stage = $("[data-friend-cabin-stage]");
    const form = $("[data-friend-cabin-letter]");
    const visit = activeCabin = { hostId, opener };
    stage.hidden = form.hidden = true;
    stage.replaceChildren();
    form.reset();
    $("#friendCabinTitle").textContent = (names[hostId] || "好友") + "的小屋";
    status.textContent = "正在確認拜訪權限…";
    dialog.showModal();
    try {
      const [{ cabin, alreadyLeft }, layout] = await Promise.all([
        callCabin({ action: "open", hostId }),
        fetch("assets/home/cabin_layout.json").then(response => {
          if (!response.ok) throw new Error("Cabin layout unavailable");
          return response.json();
        }),
      ]);
      if (activeCabin !== visit) return;
      drawCabin(stage, layout, cabin);
      form.hidden = alreadyLeft;
      status.textContent = alreadyLeft ? "今天已經留下鼓勵。" : "小屋擺設由好友公開。";
    } catch {
      if (activeCabin === visit) status.textContent = "無法開啟小屋，對方可能已關閉拜訪。";
    }
  }

  function bind() {
    const dialog = $("[data-friend-cabin-dialog]");
    const guestbook = $("[data-friend-cabin-letter]");
    for (const [value, text] of Object.entries(notes)) guestbook.elements.note.add(new Option(text, value));
    for (const [value, text] of Object.entries(stickers)) {
      const label = document.createElement("label");
      label.innerHTML = `<input type="radio" name="sticker" value="${value}" required />
        <img src="assets/chat_stickers/${value}.png" width="96" height="96" alt="${text}" />`;
      guestbook.querySelector("fieldset").append(label);
    }
    dialog.addEventListener("close", () => {
      const opener = activeCabin?.opener;
      $("[data-friend-cabin-stage]").replaceChildren();
      activeCabin = null;
      if (opener?.isConnected) opener.focus();
      else $("#visitFriendsTitle")?.focus();
    });
    guestbook.addEventListener("submit", async event => {
      event.preventDefault();
      const visit = activeCabin;
      const submit = guestbook.querySelector("button[type=submit]");
      if (!visit || submit.disabled) return;
      const data = new FormData(guestbook);
      submit.disabled = true;
      try {
        await callCabin({ action: "leave", hostId: visit.hostId, noteKey: data.get("note"), stickerKey: data.get("sticker") });
        if (activeCabin !== visit) return;
        guestbook.hidden = true;
        $("[data-friend-cabin-status]").textContent = "鼓勵與貼圖已送到好友的郵箱。";
      } catch (error) {
        if (activeCabin === visit) $("[data-friend-cabin-status]").textContent =
          error.code === "functions/already-exists" ? "今天已經留下鼓勵。" : "留言尚未確認，請稍後重試。";
      } finally {
        submit.disabled = false;
      }
    });
    $("[data-visit-cabin]")?.addEventListener("change", saveSettings);
    $("[data-visit-allow]")?.addEventListener("change", saveSettings);
    $("[data-visit-scene]")?.addEventListener("change", saveSettings);
    document.addEventListener("click", event => {
      const open = event.target.closest("[data-visit-cabin-open]");
      if (open) openCabin(open.dataset.visitCabinOpen, open);
      const remove = event.target.closest("[data-visit-cabin-remove]");
      if (remove) run(() => callCabin({ action: "remove", visitId: remove.dataset.visitCabinRemove }), "刪除留言失敗");
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
