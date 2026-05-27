const $ = (selector, root = document) => root.querySelector(selector);
const $$ = (selector, root = document) => Array.from(root.querySelectorAll(selector));

const modules = [
  ["home", "總覽入口", "index.html"],
  ["personal", "個人進階分析", "personal.html"],
  ["guardian", "家長陪伴中心", "guardian.html"],
  ["groups", "團體 / 教育管理", "groups.html"],
  ["operations", "營運後台", "operations.html"],
  ["research", "研究 / 展示中心", "research.html"],
  ["planet", "自律城市 / 星球", "planet.html"],
  ["presentation", "專題發表流程", "presentation.html"],
];

function injectModuleMenu() {
  const sidebar = $(".sidebar");
  const brand = $(".brand");
  if (!sidebar || !brand || $(".module-switcher")) return;
  const page = document.body.dataset.page || "home";
  const switcher = document.createElement("section");
  switcher.className = "module-switcher";
  switcher.innerHTML = `
    <label for="moduleSelect">選擇 Web 功能中心</label>
    <select class="module-select" id="moduleSelect" aria-label="選擇 Web 功能中心">
      ${modules
        .map(([key, label, href]) => `<option value="${href}" ${key === page ? "selected" : ""}>${label}</option>`)
        .join("")}
    </select>
  `;
  brand.insertAdjacentElement("afterend", switcher);
  $("#moduleSelect")?.addEventListener("change", (event) => {
    window.location.href = event.target.value;
  });
}

function injectDisplayModeControls() {
  const sidebar = $(".sidebar");
  if (!sidebar || $(".mode-toggle")) return;
  const actions = document.createElement("section");
  actions.className = "sidebar-actions";
  actions.innerHTML = `
    <button class="button ghost mode-toggle" data-mode-toggle type="button">展示模式</button>
  `;
  sidebar.appendChild(actions);

  if (!$(".floating-mode-button")) {
    const floating = document.createElement("button");
    floating.className = "floating-mode-button";
    floating.type = "button";
    floating.dataset.modeToggle = "true";
    floating.textContent = "退出展示模式";
    document.body.appendChild(floating);
  }

  const savedMode = localStorage.getItem("nudgeWebFocusMode") === "true";
  document.body.classList.toggle("focus-mode", savedMode);
  $$("[data-mode-toggle]").forEach((button) => {
    button.addEventListener("click", () => {
      const next = !document.body.classList.contains("focus-mode");
      document.body.classList.toggle("focus-mode", next);
      localStorage.setItem("nudgeWebFocusMode", String(next));
      toast(next ? "已進入展示模式" : "已退出展示模式");
      setTimeout(bootCharts, 120);
    });
  });
}

function animateCounters() {
  $$("[data-count]").forEach((node) => {
    const target = Number(node.dataset.count || 0);
    const suffix = node.dataset.suffix || "";
    const duration = 900;
    const start = performance.now();
    const tick = (now) => {
      const progress = Math.min((now - start) / duration, 1);
      const value = Math.round(target * (1 - Math.pow(1 - progress, 3)));
      node.textContent = `${value}${suffix}`;
      if (progress < 1) requestAnimationFrame(tick);
    };
    requestAnimationFrame(tick);
  });
}

function drawLineChart(canvas, values, color = "#22c7bb") {
  if (!canvas) return;
  const ctx = canvas.getContext("2d");
  const ratio = window.devicePixelRatio || 1;
  const rect = canvas.getBoundingClientRect();
  canvas.width = rect.width * ratio;
  canvas.height = rect.height * ratio;
  ctx.scale(ratio, ratio);
  ctx.clearRect(0, 0, rect.width, rect.height);

  const pad = 26;
  const max = Math.max(...values, 100);
  const min = Math.min(...values, 0);
  const step = (rect.width - pad * 2) / (values.length - 1);
  const toY = (v) => rect.height - pad - ((v - min) / (max - min || 1)) * (rect.height - pad * 2);

  ctx.strokeStyle = "rgba(255,255,255,.1)";
  ctx.lineWidth = 1;
  for (let i = 0; i < 4; i++) {
    const y = pad + i * ((rect.height - pad * 2) / 3);
    ctx.beginPath();
    ctx.moveTo(pad, y);
    ctx.lineTo(rect.width - pad, y);
    ctx.stroke();
  }

  const gradient = ctx.createLinearGradient(0, pad, 0, rect.height - pad);
  gradient.addColorStop(0, "rgba(34,199,187,.42)");
  gradient.addColorStop(1, "rgba(34,199,187,0)");

  ctx.beginPath();
  values.forEach((value, i) => {
    const x = pad + i * step;
    const y = toY(value);
    if (i === 0) ctx.moveTo(x, y);
    else ctx.lineTo(x, y);
  });
  ctx.lineTo(rect.width - pad, rect.height - pad);
  ctx.lineTo(pad, rect.height - pad);
  ctx.closePath();
  ctx.fillStyle = gradient;
  ctx.fill();

  ctx.beginPath();
  values.forEach((value, i) => {
    const x = pad + i * step;
    const y = toY(value);
    if (i === 0) ctx.moveTo(x, y);
    else ctx.lineTo(x, y);
  });
  ctx.strokeStyle = color;
  ctx.lineWidth = 4;
  ctx.lineCap = "round";
  ctx.lineJoin = "round";
  ctx.stroke();
}

function drawDonut(canvas, values, colors) {
  if (!canvas) return;
  const ctx = canvas.getContext("2d");
  const ratio = window.devicePixelRatio || 1;
  const rect = canvas.getBoundingClientRect();
  canvas.width = rect.width * ratio;
  canvas.height = rect.height * ratio;
  ctx.scale(ratio, ratio);
  const cx = rect.width / 2;
  const cy = rect.height / 2;
  const radius = Math.min(rect.width, rect.height) * 0.34;
  const total = values.reduce((a, b) => a + b, 0);
  let start = -Math.PI / 2;
  values.forEach((value, index) => {
    const angle = (value / total) * Math.PI * 2;
    ctx.beginPath();
    ctx.arc(cx, cy, radius, start, start + angle);
    ctx.lineWidth = 24;
    ctx.strokeStyle = colors[index];
    ctx.stroke();
    start += angle;
  });
  ctx.fillStyle = "#f7f8ff";
  ctx.font = "900 34px system-ui";
  ctx.textAlign = "center";
  ctx.fillText(`${total}`, cx, cy + 10);
}

