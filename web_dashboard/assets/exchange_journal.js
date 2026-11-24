(() => {
  "use strict";
  const get = id => document.getElementById(id);
  const books = get("journalBooks");
  const open = get("journalOpen");
  const form = get("journalWrite");
  const section = get("journalBook");
  const dialog = get("journalConfirm");
  const status = get("journalStatus");
  const stickers = {cheer:"歡呼",study:"讀書",sleep:"睡覺","thumbs-up":"讚","happy-tears":"喜極而泣",flex:"加油",coffee:"喝咖啡",heart:"愛心",okay:"沒問題",wave:"打招呼",think:"思考",fire:"火力全開"};
  form.elements.sticker.add(new Option("不加貼圖", ""));
  Object.entries(stickers).forEach(([id, label]) => form.elements.sticker.add(new Option(label, id)));
  const api = (action, data = {}) => functions.httpsCallable("manageExchangeJournal")({ action, ...data }).then(result => result.data);
  let uid, journalId, model, selection, subscribed, busy;
  let entries = [], page = 0, version = 0;

  async function refresh(preferred = journalId) {
    const current = ++version;
    section.hidden = true;
    if (!uid) return;
    model = await api("list");
    if (current !== version) return;
    const names = new Map(model.people.map(person => [person.id, person.name]));
    books.replaceChildren(new Option("選擇日記", ""), ...model.journals.map(book => {
      const peer = book.participantIds.find(member => member !== uid);
      return new Option(names.get(peer) || "小鎮夥伴", book.id);
    }));
    open.elements.peer.replaceChildren(new Option("選擇對象", ""), ...model.people.map(person => new Option(person.name, person.id)));
    open.inert = false;
    open.querySelector("button").disabled = model.people.length === 0;
    if (model.journals.some(book => book.id === preferred)) {
      books.value = preferred;
      await read(preferred);
    }
  }

  async function read(id) {
    const current = ++version;
    journalId = id;
    section.hidden = true;
    form.reset();
    if (!id) return;
    const data = await api("read", { journalId: id });
    if (current !== version) return;
    selection = data;
    entries = data.entries;
    page = 0;
    section.hidden = false;
    section.classList.toggle("journal-ended", data.status === "ended");
    get("journalTitle").textContent = books.selectedOptions[0]?.textContent || "交換日記";
    get("journalState").textContent = data.status === "ended"
      ? "保留閱讀至 " + new Date(data.expiresAt).toLocaleString("zh-TW")
      : data.status === "pending" ? "日記邀請待確認" : data.prompt ? "輪到你寫" : "等對方寫完";
    get("journalAccept").hidden = data.status !== "pending" || data.nextAuthorId !== uid;
    get("journalEnd").hidden = data.status === "ended";
    form.hidden = !data.prompt;
    get("journalPrompt").textContent = data.prompt || "";
    turn();
  }

  function turn() {
    const entry = entries[page];
    get("journalEntryPrompt").textContent = entry?.prompt || "";
    get("journalText").textContent = entry?.text || "第一頁還是空白的。";
    const sticker = get("journalSticker");
    sticker.hidden = !Object.hasOwn(stickers, entry?.sticker);
    if (!sticker.hidden) sticker.src = "assets/chat_stickers/" + entry.sticker + ".png";
    get("journalPage").textContent = entry ? "第 " + entry.number + " 頁" : "";
    get("journalOlder").disabled = !entry || entry.number < 2;
    get("journalNewer").disabled = page === 0;
    const leaf = section.querySelector(".journal-page");
    leaf.classList.remove("turn");
    requestAnimationFrame(() => leaf.classList.add("turn"));
  }

  async function run(operation) {
    if (busy) return;
    busy = true;
    status.textContent = "正在同步日記…";
    try { await operation(); status.textContent = ""; }
    catch { status.textContent = "尚未確認。請重新整理後確認日記狀態。"; }
    finally { busy = false; }
  }
  books.addEventListener("change", () => run(() => read(books.value)));
  open.addEventListener("submit", event => {
    event.preventDefault();
    void run(async () => refresh((await api("open", { peerId: open.elements.peer.value })).id));
  });
  get("journalAccept").addEventListener("click", () => run(async () => { await api("accept", { journalId }); await read(journalId); }));
  form.addEventListener("submit", event => {
    event.preventDefault();
    void run(async () => {
      await api("write", { journalId, text: form.elements.text.value, sticker: form.elements.sticker.value });
      await read(journalId);
    });
  });
  get("journalNewer").addEventListener("click", () => { page--; turn(); });
  get("journalOlder").addEventListener("click", () => run(async () => {
    if (page + 1 === entries.length) {
      const current = journalId;
      const data = await api("read", { journalId, before: entries[page].number });
      if (journalId !== current || !data.entries.length) return;
      entries.push(...data.entries);
    }
    page++;
    turn();
  }));
  for (const [id, action, label, copy] of [
    ["journalEnd", "end", "結束日記", "雙方將有 30 天可以閱讀已結束的日記。尚未接受的邀請會取消。"],
    ["journalDelete", "delete", "立即刪除", "雙方將立刻失去這本日記和所有頁面。"],
  ]) {
    const buttons = get(id);
    buttons.addEventListener("click", () => {
      const current = journalId;
      get("journalConfirmTitle").textContent = label;
      get("journalConfirmCopy").textContent = copy;
      dialog.returnValue = "cancel";
      dialog.addEventListener("close", () => {
        buttons.focus();
        if (dialog.returnValue === "yes") void run(async () => {
          await api(action, { journalId: current });
          await refresh(current);
          books.focus();
        });
      }, { once: true });
      dialog.showModal();
    });
  }
  function start() {
    if (subscribed || typeof firebase === "undefined" || !firebase.apps.length) return;
    subscribed = firebase.auth().onAuthStateChanged(user => {
      const next = user?.uid;
      if (next && next === uid) return;
      uid = next;
      journalId = undefined;
      selection = undefined;
      form.reset();
      section.hidden = true;
      books.replaceChildren();
      open.inert = true;
      open.elements.peer.replaceChildren();
      open.querySelector("button").disabled = true;
      if (uid) void run(() => refresh());
    });
  }
  document.addEventListener("firebase-ready", start);
  start();
  window.addEventListener("focus", () => {
    if (uid && !form.elements.text.value && !dialog.open) void run(() => refresh());
  });
})();
