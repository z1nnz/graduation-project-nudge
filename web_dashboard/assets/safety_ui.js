(() => {
  "use strict";
  const invoke = async (action, data = {}) =>
    (await functions.httpsCallable("manageSocialSafety")({ ...data, action })).data;
  const labels = Object.freeze({
    harassment: "騷擾", hate: "仇恨言論", spam: "垃圾訊息", privacy: "涉及隱私", other: "其他",
  });

  function watchMessages(query, roomId, render, onError, action = "roomMessages") {
    let active = true;
    let stop;
    let timer;
    let generation = 0;
    function listen() {
      const version = ++generation;
      stop?.();
      clearTimeout(timer);
      render([]);
      async function filtered() {
        try {
          if (!document.hidden) {
            const { messages } = await invoke(action, { roomId });
            if (active && version === generation) render(messages);
          }
        } catch (error) {
          if (active && version === generation) onError(error);
        } finally {
          if (active && version === generation) timer = setTimeout(filtered, 5_000);
        }
      }
      stop = query.onSnapshot({ includeMetadataChanges: true }, snapshot => {
        if (active && version === generation && !snapshot.metadata.fromCache) {
          render(snapshot.docs.map(doc => ({ ...doc.data(), id: doc.id })));
        }
      }, error => {
        if (!active || version !== generation) return;
        if (error.code === "permission-denied") {
          render([]);
          void filtered();
        } else onError(error);
      });
    }
    document.addEventListener("safety-block-changed", listen);
    listen();
    return () => {
      active = false;
      stop?.();
      clearTimeout(timer);
      document.removeEventListener("safety-block-changed", listen);
    };
  }

  function make(tag, value) {
    const element = document.createElement(tag);
    if (value) element.textContent = value;
    return element;
  }

  function field(label, control) {
    const element = make("label", label + " ");
    element.append(control);
    return element;
  }

  function button(label, call, type = "button") {
    const element = make("button", label);
    element.className = "w-btn";
    element.type = type;
    if (call) element.addEventListener("click", call);
    return element;
  }

  function showDialog(opener, title, content, submit, submitLabel) {
    const dialog = make("dialog");
    dialog.className = "safety-dialog";
    dialog.setAttribute("role", "dialog");
    const heading = make("h2", title);
    heading.id = "safetyDialogHeading";
    dialog.setAttribute("aria-labelledby", heading.id);
    const error = make("p");
    error.setAttribute("role", "status");
    const form = make("form");
    const cancel = button("關閉", () => dialog.close());
    const send = button(submitLabel, null, "submit");
    form.append(heading, ...content, error, cancel, send);
    form.addEventListener("submit", async event => {
      event.preventDefault();
      if (send.disabled) return;
      send.disabled = true;
      error.textContent = "正在確認…";
      try {
        await submit();
        dialog.close();
        notice("操作已確認。");
      } catch {
        error.textContent = "操作未確認，請檢查權限或內容後重試。";
      } finally {
        send.disabled = false;
      }
    });
    dialog.append(form);
    dialog.addEventListener("close", () => {
      dialog.remove();
      if (opener?.isConnected) opener.focus();
    }, { once: true });
    document.body.append(dialog);
    dialog.showModal();
  }

  function notice(message) {
    if (typeof toast === "function") toast(message);
    else {
      const status = document.querySelector("[data-safety-status]");
      if (status) status.textContent = message;
    }
  }

  function report(opener, type, targetId, roomId) {
    if (!targetId) return;
    const reason = make("select");
    for (const [key, label] of Object.entries(labels)) reason.add(new Option(label, key));
    const details = make("textarea");
    details.maxLength = 500;
    showDialog(opener, "檢舉內容", [field("原因", reason), field("補充說明（選填）", details)],
      () => invoke("report", { type, targetId, roomId, reason: reason.value, details: details.value }),
      "送出檢舉");
  }

  function block(opener, targetId) {
    if (!targetId) return;
    showDialog(opener, "封鎖這位成員", [make("p", "封鎖後彼此的房間訊息會隱藏，對方無法向你留言或提及你。")],
      async () => {
        await invoke("block", { targetId });
        document.dispatchEvent(new Event("safety-block-changed"));
      }, "封鎖");
  }

  async function manage(opener, scope, scopeId) {
    if (!scopeId) return;
    try {
      const { members } = await invoke("members", { scope, scopeId });
      const operation = make("select");
      operation.add(new Option("禁言", "mute"));
      operation.add(new Option("移出成員", "remove"));
      operation.add(new Option(scope === "room" ? "移除訊息" : "移除公告", "deleteMessage"));
      const member = make("select");
      for (const person of members) member.add(new Option(person.name, person.id));
      const target = make("input");
      target.maxLength = 180;
      const reason = make("textarea");
      reason.required = true;
      reason.maxLength = 300;
      const duration = make("select");
      for (const [label, value] of [["10 分鐘", "10"], ["1 小時", "60"], ["1 天", "1440"]]) duration.add(new Option(label, value));
      const memberLabel = field("成員", member);
      const targetLabel = field(scope === "room" ? "訊息識別碼" : "公告識別碼", target);
      const durationLabel = field("時間", duration);
      function configure() {
        targetLabel.hidden = operation.value !== "deleteMessage";
        target.required = !targetLabel.hidden;
        memberLabel.hidden = !targetLabel.hidden;
        member.required = !memberLabel.hidden;
        durationLabel.hidden = operation.value !== "mute";
      }
      configure();
      operation.addEventListener("input", configure);
      showDialog(opener, "管理", [field("操作", operation), memberLabel, targetLabel,
        durationLabel, field("成員可見的原因", reason)], () => invoke("moderate", {
        scope, scopeId, operation: operation.value, targetId: target.required ? target.value : member.value,
        reason: reason.value, minutes: Number(duration.value),
      }), "確認");
    } catch { notice("只有目前的房主或管理者可以執行。"); }
  }

  function removeContent(opener, scopeId, targetId, operation = "deleteMessage", scope = "room") {
    const reason = make("textarea");
    reason.required = true;
    reason.maxLength = 300;
    showDialog(opener, operation === "remove" ? "移出成員" : "移除訊息", [field("成員可見的原因", reason)], () => invoke("moderate", {
      scope, scopeId, targetId, operation, reason: reason.value,
    }), "確認移除");
  }

  let groupId;
  let familyId;
  let familyGeneration = 0;
  function setGroup(id, isManager) {
    groupId = id;
    const control = document.querySelector("[data-safety-group-manage]");
    if (control) control.hidden = !id || !isManager;
  }
  async function setFamily(id) {
    const panel = document.querySelector("[data-safety-family]");
    if (!panel || id === familyId) return;
    familyId = id;
    const version = ++familyGeneration;
    panel.hidden = true;
    if (!id) return;
    try {
      const settings = await invoke("familyView", { linkId: id });
      if (version !== familyGeneration) return;
      const form = panel.querySelector("form");
      form.elements.voice.checked = settings.allowVoice;
      form.elements.mentions.checked = settings.allowStrangerMentions;
      form.elements.confirm.checked = false;
      form.hidden = !settings.isChild;
      panel.querySelector("[data-safety-family-result]").textContent =
        "語音：" + (settings.allowVoice ? "允許" : "關閉") + " · 陌生人提及：" +
        (settings.allowStrangerMentions ? "允許" : "關閉");
      panel.hidden = false;
    } catch { panel.hidden = true; }
  }
  document.querySelector("[data-safety-family] form")?.addEventListener("submit", async event => {
    event.preventDefault();
    const form = event.currentTarget;
    const active = familyId;
    if (!active) return;
    const status = document.querySelector("[data-safety-family-result]");
    try {
      await invoke("setChildProtection", {
        linkId: active, allowVoice: form.elements.voice.checked,
        allowStrangerMentions: form.elements.mentions.checked, confirm: form.elements.confirm.checked,
      });
      if (familyId === active) {
        familyId = undefined;
        await setFamily(active);
      }
    } catch { status.textContent = "設定未確認。只有孩子本人可以送出。"; }
  });
  document.addEventListener("click", event => {
    const control = event.target.closest("[data-safety-room-manage],[data-safety-group-manage],[data-safety-room-name],[data-safety-report-visit],[data-safety-block],[data-safety-report-profile]");
    if (!control) return;
    const roomId = typeof activeWebRoom !== "undefined" ? activeWebRoom?.id : null;
    if (control.hasAttribute("data-safety-room-manage")) void manage(control, "room", roomId);
    if (control.hasAttribute("data-safety-group-manage")) void manage(control, "group", groupId);
    if (control.hasAttribute("data-safety-room-name")) report(control, "roomName", roomId);
    if (control.hasAttribute("data-safety-report-visit")) report(control, "guestbook", control.dataset.safetyReportVisit);
    if (control.hasAttribute("data-safety-block")) block(control, control.dataset.safetyBlock);
    if (control.hasAttribute("data-safety-report-profile")) report(control, "nickname", control.dataset.safetyReportProfile);
  });

  window.NudgeSafety = Object.freeze({
    invoke, watchMessages, report, block, removeContent, setGroup, setFamily,
    voiceAllowed: async () => (await invoke("settings")).allowVoice,
  });
})();