function toast(message) {
  let node = $(".toast");
  if (!node) {
    node = document.createElement("div");
    node.className = "toast";
    document.body.appendChild(node);
  }
  node.textContent = message;
  node.classList.add("show");
  setTimeout(() => node.classList.remove("show"), 2200);
}

function bindDemoButtons() {
  $$("[data-toast]").forEach((button) => {
    button.addEventListener("click", () => toast(button.dataset.toast));
  });
  $$("[data-toggle-active]").forEach((button) => {
    button.addEventListener("click", () => {
      button.classList.toggle("primary");
      button.classList.toggle("ghost");
    });
  });
}

function bootCharts() {
  drawLineChart($("#trendChart"), [62, 68, 71, 73, 76, 81, 84, 88, 86, 91, 94, 96]);
  drawLineChart($("#sleepChart"), [5.8, 6.1, 5.6, 6.8, 7.0, 6.4, 7.2], "#8d7aff");
  drawLineChart($("#groupChart"), [42, 55, 61, 70, 76, 82, 89], "#5d8cff");
  drawDonut($("#sourceDonut"), [34, 22, 18, 16, 10], ["#22c7bb", "#5d8cff", "#8d7aff", "#ffad2f", "#ff62a7"]);
}

function bindPlanet() {
  const buttons = $$("[data-planet-mode]");
  const label = $("#planetLabel");
  const hud = $("#planetHud");
  buttons.forEach((button) => {
    button.addEventListener("click", () => {
      buttons.forEach((b) => b.classList.remove("primary"));
      button.classList.add("primary");
      if (label) label.textContent = button.dataset.planetMode;
      if (hud) hud.textContent = button.dataset.planetMode;
      toast(`已切換成「${button.dataset.planetMode}」展示資料`);
    });
  });
}

function saveDemoState(key, payload) {
  const current = JSON.parse(localStorage.getItem("nudgeWebTools") || "{}");
  current[key] = {
    ...payload,
    updatedAt: new Date().toISOString(),
  };
  localStorage.setItem("nudgeWebTools", JSON.stringify(current));
}

function downloadTextFile(filename, text) {
  const blob = new Blob([text], { type: "text/plain;charset=utf-8" });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = filename;
  document.body.appendChild(anchor);
  anchor.click();
  anchor.remove();
  URL.revokeObjectURL(url);
}

