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
  bindTilt();
  bindPresentation();
});

window.addEventListener("resize", bootCharts);
