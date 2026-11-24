(() => {
  "use strict";
  const get = selector => document.querySelector(selector);
  const blockForm = get("[data-safety-block-form]");
  const status = get("[data-safety-status]");
  const settings = NudgeSafety.invoke;
  const reportStates = { pending: "待審核", reviewed: "已處理", dismissed: "未採納" };
  const reportTypes = { roomMessage: "房間訊息", guestbook: "小屋留言", roomName: "房名", nickname: "暱稱" };
  const actionName = { "safety.mute": "禁言", "safety.remove": "移出", "safety.deleteMessage": "內容已移除" };
  const lists = ["[data-safety-blocked]", "[data-safety-reports]", "[data-safety-actions]", "[data-safety-queue]"];
  let version = 0;
  let uid;
  let stopAuth;

  function item(label, buttons = []) {
    const li = document.createElement("li");
    li.textContent = label;
    for (const [label, handler] of buttons) {
      const button = document.createElement("button");
      button.type = "button";
      button.className = "w-btn";
      button.textContent = label;
      button.addEventListener("click", async () => {
        button.disabled = true;
        try {
          await handler();
          await refresh();
        } catch {
          status.textContent = "操作未確認，請稍後重試。";
          button.disabled = false;
        }
      });
      li.append(button);
    }
    return li;
  }

  async function refresh() {
    const current = ++version;
    if (!uid) return;
    try {
      const [account, tracking] = await Promise.all([settings("settings"), settings("reports")]);
      if (version !== current) return;
      get(lists[0]).replaceChildren(...account.blocked.map(user => item(user.name, [
        ["解除封鎖", () => settings("unblock", { targetId: user.id })],
      ])));
      get(lists[1]).replaceChildren(...tracking.reports.map(report =>
        item(reportTypes[report.type] + " · " + reportStates[report.status])));
      get(lists[2]).replaceChildren(...tracking.actions.map(action => item(actionName[action.action] + " · " + action.reason)));
      if (account.staff) {
        const queue = await settings("staffReports");
        if (version !== current) return;
        get(lists[3]).replaceChildren(...queue.reports.map(report =>
          item(reportTypes[report.type] + " · " + report.evidence + " · " + report.details, [
            ["標為已處理", () => settings("review", { reportId: report.id, status: "reviewed" })],
            ["不採納", () => settings("review", { reportId: report.id, status: "dismissed" })],
          ])));
        get("[data-safety-staff]").hidden = false;
      }
      status.textContent = "";
    } catch {
      if (version === current) status.textContent = "無法同步安全設定，請稍後重試。";
    }
  }
  blockForm.addEventListener("submit", async event => {
    event.preventDefault();
    const button = blockForm.querySelector("button");
    button.disabled = true;
    try {
      await settings("block", { targetId: blockForm.elements.uid.value.trim() });
      blockForm.reset();
      await refresh();
    } catch { status.textContent = "未能封鎖，請確認成員識別碼。"; }
    finally { button.disabled = !uid; }
  });

  function start() {
    if (stopAuth || typeof firebase === "undefined" || !firebase.apps.length) return;
    stopAuth = firebase.auth().onAuthStateChanged(user => {
      uid = user?.uid;
      blockForm.reset();
      blockForm.querySelector("button").disabled = !uid;
      lists.forEach(selector => get(selector).replaceChildren());
      get("[data-safety-staff]").hidden = true;
      status.textContent = uid ? "正在同步安全設定…" : "登入後查看你的安全設定。";
      void refresh();
    });
  }
  document.addEventListener("firebase-ready", start);
  start();
})();