function bindExtensionTools() {
  const templateTool = $('[data-tool="template-builder"]');
  const guardianTool = $('[data-tool="guardian-invite"]');
  const challengeTool = $('[data-tool="challenge-builder"]');
  const campaignTool = $('[data-tool="campaign-builder"]');
  const scenarioTool = $('[data-tool="scenario-builder"]');
  const planetTool = $('[data-tool="planet-builder"]');
  const capsuleTool = $('[data-tool="time-capsule"]');
  const encouragementTool = $('[data-tool="encouragement-card"]');
  const studyScheduleTool = $('[data-tool="study-schedule"]');
  const futureLetterTool = $('[data-tool="future-letter"]');

  const setOutput = (root, html) => {
    const output = $('[data-output]', root);
    if (output) output.innerHTML = html;
  };

  let templateText = "";
  templateTool?.querySelector('[data-action="generate-template"]')?.addEventListener("click", () => {
    const type = $('[data-template-type]', templateTool).value;
    const days = Number($('[data-template-days]', templateTool).value || 7);
    const effort = $('[data-template-effort]', templateTool).value;
    const pressure = $('[data-template-pressure]', templateTool).value;
    const phase = pressure === "截止日前" ? "先拆交付物、再安排檢查日" : "前段建立節奏，中段執行，最後回顧調整";
    templateText = `${type} ${days} 日任務模板\n每日投入：${effort}\n策略：${phase}\n\nDay 1：整理目標與資料\nDay ${Math.ceil(days / 2)}：完成主要進度\nDay ${days}：回顧、補強與提交`;
    setOutput(
      templateTool,
      `<strong>${type} ${days} 日模板</strong><p>每日 ${effort}，${phase}。已產生可匯入 App 的分段任務草稿。</p>`,
    );
    saveDemoState("template", { type, days, effort, pressure });
    toast("已產生任務模板");
  });
  templateTool?.querySelector('[data-action="download-template"]')?.addEventListener("click", () => {
    downloadTextFile("nudge-task-template.txt", templateText || "請先產生任務模板。");
  });

  guardianTool?.querySelector('[data-action="preview-guardian"]')?.addEventListener("click", () => {
    const goal = $('[data-guardian-goal]', guardianTool).value;
    const permission = $('[data-guardian-permission]', guardianTool).value;
    const message = $('[data-guardian-message]', guardianTool).value.trim();
    setOutput(
      guardianTool,
      `<strong>${goal}</strong><p>權限：${permission}。鼓勵訊息：「${message}」孩子同意後才會啟用，並可隨時解除。</p>`,
    );
    saveDemoState("guardianInvite", { goal, permission, message });
    toast("邀請預覽已更新");
  });
  guardianTool?.querySelector('[data-action="send-guardian"]')?.addEventListener("click", () => {
    saveDemoState("guardianInviteStatus", { status: "pending_child_approval" });
    toast("已送出陪伴邀請 Demo");
  });

  let challengeText = "";
  challengeTool?.querySelector('[data-action="generate-challenge"]')?.addEventListener("click", () => {
    const group = $('[data-challenge-group]', challengeTool).value.trim() || "未命名團體";
    const type = $('[data-challenge-type]', challengeTool).value;
    const days = Number($('[data-challenge-days]', challengeTool).value || 7);
    const reward = $('[data-challenge-reward]', challengeTool).value;
    challengeText = `${group} ${days} 日${type}\n獎勵：${reward}\n規則：每日完成目標得 1 點，連續完成加成，排行榜只顯示前 10 名。`;
    setOutput(
      challengeTool,
      `<strong>${group}：${days} 日${type}</strong><p>獎勵為 ${reward}，系統會自動產生排行榜、提醒節奏與活動週報。</p>`,
    );
    saveDemoState("challenge", { group, type, days, reward });
    toast("挑戰草稿已建立");
  });
  challengeTool?.querySelector('[data-action="download-challenge"]')?.addEventListener("click", () => {
    downloadTextFile("nudge-group-challenge.txt", challengeText || "請先建立挑戰草稿。");
  });

  campaignTool?.querySelector('[data-action="generate-campaign"]')?.addEventListener("click", () => {
    const name = $('[data-campaign-name]', campaignTool).value.trim() || "未命名套裝";
    const rarity = $('[data-campaign-rarity]', campaignTool).value;
    const price = Number($('[data-campaign-price]', campaignTool).value || 0);
    const days = Number($('[data-campaign-days]', campaignTool).value || 7);
    const health = price <= 40 ? "新手友善" : price <= 90 ? "價格健康" : "適合活動限定";
    setOutput(
      campaignTool,
      `<strong>${name}：${rarity} / ${price} 枚</strong><p>${days} 天活動，${health}。以每日 15 枚、每月 400 枚上限估算，兌換壓力合理。</p>`,
    );
    saveDemoState("campaign", { name, rarity, price, days, health });
    toast("價格檢查完成");
  });
  campaignTool?.querySelector('[data-action="save-campaign"]')?.addEventListener("click", () => {
    toast("已排程上架 Demo");
  });

  $$("[data-review-action]").forEach((button) => {
    button.addEventListener("click", () => {
      const item = button.closest(".review-item");
      const action = button.dataset.reviewAction;
      item?.classList.add("reviewed");
      item?.querySelector(".compact-actions")?.replaceChildren(Object.assign(document.createElement("span"), {
        className: "status-tag",
        textContent: `已${action}`,
      }));
      toast(`申請已${action}`);
    });
  });

  let scenarioText = "";
  scenarioTool?.querySelector('[data-action="generate-scenario"]')?.addEventListener("click", () => {
    const type = $('[data-scenario-type]', scenarioTool).value;
    const privacy = $('[data-scenario-privacy]', scenarioTool).value;
    const focus = $('[data-scenario-focus]', scenarioTool).value.trim();
    scenarioText = `${type}\n隱私層級：${privacy}\n展示重點：${focus}\n\n展示順序：App 狀態 → Web 分析 → 自律星球視覺化 → 研究價值結論。`;
    setOutput(
      scenarioTool,
      `<strong>${type}</strong><p>${privacy}。展示順序：App 狀態 → Web 分析 → 自律星球視覺化 → 研究價值結論。</p>`,
    );
    saveDemoState("scenario", { type, privacy, focus });
    toast("展示腳本已產生");
  });
  scenarioTool?.querySelector('[data-action="download-scenario"]')?.addEventListener("click", () => {
    downloadTextFile("nudge-demo-scenario.txt", scenarioText || "請先產生展示腳本。");
  });

  planetTool?.querySelector('[data-action="generate-planet"]')?.addEventListener("click", () => {
    const building = $('[data-planet-building]', planetTool).value;
    const condition = $('[data-planet-condition]', planetTool).value;
    const event = $('[data-planet-event]', planetTool).value.trim();
    setOutput(
      planetTool,
      `<strong>${building}建築計畫</strong><p>解鎖條件：${condition}。${event}</p>`,
    );
    saveDemoState("planetBuilding", { building, condition, event });
    toast("星球建築已規劃");
  });
  planetTool?.querySelector('[data-action="save-planet"]')?.addEventListener("click", () => {
    toast("已設為下週星球目標");
  });

  const renderSavedList = (selector, items, fallback) => {
    const list = $(selector);
    if (!list) return;
    if (!items.length) {
      list.innerHTML = fallback;
      return;
    }
    list.innerHTML = items
      .map((item) => `<article><strong>${item.title}</strong><span>${item.meta}</span></article>`)
      .join("");
  };

  const savedTools = JSON.parse(localStorage.getItem("nudgeWebTools") || "{}");
  const saveToolCollection = (key, items) => {
    const current = JSON.parse(localStorage.getItem("nudgeWebTools") || "{}");
    current[key] = items;
    current[`${key}UpdatedAt`] = new Date().toISOString();
    localStorage.setItem("nudgeWebTools", JSON.stringify(current));
  };
  renderSavedList(
    "[data-capsule-list]",
    savedTools.capsules || [],
    "<article><strong>尚未保存</strong><span>建立第一個時間膠囊後會出現在這裡。</span></article>",
  );
  renderSavedList(
    "[data-encourage-list]",
    savedTools.encouragements || [],
    "<article><strong>尚未送出</strong><span>送出鼓勵卡後會出現在這裡。</span></article>",
  );
  renderSavedList(
    "[data-study-list]",
    savedTools.studySchedules || [],
    "<article><strong>尚未排程</strong><span>新增讀書時段後會出現在這裡。</span></article>",
  );

  let capsuleText = "";
  capsuleTool?.querySelector('[data-action="save-capsule"]')?.addEventListener("click", () => {
    const title = $('[data-capsule-title]', capsuleTool).value.trim() || "未命名時間膠囊";
    const date = $('[data-capsule-date]', capsuleTool).value || "未設定";
    const message = $('[data-capsule-message]', capsuleTool).value.trim();
    capsuleText = `${title}\n解鎖日：${date}\n\n${message}`;
    setOutput(capsuleTool, `<strong>${title}</strong><p>將於 ${date} 解鎖。內容已保存到 Demo localStorage。</p>`);
    const store = JSON.parse(localStorage.getItem("nudgeWebTools") || "{}");
    const capsules = store.capsules || [];
    capsules.unshift({ title, meta: `${date} 解鎖`, message });
    saveToolCollection("capsules", capsules.slice(0, 6));
    renderSavedList("[data-capsule-list]", capsules.slice(0, 6), "");
    toast("時間膠囊已保存");
  });
  capsuleTool?.querySelector('[data-action="download-capsule"]')?.addEventListener("click", () => {
    downloadTextFile("nudge-time-capsule.txt", capsuleText || "請先保存時間膠囊。");
  });

  encouragementTool?.querySelector('[data-action="preview-encouragement"]')?.addEventListener("click", () => {
    const type = $('[data-encourage-type]', encouragementTool).value;
    const tone = $('[data-encourage-tone]', encouragementTool).value;
    const message = $('[data-encourage-message]', encouragementTool).value.trim();
    setOutput(encouragementTool, `<strong>${type}</strong><p>語氣：${tone}。${message}</p>`);
    toast("鼓勵卡已更新");
  });
  encouragementTool?.querySelector('[data-action="send-encouragement"]')?.addEventListener("click", () => {
    const type = $('[data-encourage-type]', encouragementTool).value;
    const tone = $('[data-encourage-tone]', encouragementTool).value;
    const message = $('[data-encourage-message]', encouragementTool).value.trim();
    const store = JSON.parse(localStorage.getItem("nudgeWebTools") || "{}");
    const encouragements = store.encouragements || [];
    encouragements.unshift({ title: type, meta: `${tone}語氣：${message}` });
    saveToolCollection("encouragements", encouragements.slice(0, 6));
    renderSavedList("[data-encourage-list]", encouragements.slice(0, 6), "");
    toast("鼓勵卡已送出 Demo");
  });

  studyScheduleTool?.querySelector('[data-action="save-study-schedule"]')?.addEventListener("click", () => {
    const title = $('[data-study-title]', studyScheduleTool).value.trim() || "未命名共讀";
    const time = $('[data-study-time]', studyScheduleTool).value || "未設定";
    const duration = $('[data-study-duration]', studyScheduleTool).value;
    const room = $('[data-study-room]', studyScheduleTool).value;
    setOutput(studyScheduleTool, `<strong>${title}</strong><p>${time}，${duration}，將建立${room}並排程提醒。</p>`);
    const store = JSON.parse(localStorage.getItem("nudgeWebTools") || "{}");
    const studySchedules = store.studySchedules || [];
    studySchedules.unshift({ title, meta: `${time} / ${duration} / ${room}` });
    saveToolCollection("studySchedules", studySchedules.slice(0, 6));
    renderSavedList("[data-study-list]", studySchedules.slice(0, 6), "");
    toast("讀書時段已建立 Demo");
  });

  let futureLetterText = "";
  futureLetterTool?.querySelector('[data-action="generate-letter"]')?.addEventListener("click", () => {
    const state = $('[data-letter-state]', futureLetterTool).value;
    const action = $('[data-letter-action]', futureLetterTool).value.trim() || "完成一個小任務";
    const note = $('[data-letter-note]', futureLetterTool).value.trim();
    futureLetterText = `一週後的你想說：\n\n我知道你現在是「${state}」。但你不用今天就解決全部事情。先做「${action}」，讓自己重新回到軌道。\n\n你留給自己的提醒：${note}`;
    const output = $('[data-letter-output]', futureLetterTool);
    if (output) {
      output.innerHTML = `<strong>一週後的你想說</strong><p>我知道你現在是「${state}」。先做「${action}」，你會感覺事情開始變小。</p><p>${note}</p>`;
    }
    saveDemoState("futureLetter", { state, action, note });
    toast("未來的信已產生");
  });
  futureLetterTool?.querySelector('[data-action="download-letter"]')?.addEventListener("click", () => {
    downloadTextFile("nudge-future-letter.txt", futureLetterText || "請先產生未來的信。");
  });
}

