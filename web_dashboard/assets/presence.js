(() => {
  "use strict";

  const root = document.querySelector("[data-friend-presence]");
  let active;

  function node(tag, text) {
    const element = document.createElement(tag);
    element.textContent = text;
    return element;
  }

  function start({ auth, db, functions, user }) {
    if (active?.uid === user.uid) return;
    active?.stop();
    const core = window.NudgePresenceCore;
    const routes = window.NudgeTownRoutes;
    const building = window.frameElement?.id === "townWindowFrame"
      ? core.buildingForPath(routes, window.location.pathname)
      : null;
    if (!building && !root) return;
    const call = async data => (await functions.httpsCallable("manageFriendPresence")(data)).data;
    const subscriptions = [];
    const timers = [];
    const uid = user.uid;
    const toggle = root?.querySelector("[data-presence-sharing]");
    const status = root?.querySelector("[data-presence-status]");
    const list = root?.querySelector("[data-presence-list]");
    let friends = new Map();
    let visible = [];
    let loaded = false;
    let offline = false;
    let error = "";
    let enabled = null;
    let saving = false;
    let version = null;
    let token;
    let stopped = false;
    let updating = false;
    let reading = false;
    let refreshRequested = false;
    let signInName = String(user.displayName || "自律夥伴").trim().slice(0, 40) || "自律夥伴";
    const sending = new Set();
    const liveListeners = new Map();

    function render() {
      if (!root || stopped) return;
      toggle.disabled = saving || enabled === null;
      toggle.checked = enabled === true;
      const live = visible.filter(item => friends.has(item.uid) && item.expiresAt > Date.now());
      const current = list.textContent;
      const signature = JSON.stringify(live.map(item => [item.uid, item.name, item.building, item.openCabin, sending.has(item.uid)]));
      if (list.dataset.signature !== signature || !current && live.length) {
        list.dataset.signature = signature;
        const focusedFriend = document.activeElement?.dataset.presenceCheer;
        list.replaceChildren(...live.map(item => {
          const row = node("li", "");
          const cheer = node("button", "送打氣");
          cheer.type = "button";
          cheer.className = "w-btn";
          cheer.dataset.presenceCheer = item.uid;
          cheer.setAttribute("aria-label", "給 " + item.name + " 打氣");
          cheer.disabled = sending.has(item.uid);
          cheer.addEventListener("click", async () => {
            if (stopped || sending.has(item.uid) || !friends.has(item.uid)) return;
            sending.add(item.uid);
            render();
            try {
              await db.collection("friend_messages").add({
                receiverId: item.uid,
                senderId: uid,
                senderName: signInName,
                senderAvatar: "🧑‍🚀",
                content: "💪",
                type: "cheer",
                createdAt: firebase.firestore.FieldValue.serverTimestamp(),
              });
              error = "已送出打氣。";
            } catch {
              error = "打氣未完成，請確認好友關係或網路。";
            } finally {
              sending.delete(item.uid);
              render();
            }
          });
          const actions = node("div", "");
          actions.className = "presence-actions";
          actions.append(cheer);
          if (item.openCabin) {
            const cabin = node("a", "拜訪小屋");
            cabin.className = "w-btn";
            cabin.href = "friend-visits.html?friend=" + encodeURIComponent(item.uid);
            actions.append(cabin);
          }
          row.append(node("p", item.name + "正在" + routes.BUILDINGS[item.building].name), actions);
          return row;
        }));
        if (focusedFriend) {
          const button = [...list.querySelectorAll("button")].find(item => item.dataset.presenceCheer === focusedFriend);
          (button && !button.disabled ? button : toggle).focus({ preventScroll: true });
        }
      }
      const message = error || (offline ? "目前無法同步好友在場狀態。" :
        !loaded ? "正在確認好友的在場狀態…" :
        !live.length ? "目前沒有可顯示的好友在場狀態。" : "");
      if (status.textContent !== message) status.textContent = message;
    }

    function dropFriendPresence(friendId) {
      liveListeners.get(friendId)?.();
      liveListeners.delete(friendId);
      visible = visible.filter(item => item.uid !== friendId);
      render();
    }

    function watchVisibleFriend(friendId) {
      if (liveListeners.has(friendId)) return;
      const unsubscribe = db.collection("presence").doc(friendId)
        .onSnapshot({ includeMetadataChanges: true }, snapshot => {
          if (stopped || snapshot.metadata.fromCache) return;
          const latest = core.visiblePresence(snapshot.data(), routes.BUILDINGS, Date.now());
          if (!latest || latest.uid !== friendId) {
            dropFriendPresence(friendId);
            return;
          }
          visible = visible.map(item => item.uid === friendId ? { ...item, ...latest } : item);
          render();
        }, () => dropFriendPresence(friendId));
      liveListeners.set(friendId, unsubscribe);
    }

    async function refresh() {
      if (!root || stopped) return;
      if (reading) {
        refreshRequested = true;
        return;
      }
      reading = true;
      let failed = false;
      try {
        const people = await Promise.all([...friends.keys()].map(async friendId => {
          try {
            const snapshot = await db.collection("presence").doc(friendId).get({ source: "server" });
            const record = core.visiblePresence(snapshot.data(), routes.BUILDINGS, Date.now());
            if (!record || record.uid !== friendId) return null;
            let name = friends.get(friendId);
            if (!name) {
              const profile = await db.collection("public_profiles").doc(friendId).get();
              name = String(profile.data()?.nickname || "好友").slice(0, 40);
              if (friends.has(friendId)) friends.set(friendId, name);
            }
            const visitSettings = await db.collection("friend_visit_settings").doc(friendId)
              .get({ source: "server" }).then(document => document.data()).catch(() => null);
            return { ...record, name, openCabin: visitSettings?.allowVisits === true && visitSettings.shareCabin === true };
          } catch (caught) {
            if (caught.code !== "permission-denied") failed = true;
            return null;
          }
        }));
        if (stopped) return;
        visible = people.filter(item => item && friends.has(item.uid));
        const liveIds = new Set(visible.map(item => item.uid));
        for (const id of liveListeners.keys()) if (!liveIds.has(id)) dropFriendPresence(id);
        for (const id of liveIds) watchVisibleFriend(id);
        loaded = true;
        offline = failed;
        render();
      } finally {
        reading = false;
        if (refreshRequested) {
          refreshRequested = false;
          void refresh();
        }
      }
    }

    async function heartbeat() {
      if (stopped || updating || !building || enabled !== true) return;
      updating = true;
      try {
        const result = await call({ action: "heartbeat", building });
        if (stopped || enabled !== true) {
          void call({ action: "leave", version: result.version }).catch(() => {});
          return;
        }
        version = result.version;
      } catch (caught) {
        if (caught.code !== "functions/permission-denied") {
          console.warn("Presence heartbeat unavailable:", caught.code);
        }
      } finally {
        updating = false;
      }
    }

    function stop() {
      if (stopped) return;
      stopped = true;
      for (const unsubscribe of subscriptions) unsubscribe();
      for (const unsubscribe of liveListeners.values()) unsubscribe();
      liveListeners.clear();
      for (const timer of timers) clearInterval(timer);
      window.removeEventListener("pagehide", stop);
      if (toggle) {
        toggle.removeEventListener("change", setConsent);
        toggle.disabled = true;
        toggle.checked = false;
        list.replaceChildren();
        delete list.dataset.signature;
      }
      if (version && token) {
        const project = firebase.app().options.projectId;
        const local = ["127.0.0.1", "localhost"].includes(location.hostname) &&
          window.NUDGE_RUNTIME_CONFIG?.useLocalEmulators === true;
        const endpoint = local ? "http://127.0.0.1:5001/" + project + "/asia-east1/manageFriendPresence"
          : "https://asia-east1-" + project + ".cloudfunctions.net/manageFriendPresence";
        void fetch(endpoint, {
          method: "POST", keepalive: true,
          headers: { "Content-Type": "application/json", Authorization: "Bearer " + token },
          body: JSON.stringify({ data: { action: "leave", version } }),
        }).catch(() => {});
      }
      if (active?.uid === uid) active = null;
    }

    async function setConsent() {
      if (saving || stopped) return;
      const choice = toggle.checked;
      saving = true;
      error = "";
      render();
      try {
        const result = await call({ action: "consent", enabled: choice });
        enabled = result.enabled;
        if (enabled) void heartbeat();
      } catch {
        error = "分享設定尚未確認，請重試。";
      } finally {
        saving = false;
        render();
      }
    }

    active = { uid, stop };
    window.addEventListener("pagehide", stop);
    subscriptions.push(auth.onIdTokenChanged(current => {
      if (current?.uid !== uid) stop();
      else current.getIdToken().then(result => { if (!stopped) token = result; }).catch(() => {});
    }));
    subscriptions.push(db.collection("presence_settings").doc(uid)
      .onSnapshot({ includeMetadataChanges: true }, snapshot => {
        if (stopped || snapshot.metadata.fromCache) return;
        const wasEnabled = enabled;
        enabled = snapshot.data()?.enabled === true;
        if (enabled && wasEnabled !== true) void heartbeat();
        render();
      }, () => {
        enabled = null;
        error = "無法確認分享設定。";
        render();
      }));
    if (building) timers.push(setInterval(heartbeat, 60_000));
    if (root) {
      toggle.addEventListener("change", setConsent);
      subscriptions.push(db.collection("users").doc(uid).collection("friends").onSnapshot(snapshot => {
        friends = new Map(snapshot.docs.map(friend => [
          friend.id, friends.get(friend.id) || friend.data().nickname || friend.data().displayName || "",
        ]));
        for (const id of liveListeners.keys()) if (!friends.has(id)) dropFriendPresence(id);
        render();
        void refresh();
      }, () => {
        friends.clear();
        for (const id of liveListeners.keys()) dropFriendPresence(id);
        offline = true;
        render();
      }));
      void db.collection("public_profiles").doc(uid).get().then(snapshot => {
        const nickname = snapshot.data()?.nickname;
        if (nickname) signInName = String(nickname).slice(0, 40);
      }).catch(() => {});
      timers.push(setInterval(refresh, 20_000), setInterval(render, 1_000));
    }
  }

  window.NudgeFriendPresence = Object.freeze({ start });
})();
