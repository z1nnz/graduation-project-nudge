(() => {
  "use strict";
  const get = id => document.getElementById(id);
  const form = get("townOptOut");
  const status = get("townGoalStatus");
  let subscription, prefs, goal, unsubscribe, version = 0;
  function remaining() {
    if (!goal) return;
    const left = Math.max(0, Math.ceil((Date.parse(goal.endsAt) - Date.now()) / 60_000));
    const days = Math.floor(left / 1440);
    const hours = Math.floor(left % 1440 / 60);
    get("townRemaining").textContent = left ? "還有 " + days + " 天 " + hours + " 小時 " + (left % 60) + " 分鐘" : "本週結束，等待下一個目標。";
  }
  function render(data) {
    if (!data) {
      get("townGoalTitle").textContent = "等待本週全鎮目標";
      get("townTotal").textContent = "";
      get("townRemaining").textContent = "";
      goal = null;
      return;
    }
    goal = data;
    const progress = get("townProgress");
    progress.max = data.target;
    progress.value = Math.min(data.target, data.total);
    const level = Math.min(4, Math.floor(data.total / data.target * 4));
    get("townLighthouse").src = "assets/town_events/light-" + level + ".png";
    get("townGoalTitle").textContent = data.title;
    get("townTotal").textContent = data.total.toLocaleString("zh-TW") + " / " + data.target.toLocaleString("zh-TW") + " " + data.unit;
    get("townMayor").textContent = data.celebrated ? "謝謝每位居民。廣場的燈塔亮起來了！" : "大家各自的一小步，會讓鎮上更亮一點。";
    remaining();
  }
  function enabled(value) {
    form.elements.excluded.disabled = !value;
    form.querySelector("button").disabled = !value;
  }
  function start() {
    if (subscription || typeof firebase === "undefined" || !firebase.apps.length || !db) return;
    subscription = db.collection("town_events").doc("current").onSnapshot(snapshot => render(snapshot.data()),
      () => { status.textContent = "暫時無法同步全鎮目標。"; });
    unsubscribe = firebase.auth().onAuthStateChanged(async user => {
      const current = ++version;
      enabled(false);
      form.elements.excluded.checked = false;
      prefs = null;
      if (!user) return;
      try {
        const document = await db.collection("town_event_preferences").doc(user.uid).get();
        if (current !== version) return;
        prefs = user.uid;
        form.elements.excluded.checked = document.data()?.excluded === true;
        enabled(true);
      } catch { status.textContent = "暫時無法同步你的設定。"; }
    });
  }
  form.addEventListener("submit", async event => {
    event.preventDefault();
    if (!prefs) return;
    const current = version;
    enabled(false);
    try {
      await functions.httpsCallable("manageTownEventPreferences")({ excluded: form.elements.excluded.checked });
      if (current === version) status.textContent = "已確認你的設定，下一次統計會套用。";
    } catch { if (current === version) status.textContent = "設定尚未確認，請再試一次。"; }
    finally { if (current === version) enabled(true); }
  });
  document.addEventListener("firebase-ready", start);
  start();
  setInterval(remaining, 30_000);
  window.addEventListener("pagehide", event => {
    if (!event.persisted) { subscription?.(); unsubscribe?.(); }
  });
})();