function bindTilt() {
  $$("[data-tilt]").forEach((node) => {
    node.addEventListener("pointermove", (event) => {
      const rect = node.getBoundingClientRect();
      const x = (event.clientX - rect.left) / rect.width - 0.5;
      const y = (event.clientY - rect.top) / rect.height - 0.5;
      node.style.transform = `rotateX(${(-y * 7).toFixed(2)}deg) rotateY(${(x * 9).toFixed(2)}deg)`;
    });
    node.addEventListener("pointerleave", () => {
      node.style.transform = "";
    });
  });
}

const demoSlides = [
  {
    title: "問題與定位",
    script:
      "現在很多人會下載任務或番茄鐘 App，但問題是完成後的回饋很短暫，很難形成長期動機。Nudge 想做的是把任務、健康、專注與社交整合，讓自律不只是打勾，而是一個可以被累積、被看見、被陪伴的生活系統。",
    items: [
      ["使用者痛點", "想自律，但回饋不夠持久。"],
      ["Nudge 定位", "自律 App + 社交陪伴 + 遊戲化成長。"],
      ["核心差異", "不是只記錄，而是讓資料產生下一步行動。"],
    ],
  },
  {
    title: "App 每日行動",
    script:
      "App 端負責每天最直接的自律行動：建立任務、開始專注、同步健康資料、進入自律房。使用者不用先看很多報表，而是每天打開就知道下一步該做什麼。",
    items: [
      ["任務系統", "一般任務、自動追蹤、截止日任務分工明確。"],
      ["專注與健康", "專注分鐘、睡眠、步數、運動可自動成為任務依據。"],
      ["今日建議", "把資料轉成可直接執行的行動入口。"],
    ],
  },
  {
    title: "自律分數與自律幣",
    script:
      "Nudge 用加權自律分數衡量每日完成度，再依百分比門檻給自律幣。這樣可以避免任務亂設造成獎勵失衡，也能讓健康、專注、自律房這些高價值行為被看見。",
    items: [
      ["加權分數", "不同任務來源有不同重要性。"],
      ["幣上限", "日、週、月都有上限，避免刷幣。"],
      ["截止日獎勵", "額外獎勵獨立處理，不擠壓每日上限。"],
    ],
  },
  {
    title: "社交與換裝",
    script:
      "自律幣不是只是一個數字，而是能換成角色造型。好友公開頁、自律房與角色展示讓努力成果被朋友看見，形成一種比較柔和的社交動機。",
    items: [
      ["角色換裝", "完成任務後兌換衣服與造型。"],
      ["好友展示", "朋友看得到你的穿搭、狀態與活躍房間。"],
      ["自律房", "多人一起讀書、睡眠、運動或步數挑戰。"],
    ],
  },
  {
    title: "Web 延伸平台",
    script:
      "Web 版不是複製 App，而是提供大螢幕才適合的延伸功能：個人長期分析、家長陪伴、團體教育管理、營運後台和研究展示。這讓 Nudge 從 App 變成完整服務。",
    items: [
      ["個人分析", "月度趨勢、壓力雷達、自律天氣、技能樹。"],
      ["家長陪伴", "看趨勢、送鼓勵、共同目標、權限分級。"],
      ["團體與營運", "企業挑戰、補習班後台、商城與活動管理。"],
    ],
  },
  {
    title: "自律星球亮點",
    script:
      "最後用自律城市或自律星球把整個系統收起來：專注任務蓋圖書館、健康任務蓋公園、睡眠點亮住宅區、自律房出現朋友角色。這讓抽象分數變成看得見的世界。",
    items: [
      ["可視化成果", "任務成果變成建築與星球成長。"],
      ["社交展示", "朋友角色可以拜訪城市或共同建設星球。"],
      ["發表亮點", "老師能一眼理解遊戲化與資料整合價值。"],
    ],
  },
];

