(() => {
  "use strict";
  const get = id => document.getElementById(id);
  const invite = get("buddyInvite");
  const limit = get("buddyLimit");
  const pairs = get("buddyPairs");
  const status = get("buddyStatus");
  const dialog = get("buddyRemove");
  let uid, subscription, busy, generation = 0;
  const ask = async (action, payload = {}) => (await functions.httpsCallable("manageBuddies")({ action, ...payload })).data;

  function node(tag, value) {
    const element = document.createElement(tag);
    if (value) element.textContent = value;
    return element;
  }
  function button(label, onClick) {
    const element = node("button", label);
    element.type = "button";
    element.className = "w-btn";
    element.addEventListener("click", () => onClick(element));
    return element;
  }
  function picture(src, alt = "") {
    const img = new Image();
    img.src = src;
    img.alt = alt;
    return img;
  }

  function show(pair) {
    const card = node("article");
    card.className = "w-parchment";
    const art = node("div");
    art.className = "buddy-frame";
    art.append(...[pair.ownAvatar, pair.peerAvatar].map(index => picture(
      "assets/avatar/characters/character_" + (Number.isInteger(index) && index >= 0 && index < 18 ? index : 0) + ".png",
    )));
    card.append(node("h3", pair.name || "小鎮夥伴"), art,
      node("p", pair.status === "active" ? "每天 " + pair.time + "（臺灣時間）" : "約定 " + pair.time + " · 等待雙方確認"));
    const actions = node("div");
    actions.className = "buddy-actions";
    const act = (action, data) => run(action, { pairId: pair.id, ...data });
    if (!pair.blocked && pair.status === "pending" && pair.proposerId !== uid) {
      actions.append(button("接受搭檔", () => act("accept")));
    }
    if (!pair.blocked && pair.status === "active") {
      const today = pair.checkIn;
      if (today) {
        const lights = node("div");
        lights.className = "buddy-lights";
        const lit = picture("assets/buddies/lights-on.png");
        const count = Math.min(7, today.streak);
        lit.style.clipPath = "inset(0 " + (count === 7 ? 0 : 100 - (18 + count * 9)) + "% 0 0)";
        lights.append(picture("assets/buddies/lights-off.png"));
        if (count) lights.append(lit);
        card.append(lights, node("p", "你：" + (today.mine ? "已完成" : "尚未完成") +
          " · 夥伴：" + (today.theirs ? "已完成" : "尚未完成")));
        card.append(node("p", today.interrupted ? "明天再一起開始" : "連續一起完成 " + today.streak + " 天"));
      }
      if (!pair.paused) actions.append(button("推推夥伴", () => act("nudge")));
      actions.append(button(pair.pausedByMe ? "恢復搭檔" : "暫停搭檔", () => act("pause", { paused: !pair.pausedByMe })));
      if (pair.paused) card.append(node("p", "搭檔目前暫停提醒。"));
      const time = node("input");
      const label = node("label", "提議新的約定時間");
      time.type = "time";
      time.value = pair.time;
      label.append(time);
      actions.append(label, button("提議新時間", () => act("propose", { time: time.value })));
      if (pair.proposal) {
        card.append(node("p", "待確認的新時間：" + pair.proposal.time));
        if (pair.proposal.by !== uid) actions.append(button("接受新時間", () => act("confirm")));
      }
    }
    actions.append(button(pair.status === "pending" ? "取消邀請" : "解除搭檔", opener => {
      dialog.returnValue = "cancel";
      dialog.addEventListener("close", () => {
        opener.focus();
        if (dialog.returnValue === "yes") void act("remove");
      }, { once: true });
      dialog.showModal();
    }));
    card.append(actions);
    return card;
  }

  async function refresh() {
    const version = ++generation;
    const view = await ask("list");
    if (generation !== version || !uid) return;
    const used = new Set(view.pairs.map(pair => pair.peerId));
    const available = view.friends.filter(friend => !used.has(friend.id));
    invite.elements.peer.replaceChildren(new Option("選擇好友", ""),
      ...available.map(friend => new Option(friend.name, friend.id)));
    invite.querySelector("button").disabled = !available.length ||
      view.pairs.filter(pair => pair.status === "active" || pair.proposerId === uid).length >= 3;
    limit.elements.limit.value = String(view.limit);
    limit.querySelector("button").disabled = false;
    pairs.replaceChildren(...view.pairs.map(show));
    if (!view.pairs.length) pairs.append(node("p", "目前還沒有自律夥伴。"));
  }

  async function run(action, args) {
    if (!uid || busy) return;
    busy = true;
    status.textContent = "正在確認…";
    try {
      if (action) await ask(action, args);
      await refresh();
      if (uid) status.textContent = action ? "已更新搭檔資料。" : "";
    } catch { if (uid) status.textContent = "尚未確認，請檢查搭檔狀態或今日接收上限。"; }
    finally { busy = false; }
  }
  invite.addEventListener("submit", event => {
    event.preventDefault();
    void run("invite", { peerId: invite.elements.peer.value, time: invite.elements.time.value });
  });
  limit.addEventListener("submit", event => {
    event.preventDefault();
    void run("limit", { limit: Number(limit.elements.limit.value) });
  });
  function start() {
    if (subscription || typeof firebase === "undefined" || !firebase.apps.length) return;
    subscription = firebase.auth().onAuthStateChanged(user => {
      uid = user?.uid;
      generation++;
      pairs.replaceChildren();
      invite.elements.peer.replaceChildren();
      invite.querySelector("button").disabled = limit.querySelector("button").disabled = true;
      if (uid) void run();
    });
  }
  document.addEventListener("firebase-ready", start);
  start();
  get("buddyRefresh").addEventListener("click", () => run());
})();
