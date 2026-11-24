(() => {
  "use strict";
  const root = document.querySelector("[data-room-lobby]");
  const get = selector => root.querySelector(selector);
  const doors = get("[data-lobby-doors]");
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

  function seekRoom(id) {
    const url = new URL(location.href);
    url.searchParams.delete("invite");
    url.searchParams.set("room", id);
    location.replace(url.href);
  }

  function showOpener(element) {
    returnFocus = element;
    modalStatus.textContent = "";
    modal.showModal();
  }
  modal.addEventListener("close", () => {
    if (returnFocus?.isConnected) returnFocus.focus();
    selection = null;
  });
  get("[data-lobby-close]").addEventListener("click", () => modal.close());
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
    doors.replaceChildren();
    for (const room of list) {
      const button = document.createElement("button");
      button.type = "button";
      button.className = "w-btn room-lobby-door";
      const image = new Image(96, 160);
      image.alt = "";
      image.src = asset("door-" + (room.count === 0 ? 0 : room.count / room.limit < .75 ? 1 : 2));
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
      button.append(image, lights, title, summary);
      button.addEventListener("click", () => void showRoom(room, button));
      doors.append(button);
    }
    status.textContent = list.length ? list.length + " 間房" : "沒有符合條件的房間。";
  }

  async function showRoom(room, opener, code) {
    selection = { room, code };
    form.hidden = true;
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
      get("[data-lobby-preview]").textContent = form.elements.name.value + " · " +
        roomTypes[form.elements.roomType.value] + " · " + form.elements.memberLimit.value + " 人 · " +
        (form.elements.approval.checked ? "須審核" : "開放加入") + " · 每日目標 " + form.elements.dailyGoalValue.value;
    }
  }

  const start = get("[data-lobby-new]");
  start.addEventListener("click", () => {
    form.reset();
    get("[data-lobby-theme]").src = asset(form.elements.theme.value);
    form.hidden = false;
    detail.hidden = true;
    showStep(0);
    showOpener(start);
  });
  get("[data-lobby-back]").addEventListener("click", () => showStep(step - 1));
  form.elements.theme.addEventListener("change", () => { get("[data-lobby-theme]").src = asset(form.elements.theme.value); });
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
    doors.replaceChildren();
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