function renderDemoSlide(index) {
  const title = $("#demoTitle");
  const script = $("#demoScript");
  const checklist = $("#demoChecklist");
  const steps = $$("[data-demo-step]");
  const slide = demoSlides[index % demoSlides.length];
  if (!title || !script || !checklist) return;
  title.textContent = slide.title;
  script.textContent = slide.script;
  checklist.innerHTML = slide.items
    .map(([head, body]) => `<li><strong>${head}</strong><span>${body}</span></li>`)
    .join("");
  steps.forEach((step, stepIndex) => {
    step.classList.toggle("active", stepIndex === index % demoSlides.length);
  });
}

function bindPresentation() {
  if (!document.body.matches('[data-page="presentation"]')) return;
  let demoIndex = 0;
  renderDemoSlide(demoIndex);
  $$("[data-demo-next]").forEach((button) => {
    button.addEventListener("click", () => {
      demoIndex = (demoIndex + 1) % demoSlides.length;
      renderDemoSlide(demoIndex);
      toast(`已切換到第 ${demoIndex + 1} 段：${demoSlides[demoIndex].title}`);
    });
  });
  $$("[data-demo-step]").forEach((step, index) => {
    step.addEventListener("click", () => {
      demoIndex = index;
      renderDemoSlide(demoIndex);
    });
  });
}

window.addEventListener("DOMContentLoaded", () => {
  injectModuleMenu();
  injectDisplayModeControls();
  animateCounters();
  bootCharts();
  bindDemoButtons();
  bindPlanet();
  bindExtensionTools();
  bindTilt();
  bindPresentation();
  initializeFirebaseWeb();
  if (document.body.dataset.page === "planet") {
    setTimeout(init3DPlanet, 300);
  }
});

window.addEventListener("resize", bootCharts);

const firebaseConfig = {
  apiKey: "AIzaSyCsvP-r0EygpkhH0Zwzfrl4uFzy6LcbsTQ",
  authDomain: "nudge-discipline-app.firebaseapp.com",
  projectId: "nudge-discipline-app",
  storageBucket: "nudge-discipline-app.firebasestorage.app",
  messagingSenderId: "497972469632",
  appId: "1:497972469632:web:cb87819a70c7cb8f2f6b65"
};

function loadFirebaseSDKs() {
  return new Promise((resolve) => {
    if (window.firebase) {
      resolve();
      return;
    }
    const coreScript = document.createElement('script');
    coreScript.src = "https://www.gstatic.com/firebasejs/9.22.0/firebase-app-compat.js";
    coreScript.onload = () => {
      const dbScript = document.createElement('script');
      dbScript.src = "https://www.gstatic.com/firebasejs/9.22.0/firebase-firestore-compat.js";
      dbScript.onload = () => {
        resolve();
      };
      dbScript.onerror = () => resolve();
      document.head.appendChild(dbScript);
    };
    coreScript.onerror = () => resolve();
    document.head.appendChild(coreScript);
  });
}

let db = null;

function initializeFirebaseWeb() {
  loadFirebaseSDKs().then(() => {
    if (typeof firebase !== 'undefined') {
      try {
        if (!firebase.apps.length) {
          firebase.initializeApp(firebaseConfig);
        }
        db = firebase.firestore();
        console.log("Firebase initialized successfully on Web Center");
        startListeningToFirestoreData();
      } catch (e) {
        console.warn("Firebase initialization failed, falling back to mock data: ", e);
      }
    } else {
      console.log("Firebase SDK not loaded, using local demo data");
    }
  });
}

