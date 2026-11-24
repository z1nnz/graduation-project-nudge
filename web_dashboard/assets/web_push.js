(() => {
  "use strict";
  const options = {
    mentions: "聊天室提及", invitations: "邀請", focusRounds: "同步番茄鐘開始",
    guildEvents: "團體活動提醒", familyLetters: "家庭鼓勵信",
  };
  const markerKey = "nudgeWebPushOwner";
  const installKey = "nudgeWebPushInstallation";
  let active;
  let sdk;

  async function messaging() {
    sdk ||= loadWindowModule(
      "nudgeWebPushMessagingSdk", "assets/web_push_sdk.js?v=1", "推播模組載入失敗",
    ).then(async () => {
      if (!firebase.messaging.isSupported || !await firebase.messaging.isSupported()) {
        throw new Error("目前的瀏覽器不支援推播。");
      }
      return firebase.messaging();
    }).catch(error => { sdk = null; throw error; });
    return sdk;
  }

  function localMode() {
    return ["127.0.0.1", "localhost"].includes(location.hostname) &&
      window.NUDGE_RUNTIME_CONFIG?.useLocalEmulators === true;
  }

  async function revoke(user, cloud) {
    if (localStorage.getItem(markerKey) !== user?.uid) return;
    const installationId = localStorage.getItem(installKey);
    const service = await messaging();
    // Revoke the provider token first, so a failed Cloud acknowledgment cannot keep it deliverable.
    await service.deleteToken();
    if (installationId) await cloud.httpsCallable("updatePushInstallation")({
      action: "revoke", installationId, clientRequestId: crypto.randomUUID(),
    });
    localStorage.removeItem(markerKey);
    localStorage.removeItem(markerKey + ":refreshed");
  }

  function start({ auth, db, cloud, user }) {
    if (active?.uid === user.uid) return;
    active?.stop();
    const panel = document.querySelector("[data-web-push]");
    const local = localMode();
    const supported = !local && window.isSecureContext && "Notification" in window &&
      "serviceWorker" in navigator && Boolean(window.NUDGE_RUNTIME_CONFIG?.webPushVapidKey);
    if (!panel && (!supported || localStorage.getItem(markerKey) !== user.uid)) return;
    const controls = panel?.querySelector("fieldset");
    const form = panel?.querySelector("form");
    const status = panel?.querySelector("[data-web-push-status]");
    const enable = panel?.querySelector("[data-web-push-enable]");
    const disable = panel?.querySelector("[data-web-push-disable]");
    const say = text => { if (status) status.textContent = text; };
    const subscriptions = [];
    let working = false;
    let disposed = false;
    let ready = false;

    function render() {
      if (!panel || disposed) return;
      const registered = localStorage.getItem(markerKey) === user.uid;
      const denied = window.Notification?.permission === "denied";
      enable.disabled = working || !supported || denied || registered;
      disable.disabled = working || !supported || !registered;
      form.querySelector("button").disabled = working || !ready;
      if (denied) say("瀏覽器已拒絕推播。你可以在網站權限中調整設定。");
      else if (local) say("本機測試模式可驗證設定，實際推播需使用已設定的站點。");
      else if (!supported) say("此站點或瀏覽器尚未支援推播。");
      else if (!status.textContent) say(registered ? "這個瀏覽器已開啟推播。" : "這個瀏覽器尚未開啟推播。");
    }

    async function register() {
      const registration = await navigator.serviceWorker.register("./web_push_sw.js");
      const service = await messaging();
      const token = await service.getToken({
        serviceWorkerRegistration: registration,
        vapidKey: window.NUDGE_RUNTIME_CONFIG.webPushVapidKey,
      });
      if (!token || auth.currentUser?.uid !== user.uid) throw new Error("登入已變更。");
      const installationId = localStorage.getItem(installKey) || crypto.randomUUID();
      localStorage.setItem(installKey, installationId);
      try {
        await cloud.httpsCallable("updatePushInstallation")({
          action: "register", platform: "web", token,
          installationId, clientRequestId: crypto.randomUUID(),
        });
      } catch (error) {
        if (localStorage.getItem(markerKey) !== user.uid) await service.deleteToken().catch(() => {});
        throw error;
      }
      localStorage.setItem(markerKey, user.uid);
      localStorage.setItem(markerKey + ":refreshed", String(Date.now()));
      watchMessages(service);
    }

    let watching = false;
    async function watchMessages(service) {
      if (watching || disposed) return;
      watching = true;
      try {
        const core = await loadWindowModule(
          "NudgeWebPushCore", "assets/web_push_core.js?v=1", "推播路由載入失敗",
        );
        if (disposed) return;
        subscriptions.push(service.onMessage(async payload => {
          if (auth.currentUser?.uid !== user.uid || localStorage.getItem(markerKey) !== user.uid) return;
          const notice = core.notification(payload.data);
          if (!notice || Notification.permission !== "granted") return;
          const registration = await navigator.serviceWorker.getRegistration();
          await registration?.showNotification(notice.title, notice);
        }));
      } catch {
        watching = false;
      }
    }

    async function run(action, success, failed) {
      if (working || disposed) return;
      working = true;
      render();
      try {
        await action();
        say(success);
      } catch {
        say(failed);
      } finally {
        working = false;
        render();
      }
    }

    active = {
      uid: user.uid,
      stop() {
        disposed = true;
        subscriptions.forEach(unsubscribe => unsubscribe());
        active = null;
      },
    };
    subscriptions.push(auth.onAuthStateChanged(current => {
      if (current?.uid !== user.uid && active?.uid === user.uid) active.stop();
    }));
    if (supported && Notification.permission === "granted" && localStorage.getItem(markerKey) === user.uid) {
      if (Date.now() - Number(localStorage.getItem(markerKey + ":refreshed")) > 86400000) {
        void register().catch(() => {});
      } else {
        messaging().then(watchMessages).catch(() => {});
      }
    }
    if (!panel) return;
    for (const [key, name] of Object.entries(options)) {
      if (form.elements[key]) continue;
      const wrap = document.createElement("label");
      const input = document.createElement("input");
      input.type = "checkbox";
      input.name = key;
      wrap.append(input, " " + name);
      controls.append(wrap);
    }
    const enableBrowser = () => run(async () => {
      if (!supported || Notification.permission === "denied") return;
      const permission = await Notification.requestPermission();
      if (permission !== "granted") throw new Error("Permission unavailable.");
      await register();
    }, "已在這個瀏覽器開啟推播。", "推播尚未啟用，站內通知仍可使用。");
    enable.onclick = enableBrowser;
    disable.onclick = () => run(() => revoke(user, cloud), "已關閉這個瀏覽器的推播。", "暫時無法確認撤銷。");
    form.onsubmit = event => {
      event.preventDefault();
      void run(() => cloud.httpsCallable("updateWebPushPreferences")({
        categories: Object.fromEntries(Object.keys(options).map(key => [key, form.elements[key].checked])),
        quiet: {
          enabled: form.elements.quiet.checked,
          start: form.elements.start.value,
          end: form.elements.end.value,
          zone: Intl.DateTimeFormat().resolvedOptions().timeZone,
        },
      }), "已儲存推播偏好。", "設定尚未儲存。勿擾的開始與結束時間須不同。");
    };
    subscriptions.push(db.collection("web_push_preferences").doc(user.uid).onSnapshot(snapshot => {
      const data = snapshot.data();
      for (const key of Object.keys(options)) form.elements[key].checked = data?.categories?.[key] !== false;
      form.elements.quiet.checked = data?.quiet?.enabled === true;
      form.elements.start.value = data?.quiet?.start || "22:00";
      form.elements.end.value = data?.quiet?.end || "07:00";
      ready = true;
      render();
    }, () => say("無法讀取推播偏好。")));
    render();
  }

  window.NudgeWebPush = Object.freeze({ start, revoke });
})();
