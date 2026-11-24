(() => {
  "use strict";
  const get = id => document.getElementById(id);
  const query = new URLSearchParams(location.search);
  const recipientId = query.get("to");
  const roomId = query.get("room");
  const fromLetter = query.get("card");
  const form = get("thanksForm");
  const compose = get("thanksCompose");
  const status = get("thanksStatus");
  const dialog = get("thanksDelete");
  const patterns = { stars:"星星",flowers:"花朵",coffee:"咖啡",books:"書堆",moon:"月亮",sun:"太陽",rainbow:"彩虹",mountain:"山巒",lantern:"燈籠",heart:"愛心",leaf:"葉子",music:"音符" };
  const path = key => "assets/thanks_cards/" + key + ".png";
  const request = async (action, data = {}) => (await functions.httpsCallable("manageThanksCards")({ action, ...data })).data;
  let uid, subscription, busy, version = 0;
  function node(tag, value) {
    const element = document.createElement(tag);
    if (value) element.textContent = value;
    return element;
  }
  function button(label, click) {
    const element = node("button", label);
    element.type = "button";
    element.className = "w-btn";
    element.addEventListener("click", () => click(element));
    return element;
  }

  function display(card) {
    const entry = node("article");
    entry.className = "w-parchment thanks-entry";
    entry.dataset.thanksCard = card.id;
    const image = new Image(240, 160);
    image.src = path(Object.hasOwn(patterns, card.pattern) ? card.pattern : "stars");
    image.alt = patterns[card.pattern] || "感謝卡";
    entry.append(image, node("h3", (card.senderName || "小鎮夥伴") + " 寄來的感謝"), node("p", card.text));
    const actions = node("div");
    actions.className = "thanks-controls";
    if (!card.saved) actions.append(button("收藏到卡片冊", () => run("save", { cardId: card.id })));
    actions.append(button("刪除卡片", opener => {
      dialog.returnValue = "cancel";
      dialog.addEventListener("close", () => {
        opener.focus();
        if (dialog.returnValue === "yes") void run("delete", { cardId: card.id });
      }, { once: true });
      dialog.showModal();
    }));
    entry.append(actions);
    return entry;
  }

  async function refresh() {
    const current = ++version;
    const data = await request("list");
    if (current !== version || !uid) return;
    const inbox = get("thanksInbox");
    const album = get("thanksAlbum");
    inbox.replaceChildren(...data.cards.filter(card => !card.saved).map(display));
    album.replaceChildren();
    for (const month of new Set(data.cards.filter(card => card.saved).map(card => card.month))) {
      const section = node("section");
      section.append(node("h3", month), ...data.cards.filter(card => card.saved && card.month === month).map(display));
      album.append(section);
    }
    if (!inbox.childElementCount) inbox.append(node("p", "目前沒有待收藏的卡片。"));
    if (!album.childElementCount) album.append(node("p", "卡片冊目前是空的。"));
    if (fromLetter) {
      const selected = [...document.querySelectorAll("[data-thanks-card]")].find(element => element.dataset.thanksCard === fromLetter);
      selected?.scrollIntoView({ block: "nearest" });
    }
  }

  async function run(action, data) {
    if (!uid || busy) return;
    busy = true;
    status.textContent = "正在確認…";
    const account = uid;
    try {
      if (action) await request(action, data);
      if (uid !== account) return;
      await refresh();
      if (uid !== account) return;
      if (action === "send") { form.reset(); get("thanksPreview").src = path(form.elements.pattern.value); compose.hidden = true; }
      status.textContent = {send:"感謝卡已寄出。",save:"已收藏到卡片冊。",delete:"已刪除卡片。"}[action] || "";
    } catch (error) {
      if (uid !== account) return;
      status.textContent = ({
        "functions/already-exists": "你今天已寄過感謝卡給這位夥伴。",
        "functions/resource-exhausted": "今天寄出的感謝卡已達 10 張。",
        "functions/permission-denied": "現在無法寄給這位夥伴。",
      })[error.code] || "卡片尚未確認，請稍後重試。";
    } finally { busy = false; }
  }

  Object.entries(patterns).forEach(([key, label]) => form.elements.pattern.add(new Option(label, key)));
  get("thanksPreview").src = path(form.elements.pattern.value);
  form.elements.pattern.addEventListener("change", () => { get("thanksPreview").src = path(form.elements.pattern.value); });
  form.elements.template.addEventListener("change", () => { if (form.elements.template.value) form.elements.text.value = form.elements.template.value; });
  form.addEventListener("submit", event => {
    event.preventDefault();
    void run("send", { recipientId, ...(roomId ? { roomId } : {}), pattern: form.elements.pattern.value, text: form.elements.text.value });
  });
  function start() {
    if (subscription || typeof firebase === "undefined" || !firebase.apps.length) return;
    subscription = firebase.auth().onAuthStateChanged(async user => {
      version++;
      uid = user?.uid;
      form.reset();
      compose.hidden = true;
      get("thanksInbox").replaceChildren();
      get("thanksAlbum").replaceChildren();
      if (!uid) return;
      await run();
      if (recipientId && recipientId !== uid && /^[^/]{1,180}$/.test(recipientId)) {
        const account = uid;
        const info = await db.collection("public_profiles").doc(recipientId).get().catch(() => null);
        if (uid !== account) return;
        const name = info?.data()?.nickname || info?.data()?.displayName || "這位夥伴";
        get("thanksRecipient").textContent = "寫給 " + name;
        compose.hidden = false;
      }
    });
  }
  document.addEventListener("firebase-ready", start);
  start();
})();