function startListeningToFirestoreData() {
  if (!db) return;
  db.collection("users").get().then((querySnapshot) => {
    const users = [];
    querySnapshot.forEach((doc) => {
      users.push({ id: doc.id, ...doc.data() });
    });
    
    if (users.length === 0) {
      console.log("No users found in Firestore.");
      return;
    }
    
    let activeUserId = localStorage.getItem("nudgeActiveDemoUserId") || users[0].id;
    if (!users.some(u => u.id === activeUserId)) {
      activeUserId = users[0].id;
    }
    localStorage.setItem("nudgeActiveDemoUserId", activeUserId);
    
    // Clear static demo panel status
    const panel = $(".side-panel");
    if (panel) {
      panel.innerHTML = "";
    }
    
    injectUserSwitcher(users, activeUserId);
    listenToUser(activeUserId);
  }).catch(e => {
    console.warn("Firestore access error: ", e);
  });
}

function injectUserSwitcher(users, activeUserId) {
  const panel = $(".side-panel");
  if (!panel || $(".demo-user-select").length) return;
  
  const selectHtml = `
    <div style="margin-top: 10px; border-top: 1px solid rgba(255,255,255,0.06); padding-top: 10px;" class="demo-user-select">
      <span class="eyebrow">切換自律帳號</span>
      <select id="demoUserSelect" class="module-select" style="width: 100%; margin-top: 5px; background: #1a1d24; color: #fff; border: 1px solid rgba(255,255,255,0.12); padding: 8px; borderRadius: 8px; font-weight: 600; cursor: pointer;">
        ${users.map(u => `<option value="${u.id}" ${u.id === activeUserId ? 'selected' : ''}>${u.nickname} (${u.username || 'NDG'})</option>`).join('')}
      </select>
    </div>
  `;
  panel.insertAdjacentHTML('beforeend', selectHtml);
  
  document.getElementById("demoUserSelect")?.addEventListener("change", (e) => {
    const nextUserId = e.target.value;
    localStorage.setItem("nudgeActiveDemoUserId", nextUserId);
    toast(`已切換自律帳號數據`);
    setTimeout(() => window.location.reload(), 500);
  });
}

function updateSidebarProfile(data) {
  const panel = $(".side-panel");
  if (!panel) return;
  
  const nickname = data.nickname || "未知使用者";
  const nudgeId = data.myNudgeId || data.username || "NDG-Guest";
  const coins = typeof data.disciplineCoins === 'number' ? data.disciplineCoins : 0;
  
  let accentColor = "#7c6ae6";
  if (data.accentColor) {
    if (typeof data.accentColor === 'number') {
      const hex = (data.accentColor & 0x00FFFFFF).toString(16).padStart(6, '0');
      accentColor = `#${hex}`;
    } else {
      accentColor = data.accentColor;
    }
  }

  let profileContainer = $(".sidebar-profile-container");
  const cardHtml = `
    <div class="sidebar-profile-container" style="text-align: left;">
      <span class="eyebrow">同步使用者資料</span>
      <div class="user-profile-card" style="margin-top: 8px; margin-bottom: 12px; background: rgba(255,255,255,0.03); border: 1px solid rgba(255,255,255,0.08); border-radius: 12px; padding: 12px; display: flex; align-items: center; gap: 12px; box-shadow: inset 0 1px 0 rgba(255,255,255,0.05);">
        <div style="width: 40px; height: 40px; border-radius: 50%; background: ${accentColor}; display: flex; align-items: center; justify-content: center; font-weight: 800; color: white; font-size: 16px; box-shadow: 0 4px 12px ${accentColor}40; flex-shrink: 0;">
          ${nickname.substring(0, 1).toUpperCase()}
        </div>
        <div style="flex: 1; min-width: 0;">
          <div style="font-weight: 700; color: #fff; font-size: 14px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">${nickname}</div>
          <div style="font-size: 11px; color: rgba(255,255,255,0.4); font-family: monospace;">ID: ${nudgeId}</div>
        </div>
        <div style="text-align: right; flex-shrink: 0;">
          <div style="font-weight: 800; color: #f59e0b; font-size: 13px;">🪙${coins}</div>
        </div>
      </div>
    </div>
  `;

  if (profileContainer) {
    profileContainer.outerHTML = cardHtml;
  } else {
    panel.insertAdjacentHTML('afterbegin', cardHtml);
  }
}

function listenToUser(userId) {
  if (!db) return;
  db.collection("users").doc(userId).onSnapshot((docSnap) => {
    if (!docSnap.exists) return;
    const data = docSnap.data();
    
    updateSidebarProfile(data);
    
    const dailySummaries = data.dailySummaries || [];
    const tasks = data.tasks || [];
    
    if (dailySummaries.length > 0) {
      const scores = dailySummaries.map(s => s.disciplineScore || 0);
      const sleepHours = dailySummaries.map(s => s.sleepHours || 0);
      
      const trendChart = $("#trendChart");
      if (trendChart && scores.length > 0) {
        drawLineChart(trendChart, scores.slice(-12));
      }
      
      const sleepChart = $("#sleepChart");
      if (sleepChart && sleepHours.length > 0) {
        drawLineChart(sleepChart, sleepHours.slice(-7), "#8d7aff");
      }
    }
    
    if (tasks.length > 0) {
      const completedCount = tasks.filter(t => t.done || t.isDone).length;
      const completionRate = Math.round((completedCount / tasks.length) * 100);
      const chipA = $(".chip-a strong");
      if (chipA) {
        chipA.dataset.count = completionRate;
        chipA.textContent = `${completionRate}%`;
      }
    }

    if (document.body.dataset.page === "planet") {
      const todaySummary = dailySummaries[dailySummaries.length - 1] || {};
      const completedCount = tasks.filter(t => t.done || t.isDone).length;
      const syncData = {
        completedTasks: completedCount || 3,
        focusMinutes: todaySummary.focusMinutes || (data.focusSeconds ? Math.floor(data.focusSeconds/60) : 40),
        sleepHours: todaySummary.sleepHours || 7.0,
        activeFriendsCount: data.friends ? data.friends.length : 2
      };
      if (typeof update3DPlanet === 'function') {
        update3DPlanet(syncData);
      }
    }
  });
}

function updateTextContent(selector, text) {
  const node = $(selector);
  if (node) node.textContent = text;
}

