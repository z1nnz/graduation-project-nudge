(() => {
  "use strict";
  const root = document.querySelector("[data-room-lobby]");
  const get = selector => root.querySelector(selector);
  const doors = get("[data-lobby-doors]");
  const tower = get("[data-tower-scroll]");
  const gate = get("[data-lobby-gate]");
  const porter = get("[data-lobby-porter]");
  const redeem = get("[data-lobby-redeem]");
  const themeChoices = [...root.querySelectorAll("[data-tower-theme]")];
  const motion = matchMedia("(prefers-reduced-motion: reduce)");
  const dialogue = "沿著塔往上走就能找房間。有邀請碼的話，交給我看看。";
  let greetingStart;
  const filters = get("[data-lobby-filters]");
  const modal = get("dialog");
  const form = get("[data-lobby-wizard]");
  const detail = get("[data-lobby-detail]");
  const status = get("[data-lobby-status]");
  const modalStatus = get("[data-lobby-modal-status]");
  const steps = [...form.querySelectorAll("fieldset")];
  const roomTypes = { study: "📚 讀書", exercise: "運動", sleep: "☾ 睡眠", steps: "步數", custom: "✦ 自訂" };
  const asset = name => "assets/room_lobby/" + name + ".png";
  const token = new URLSearchParams(location.search).get("invite");
  let model = { rooms: [], activity: [] };
  let returnFocus;
  let selection;
  let step = 0;
  let busy = false;
  let authVersion = 0;
  let userId;
  const call = async (action, payload = {}) => (await functions.httpsCallable("manageRoomLobby")({ action, ...payload })).data;

  const bird = root.querySelector(".tower-bird");
  const bell = NudgeSpritePlayer.characterPlayer(get(".tower-porter-portrait"), "bell", { size: 64 });
  const readers = new Map();
  function clearReaders() {
    for (const reader of readers.values()) reader.destroy();
    readers.clear();
  }
  addEventListener("pagehide", event => {
    if (event.persisted) return;
    bell.destroy();
    clearReaders();
  });
  const greeting = get("[data-lobby-greeting]");
  let frame;
  let towerVisible = false;
  let lastTick = -1;
  function animate(timestamp) {
    frame = undefined;
    if (motion.matches || document.hidden || !towerVisible) return;
    const tick = Math.floor(timestamp / 100);
    if (tick !== lastTick) {
      lastTick = tick;
      root.style.setProperty("--tower-flame", String([0.4, 0.65, 0.8, 0.6][tick % 4]));
      bird.style.transform = "translate(" + (tick % 65) + "vw," + [0, -2, -4, -2][tick % 4] + "px)";
      if (greetingStart != null && modal.open && !gate.hidden) {
        const shown = NudgeNpcDialog.typedLength(dialogue, timestamp - greetingStart);
        greeting.textContent = dialogue.slice(0, shown);
        if (greeting.textContent === dialogue) {
          greetingStart = null;
          bell.play("idle");
        }
      }
    }
    frame = requestAnimationFrame(animate);
  }
  function updateMotion() {
    if (frame != null) cancelAnimationFrame(frame);
    frame = undefined;
    if (motion.matches) {
      root.style.removeProperty("--tower-flame");
      bird.style.removeProperty("transform");
      greeting.textContent = dialogue;
    } else if (!document.hidden && towerVisible) {
      frame = requestAnimationFrame(animate);
    }
  }
  motion.addEventListener("change", updateMotion);
  document.addEventListener("visibilitychange", updateMotion);
  new IntersectionObserver(entries => {
    towerVisible = entries[0].isIntersecting;
    updateMotion();
  }).observe(tower);

  function reachFloor() {
    const floor = doors.lastElementChild ?? get(".tower-roof").querySelector("button");
    floor.scrollIntoView({ block: "center", behavior: motion.matches ? "instant" : "smooth" });
    if (!floor.disabled) floor.focus({ preventScroll: true });
  }
  get("[data-tower-climb]").addEventListener("click", reachFloor);
  addEventListener("resize", () => {
    if (!tower.scrollTop || tower.scrollHeight - tower.clientHeight - tower.scrollTop < 10) {
      tower.scrollTop = tower.scrollHeight;
    }
  });

  const activeFloors = new IntersectionObserver(entries => {
    for (const entry of entries) {
      if (!entry.isIntersecting || !db) continue;
      const floor = entry.target;
      activeFloors.unobserve(floor);
      db.collection("rooms").doc(floor.dataset.roomId).collection("members")
        .where("presenceStatus", "==", "studying").limit(8).get().then(snapshot => {
          if (floor.isConnected && !snapshot.empty) {
            floor.dataset.towerActive = "true";
            readers.set(floor, NudgeSpritePlayer.characterPlayer(
              floor.querySelector(".tower-reader"), "companion", { animation: "think", size: 32 }
            ));
          }
        }).catch(() => {
          // A pending or former member has no access to room presence.
        });
    }
  }, { root: tower });

  function seekRoom(id) {
    const url = new URL(location.href);
    url.searchParams.delete("invite");
    url.searchParams.set("room", id);
    location.replace(url.href);
  }

  function showOpener(element) {
    if (!modal.open) {
      returnFocus = element;
      modal.showModal();
    }
    modalStatus.textContent = "";
    get("[data-lobby-dialog-title]").focus();
  }
  modal.addEventListener("close", () => {
    if (returnFocus?.isConnected) returnFocus.focus();
    selection = null;
    greetingStart = null;
    bell.play("idle");
  });
  get("[data-lobby-close]").addEventListener("click", () => modal.close());
  porter.addEventListener("click", () => {
    detail.hidden = form.hidden = true;
    gate.hidden = false;
    redeem.elements.inviteCode.disabled = !userId;
    redeem.querySelector("button").disabled = !userId;
    get("[data-lobby-dialog-title]").textContent = "鐘鐘的守門台";
    greeting.textContent = motion.matches ? dialogue : "";
    greetingStart = motion.matches ? null : performance.now();
    if (!motion.matches) bell.play("talk");
    updateMotion();
    showOpener(porter);
  });
  get("[data-lobby-recommend]").addEventListener("click", () => {
    modal.close();
    requestAnimationFrame(reachFloor);
  });
  redeem.addEventListener("submit", async event => {
    event.preventDefault();
    if (!userId || busy) return;
    busy = true;
    const code = redeem.elements.inviteCode.value.trim();
    try {
      const room = await call("preview", { token: code });
      if (modal.open && !gate.hidden) await showRoom(room, porter, code);
    } catch {
      if (modal.open) modalStatus.textContent = "邀請無效或已過期。";
    } finally {
      busy = false;
    }
  });

  function optionSummary(room) {
    return (roomTypes[room.roomType] || room.roomType) + " · " + room.count + "/" + room.limit +
      " 人 · " + (room.approval ? "須審核" : "開放加入") + " · " + (room.voice ? "語音開放" : "語音關閉");
  }
  function render() {
    const selected = Object.fromEntries(new FormData(filters));
    const contains = (value, needle) => String(value || "").toLocaleLowerCase().includes(needle.toLocaleLowerCase());
    const list = NudgeRoomLobbyCore.recommend(model.rooms, model.activity)
      .filter(room => (!selected.type || room.roomType === selected.type) &&
        (!selected.occupancy || (selected.occupancy === "available" ? room.count < room.limit : room.count >= room.limit)) &&
        (!selected.approval || room.approval === (selected.approval === "review")) &&
        (!selected.tag || room.tags.some(tag => contains(tag, selected.tag.trim()))) &&
        (!selected.search || contains(room.name, selected.search.trim())));
    activeFloors.disconnect();
    clearReaders();
    const atGate = tower.scrollHeight - tower.clientHeight - tower.scrollTop < 24;
    doors.replaceChildren();
    for (const [index, room] of list.entries()) {
      const button = document.createElement("button");
      button.type = "button";
      button.className = "room-lobby-door";
      button.setAttribute("aria-label", room.name + "：" + optionSummary(room));
      button.dataset.roomId = room.id;
      const plaque = document.createElement("span");
      plaque.className = "tower-plaque";
      const level = document.createElement("span");
      level.className = "tower-level";
      level.textContent = (index + 1) + "F";
      level.setAttribute("aria-hidden", "true");
      const title = document.createElement("strong");
      title.textContent = room.name;
      const summary = document.createElement("small");
      summary.textContent = optionSummary(room);
      if (new URLSearchParams(location.search).get("room") === room.id) button.setAttribute("aria-current", "true");
      const lights = document.createElement("span");
      lights.className = "room-lobby-lights";
      lights.setAttribute("aria-hidden", "true");
      const panes = Math.min(room.limit, 8);
      const lit = room.count === 0 ? 0 : Math.ceil(room.count * panes / room.limit);
      for (let index = 0; index < panes; index++) {
        const pane = document.createElement("i");
        if (index < lit) pane.className = "lit";
        lights.append(pane);
      }
      const reader = document.createElement("span");
      reader.className = "tower-reader";
      reader.setAttribute("aria-hidden", "true");
      plaque.append(title, summary, lights);
      button.append(level, reader, plaque);
      button.addEventListener("click", () => void showRoom(room, button));
      doors.prepend(button);
      if (room.joined) activeFloors.observe(button);
    }
    if (atGate) tower.scrollTop = tower.scrollHeight;
    status.textContent = list.length ? list.length + " 間房 · 從塔底向上探索" : "沒有符合條件的房間。";
  }

  async function showRoom(room, opener, code) {
    selection = { room, code };
    form.hidden = gate.hidden = true;
    detail.hidden = false;
    get("[data-lobby-dialog-title]").textContent = room.name;
    get("[data-lobby-room-theme]").src = asset(room.theme);
    get("[data-lobby-room-description]").textContent = room.description || optionSummary(room);
    const answer = get("[data-lobby-answer]");
    answer.value = "";
    answer.required = Boolean(room.question) && !room.joined;
    get("[data-lobby-question]").hidden = !answer.required;
    get("[data-lobby-question-text]").textContent = room.question;
    get("[data-lobby-enter]").textContent = room.joined ? "進入自律房" : room.approval ? "送出加入申請" : "加入自律房";
    get("[data-lobby-enter]").disabled = !room.joined && room.count >= room.limit;
    get("[data-lobby-invite-actions]").hidden = !room.owner;
    get("[data-lobby-linkbox]").hidden = true;
    const applicants = get("[data-lobby-applicants]");
    applicants.replaceChildren();
    showOpener(opener);
    if (room.owner) {
      try {
        const data = await call("applications", { roomId: room.id });
        if (selection?.room.id !== room.id) return;
        data.answers.forEach(application => {
          const item = document.createElement("li");
          item.textContent = application.name + "：" + application.answer;
          applicants.append(item);
        });
      } catch { modalStatus.textContent = "暫時無法取得申請答案。"; }
    }
  }
  detail.addEventListener("submit", async event => {
    event.preventDefault();
    if (!selection || busy) return;
    const { room, code } = selection;
    if (room.joined) { seekRoom(room.id); return; }
    busy = true;
    try {
      const payload = code ? { token: code } : { roomId: room.id };
      const result = await call("join", { ...payload, answer: get("[data-lobby-answer]").value });
      seekRoom(result.roomId);
    } catch { modalStatus.textContent = "無法加入，房間可能已滿或邀請已失效。"; }
    finally { busy = false; }
  });

  get("[data-lobby-invite]").addEventListener("click", async () => {
    if (!selection || busy) return;
    const roomId = selection.room.id;
    busy = true;
    try {
      const result = await call("invite", { roomId });
      if (selection?.room.id !== roomId) return;
      const url = new URL("town.html", location.href);
      url.hash = "open=rooms.html?invite=" + result.code;
      get("[data-lobby-url]").value = url.href;
      const qr = qrcode(0, "M");
      qr.addData(url.href);
      qr.make();
      get("[data-lobby-qr]").src = qr.createDataURL(3, 12);
      get("[data-lobby-linkbox]").hidden = false;
      modalStatus.textContent = "邀請有效 7 天，產生新邀請時會撤銷舊邀請。";
    } catch { modalStatus.textContent = "無法產生邀請。"; }
    finally { busy = false; }
  });

  get("[data-lobby-revoke]").addEventListener("click", async () => {
    if (!selection || busy) return;
    busy = true;
    try {
      await call("revoke", { roomId: selection.room.id });
      get("[data-lobby-linkbox]").hidden = true;
      get("[data-lobby-url]").value = "";
      get("[data-lobby-qr]").removeAttribute("src");
      modalStatus.textContent = "邀請已撤銷。";
    } catch { modalStatus.textContent = "無法撤銷邀請。"; }
    finally { busy = false; }
  });

  function showStep(index) {
    step = index;
    steps.forEach((fieldset, position) => { fieldset.hidden = fieldset.disabled = position !== index; });
    get("[data-lobby-dialog-title]").textContent = "建立房間 · " + (index + 1) + "/4";
    get("[data-lobby-back]").hidden = index === 0;
    get("[data-lobby-next]").textContent = index === 3 ? "建立房間" : "下一步";
    modalStatus.textContent = "";
    if (index === 3) {
      get("[data-lobby-theme]").src = asset(form.elements.theme.value);
      get("[data-lobby-preview]").textContent = form.elements.name.value + " · " +
        roomTypes[form.elements.roomType.value] + " · " + form.elements.memberLimit.value + " 人 · " +
        (form.elements.approval.checked ? "須審核" : "開放加入") + " · 每日目標 " + form.elements.dailyGoalValue.value;
    }
  }

  const start = get("[data-lobby-new]");
  start.addEventListener("click", () => {
    form.reset();
    syncTheme();
    form.hidden = false;
    detail.hidden = gate.hidden = true;
    showStep(0);
    showOpener(start);
  });
  get("[data-lobby-back]").addEventListener("click", () => showStep(step - 1));
  function syncTheme() {
    for (const choice of themeChoices) {
      choice.setAttribute("aria-pressed", String(choice.dataset.towerTheme === form.elements.theme.value));
    }
  }
  form.elements.theme.addEventListener("change", syncTheme);
  for (const choice of themeChoices) choice.addEventListener("click", () => {
    form.elements.theme.value = choice.dataset.towerTheme;
    syncTheme();
  });
  form.addEventListener("submit", async event => {
    event.preventDefault();
    if (busy) return;
    if (step < 3) {
      if (step === 2 && form.elements.question.value.trim() && !form.elements.approval.checked) {
        modalStatus.textContent = "使用入房問題時，請開啟入房審核。";
        return;
      }
      showStep(step + 1);
      steps[step].querySelector("input, select, button")?.focus();
      return;
    }
    busy = true;
    const fields = form.elements;
    try {
      const result = await call("create", {
        name: fields.name.value, description: fields.description.value, roomType: fields.roomType.value,
        dailyGoalValue: Number(fields.dailyGoalValue.value), memberLimit: Number(fields.memberLimit.value),
        theme: fields.theme.value, approval: fields.approval.checked, voiceEnabled: fields.voiceEnabled.checked,
        question: fields.question.value, visibility: fields.visibility.value,
        tags: fields.tags.value.split(/[、,]/).map(tag => tag.trim()).filter(Boolean),
      });
      seekRoom(result.roomId);
    } catch { modalStatus.textContent = "無法建立房間，請確認房規與標籤後重試。"; }
    finally { busy = false; }
  });
  filters.addEventListener("input", render);
  async function load(user) {
    const version = ++authVersion;
    userId = user?.uid;
    start.disabled = !userId;
    model = { rooms: [], activity: [] };
    activeFloors.disconnect();
    clearReaders();
    doors.replaceChildren();
    tower.scrollTop = tower.scrollHeight;
    if (modal.open) modal.close();
    status.textContent = userId ? "正在載入自律房…" : "登入後探索自律房。";
    if (!userId) return;
    try {
      const data = await call("list");
      if (version !== authVersion) return;
      model = data;
      render();
      if (token) {
        const room = await call("preview", { token });
        if (version === authVersion) await showRoom(room, start, token);
      }
    } catch { if (version === authVersion) status.textContent = token ? "邀請無效或已過期。" : "暫時無法載入自律房。"; }
  }
  let unsubscribe;
  function startLobby() {
    if (!unsubscribe && typeof firebase !== "undefined" && firebase.apps.length) {
      unsubscribe = firebase.auth().onAuthStateChanged(load);
    }
  }
  filters.addEventListener("submit", event => event.preventDefault());
  document.addEventListener("firebase-ready", startLobby);
  startLobby();
})();
