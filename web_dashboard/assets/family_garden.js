(() => {
  "use strict";
  const root = document.querySelector("[data-family-garden]");
  const query = selector => root.querySelector(selector);
  const plot = query("[data-garden-plot]");
  const status = query("[data-garden-status]");
  const review = query("[data-garden-review]");
  const remove = query("[data-garden-remove]");
  const letter = query("[data-garden-letter]");
  const optOut = query("[data-garden-optout]");
  const kinds = { sunflower: "向日葵", sapling: "樹苗", moonflower: "月光花" };
  let linkId;
  let model;
  let version = 0;
  let changed = false;
  let saving = false;

  const call = async (action, payload = {}) =>
    (await functions.httpsCallable("manageFamilyGarden")({ ...payload, linkId, action })).data;

  function render(data) {
    root.hidden = false;
    plot.replaceChildren();
    for (const [kind, name] of Object.entries(kinds)) {
      const stage = data.stages[kind];
      if (stage < 1 || stage > 3) continue;
      const image = new Image(48, 64);
      image.src = "assets/family_garden/" + kind + "-" + stage + ".png";
      image.alt = name + "，有家人完成了活動";
      plot.append(image);
    }
    query("[data-garden-week]").textContent = "回顧週開始於 " + data.reviewDate + " 晚上。";
    const entries = query("[data-garden-reviews]");
    entries.replaceChildren();
    if (data.other) {
      const note = document.createElement("p");
      note.textContent = "家人的回顧：" + data.other.achievement + " · " + data.other.gratitude;
      entries.append(note);
    }
    if (!changed) {
      review.elements.achievement.value = data.own?.achievement || "";
      review.elements.gratitude.value = data.own?.gratitude || "";
    }
    if (review.elements.template.options.length === 1) {
      data.snippets.forEach((text, index) => review.elements.template.add(new Option(text, String(index))));
    }
    remove.hidden = !data.own;
    optOut.hidden = !data.isChild;
    optOut.querySelector("input").checked = data.optedOut;
    letter.hidden = data.isChild;
    const previous = letter.elements.goalId.value;
    letter.elements.goalId.replaceChildren(...data.goals.map(goal => new Option(goal.title, goal.id)));
    if (data.goals.some(goal => goal.id === previous)) letter.elements.goalId.value = previous;
    letter.querySelector("button").disabled = data.optedOut;
    root.querySelectorAll("fieldset").forEach(fieldset => { fieldset.disabled = false; });
  }

  async function refresh(link) {
    if (!linkId) return;
    if (link && link.status !== "active") {
      select(null);
      return;
    }
    if (link && model) {
      const scopes = link.consentScopes || {};
      for (const kind of Object.keys(kinds)) {
        if (!(kind === "sunflower" ? scopes.summary : scopes.healthTrends)) model.stages[kind] = 0;
      }
      render(model);
    }
    const request = ++version;
    try {
      const response = await call("view");
      if (request !== version) return;
      model = response;
      render(model);
      status.textContent = plot.childElementCount ? "有人完成了已同意分享的活動。" : "目前還沒有可顯示的花。";
    } catch {
      if (request !== version) return;
      root.hidden = true;
      plot.replaceChildren();
    }
  }

  function select(id) {
    if (linkId === id) return;
    version++;
    linkId = id;
    model = null;
    changed = false;
    plot.replaceChildren();
    root.hidden = true;
    review.reset();
    letter.reset();
    query('[data-garden-reviews]').replaceChildren();
    if (id) {
      status.textContent = "正在確認家庭權限…";
      void refresh();
    }
  }

  async function update(action, data, confirmation) {
    if (!linkId || !model || saving) return;
    const current = linkId;
    saving = true;
    try {
      await call(action, data);
      if (linkId !== current) return;
      if (action === "writeReview" || action === "deleteReview") changed = false;
      if (action === "schedule") letter.elements.body.value = "";
      await refresh();
      if (linkId === current) status.textContent = confirmation;
    } catch {
      if (linkId === current) status.textContent = "尚未確認，請檢查家庭權限、日期或輸入內容。";
    } finally {
      saving = false;
    }
  }

  review.addEventListener("input", () => { changed = true; });
  review.elements.template.addEventListener("change", event => {
    const index = Number(event.target.value);
    if (!model || event.target.value === "") return;
    review.elements[index < 5 ? "achievement" : "gratitude"].value = model.snippets[index];
    changed = true;
  });
  review.addEventListener("submit", event => {
    event.preventDefault();
    void update("writeReview", {
      achievement: review.elements.achievement.value, gratitude: review.elements.gratitude.value,
    }, "已更新你的回顧。");
  });
  remove.addEventListener("click", () => update("deleteReview", {}, "已刪除你的回顧。"));
  optOut.addEventListener("change", event => update("setOptOut", {
    optedOut: event.target.checked,
  }, "已更新接收設定。"));
  letter.elements.kind.addEventListener("change", () => {
    const goal = letter.elements.kind.value === "goal";
    query("[data-garden-date]").hidden = goal;
    query("[data-garden-goal]").hidden = !goal;
  });
  letter.addEventListener("submit", event => {
    event.preventDefault();
    void update("schedule", {
      body: letter.elements.body.value, kind: letter.elements.kind.value,
      date: letter.elements.date.value, goalId: letter.elements.goalId.value,
    }, "鼓勵信已排程。");
  });
  setInterval(() => { if (linkId) void refresh(); }, 30_000);

  window.NudgeFamilyGarden = Object.freeze({ select, refresh });
})();