let activePlanetScene = null;
let update3DPlanetFn = null;

function update3DPlanet(data) {
  if (typeof update3DPlanetFn === 'function') {
    update3DPlanetFn(data);
  }
}

function init3DPlanet() {
  const container = document.getElementById("planetCanvasContainer");
  if (!container) return;

  const width = container.clientWidth;
  const height = container.clientHeight;

  // Scene, Camera, Renderer
  const scene = new THREE.Scene();
  scene.fog = new THREE.FogExp2(0x050608, 0.015);

  const camera = new THREE.PerspectiveCamera(45, width / height, 0.1, 1000);
  camera.position.set(0, 0, 15);

  const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
  renderer.setSize(width, height);
  renderer.setPixelRatio(window.devicePixelRatio);
  renderer.shadowMap.enabled = true;
  container.appendChild(renderer.domElement);

  // Controls
  const controls = new THREE.OrbitControls(camera, renderer.domElement);
  controls.enableDamping = true;
  controls.dampingFactor = 0.05;
  controls.minDistance = 6;
  controls.maxDistance = 25;

  // Lights
  const ambientLight = new THREE.AmbientLight(0xffffff, 0.35);
  scene.add(ambientLight);

  const dirLight = new THREE.DirectionalLight(0xffffff, 0.95);
  dirLight.position.set(5, 10, 7);
  dirLight.castShadow = true;
  scene.add(dirLight);

  // Planet Base (Purple sphere representing Nudge)
  const planetRadius = 3.5;
  const planetGeo = new THREE.SphereGeometry(planetRadius, 32, 32);
  const planetMat = new THREE.MeshPhongMaterial({
    color: 0x7c6ae6,
    emissive: 0x1a153b,
    shininess: 25,
    flatShading: true
  });
  const planet = new THREE.Mesh(planetGeo, planetMat);
  planet.receiveShadow = true;
  scene.add(planet);

  // Continents (smaller overlay panels)
  const continentMat = new THREE.MeshPhongMaterial({
    color: 0x5a48c4,
    shininess: 5,
    flatShading: true
  });
  const continentCount = 6;
  for (let i = 0; i < continentCount; i++) {
    const size = 1.2 + Math.random() * 1.6;
    const contGeo = new THREE.BoxGeometry(size, size, 0.4);
    const cont = new THREE.Mesh(contGeo, continentMat);
    // Position on sphere surface
    const u = Math.random();
    const v = Math.random();
    const theta = u * 2.0 * Math.PI;
    const phi = Math.acos(2.0 * v - 1.0);
    cont.position.set(
      planetRadius * Math.sin(phi) * Math.cos(theta),
      planetRadius * Math.sin(phi) * Math.sin(theta),
      planetRadius * Math.cos(phi)
    );
    cont.lookAt(0, 0, 0);
    planet.add(cont);
  }

  // Starfield
  const starGeo = new THREE.BufferGeometry();
  const starCount = 500;
  const starPositions = new Float32Array(starCount * 3);
  for (let i = 0; i < starCount * 3; i += 3) {
    const dist = 30 + Math.random() * 40;
    const u = Math.random();
    const v = Math.random();
    const theta = u * 2.0 * Math.PI;
    const phi = Math.acos(2.0 * v - 1.0);
    starPositions[i] = dist * Math.sin(phi) * Math.cos(theta);
    starPositions[i+1] = dist * Math.sin(phi) * Math.sin(theta);
    starPositions[i+2] = dist * Math.cos(phi);
  }
  starGeo.setAttribute('position', new THREE.BufferAttribute(starPositions, 3));
  const starMat = new THREE.PointsMaterial({
    color: 0xffffff,
    size: 0.22,
    transparent: true,
    opacity: 0.8
  });
  const starfield = new THREE.Points(starGeo, starMat);
  scene.add(starfield);

  // Group to hold spawned buildings/assets on the planet
  const assetGroup = new THREE.Group();
  planet.add(assetGroup);

  // Helper to convert lat/lon to Cartesian position on planet surface
  function getPositionOnPlanet(lat, lon, heightOffset = 0) {
    const phi = (90 - lat) * (Math.PI / 180);
    const theta = (lon + 180) * (Math.PI / 180);
    const r = planetRadius + heightOffset;
    return new THREE.Vector3(
      r * Math.sin(phi) * Math.cos(theta),
      r * Math.cos(phi),
      r * Math.sin(phi) * Math.sin(theta)
    );
  }

  // Spawning systems
  function clearAssets() {
    while (assetGroup.children.length > 0) {
      assetGroup.remove(assetGroup.children[0]);
    }
  }

  function spawnTree(lat, lon) {
    const tree = new THREE.Group();
    // Trunk
    const trunkGeo = new THREE.CylinderGeometry(0.04, 0.06, 0.35, 6);
    const trunkMat = new THREE.MeshPhongMaterial({ color: 0x5c4033 });
    const trunk = new THREE.Mesh(trunkGeo, trunkMat);
    trunk.position.y = 0.15;
    tree.add(trunk);

    // Leaves
    const leavesGeo = new THREE.ConeGeometry(0.2, 0.5, 6);
    const leavesMat = new THREE.MeshPhongMaterial({ color: 0x10B981 });
    const leaves = new THREE.Mesh(leavesGeo, leavesMat);
    leaves.position.y = 0.5;
    tree.add(leaves);

    const pos = getPositionOnPlanet(lat, lon);
    tree.position.copy(pos);
    tree.lookAt(new THREE.Vector3(0, 0, 0));
    tree.rotateX(Math.PI / 2);
    assetGroup.add(tree);
  }

  function spawnLibrary(lat, lon) {
    const library = new THREE.Group();
    // Base
    const baseGeo = new THREE.BoxGeometry(0.6, 0.5, 0.6);
    const baseMat = new THREE.MeshPhongMaterial({ color: 0x3B82F6 });
    const base = new THREE.Mesh(baseGeo, baseMat);
    base.position.y = 0.25;
    library.add(base);

    // Roof
    const roofGeo = new THREE.ConeGeometry(0.5, 0.35, 4);
    const roofMat = new THREE.MeshPhongMaterial({ color: 0xEF4444 });
    const roof = new THREE.Mesh(roofGeo, roofMat);
    roof.position.y = 0.6;
    roof.rotation.y = Math.PI / 4;
    library.add(roof);

    const pos = getPositionOnPlanet(lat, lon);
    library.position.copy(pos);
    library.lookAt(new THREE.Vector3(0, 0, 0));
    library.rotateX(Math.PI / 2);
    assetGroup.add(library);
  }

  function spawnStreetLight(lat, lon, isGlowing) {
    const lightGroup = new THREE.Group();
    const poleGeo = new THREE.CylinderGeometry(0.015, 0.015, 0.6, 4);
    const poleMat = new THREE.MeshPhongMaterial({ color: 0x4B5563 });
    const pole = new THREE.Mesh(poleGeo, poleMat);
    pole.position.y = 0.3;
    lightGroup.add(pole);

    const bulbGeo = new THREE.SphereGeometry(0.06, 8, 8);
    const bulbMat = new THREE.MeshBasicMaterial({ color: isGlowing ? 0xFBBF24 : 0x9CA3AF });
    const bulb = new THREE.Mesh(bulbGeo, bulbMat);
    bulb.position.y = 0.6;
    lightGroup.add(bulb);

    if (isGlowing) {
      const glow = new THREE.PointLight(0xFBBF24, 1.5, 3);
      glow.position.set(0, 0.6, 0);
      lightGroup.add(glow);
    }

    const pos = getPositionOnPlanet(lat, lon);
    lightGroup.position.copy(pos);
    lightGroup.lookAt(new THREE.Vector3(0, 0, 0));
    lightGroup.rotateX(Math.PI / 2);
    assetGroup.add(lightGroup);
  }

  function spawnFriendAvatar(lat, lon) {
    const avatar = new THREE.Group();
    const headGeo = new THREE.SphereGeometry(0.14, 8, 8);
    const headMat = new THREE.MeshPhongMaterial({ color: 0xFDBA74 });
    const head = new THREE.Mesh(headGeo, headMat);
    head.position.y = 0.4;
    avatar.add(head);

    const bodyGeo = new THREE.CylinderGeometry(0.02, 0.12, 0.3, 8);
    const bodyMat = new THREE.MeshPhongMaterial({ color: 0x8B5CF6 });
    const body = new THREE.Mesh(bodyGeo, bodyMat);
    body.position.y = 0.15;
    avatar.add(body);

    const pos = getPositionOnPlanet(lat, lon);
    avatar.position.copy(pos);
    avatar.lookAt(new THREE.Vector3(0, 0, 0));
    avatar.rotateX(Math.PI / 2);
    assetGroup.add(avatar);
  }

  update3DPlanetFn = function(data) {
    clearAssets();

    // Spawn Trees based on completedTasks
    const completedTasks = data.completedTasks || 0;
    const treeCount = Math.min(completedTasks * 3, 24);
    for (let i = 0; i < treeCount; i++) {
      const lat = -65 + (i * 137.5) % 130;
      const lon = -180 + (i * 222.5) % 360;
      spawnTree(lat, lon);
    }

    // Spawn Libraries based on focusMinutes
    const focusMinutes = data.focusMinutes || 0;
    const libCount = Math.min(Math.floor(focusMinutes / 20), 6);
    for (let i = 0; i < libCount; i++) {
      const lat = -35 + (i * 117.5) % 70;
      const lon = -160 + (i * 197.5) % 320;
      spawnLibrary(lat, lon);
    }

    // Spawn Street Lights based on sleepHours
    const sleepHours = data.sleepHours || 0;
    const lightCount = Math.min(Math.floor(sleepHours), 8);
    const isGlowing = sleepHours >= 6.5;
    for (let i = 0; i < lightCount; i++) {
      const lat = -50 + (i * 97.5) % 100;
      const lon = -170 + (i * 187.5) % 340;
      spawnStreetLight(lat, lon, isGlowing);
    }

    // Spawn Friend avatars
    const friendsCount = data.activeFriendsCount || 2;
    for (let i = 0; i < friendsCount; i++) {
      const lat = -25 + (i * 77.5) % 50;
      const lon = -140 + (i * 167.5) % 280;
      spawnFriendAvatar(lat, lon);
    }

    // Update Prosperity in HUD
    const prosperity = (completedTasks * 8) + (focusMinutes * 2) + Math.round(sleepHours * 5);
    const hud = document.getElementById("planetHud");
    if (hud) hud.textContent = "已連動 - 星球繁榮度 " + Math.max(prosperity, 10);
    const label = document.getElementById("planetLabel");
    if (label) label.textContent = "自律星球 (繁榮度: " + Math.max(prosperity, 10) + ")";
  };

  // Seed default display
  update3DPlanet({
    completedTasks: 4,
    focusMinutes: 45,
    sleepHours: 7.5,
    activeFriendsCount: 2
  });

  // Animation Loop
  let reqId;
  function animate() {
    reqId = requestAnimationFrame(animate);
    planet.rotation.y += 0.0018;
    planet.rotation.x += 0.0003;
    starfield.rotation.y -= 0.0003;
    controls.update();
    renderer.render(scene, camera);
  }
  animate();

  function handleResize() {
    const w = container.clientWidth;
    const h = container.clientHeight;
    camera.aspect = w / h;
    camera.updateProjectionMatrix();
    renderer.setSize(w, h);
  }
  window.addEventListener("resize", handleResize);

  // Auto clean up
  const observer = new MutationObserver(() => {
    if (!document.body.contains(container)) {
      cancelAnimationFrame(reqId);
      window.removeEventListener("resize", handleResize);
      renderer.dispose();
      observer.disconnect();
    }
  });
  observer.observe(document.body, { childList: true, subtree: true });
}
