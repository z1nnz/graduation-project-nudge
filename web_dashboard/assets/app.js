const $ = (selector, root = document) => root.querySelector(selector);
const $$ = (selector, root = document) => Array.from(root.querySelectorAll(selector));

const modules = [
  ["home", "總覽入口", "index.html"],
  ["personal", "個人進階分析", "personal.html"],
  ["guardian", "家長陪伴中心", "guardian.html"],
  ["groups", "團體 / 教育管理", "groups.html"],
  ["operations", "商城頁", "operations.html"],
  ["research", "研究中心", "research.html"],
  ["friend", "好友功能", "friend.html"],
  ["planet", "自律星球", "planet.html"],
  ["presentation", "專題發表流程", "presentation.html"],
];

// Authentication Check
const pathName = window.location.pathname;
const isPublicPage = pathName.endsWith("/") || pathName.endsWith("index.html") || pathName.endsWith("login.html") || pathName.includes("admin_dashboard.html");
if (!isPublicPage && localStorage.getItem("nudgeWebLoggedIn") !== "true") {
  window.location.href = "login.html";
}


function injectModuleMenu() {
  if (window.location.pathname.includes('admin_dashboard.html')) return;
  const sidebar = $(".sidebar");
  if (!sidebar) return;
  
  const nav = sidebar.querySelector(".nav");
  if (!nav) return;
  
  // Determine active category based on URL
  let activeKey = "home";
  const path = window.location.pathname;
  for (const [key, label, href] of modules) {
    if (path.includes(key) || path.includes(href)) {
      activeKey = key;
    }
  }
  if (path.endsWith("/") || path.includes("index.html")) {
    activeKey = "home";
  }

  // Populate navigation dynamically
  nav.innerHTML = modules
    .map(([key, label, href]) => `<a href="${href}" class="${key === activeKey ? 'active' : ''}">${label}</a>`)
    .join("");

  // 登出按鈕邏輯：如果目前是登入狀態，就在選單最後面加入「登出」按鈕
  if (localStorage.getItem("nudgeWebLoggedIn") === "true") {
    const logoutBtn = document.createElement("a");
    logoutBtn.href = "#";
    logoutBtn.style.marginTop = "16px";
    logoutBtn.style.color = "var(--red)"; // 使用現有的紅色彩色變數
    logoutBtn.innerHTML = "<span>🚪</span> 登出帳號";
    logoutBtn.addEventListener("click", (e) => {
      e.preventDefault();
      localStorage.removeItem("nudgeWebLoggedIn");
      localStorage.removeItem("nudgeActiveDemoUserId");
      
      if (typeof firebase !== 'undefined' && firebase.auth) {
        firebase.auth().signOut().then(() => {
          window.location.href = "index.html"; // 登出後回到總覽頁面
        }).catch(err => {
          console.error("Firebase sign out failed:", err);
          window.location.href = "index.html";
        });
      } else {
        window.location.href = "index.html";
      }
    });
    nav.appendChild(logoutBtn);
  } else {
    // 若未登入，也可選擇顯示「登入」按鈕
    const loginBtn = document.createElement("a");
    loginBtn.href = "login.html";
    loginBtn.style.marginTop = "16px";
    loginBtn.style.color = "var(--page-accent)";
    loginBtn.innerHTML = "<span>👤</span> 登入 / 註冊";
    nav.appendChild(loginBtn);
  }

  // Remove the old drop-down module switcher if it exists
  const switcher = $(".module-switcher");
  if (switcher) switcher.remove();
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
  // Simple hack to get a semi-transparent version of the color (if it's hex)
  gradient.addColorStop(0, color === "#22c7bb" ? "rgba(34,199,187,0.4)" : color === "#8d7aff" ? "rgba(141,122,255,0.4)" : "rgba(93,140,255,0.4)");
  gradient.addColorStop(1, "rgba(0,0,0,0)");

  // Draw Filled Area
  ctx.beginPath();
  values.forEach((value, i) => {
    const x = pad + i * step;
    const y = toY(value);
    if (i === 0) {
      ctx.moveTo(x, y);
    } else {
      const prevX = pad + (i - 1) * step;
      const prevY = toY(values[i - 1]);
      const cpX = (prevX + x) / 2;
      ctx.bezierCurveTo(cpX, prevY, cpX, y, x, y);
    }
  });
  ctx.lineTo(rect.width - pad, rect.height - pad);
  ctx.lineTo(pad, rect.height - pad);
  ctx.closePath();
  ctx.fillStyle = gradient;
  ctx.fill();

  // Draw Neon Line
  ctx.beginPath();
  values.forEach((value, i) => {
    const x = pad + i * step;
    const y = toY(value);
    if (i === 0) {
      ctx.moveTo(x, y);
    } else {
      const prevX = pad + (i - 1) * step;
      const prevY = toY(values[i - 1]);
      const cpX = (prevX + x) / 2;
      ctx.bezierCurveTo(cpX, prevY, cpX, y, x, y);
    }
  });
  ctx.strokeStyle = color;
  ctx.lineWidth = 4;
  ctx.lineCap = "round";
  ctx.lineJoin = "round";
  ctx.shadowColor = color;
  ctx.shadowBlur = 12;
  ctx.stroke();
  
  // Reset shadow for points
  ctx.shadowBlur = 0;

  // Draw Data Points
  values.forEach((value, i) => {
    const x = pad + i * step;
    const y = toY(value);
    
    // Outer glow dot
    ctx.beginPath();
    ctx.arc(x, y, 6, 0, Math.PI * 2);
    ctx.fillStyle = color;
    ctx.fill();

    // Inner white dot
    ctx.beginPath();
    ctx.arc(x, y, 3, 0, Math.PI * 2);
    ctx.fillStyle = "#fff";
    ctx.fill();
    
    // Values text (only for every other point or if few points to avoid clutter)
    if (values.length <= 10 || i % 2 === 0 || i === values.length - 1) {
      ctx.fillStyle = "#fff";
      ctx.font = "11px system-ui";
      ctx.textAlign = "center";
      ctx.fillText(value, x, y - 12);
    }
  });
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
  const radius = Math.min(rect.width, rect.height) * 0.32;
  const total = values.reduce((a, b) => a + b, 0);
  let start = -Math.PI / 2;
  const gap = 0.08; // gap between segments
  
  values.forEach((value, index) => {
    const angle = (value / total) * Math.PI * 2;
    ctx.beginPath();
    ctx.arc(cx, cy, radius, start + gap/2, start + angle - gap/2);
    ctx.lineWidth = 20;
    ctx.lineCap = "round";
    ctx.strokeStyle = colors[index];
    
    // Add glowing effect
    ctx.shadowColor = colors[index];
    ctx.shadowBlur = 12;
    
    ctx.stroke();
    // Reset shadow for next draw to avoid compounding issues
    ctx.shadowBlur = 0;
    start += angle;
  });

  // Center text
  ctx.fillStyle = "#ffffff";
  ctx.font = "800 36px 'Inter', system-ui";
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.fillText(`${total}`, cx, cy - 8);
  
  ctx.fillStyle = "rgba(255, 255, 255, 0.5)";
  ctx.font = "600 14px 'Inter', system-ui";
  ctx.fillText("總樣本", cx, cy + 20);
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

  const viewButtons = $$("[data-view]");
  const solarView = $(".view-solar-system");
  const cityView = $(".view-city");
  const hudDesc = $("#hudDesc");
  
  // New elements for text swapping
  const hudTitle = $("#hudTitle");
  const planetHud = $("#planetHud");
  const navSolar = $("#navSolar");
  const navGalaxy = $("#navGalaxy");
  const navUniverse = $("#navUniverse");

  viewButtons.forEach((button) => {
    button.addEventListener("click", () => {
      viewButtons.forEach((b) => b.classList.remove("active"));
      button.classList.add("active");
      const view = button.dataset.view;
      if (view === 'solar-system') {
        if (solarView) solarView.style.display = 'block';
        if (hudDesc) hudDesc.textContent = "任務完成會即時點亮星星與軌道";
        if (hudTitle) hudTitle.textContent = "COSMIC EVOLUTION";
        if (planetHud) planetHud.textContent = "太陽系";
        if (navSolar) navSolar.textContent = "太陽系";
        if (navGalaxy) navGalaxy.textContent = "銀河系";
        if (navUniverse) navUniverse.textContent = "宇宙";
      }
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
  
  // Sync to Firestore if user logged in
  const activeUserId = localStorage.getItem("nudgeActiveDemoUserId");
  if (activeUserId && typeof db !== 'undefined' && db) {
    db.collection("users").doc(activeUserId).update({
      [`webToolsState.${key}`]: current[key]
    }).catch(e => console.warn("Firestore update error:", e));

    // Guardian mode: write to child's document too
    if (window.linkedChildUid) {
      db.collection("users").doc(window.linkedChildUid).update({
        [`webToolsState.${key}`]: current[key]
      }).catch(e => console.warn("Child Firestore update error:", e));
    }
  }
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
    templateText = `${type} ${days} 日任務規劃\n每日投入：${effort}\n策略：${phase}\n\nDay 1：整理目標與資料\nDay ${Math.ceil(days / 2)}：完成主要進度\nDay ${days}：回顧、補強與提交`;
    setOutput(
      templateTool,
      `<strong>${type} ${days} 日模板</strong><p>每日 ${effort}，${phase}。已產生可匯入 App 的分段任務草稿。</p>`,
    );
    saveDemoState("template", { type, days, effort, pressure });
    toast("已產生任務規劃");
  });
  templateTool?.querySelector('[data-action="download-template"]')?.addEventListener("click", () => {
    downloadTextFile("nudge-task-template.txt", templateText || "請先產生任務規劃。");
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
      `<span class="card-icon">🎁</span><div class="card-content"><strong>${name}：${rarity} / ${price} 枚</strong><p>${days} 天活動，${health}。以每日 15 枚、每月 400 枚上限估算，兌換壓力合理。</p></div>`,
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
      `<span class="card-icon">📝</span><div class="card-content"><strong>${type}</strong><p>${privacy}。展示順序：App 狀態 → Web 分析 → 自律星球視覺化 → 研究價值結論。</p></div>`,
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

  const renderSavedList = (selector, key, fallback) => {
    const list = $(selector);
    if (!list) return;
    const store = JSON.parse(localStorage.getItem("nudgeWebTools") || "{}");
    const items = store[key] || [];
    
    if (!items.length) {
      list.innerHTML = fallback;
      return;
    }
    list.innerHTML = items
      .map((item, index) => `
        <article style="position: relative;">
          <strong>${item.title}</strong>
          <span>${item.meta}</span>
          <button class="delete-btn" data-key="${key}" data-index="${index}" style="position: absolute; right: 10px; top: 10px; background: transparent; border: none; color: #ff3b3b; cursor: pointer; font-family: monospace;">[刪除]</button>
        </article>
      `)
      .join("");
  };
  window.renderSavedList = renderSavedList;

  // Delegate delete events globally
  document.body.addEventListener("click", (e) => {
    if (e.target.matches(".delete-btn")) {
      const key = e.target.dataset.key;
      const index = parseInt(e.target.dataset.index, 10);
      const store = JSON.parse(localStorage.getItem("nudgeWebTools") || "{}");
      if (store[key]) {
        store[key].splice(index, 1);
        saveToolCollection(key, store[key]);
        // Re-render the specific list based on the key
        let selector, fallback;
        if (key === "capsules") { selector = "[data-capsule-list]"; fallback = "<article><strong>尚未保存</strong><span>建立第一個時間膠囊後會出現在這裡。</span></article>"; }
        else if (key === "encouragements") { selector = "[data-encourage-list]"; fallback = "<article><strong>尚未送出</strong><span>送出鼓勵卡後會出現在這裡。</span></article>"; }
        else if (key === "studySchedules") { selector = "[data-study-list]"; fallback = "<article><strong>尚未排程</strong><span>新增讀書時段後會出現在這裡。</span></article>"; }
        if (selector) renderSavedList(selector, key, fallback);
      }
    }
  });

  const savedTools = JSON.parse(localStorage.getItem("nudgeWebTools") || "{}");
  const saveToolCollection = (key, items) => {
    const current = JSON.parse(localStorage.getItem("nudgeWebTools") || "{}");
    current[key] = items;
    current[`${key}UpdatedAt`] = new Date().toISOString();
    localStorage.setItem("nudgeWebTools", JSON.stringify(current));
    
    // Sync to Firestore if user logged in
    const activeUserId = localStorage.getItem("nudgeActiveDemoUserId");
    if (activeUserId && typeof db !== 'undefined' && db) {
      db.collection("users").doc(activeUserId).update({
        [`webToolsCollection.${key}`]: items,
        [`webToolsCollection.${key}UpdatedAt`]: current[`${key}UpdatedAt`]
      }).catch(e => console.warn("Firestore update error:", e));

      // Guardian mode: write to child's document too
      if (window.linkedChildUid) {
        db.collection("users").doc(window.linkedChildUid).update({
          [`webToolsCollection.${key}`]: items,
          [`webToolsCollection.${key}UpdatedAt`]: current[`${key}UpdatedAt`]
        }).catch(e => console.warn("Child Firestore update error:", e));
      }
    }
  };
  
  renderSavedList("[data-capsule-list]", "capsules", "<article><strong>尚未保存</strong><span>建立第一個時間膠囊後會出現在這裡。</span></article>");
  renderSavedList("[data-encourage-list]", "encouragements", "<article><strong>尚未送出</strong><span>送出鼓勵卡後會出現在這裡。</span></article>");
  renderSavedList("[data-study-list]", "studySchedules", "<article><strong>尚未排程</strong><span>新增讀書時段後會出現在這裡。</span></article>");

  let capsuleText = "";
  capsuleTool?.querySelector('[data-action="save-capsule"]')?.addEventListener("click", (e) => {
    const title = $('[data-capsule-title]', capsuleTool).value.trim() || "未命名時間膠囊";
    const date = $('[data-capsule-date]', capsuleTool).value || "未設定";
    const message = $('[data-capsule-message]', capsuleTool).value.trim();
    capsuleText = `${title}\n解鎖日：${date}\n\n${message}`;
    setOutput(capsuleTool, `<strong>${title}</strong><p>將於 ${date} 解鎖。內容已保存到 Demo localStorage。</p>`);
    const store = JSON.parse(localStorage.getItem("nudgeWebTools") || "{}");
    const capsules = store.capsules || [];
    capsules.unshift({ title, meta: `${date} 解鎖`, message });
    saveToolCollection("capsules", capsules.slice(0, 50));

    // Elf Capsule Throw Animation
    const btn = e.currentTarget;
    const targetEl = $("[data-capsule-list]");
    if (btn && targetEl) {
      const rect = btn.getBoundingClientRect();
      const targetRect = targetEl.getBoundingClientRect();
      const startX = rect.left + rect.width / 2;
      const startY = rect.top + rect.height / 2;
      const endX = targetRect.left + targetRect.width / 2;
      const endY = targetRect.top + targetRect.height / 2;

      const capsule = document.createElement("div");
      capsule.className = "elf-capsule";
      capsule.style.left = startX - 12 + "px";
      capsule.style.top = startY - 12 + "px";
      document.body.appendChild(capsule);

      // Animate throwing arc
      const duration = 600;
      const startTime = performance.now();
      
      const animateThrow = (now) => {
        const elapsed = now - startTime;
        let progress = elapsed / duration;
        if (progress > 1) progress = 1;

        // Quadratic bezier arc
        const controlX = startX + (endX - startX) / 2;
        const controlY = Math.min(startY, endY) - 200;

        const x = (1 - progress) * (1 - progress) * startX + 2 * (1 - progress) * progress * controlX + progress * progress * endX;
        const y = (1 - progress) * (1 - progress) * startY + 2 * (1 - progress) * progress * controlY + progress * progress * endY;
        
        capsule.style.transform = `translate(${x - startX}px, ${y - startY}px) rotate(${progress * 720}deg)`;

        if (progress < 1) {
          requestAnimationFrame(animateThrow);
        } else {
          // Burst effect
          const burst = document.createElement("div");
          burst.className = "capsule-burst";
          burst.style.left = endX + "px";
          burst.style.top = endY + "px";
          document.body.appendChild(burst);
          
          setTimeout(() => burst.remove(), 400);
          capsule.remove();
          
          renderSavedList("[data-capsule-list]", "capsules", "<article><strong>尚未保存</strong><span>建立第一個時間膠囊後會出現在這裡。</span></article>");
          toast("時間膠囊已保存");
        }
      };
      requestAnimationFrame(animateThrow);
    } else {
      renderSavedList("[data-capsule-list]", "capsules", "<article><strong>尚未保存</strong><span>建立第一個時間膠囊後會出現在這裡。</span></article>");
      toast("時間膠囊已保存");
    }
  });
  capsuleTool?.querySelector('[data-action="download-capsule"]')?.addEventListener("click", () => {
    downloadTextFile("nudge-time-capsule.txt", capsuleText || "請先保存時間膠囊。");
  });

  encouragementTool?.querySelector('[data-action="preview-encouragement"]')?.addEventListener("click", () => {
    toast("預覽：這是一張溫暖的鼓勵卡。");
  });
  encouragementTool?.querySelector('[data-action="send-encouragement"]')?.addEventListener("click", () => {
    const card = encouragementTool.querySelector('.generated-card');
    if (card) {
      card.classList.add("toss-animation");
      setTimeout(() => {
        card.classList.remove("toss-animation");
      }, 400);
    }
    
    const tone = $('[data-encourage-tone]', encouragementTool)?.value || "溫暖支持";
    const type = $('[data-encourage-type]', encouragementTool)?.value || "貼圖";
    const msg = $('[data-encourage-message]', encouragementTool)?.value.trim() || "無內容";
    const store = JSON.parse(localStorage.getItem("nudgeWebTools") || "{}");
    const encouragements = store.encouragements || [];
    encouragements.unshift({ title: `${tone} ${type}`, meta: "已發送至孩子端", message: msg });
    saveToolCollection("encouragements", encouragements.slice(0, 50));
    
    setTimeout(() => {
      renderSavedList("[data-encourage-list]", "encouragements", "<article><strong>尚未送出</strong><span>送出鼓勵卡後會出現在這裡。</span></article>");
      toast("鼓勵卡已送出 Demo");
    }, 300);
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
    saveToolCollection("studySchedules", studySchedules.slice(0, 50));
    renderSavedList("[data-study-list]", "studySchedules", "<article><strong>尚未排程</strong><span>新增讀書時段後會出現在這裡。</span></article>");
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
      "最後用自律星球把整個系統收起來：專注任務蓋圖書館、健康任務蓋公園、睡眠點亮住宅區、自律房出現朋友角色。這讓抽象分數變成看得見的世界。",
    items: [
      ["可視化成果", "任務成果變成建築與星球成長。"],
      ["社交展示", "朋友角色可以共同建設星球。"],
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

function injectAINavigator() {
  const container = document.createElement("div");
  container.className = "ai-navigator";
  container.innerHTML = `
    <div class="ai-chat-panel" id="aiChatPanel">
      <div class="ai-chat-header">
        <div class="ai-header-title">艦載 AI 導航助手</div>
        <div>
          <button class="ai-close-btn" id="aiCloseBtn">✕</button>
        </div>
      </div>

      <div class="ai-chat-body" id="aiChatBody">
        <div class="ai-msg">您好！艦長。我是您的自律宇宙導航助手，已成功連線至中樞神經，有什麼我可以幫您的嗎？</div>
      </div>
      <div class="ai-chat-input">
        <input type="text" placeholder="輸入指令..." id="aiInput" />
        <button id="aiSend">發送</button>
      </div>
    </div>
    <div class="ai-orb" id="aiOrb">
      <div class="ai-orb-core"></div>
    </div>
  `;
  document.body.appendChild(container);

  const orb = $("#aiOrb", container);
  const panel = $("#aiChatPanel", container);
  const closeBtn = $("#aiCloseBtn", container);
  const input = $("#aiInput", container);
  const send = $("#aiSend", container);
  const body = $("#aiChatBody", container);

  orb.addEventListener("click", () => {
    panel.classList.toggle("open");
  });

  closeBtn.addEventListener("click", () => {
    panel.classList.remove("open");
  });

  const sendMsg = async () => {
    const text = input.value.trim();
    if (!text) return;

    body.innerHTML += `<div class="ai-msg user">${text}</div>`;
    input.value = "";
    body.scrollTop = body.scrollHeight;
    
    const loadingId = "msg-" + Date.now();
    body.innerHTML += `<div class="ai-msg" id="${loadingId}">[ 系統讀取中... 與中樞神經連線中 ]</div>`;
    body.scrollTop = body.scrollHeight;

    const tasksContext = (currentUserTasks && currentUserTasks.length > 0)
      ? `目前艦長（使用者）的自律任務列表如下：\n` + currentUserTasks.map(t => `- 任務名稱: "${t.title}" (ID: ${t.id}, 狀態: ${t.isDone || t.done ? '已完成' : '未完成'})`).join('\n')
      : `目前無活躍任務。`;

    const summariesContext = (currentUserDailySummaries && currentUserDailySummaries.length > 0)
      ? `近期每日自律數據摘要如下：\n` + currentUserDailySummaries.slice(-5).map(s => `- 日期: ${s.date}, 步數: ${s.steps}, 睡眠: ${s.sleepHours}小時, 專注: ${s.focusMinutes}分鐘, 完成任務: ${s.completedTasks}/${s.totalTasks}`).join('\n')
      : `無近期數據。`;

    const systemText = `你是一個名為 Nudge 的科幻太空船艦載 AI 助手，同時也是溫和且專業的「Nudge 自律導師」。你負責協助艦長（使用者）進行時間管理與自律任務。你的語氣要像科幻電影中的 AI（冷靜、聰明、帶點科技感），稱呼使用者為艦長。回答要簡潔有力，不要給出落落長的文章。
如果使用者要求開始專注、倒數計時，請加上：[ACTION:START_FOCUS:分鐘數]
如果使用者要求新增任務，請加上：[ACTION:ADD_TASK:任務名稱]
如果使用者要求前往某個頁面(例如總覽、家長中心、營運後台等)，請加上：[ACTION:NAVIGATE:該頁面網址.html] (頁面包含: index.html, personal.html, guardian.html, groups.html, operations.html, planet.html, friend.html)。
如果使用者說他完成了某個任務，或者要求你幫他完成（例如「我完成了準備期中報告的任務」、「我剛剛去跑步了」，或者「幫我完成看書任務」），請在回覆中包含：[ACTION:COMPLETE_TASK:任務ID]。請務必使用對應任務的 ID。

${tasksContext}

${summariesContext}

如果使用者問你怎麼用，請以繁體中文簡要介紹：左側是導航面板，中間是數據儀表板，下方是專屬星球，每天完成任務可以發射衛星環繞星球，右下角可以點擊小球召喚我為您導航。`;

    try {
      const apiHost = window.location.protocol === 'file:' ? 'http://127.0.0.1:5001' : '';
      const response = await fetch(`${apiHost}/api/chat`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          systemInstruction: {
            parts: [{ text: systemText }]
          },
          contents: [{ parts: [{ text: text }] }]
        })
      });

      const loadingMsg = document.getElementById(loadingId);
      if (!response.ok) {
        const errData = await response.json().catch(() => ({}));
        throw new Error(errData.error || "API 請求失敗：" + response.status);
      }

      const data = await response.json();
      let reply = data.candidates[0].content.parts[0].text;
      
      const focusMatch = reply.match(/\[ACTION:START_FOCUS:(\d+)\]/);
      if (focusMatch) {
        reply = reply.replace(focusMatch[0], '');
        setTimeout(() => {
          window.location.href = `personal-focus.html?start=true&focus=${focusMatch[1]}`;
        }, 1500);
      }

      const taskMatch = reply.match(/\[ACTION:ADD_TASK:(.+)\]/);
      if (taskMatch) {
        reply = reply.replace(taskMatch[0], '');
        const taskTitle = taskMatch[1].trim();
        if (typeof db !== 'undefined' && db) {
          addFirestoreTask(taskTitle);
        } else {
          const tasks = JSON.parse(localStorage.getItem('nudge_tasks') || '[]');
          tasks.push(taskTitle);
          localStorage.setItem('nudge_tasks', JSON.stringify(tasks));
          if (window.bindMissions) {
            window.bindMissions(); // re-render if on planet page
          }
        }
      }

      const completeMatch = reply.match(/\[ACTION:COMPLETE_TASK:(.+)\]/);
      if (completeMatch) {
        reply = reply.replace(completeMatch[0], '');
        const taskId = completeMatch[1].trim();
        if (typeof db !== 'undefined' && db) {
          completeFirestoreTask(taskId);
        }
      }

      const navMatch = reply.match(/\[ACTION:NAVIGATE:([a-zA-Z0-9_-]+\.html)\]/);
      if (navMatch) {
        reply = reply.replace(navMatch[0], '');
        setTimeout(() => {
          window.location.href = navMatch[1];
        }, 1500);
      }

      if (loadingMsg) {
        loadingMsg.innerHTML = reply.trim().replace(/\n/g, '<br/>');
        loadingMsg.removeAttribute('id');
      }
    } catch (error) {
      const loadingMsg = document.getElementById(loadingId);
      if (loadingMsg) {
        loadingMsg.innerHTML = `連線錯誤：${error.message}。請確認您的 API 金鑰是否正確。`;
        loadingMsg.style.color = '#ff3333';
        loadingMsg.removeAttribute('id');
      }
    }
    body.scrollTop = body.scrollHeight;
  };

  send.addEventListener("click", sendMsg);
  input.addEventListener("keypress", (e) => {
    if (e.key === "Enter") sendMsg();
  });
}

window.bindMissions = function() {
  const list = document.getElementById("dynamicMissionList");
  if (!list) return; // Not on planet page
  
  const defaultTasks = [
    "完成 2 小時讀書",
    "步行超過 6000 步",
    "運動 30 分鐘",
    "晚上 11:30 前睡覺",
    "準備期中報告"
  ];
  const tasks = JSON.parse(localStorage.getItem('nudge_tasks')) || defaultTasks;
  // Initialize default if empty in localStorage just for the first time
  if (!localStorage.getItem('nudge_tasks')) {
    localStorage.setItem('nudge_tasks', JSON.stringify(tasks));
  }

  list.innerHTML = "";
  tasks.slice(0, 36).forEach((task, index) => {
    const sId = "s" + (index + 1);
    
    // Classify task type
    let taskType = "general";
    if (/(專案|期末|大考|挑戰)/.test(task)) {
      taskType = "skyscraper";
    } else if (/(書|讀|作業|考試|專注|報告)/.test(task)) {
      taskType = "study";
    } else if (/(健康|水|睡|運動|步)/.test(task)) {
      taskType = "health";
    }

    list.innerHTML += `
      <li class="mission-item" data-id="${index}">
        <label>
          <input type="checkbox" class="mission-check" data-satellite="${sId}" data-task-type="${taskType}" />
          <span>${task}</span>
        </label>
        <div class="mission-meta">
          <div class="energy-bar-container">
            <div class="energy-bar" id="energy-${index}" style="width: 100%;"></div>
          </div>
          <div class="mission-actions">
            <button class="cyber-btn micro-split-btn">微型拆解</button>
            <button class="cyber-btn sos-btn bypass" style="display: none;">發送 SOS</button>
          </div>
        </div>
      </li>
    `;
  });

  // Bind Micro-split buttons
  $$('.micro-split-btn').forEach(btn => {
    btn.addEventListener('click', (e) => {
      const item = e.target.closest('.mission-item');
      const span = item.querySelector('span');
      const taskName = span.innerText;
      
      const ul = document.createElement('ul');
      ul.className = 'micro-steps';
      ul.innerHTML = `
        <li><label><input type="checkbox" class="micro-check"> 準備環境與文件</label></li>
        <li><label><input type="checkbox" class="micro-check"> 規劃大綱與步驟</label></li>
        <li><label><input type="checkbox" class="micro-check"> 專注執行 15 分鐘</label></li>
      `;
      span.innerHTML = `<strong>${taskName}</strong>`;
      span.appendChild(ul);
      e.target.style.display = 'none'; // hide split button
    });
  });

  // Bind SOS buttons
  $$('.sos-btn').forEach(btn => {
    btn.addEventListener('click', (e) => {
      btn.innerText = "求救信號已發出！";
      btn.style.color = "#0f0";
      btn.style.borderColor = "#0f0";
      btn.style.boxShadow = "inset 0 0 5px rgba(0, 255, 0, 0.2)";
      btn.disabled = true;
      
      // Remove critical glitch state since friend was notified
      const item = e.target.closest('.mission-item');
      item.classList.remove('critical-glitch');
      const idx = item.dataset.id;
      const sId = "s" + (parseInt(idx) + 1);
      const sat = $("." + sId);
      if (sat) sat.classList.remove('critical-glitch-planet');
      
      // Refill energy slightly
      const bar = item.querySelector('.energy-bar');
      if (bar) bar.style.width = '50%';
      bar.style.background = '#0f0';
    });
  });

  // Dev Trigger for Decay
  const devDecayBtn = document.getElementById("devDecayBtn");
  if (devDecayBtn) {
    devDecayBtn.addEventListener("click", (e) => {
      e.stopPropagation();
      // Find all unchecked mission items and drop their energy to critical
      $$('.mission-item').forEach(item => {
        const check = item.querySelector('.mission-check');
        if (check && check.checked) return; // Skip completed ones
        
        const bar = item.querySelector('.energy-bar');
        if (bar) {
          bar.style.width = '10%';
          bar.style.background = '#f00';
        }
        item.classList.add('critical-glitch');
        
        const sosBtn = item.querySelector('.sos-btn');
        if (sosBtn) sosBtn.style.display = 'inline-block';
        
        const idx = item.dataset.id;
        const sId = "s" + (parseInt(idx) + 1);
        const sat = $("." + sId);
        if (sat) sat.classList.add('critical-glitch-planet');
      });
    });
  }

  // Dev Cheat: Unlock everything with dramatic cascade
  const devCheatBtn = document.getElementById("devCheatBtn");
  if (devCheatBtn) {
    devCheatBtn.addEventListener("click", (e) => {
      e.stopPropagation();
      localStorage.removeItem('nudge_planet_states');
      localStorage.removeItem('nudge_auto_galaxy');
      localStorage.removeItem('nudge_auto_universe');
      planetStates = Array(36).fill(null);
      const allChecks = $$(".mission-check");
      allChecks.forEach(c => {
        if (c.checked) {
          c.checked = false;
          c.dispatchEvent(new Event('change'));
        }
      });
      const viewSolar = document.querySelector('.view-solar-system');
      const viewGalaxy = document.querySelector('.view-galaxy');
      const viewUniverse = document.querySelector('.view-universe');
      
      let startIdx = 0;
      let endIdx = 36;
      if (viewSolar && viewSolar.style.display !== 'none') {
        startIdx = 0;
        endIdx = 12;
      } else if (viewGalaxy && viewGalaxy.style.display !== 'none') {
        startIdx = 0;
        endIdx = 24;
      } else if (viewUniverse && viewUniverse.style.display !== 'none') {
        startIdx = 0;
        endIdx = 36;
      }
      
      let i = startIdx;
      const interval = setInterval(() => {
        if (i >= endIdx || i >= allChecks.length) {
          clearInterval(interval);
          return;
        }
        if (!allChecks[i].checked) {
          allChecks[i].checked = true;
          allChecks[i].dispatchEvent(new Event('change'));
        }
        i++;
      }, 50);
    });
  }

  // Direct cinematic test buttons
  const btnForceBlackhole = document.getElementById("btnForceBlackhole");
  if (btnForceBlackhole) {
    btnForceBlackhole.addEventListener("click", (e) => {
      e.stopPropagation();
      triggerBlackHoleSuction(true);
    });
  }

  const btnForceExplosion = document.getElementById("btnForceExplosion");
  if (btnForceExplosion) {
    btnForceExplosion.addEventListener("click", (e) => {
      e.stopPropagation();
      triggerUniverseExplosion(true);
    });
  }

  // Toggle Panel Logic (Orb System)
  const orbBtn = document.getElementById("missionOrbBtn");
  const logPanel = document.getElementById("missionLogPanel");
  if (orbBtn && logPanel) {
    orbBtn.addEventListener("click", () => {
      logPanel.classList.toggle("active");
    });
  }

  const checks = $$(".mission-check");
  let currentCombo = 0;
  const comboContainer = $("#comboContainer");

  let planetStates = JSON.parse(localStorage.getItem('nudge_planet_states')) || Array(36).fill(null);

  // Position galaxy planets on their orbits (4 planets per orbit)
  const galaxyPlanets = document.querySelectorAll('.galaxy-planet');
  galaxyPlanets.forEach((p, i) => {
    const angle = (i % 4) * 90 * (Math.PI / 180); // 0, 90, 180, 270 degrees
    p.style.left = `calc(50% + ${Math.cos(angle) * 50}%)`;
    p.style.top = `calc(50% + ${Math.sin(angle) * 50}%)`;
  });

  // Position universe planets on their orbits (3 planets per orbit)
  const universePlanets = document.querySelectorAll('.universe-planet');
  universePlanets.forEach((p, i) => {
    const angle = (i % 3) * 120 * (Math.PI / 180);
    p.style.left = `calc(50% + ${Math.cos(angle) * 50}%)`;
    p.style.top = `calc(50% + ${Math.sin(angle) * 50}%)`;
  });

  function triggerBlackHoleSuction(force = false) {
    const viewGalaxy = document.querySelector('.view-galaxy');
    if (!viewGalaxy || viewGalaxy.style.display === 'none') return;
    
    const overlay = document.getElementById('blackholeOverlay');
    if (!overlay) return;
    overlay.classList.add('active');
    
    // Suck in all active planets and UI elements
    const elements = document.querySelectorAll('.mission-satellite.active, .galaxy-planet.active, .stage-hud, .mission-log-panel');
    elements.forEach(el => el.classList.add('sucked-in'));
    
    setTimeout(() => {
      overlay.classList.remove('active');
      elements.forEach(el => el.classList.remove('sucked-in'));
    }, 3000);
  }

  function triggerUniverseExplosion(force = false) {
    const viewUniverse = document.querySelector('.view-universe');
    if (!viewUniverse || viewUniverse.style.display === 'none') return;
    
    const overlay = document.getElementById('explosionOverlay');
    if (!overlay) return;
    overlay.classList.add('active');
    
    // Screen shake
    document.body.classList.add('shake-screen');
    
    // Generate debris
    const debrisContainer = document.getElementById('debrisContainer');
    if (debrisContainer) {
      debrisContainer.innerHTML = '';
      for(let i=0; i<30; i++) {
        const d = document.createElement('div');
        d.className = 'debris-particle';
        const angle = Math.random() * Math.PI * 2;
        const dist = 300 + Math.random() * 500;
        d.style.setProperty('--dx', `${Math.cos(angle) * dist}px`);
        d.style.setProperty('--dy', `${Math.sin(angle) * dist}px`);
        d.style.transform = `rotate(${angle}rad)`;
        debrisContainer.appendChild(d);
      }
    }

    // Blast away all UI elements
    const elements = document.querySelectorAll('.mission-satellite.active, .galaxy-planet.active, .universe-planet.active, .stage-hud, .mission-log-panel');
    elements.forEach(el => el.classList.add('exploded-out'));
    
    setTimeout(() => {
      overlay.classList.remove('active');
      document.body.classList.remove('shake-screen');
      if (debrisContainer) debrisContainer.innerHTML = '';
      elements.forEach(el => el.classList.remove('exploded-out'));
    }, 5500);
  }

  function triggerMeteorShower() {
    const viewSolar = document.querySelector('.view-solar-system');
    if (!viewSolar || viewSolar.style.display === 'none') return;
    
    const container = document.getElementById("meteorShower");
    if (!container) return;
    container.innerHTML = "";
    for (let i = 0; i < 20; i++) {
      const meteor = document.createElement("div");
      meteor.className = "meteor";
      meteor.style.left = Math.random() * 100 + "vw";
      meteor.style.top = (Math.random() * 50 - 50) + "vh";
      meteor.style.animation = `meteorFall ${Math.random() * 1 + 0.5}s linear forwards`;
      meteor.style.animationDelay = Math.random() * 2 + "s";
      container.appendChild(meteor);
    }
  }

  function checkEvolution() {
    const unlockedCount = planetStates.filter(s => s !== null).length;
    
    // Unlock Galaxy at 12
    if (unlockedCount >= 12) {
      document.getElementById('navGalaxy').style.display = 'inline-block';
    }
    
    // Unlock Universe at 24
    if (unlockedCount >= 24) {
      document.getElementById('navUniverse').style.display = 'inline-block';
    }
  }

  function showCombo(isSpecial) {
    currentCombo++;
    if (!comboContainer) return;
    const comboEl = document.createElement("div");
    comboEl.className = "combo-text";
    if (isSpecial) {
      comboEl.innerText = `RARE UNLOCKED!`;
      comboEl.style.color = "#0ff";
      comboEl.style.textShadow = "0 0 20px #0ff";
    } else {
      comboEl.innerText = `COMBO x${currentCombo}!`;
    }
    const rot = (Math.random() - 0.5) * 20;
    comboEl.style.transform = `translate(-50%, -50%) rotate(${rot}deg)`;
    comboContainer.appendChild(comboEl);
    setTimeout(() => {
      comboEl.remove();
    }, 2500);
  }

  checks.forEach((check, index) => {
    check.addEventListener("change", (e) => {
      const satClass = e.target.dataset.satellite;
      const taskType = e.target.dataset.taskType || "general";
      const sat = satClass ? $("." + satClass) : null;
      const plot = satClass ? $("." + satClass.replace("s", "p")) : null; // for city view
      const gal = $(".g" + (index + 1)); // galaxy planet (up to 24)
      const uni = $(".u" + (index - 23)); // universe planet (1 to 12)
      
      if (e.target.checked) {
        let isSpecial = false;
        let rareType = planetStates[index];
        
        // Generate RNG state if first time
        if (!rareType) {
          const rng = Math.random();
          if (index < 12) {
            if (rng < 0.1) rareType = 'hidden-comet';
            else if (rng < 0.2) rareType = 'hidden-moon';
            else rareType = 'standard';
          } else if (index < 24) {
            if (rng < 0.1) rareType = 'hidden-blackhole';
            else rareType = 'standard';
          } else {
            if (rng < 0.15) rareType = 'hidden-explosion';
            else rareType = 'standard';
          }
          
          planetStates[index] = rareType;
          localStorage.setItem('nudge_planet_states', JSON.stringify(planetStates));
        }

        // Apply to Solar System (s1-s12)
        if (sat && index < 12) {
          sat.classList.add("active");
          if (rareType !== 'standard') {
            sat.classList.add(rareType);
            isSpecial = true;
            triggerMeteorShower();
          }
        }
        
        // Apply to Galaxy (g1-g24)
        if (gal && index < 24) {
          gal.classList.add("active");
          if (rareType !== 'standard') {
            gal.classList.add(rareType);
            isSpecial = true;
            if (index >= 12 && rareType === 'hidden-blackhole') triggerBlackHoleSuction();
          }
        }

        // Apply to Universe (u1-u12)
        if (uni && index >= 24) {
          uni.classList.add("active");
          if (rareType !== 'standard') {
            uni.classList.add(rareType);
            isSpecial = true;
            if (rareType === 'hidden-explosion') triggerUniverseExplosion();
          }
        }

        if (plot) {
          plot.classList.add("built");
          plot.classList.add("built-" + taskType);
        }
        
        showCombo(isSpecial);
        checkEvolution();
      } else {
        // Solar System
        if (sat) {
          sat.classList.remove("active");
          sat.classList.remove("hidden-comet", "hidden-moon", "hidden-blackhole");
        }
        // Galaxy
        if (gal) {
          gal.classList.remove("active");
          gal.classList.remove("hidden-comet", "hidden-moon", "hidden-blackhole");
        }
        // Universe
        if (uni) {
          uni.classList.remove("active");
          uni.classList.remove("hidden-explosion");
        }
        if (plot) {
          plot.classList.remove("built", "built-study", "built-health", "built-general", "built-skyscraper");
        }
        currentCombo = 0;
        // Historical array preserves the unlocked RNG state
      }
    });
  });

  // Stage Navigation Binding
  const btnSolar = document.getElementById('navSolar');
  const btnGalaxy = document.getElementById('navGalaxy');
  const btnUniverse = document.getElementById('navUniverse');
  const viewSolar = document.querySelector('.view-solar-system');
  const viewGalaxy = document.querySelector('.view-galaxy');
  const viewUniverse = document.querySelector('.view-universe');

  function switchStage(stage) {
    if (viewSolar) viewSolar.style.display = 'none';
    if (viewGalaxy) viewGalaxy.style.display = 'none';
    if (viewUniverse) viewUniverse.style.display = 'none';
    
    let targetView = null;
    let displayStyle = 'block';
    
    if (stage === 'solar') {
      targetView = viewSolar;
      displayStyle = 'block';
    } else if (stage === 'galaxy') {
      targetView = viewGalaxy;
      displayStyle = 'flex';
    } else if (stage === 'universe') {
      targetView = viewUniverse;
      displayStyle = 'block';
    }
    
    if (targetView) {
      targetView.style.display = displayStyle;
      
      // Force browser reflow to restart CSS animations (prevents Safari/Chrome 3D transform display:none freeze bug)
      const animatedEls = targetView.querySelectorAll('.starfield, .orbit-line, .mission-satellite, .asteroid, .galaxy-orbit-line, .galaxy-planet, .universe-orbit-line, .universe-planet, .unlocked-planet-node');
      animatedEls.forEach(el => {
        const originalStyle = el.style.animation;
        el.style.animation = 'none';
        void el.offsetHeight; // Force reflow
        el.style.animation = originalStyle;
      });
    }
  }

  if (btnSolar) btnSolar.addEventListener('click', () => switchStage('solar'));
  if (btnGalaxy) btnGalaxy.addEventListener('click', () => switchStage('galaxy'));
  if (btnUniverse) btnUniverse.addEventListener('click', () => switchStage('universe'));

  // Initial UI check for Evolution buttons based on history
  const unlockedCount = planetStates.filter(s => s !== null).length;
  if (unlockedCount >= 12 && btnGalaxy) btnGalaxy.style.display = 'inline-block';
  if (unlockedCount >= 24 && btnUniverse) btnUniverse.style.display = 'inline-block';
  // Mouse Wheel Zoom for City View
  const cityView = document.querySelector('.view-city');
  const neighborhoodScene = document.querySelector('.neighborhood-scene');
  if (cityView && neighborhoodScene) {
    let zoomLevel = 1;
    cityView.addEventListener('wheel', (e) => {
      e.preventDefault(); // Prevent page scrolling
      if (e.deltaY < 0) {
        zoomLevel = Math.min(zoomLevel + 0.1, 3); // zoom in (max 3x)
      } else {
        zoomLevel = Math.max(zoomLevel - 0.1, 0.5); // zoom out (min 0.5x)
      }
      neighborhoodScene.style.transform = `scale(${zoomLevel})`;
      neighborhoodScene.style.transformOrigin = 'center center';
      neighborhoodScene.style.transition = 'transform 0.1s ease-out';
    }, { passive: false });
  }

};

function bindExamTemplates() {
  const templateListContainer = $("[data-template-list]");
  if (!templateListContainer) return;

  const defaultTemplates = [
    { time: "週一", title: "建立目標", desc: "派發本週讀書與健康任務。" },
    { time: "週三", title: "中段提醒", desc: "自動提醒落後小組與個人。" },
    { time: "週五", title: "共同自律房", desc: "排程 50 分鐘團體專注。" },
    { time: "週日", title: "週報匯出", desc: "生成班級、小組、個人摘要。" }
  ];

  const loadExamTemplates = () => {
    const store = JSON.parse(localStorage.getItem("nudgeWebExamTemplates"));
    return store || defaultTemplates;
  };

  const saveExamTemplates = (templates) => {
    localStorage.setItem("nudgeWebExamTemplates", JSON.stringify(templates));
  };

  const renderExamTemplates = () => {
    const templates = loadExamTemplates();
    templateListContainer.innerHTML = templates.map((tpl, idx) => `
      <article>
        <button type="button" class="delete-template-btn" data-idx="${idx}" title="刪除">×</button>
        <small>${tpl.time}</small>
        <strong>${tpl.title}</strong>
        <span>${tpl.desc}</span>
      </article>
    `).join("");

    $$(".delete-template-btn", templateListContainer).forEach(btn => {
      btn.addEventListener("click", (e) => {
        const idx = parseInt(e.currentTarget.dataset.idx, 10);
        const tpls = loadExamTemplates();
        tpls.splice(idx, 1);
        saveExamTemplates(tpls);
        renderExamTemplates();
        toast("已刪除模板");
      });
    });
  };

  renderExamTemplates();

  const addBtn = $('[data-action="add-template"]');
  if (addBtn) {
    addBtn.addEventListener("click", () => {
      const timeInput = $('[data-template-time]');
      const titleInput = $('[data-template-title]');
      const descInput = $('[data-template-desc]');
      
      const time = timeInput.value.trim() || "新時段";
      const title = titleInput.value.trim() || "新模板";
      const desc = descInput.value.trim() || "無說明";

      const tpls = loadExamTemplates();
      tpls.push({ time, title, desc });
      
      const dayWeights = { "週一": 1, "週二": 2, "週三": 3, "週四": 4, "週五": 5, "週六": 6, "週日": 7 };
      tpls.sort((a, b) => {
        const weightA = dayWeights[a.time] || 99;
        const weightB = dayWeights[b.time] || 99;
        if (weightA !== weightB) return weightA - weightB;
        return 0;
      });

      saveExamTemplates(tpls);
      renderExamTemplates();

      timeInput.value = "";
      titleInput.value = "";
      descInput.value = "";
      toast("已加入模板");
    });
  }
}

window.addEventListener("DOMContentLoaded", () => {
  try { injectSidebarControls(); } catch(e){}
  try { injectModuleMenu(); } catch(e){}
  try { injectDisplayModeControls(); } catch(e){}
  try { injectAINavigator(); } catch(e){}
  try { animateCounters(); } catch(e){}
  try { bootCharts(); } catch(e){}
  try { bindDemoButtons(); } catch(e){}
  try { bindPlanet(); } catch(e){}
  try { bindExtensionTools(); } catch(e){}
  try { bindTilt(); } catch(e){}
  try { bindPresentation(); } catch(e){}
  try { bindExamTemplates(); } catch(e){}
  try { if (window.bindMissions) window.bindMissions(); } catch(e){}
});

window.addEventListener("resize", bootCharts);

function injectSidebarControls() {
  const sidebar = document.querySelector(".sidebar");
  if (!sidebar) return;

  // 1. Inject Floating Toggle Button & Backdrop
  if (!document.getElementById("sidebarToggleBtn")) {
    const toggleBtn = document.createElement("button");
    toggleBtn.id = "sidebarToggleBtn";
    toggleBtn.className = "sidebar-toggle";
    toggleBtn.setAttribute("aria-label", "Toggle Sidebar");
    toggleBtn.innerHTML = `
      <span></span>
      <span></span>
      <span></span>
    `;
    document.body.appendChild(toggleBtn);

    const backdrop = document.createElement("div");
    backdrop.id = "sidebarBackdrop";
    backdrop.className = "sidebar-backdrop";
    document.body.appendChild(backdrop);

    toggleBtn.addEventListener("click", () => {
      if (window.innerWidth <= 980) {
        document.body.classList.toggle("sidebar-open");
      } else {
        document.body.classList.toggle("sidebar-collapsed");
        const collapsed = document.body.classList.contains("sidebar-collapsed");
        localStorage.setItem("nudgeSidebarCollapsed", collapsed ? "true" : "false");
      }
    });

    backdrop.addEventListener("click", () => {
      document.body.classList.remove("sidebar-open");
    });
  }

  // 2. Inject Desktop Close Button (Inner Collapse) next to brand logo
  const brand = sidebar.querySelector(".brand");
  if (brand && !sidebar.querySelector(".sidebar-close-inner")) {
    const headerRow = document.createElement("div");
    headerRow.className = "sidebar-header-row";
    brand.parentNode.insertBefore(headerRow, brand);
    headerRow.appendChild(brand);

    const closeBtn = document.createElement("button");
    closeBtn.className = "sidebar-close-inner";
    closeBtn.title = "收折選單";
    closeBtn.innerHTML = "◀";
    headerRow.appendChild(closeBtn);

    closeBtn.addEventListener("click", () => {
      document.body.classList.add("sidebar-collapsed");
      localStorage.setItem("nudgeSidebarCollapsed", "true");
    });
  }

  // 3. Restore saved layout preference
  const savedCollapsed = localStorage.getItem("nudgeSidebarCollapsed");
  if (savedCollapsed === "true" && window.innerWidth > 980) {
    document.body.classList.add("sidebar-collapsed");
  }
}






function injectAdminSwitch() {
  const existingBtn1 = document.querySelector('.admin-switch-btn');
  if (existingBtn1) existingBtn1.remove();
  const existingBtn2 = document.querySelector('.exit-admin-btn');
  if (existingBtn2) existingBtn2.remove();

  const isAdminPage = window.location.pathname.includes('admin_dashboard.html');

  const style = document.createElement('style');
  style.innerHTML = `
    .global-admin-switch-btn {
      position: fixed;
      top: 1.5rem;
      right: 1.5rem;
      background: transparent;
      border: none;
      color: #F3F4F6;
      font-weight: 700;
      font-size: 1.1rem;
      cursor: pointer;
      z-index: 1000;
      display: flex;
      align-items: center;
      gap: 0.5rem;
      text-shadow: 0 1px 4px rgba(0,0,0,0.6);
      transition: opacity 0.2s;
    }
    .global-admin-switch-btn:hover {
      opacity: 0.8;
    }
    .global-login-modal-overlay {
      position: fixed;
      inset: 0;
      background: rgba(0, 0, 0, 0.5);
      backdrop-filter: blur(4px);
      display: flex;
      align-items: center;
      justify-content: center;
      z-index: 10000;
      opacity: 0;
      pointer-events: none;
      transition: opacity 0.3s ease;
    }
    .global-login-modal-overlay.active {
      opacity: 1;
      pointer-events: auto;
    }
    .global-login-modal {
      background: var(--c-panel-bg);
      padding: 2.5rem;
      border-radius: 20px;
      width: 100%;
      max-width: 400px;
      box-shadow: 0 24px 48px var(--shadow-color);
      transform: translateY(20px);
      transition: transform 0.3s ease;
      border: 1px solid var(--c-border);
      color: var(--c-text);
    }
    .global-login-modal-overlay.active .global-login-modal {
      transform: translateY(0);
    }
    .global-login-modal h2 { margin-top: 0; margin-bottom: 1.5rem; font-size: 1.5rem; }
    .global-form-group { margin-bottom: 1.25rem; text-align: left; }
    .global-form-group label { display: block; font-size: 0.875rem; margin-bottom: 0.5rem; color: var(--c-text-muted); }
    .global-form-group input { width: 100%; padding: 0.75rem 1rem; border-radius: 8px; border: 1px solid var(--c-border); background: var(--c-bg); color: var(--c-text); box-sizing: border-box; }
    .global-login-actions { display: flex; justify-content: flex-end; gap: 1rem; margin-top: 2rem; }
    .global-btn-cancel { background: transparent; border: 1px solid var(--c-border); color: var(--c-text); padding: 0.6rem 1.2rem; border-radius: 8px; cursor: pointer; }
    .global-btn-submit { background: var(--c-primary); border: none; color: white; padding: 0.6rem 1.2rem; border-radius: 8px; cursor: pointer; font-weight: 600; }
    .global-error-msg { color: #ef4444; font-size: 0.875rem; margin-top: 0.5rem; display: none; text-align: left; }
  `;
  document.head.appendChild(style);

  const main = document.querySelector('.main');
  if (main) main.style.position = 'relative';
  const btnContainer = main || document.body;

  if (isAdminPage) {
    const btn = document.createElement('button');
    btn.className = 'global-admin-switch-btn';
    btn.innerHTML = '⚙ 切回前台';
    btn.onclick = () => window.location.href = 'index.html';
    btnContainer.appendChild(btn);
  } else {
    window.showAdminLoginModal = function() {
      let overlay = document.getElementById('globalLoginModal');
      if (!overlay) {
        const modalHtml = `
          <div class="global-login-modal-overlay" id="globalLoginModal">
            <div class="global-login-modal">
              <h2>後台登入</h2>
              <div class="global-form-group">
                <label>帳號</label>
                <input type="text" id="gAdminUsername" placeholder="請輸入 admin" />
              </div>
              <div class="global-form-group">
                <label>密碼</label>
                <input type="password" id="gAdminPassword" placeholder="請輸入 admin" />
              </div>
              <div class="global-error-msg" id="gLoginError">帳號或密碼錯誤！預設請使用 admin / admin。</div>
              <div class="global-login-actions">
                <button class="global-btn-cancel" onclick="document.getElementById('globalLoginModal').classList.remove('active')">取消</button>
                <button class="global-btn-submit" onclick="gAttemptLogin()">登入</button>
              </div>
            </div>
          </div>
        `;
        document.body.insertAdjacentHTML('beforeend', modalHtml);

        // Enter key to login
        document.getElementById('gAdminPassword').addEventListener('keypress', function(e) {
          if (e.key === 'Enter') gAttemptLogin();
        });
      }

      document.getElementById('globalLoginModal').classList.add('active');
      document.getElementById('gAdminUsername').focus();
    };

    window.gAttemptLogin = function() {
      const user = document.getElementById('gAdminUsername').value;
      const pass = document.getElementById('gAdminPassword').value;
      if (user === 'admin' && pass === 'admin') {
        window.location.href = 'admin_dashboard.html';
      } else {
        document.getElementById('gLoginError').style.display = 'block';
      }
    };

    // Secret entry triggers:
    
    // 1. Double Click Brand Mark
    const brandMark = document.querySelector('.brand-mark');
    if (brandMark) {
      brandMark.addEventListener('dblclick', () => {
        window.showAdminLoginModal();
      });
    }

    // 2. Keyboard Shortcut: Ctrl + Shift + A (or Cmd + Shift + A)
    document.addEventListener('keydown', (e) => {
      if ((e.ctrlKey || e.metaKey) && e.shiftKey && e.key.toLowerCase() === 'a') {
        e.preventDefault();
        window.showAdminLoginModal();
      }
    });

    // 3. Query Parameter: ?admin or ?ops
    if (window.location.search.includes('admin') || window.location.search.includes('ops')) {
      setTimeout(() => window.showAdminLoginModal(), 200);
    }
  }
}

document.addEventListener("DOMContentLoaded", () => {
    setTimeout(injectAdminSwitch, 100);
    try { initializeFirebaseWeb(); } catch(e){}
});

// ─── Firebase / Firestore Real-time Sync Integration ──────────────────────────

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
    if (window.firebase && window.firebase.auth && window.firebase.firestore) {
      resolve();
      return;
    }
    const coreScript = document.createElement('script');
    coreScript.src = "https://www.gstatic.com/firebasejs/9.22.0/firebase-app-compat.js";
    coreScript.onload = () => {
      const authScript = document.createElement('script');
      authScript.src = "https://www.gstatic.com/firebasejs/9.22.0/firebase-auth-compat.js";
      authScript.onload = () => {
        const dbScript = document.createElement('script');
        dbScript.src = "https://www.gstatic.com/firebasejs/9.22.0/firebase-firestore-compat.js";
        dbScript.onload = () => {
          resolve();
        };
        dbScript.onerror = () => resolve();
        document.head.appendChild(dbScript);
      };
      authScript.onerror = () => resolve();
      document.head.appendChild(authScript);
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
        
        // Listen to Auth State
        firebase.auth().onAuthStateChanged((user) => {
          if (user) {
            console.log("Authenticated user detected:", user.uid);
            if (!user.isAnonymous) {
              localStorage.setItem("nudgeWebLoggedIn", "true");
              localStorage.setItem("nudgeActiveDemoUserId", user.uid);
            }
          } else {
            console.log("No authenticated user. Attempting anonymous sign in...");
            // Sign in anonymously if not logged in, to allow reading the users list and data!
            firebase.auth().signInAnonymously().catch(err => {
              console.warn("Anonymous sign in failed: ", err);
            });
          }
          startListeningToFirestoreData();
          document.dispatchEvent(new Event('firebase-ready'));
        });
      } catch (e) {
        console.warn("Firebase initialization failed, falling back to mock data: ", e);
        startListeningToFirestoreData();
        document.dispatchEvent(new Event('firebase-ready'));
      }
    } else {
      console.log("Firebase SDK not loaded, using local demo data");
      startListeningToFirestoreData();
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
    const panel = getOrCreateSidePanel();
    if (panel) {
      if (!$(".demo-user-select").length) {
        injectUserSwitcher(users, activeUserId);
      }
    }
    
    listenToUser(activeUserId);
  }).catch(e => {
    console.warn("Firestore access error: ", e);
  });
}

function getOrCreateSidePanel() {
  let panel = $(".side-panel");
  if (!panel) {
    const sidebar = $(".sidebar");
    if (sidebar) {
      sidebar.insertAdjacentHTML('beforeend', '<section class="side-panel"></section>');
      panel = $(".side-panel");
    }
  }
  return panel;
}

function injectUserSwitcher(users, activeUserId) {
  const panel = getOrCreateSidePanel();
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
  const panel = getOrCreateSidePanel();
  if (!panel) return;
  
  const nickname = data.nickname || "未知使用者";
  const nudgeId = data.myNudgeId || data.username || "NDG-Guest";
  const coins = typeof data.disciplineCoins === 'number' ? data.disciplineCoins : 0;
  const planets = typeof data.planetCount === 'number' ? data.planetCount : 0;
  const userRole = data.userRole || "personal";
  
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
      <div style="display: flex; align-items: center; justify-content: space-between;">
        <span class="eyebrow">同步使用者資料</span>
        <a href="javascript:void(0);" id="editWebProfileBtn" style="font-size: 11px; color: var(--c-primary); font-weight: 700; text-decoration: none; display: flex; align-items: center; gap: 4px; transition: opacity 0.2s;">
          <span>⚙️ 編輯資料</span>
        </a>
      </div>
      <div class="user-profile-card" style="margin-top: 8px; margin-bottom: 12px; background: rgba(255,255,255,0.03); border: 1px solid rgba(255,255,255,0.08); border-radius: 12px; padding: 12px; display: flex; align-items: center; gap: 12px; box-shadow: inset 0 1px 0 rgba(255,255,255,0.05);">
        <div style="width: 40px; height: 40px; border-radius: 50%; background: ${accentColor}; display: flex; align-items: center; justify-content: center; font-weight: 800; color: white; font-size: 16px; box-shadow: 0 4px 12px ${accentColor}40; flex-shrink: 0;">
          ${nickname.substring(0, 1).toUpperCase()}
        </div>
        <div style="flex: 1; min-width: 0;">
          <div style="font-weight: 700; color: #fff; font-size: 14px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">${nickname}</div>
          <div style="font-size: 11px; color: rgba(255,255,255,0.4); font-family: monospace;">ID: ${nudgeId}</div>
        </div>
        <div style="text-align: right; flex-shrink: 0; display: flex; flex-direction: column; gap: 2px;">
          <div style="font-weight: 800; color: #f59e0b; font-size: 13px;">🪙${coins}</div>
          <div style="font-weight: 800; color: #a855f7; font-size: 12px;">🪐${planets}</div>
        </div>
      </div>
      <div class="sidebar-role-select-wrapper" style="margin-bottom: 12px; border-top: 1px solid rgba(255,255,255,0.06); padding-top: 10px;">
        <span class="eyebrow" style="display: block; margin-bottom: 5px;">切換自律身分</span>
        <select id="sidebarRoleSelect" class="module-select" style="width: 100%; background: #1a1d24; color: #fff; border: 1px solid rgba(255,255,255,0.12); padding: 8px; border-radius: 8px; font-weight: 600; cursor: pointer;">
          <option value="personal" ${userRole === 'personal' ? 'selected' : ''}>🧑‍💻 個人/小孩模式</option>
          <option value="guardian" ${userRole === 'guardian' ? 'selected' : ''}>🛡️ 家長模式</option>
          <option value="group" ${userRole === 'group' ? 'selected' : ''}>👥 團體挑戰模式</option>
          <option value="enterprise" ${userRole === 'enterprise' ? 'selected' : ''}>🏢 企業管理模式</option>
          <option value="tutor" ${userRole === 'tutor' ? 'selected' : ''}>🎒 補習班管理模式</option>
          <option value="school" ${userRole === 'school' ? 'selected' : ''}>🏫 學校班級模式</option>
        </select>
      </div>
    </div>
  `;

  if (profileContainer) {
    profileContainer.outerHTML = cardHtml;
  } else {
    panel.insertAdjacentHTML('afterbegin', cardHtml);
  }

  // 掛載事件監聽
  const roleSelect = document.getElementById("sidebarRoleSelect");
  if (roleSelect) {
    roleSelect.addEventListener("change", (e) => {
      const newRole = e.target.value;
      const activeUserId = localStorage.getItem("nudgeActiveDemoUserId") || "an_nudge";
      if (activeUserId && typeof db !== "undefined") {
        db.collection("users").doc(activeUserId).update({
          userRole: newRole,
          updatedAt: new Date().toISOString()
        }).then(() => {
          let roleName = "個人/小孩";
          if (newRole === "guardian") roleName = "家長陪伴";
          if (newRole === "group") roleName = "團體挑戰";
          if (newRole === "enterprise") roleName = "企業管理";
          if (newRole === "tutor") roleName = "補習班管理";
          if (newRole === "school") roleName = "學校班級";
          toast(`自律身份已成功切換為：【${roleName}】`);
        }).catch(err => {
          console.error("更新角色失敗：", err);
          toast("切換失敗，請稍後再試");
        });
      }
    });
  }

  const editProfileBtn = document.getElementById("editWebProfileBtn");
  if (editProfileBtn) {
    editProfileBtn.addEventListener("click", () => {
      showWebProfileEditModal(data);
    });
  }

  // 門禁安全保護判斷
  checkPagePermissions(data);
}

function checkPagePermissions(data) {
  const userRole = data.userRole || "personal";
  const path = window.location.pathname;
  const isGuardianPage = path.includes("guardian") || document.body.getAttribute("data-page") === "guardian";
  const isGroupsPage = path.includes("groups") || document.body.getAttribute("data-page") === "groups";

  // 1. 導覽列發光推薦與引導橫幅
  updateNavigationRecommendation(userRole);

  // 2. 移除舊的防護遮罩
  const existingOverlay = document.getElementById("roleGatekeeperOverlay");
  if (existingOverlay) {
    existingOverlay.remove();
  }

  // 3. 移除網頁端舊的綁定卡片並恢復主體顯示
  const existingBindingCard = document.getElementById("webBindingGatedCard");
  if (existingBindingCard) {
    existingBindingCard.remove();
  }
  const existingGroupInfo = document.getElementById("webGroupInfoCard");
  if (existingGroupInfo) {
    existingGroupInfo.remove();
  }
  document.querySelectorAll(".main > section, .main > div:not(.hero), .main > a").forEach(el => {
    if (el.id !== "webBindingGatedCard" && el.id !== "webGroupInfoCard") {
      el.style.display = ""; // 恢復預設
    }
  });

  if (isGuardianPage && userRole !== "guardian") {
    // 角色不符：跳出毛玻璃遮罩
    showGatekeeperOverlay(
      "🛡️",
      "家長陪伴中心專屬",
      `您目前的自律身分是【${getRoleLabel(userRole)}】，本頁面僅供家長身分存取。請點擊下方按鈕或透過側邊欄切換為「家長模式」以啟用共同目標、每週報告與鼓勵系統。`,
      "guardian"
    );
  } else if (isGroupsPage && !["group", "enterprise", "tutor", "school"].includes(userRole)) {
    if (window.location.pathname.includes("groups-creation.html")) {
      renderWebGroupCreationPage(data);
    } else {
      // 角色不符：跳出毛玻璃遮罩
      showGatekeeperOverlay(
        "👥",
        "團體與教育管理端專屬",
        `您目前的自律身分是【${getRoleLabel(userRole)}】，本頁面僅供團體、學校、企業或補習班管理人員存取。請切換為對應模式以建立挑戰、規劃讀書時段或發佈學業大考任務模板。`,
        "group"
      );
    }
  } else {
    // 角色符合：檢查是否完成前置綁定
    if (isGuardianPage && userRole === "guardian") {
      const isLinked = data.webToolsState?.guardianInviteStatus?.status === 'linked';
      if (!isLinked) {
        // 隱藏主體內容，插入親屬綁定卡片
        document.querySelectorAll(".main > section, .main > div:not(.hero), .main > a").forEach(el => {
          el.style.display = "none";
        });
        showWebRelativeBindingCard();
      }
    } else if (isGroupsPage && ["group", "enterprise", "tutor", "school"].includes(userRole)) {
      const hasGroup = !!data.groupId;
      if (window.location.pathname.includes("groups-creation.html")) {
        renderWebGroupCreationPage(data);
      } else if (!hasGroup) {
        // 隱藏主體內容，插入團體綁定卡片
        document.querySelectorAll(".main > section, .main > div:not(.hero), .main > a").forEach(el => {
          el.style.display = "none";
        });
        showWebGroupBindingCard();
      } else {
        renderWebGroupInfo(data);
      }
    }
  }
}

function updateNavigationRecommendation(userRole) {
  // 清除舊的發光
  document.querySelectorAll(".nav a").forEach(a => a.classList.remove("recommend-glow"));

  const isHome = document.body.getAttribute("data-page") === "home" || window.location.pathname.includes("index");
  const main = document.querySelector(".main");

  // 移除舊橫幅
  const oldBanner = document.getElementById("recommendBanner");
  if (oldBanner) {
    oldBanner.remove();
  }

  if (userRole === "guardian") {
    // 家長發光推薦
    document.querySelectorAll(".nav a").forEach(a => {
      if (a.getAttribute("href") === "guardian.html") {
        a.classList.add("recommend-glow");
      }
    });
    // 首頁橫幅引導
    if (isHome && main) {
      const bannerHtml = `
        <div id="recommendBanner" class="recommend-banner">
          <div class="recommend-banner-content">
            <span class="recommend-banner-icon">🛡️</span>
            <div class="recommend-banner-text">
              <strong>您當前處於家長陪伴身分</strong>
              <p>系統已為您推薦專屬【家長陪伴中心】，點擊右側按鈕快速進入以進行管理。</p>
            </div>
          </div>
          <button class="recommend-banner-btn" onclick="window.location.href='guardian.html'">前往家長中心</button>
        </div>
      `;
      main.insertAdjacentHTML("afterbegin", bannerHtml);
    }
  } else if (["group", "enterprise", "tutor", "school"].includes(userRole)) {
    // 團體發光推薦
    document.querySelectorAll(".nav a").forEach(a => {
      if (a.getAttribute("href") === "groups.html") {
        a.classList.add("recommend-glow");
      }
    });
    // 首頁橫幅引導
    if (isHome && main) {
      const bannerHtml = `
        <div id="recommendBanner" class="recommend-banner">
          <div class="recommend-banner-content">
            <span class="recommend-banner-icon">👥</span>
            <div class="recommend-banner-text">
              <strong>您當前處於團體/教育管理身分</strong>
              <p>系統已為您推薦專屬【團體與教育管理端】，點擊右側按鈕快速進入管理挑戰與排程。</p>
            </div>
          </div>
          <button class="recommend-banner-btn" onclick="window.location.href='groups.html'">前往團體中心</button>
        </div>
      `;
      main.insertAdjacentHTML("afterbegin", bannerHtml);
    }
  }
}

let currentIncomingRequests = [];
let currentOutgoingRequests = [];
let incomingRequestsSub = null;
let outgoingRequestsSub = null;

function listenToRequests(userId) {
  if (!db) return;
  if (incomingRequestsSub) incomingRequestsSub();
  if (outgoingRequestsSub) outgoingRequestsSub();

  incomingRequestsSub = db.collection("guardian_requests")
    .where("receiverId", "==", userId)
    .onSnapshot(snapshot => {
      const docs = [];
      snapshot.forEach(doc => {
        docs.push({ id: doc.id, ...doc.data() });
      });
      currentIncomingRequests = docs.filter(d => d.status === 'pending');
      
      const accepted = docs.filter(d => d.status === 'accepted');
      if (accepted.length > 0) {
        const relativeNudgeId = accepted[0].senderNudgeId;
        autoUpdateWebLinkage(userId, relativeNudgeId);
      } else {
        checkAndAutoClearWebLinkage(userId);
      }
      refreshWebBindingCardUI();
    }, err => console.error("Incoming requests listen error: ", err));

  outgoingRequestsSub = db.collection("guardian_requests")
    .where("senderId", "==", userId)
    .onSnapshot(snapshot => {
      const docs = [];
      snapshot.forEach(doc => {
        docs.push({ id: doc.id, ...doc.data() });
      });
      currentOutgoingRequests = docs.filter(d => d.status === 'pending');

      const accepted = docs.filter(d => d.status === 'accepted');
      if (accepted.length > 0) {
        const relativeNudgeId = accepted[0].receiverNudgeId;
        autoUpdateWebLinkage(userId, relativeNudgeId);
      } else {
        checkAndAutoClearWebLinkage(userId);
      }
      refreshWebBindingCardUI();
    }, err => console.error("Outgoing requests listen error: ", err));
}

function autoUpdateWebLinkage(userId, relativeNudgeId) {
  const store = JSON.parse(localStorage.getItem("nudgeWebTools") || "{}");
  const isAlreadyLinked = store.guardianInviteStatus?.status === 'linked' && store.guardianInvite?.relativeId === relativeNudgeId;
  if (isAlreadyLinked) return;

  db.collection("users").doc(userId).update({
    "webToolsState.guardianInvite": {
      "goal": "共同健康與專注",
      "permission": "完整資料",
      "message": "親屬帳號已連結。",
      "relativeId": relativeNudgeId
    },
    "webToolsState.guardianInviteStatus": {
      "status": "linked",
      "updatedAt": new Date().toISOString()
    }
  }).then(() => {
    console.log("Web linkage auto-updated successfully.");
  }).catch(err => {
    console.error("Failed to auto-update web linkage: ", err);
  });
}

function checkAndAutoClearWebLinkage(userId) {
  const store = JSON.parse(localStorage.getItem("nudgeWebTools") || "{}");
  const isLinked = store.guardianInviteStatus?.status === 'linked';
  if (!isLinked) return;

  db.collection("guardian_requests")
    .where("receiverId", "==", userId)
    .where("status", "==", "accepted")
    .get()
    .then(incomingSnap => {
      if (incomingSnap.size > 0) return;
      db.collection("guardian_requests")
        .where("senderId", "==", userId)
        .where("status", "==", "accepted")
        .get()
        .then(outgoingSnap => {
          if (outgoingSnap.size > 0) return;
          
          db.collection("users").doc(userId).update({
            "webToolsState.guardianInvite": firebase.firestore.FieldValue.delete(),
            "webToolsState.guardianInviteStatus": firebase.firestore.FieldValue.delete()
          }).then(() => {
            console.log("Web linkage auto-cleared successfully.");
          }).catch(err => {
            console.error("Failed to auto-clear web linkage: ", err);
          });
        });
    });
}

function refreshWebBindingCardUI() {
  if (document.getElementById("webBindingGatedCard")) {
    renderRequestsList();
  }
}

function sendWebGuardianRequest(targetNudgeId) {
  const activeUserId = localStorage.getItem("nudgeActiveDemoUserId") || "an_nudge";
  if (!activeUserId || !db) return;

  const targetNudgeIdUpper = targetNudgeId.trim().toUpperCase();
  if (!targetNudgeIdUpper) {
    toast("Nudge ID 不能為空");
    return;
  }

  db.collection("users").doc(activeUserId).get().then(mySnap => {
    if (!mySnap.exists) return;
    const myData = mySnap.data();
    const myNudgeId = myData.myNudgeId || myData.username || "";
    const myNickname = myData.nickname || "使用者";
    const myRole = myData.userRole || "personal";

    if (targetNudgeIdUpper === myNudgeId.toUpperCase()) {
      toast("不能與自己進行親屬綁定");
      return;
    }

    db.collection("users").where("username", "==", targetNudgeIdUpper).limit(1).get().then(querySnap => {
      if (querySnap.empty) {
        toast("找不到該 Nudge ID 的使用者");
        return;
      }
      const receiverSnap = querySnap.docs[0];
      const receiverId = receiverSnap.id;
      const receiverNudgeId = receiverSnap.data().username || "";

      const isLinked = myData.webToolsState?.guardianInviteStatus?.status === 'linked';
      if (isLinked && myData.webToolsState?.guardianInvite?.relativeId === receiverNudgeId) {
        toast("雙方已處於綁定狀態");
        return;
      }

      db.collection("guardian_requests")
        .where("senderId", "==", activeUserId)
        .where("receiverId", "==", receiverId)
        .where("status", "==", "pending")
        .get()
        .then(outgoingCheck => {
          if (!outgoingCheck.empty) {
            toast("已發送過綁定申請，請耐心等待對方同意");
            return;
          }

          db.collection("guardian_requests")
            .where("senderId", "==", receiverId)
            .where("receiverId", "==", activeUserId)
            .where("status", "==", "pending")
            .get()
            .then(incomingCheck => {
              if (!incomingCheck.empty) {
                approveWebGuardianRequest(incomingCheck.docs[0].id);
                toast("偵測到對方已發送過申請，已自動為您同意並綁定！ 🎉");
                return;
              }

              db.collection("guardian_requests").add({
                senderId: activeUserId,
                senderNudgeId: myNudgeId,
                senderNickname: myNickname,
                senderRole: myRole,
                receiverId: receiverId,
                receiverNudgeId: receiverNudgeId,
                status: "pending",
                createdAt: new Date().toISOString(),
                updatedAt: new Date().toISOString()
              }).then(() => {
                toast(`已成功向 ${receiverNudgeId} 發送綁定申請！`);
              }).catch(err => {
                console.error(err);
                toast("發送申請失敗");
              });
            });
        });
    });
  }).catch(err => console.error(err));
}

function approveWebGuardianRequest(requestId) {
  if (!db) return;
  db.collection("guardian_requests").doc(requestId).update({
    status: "accepted",
    updatedAt: new Date().toISOString()
  }).then(() => {
    toast("已成功同意親屬綁定！ 🎉");
  }).catch(err => {
    console.error(err);
    toast("同意失敗");
  });
}

function declineWebGuardianRequest(requestId) {
  if (!db) return;
  db.collection("guardian_requests").doc(requestId).update({
    status: "declined",
    updatedAt: new Date().toISOString()
  }).then(() => {
    toast("已拒絕該綁定申請");
  }).catch(err => {
    console.error(err);
    toast("操作失敗");
  });
}

function cancelWebGuardianRequest(requestId) {
  if (!db) return;
  db.collection("guardian_requests").doc(requestId).update({
    status: "declined",
    updatedAt: new Date().toISOString()
  }).then(() => {
    toast("已取消綁定申請");
  }).catch(err => {
    console.error(err);
    toast("取消失敗");
  });
}

// Expose these methods globally so inline html onclick can access them
window.approveWebGuardianRequest = approveWebGuardianRequest;
window.declineWebGuardianRequest = declineWebGuardianRequest;
window.cancelWebGuardianRequest = cancelWebGuardianRequest;

function renderRequestsList() {
  const container = document.getElementById("webRequestsContainer");
  if (!container) return;

  let html = "";

  if (currentIncomingRequests.length > 0) {
    html += `
      <div class="web-pending-section" style="margin-top: 15px; text-align: left;">
        <h4 style="font-size: 13px; color: #fff; margin-bottom: 8px; font-weight: 700;">待處理的親屬綁定申請：</h4>
    `;
    currentIncomingRequests.forEach(req => {
      const senderName = req.senderNickname || "使用者";
      const senderNudge = req.senderNudgeId || "";
      html += `
        <div class="web-pending-item" style="display: flex; align-items: center; justify-content: space-between; padding: 10px; background: rgba(255, 255, 255, 0.05); border: 1px solid rgba(255, 255, 255, 0.1); border-radius: 8px; margin-bottom: 8px;">
          <span style="font-size: 13px; color: #fff;">${senderName} (${senderNudge})</span>
          <div style="display: flex; gap: 8px;">
            <button onclick="approveWebGuardianRequest('${req.id}')" style="background: #10b981; border: none; color: #fff; padding: 4px 10px; border-radius: 4px; font-size: 12px; cursor: pointer; font-weight: 600;">同意</button>
            <button onclick="declineWebGuardianRequest('${req.id}')" style="background: transparent; border: 1px solid #ef4444; color: #ef4444; padding: 4px 10px; border-radius: 4px; font-size: 12px; cursor: pointer; font-weight: 600;">拒絕</button>
          </div>
        </div>
      `;
    });
    html += `</div>`;
  }

  if (currentOutgoingRequests.length > 0) {
    html += `
      <div class="web-pending-section" style="margin-top: 15px; text-align: left;">
    `;
    currentOutgoingRequests.forEach(req => {
      html += `
        <div class="web-pending-item" style="display: flex; align-items: center; justify-content: space-between; padding: 10px; background: rgba(255, 255, 255, 0.03); border: 1px solid rgba(255, 255, 255, 0.06); border-radius: 8px; margin-bottom: 8px;">
          <span style="font-size: 13px; color: rgba(255, 255, 255, 0.7); display: flex; align-items: center; gap: 6px;">
            <span style="color: #f59e0b;">⏳</span> 已向 ${req.receiverNudgeId} 發送申請，等待同意中...
          </span>
          <button onclick="cancelWebGuardianRequest('${req.id}')" style="background: transparent; border: 1px solid rgba(255, 255, 255, 0.3); color: rgba(255,255,255,0.6); padding: 4px 10px; border-radius: 4px; font-size: 12px; cursor: pointer; font-weight: 600;">取消</button>
        </div>
      `;
    });
    html += `</div>`;
  }

  container.innerHTML = html;

  const form = document.getElementById("webBindingForm");
  if (form) {
    if (currentOutgoingRequests.length > 0) {
      form.style.display = "none";
    } else {
      form.style.display = "flex";
    }
  }
}

function showWebRelativeBindingCard() {
  const main = document.querySelector(".main");
  if (!main || document.getElementById("webBindingGatedCard")) return;

  const cardHtml = `
    <div id="webBindingGatedCard" class="web-binding-gated-wrapper">
      <h2>🛡️ 親屬帳號連結</h2>
      <p id="webBindingDesc">為了查閱對方的專注、睡眠與健康數據牆，請先與對方進行親屬綁定。請在下方輸入您對方的 Nudge ID 發送申請，或在列表處理待同意的申請：</p>
      
      <div id="webRequestsContainer" style="margin-bottom: 20px;"></div>

      <div id="webBindingForm" class="web-binding-form">
        <input type="text" id="webRelativeIdInput" class="web-binding-input" placeholder="輸入對方的 Nudge ID (例如: child_123)">
        <button id="webRelativeBindBtn" class="role-gatekeeper-btn" style="width: 100%;">發送綁定申請</button>
      </div>
    </div>
  `;
  main.insertAdjacentHTML("beforeend", cardHtml);

  document.getElementById("webRelativeBindBtn")?.addEventListener("click", () => {
    const relativeInput = document.getElementById("webRelativeIdInput");
    const relativeId = relativeInput ? relativeInput.value.trim() : "";
    if (!relativeId) {
      toast("請輸入有效的 Nudge ID");
      return;
    }
    sendWebGuardianRequest(relativeId);
  });

  renderRequestsList();
}

function showWebGroupBindingCard() {
  const main = document.querySelector(".main");
  if (!main || document.getElementById("webBindingGatedCard")) return;

  const cardHtml = `
    <div id="webBindingGatedCard" class="web-binding-gated-wrapper">
      <h2>👥 團體自律組織關聯</h2>
      <p>請先創建新的自律團體（獲取最高房主權限並生成團體 ID），或輸入已有組織 ID 加入，以解鎖後續功能：</p>
      <div class="web-binding-form" style="margin-bottom: 24px; border-bottom: 1px dashed rgba(255,255,255,0.1); padding-bottom: 24px;">
        <input type="text" id="webGroupNameInput" class="web-binding-input" placeholder="輸入要創建的團體名稱 (例如: 皇家自律班)">
        <button id="webGroupCreateBtn" class="role-gatekeeper-btn" style="width: 100%;">創建新團體並獲取房主權限</button>
      </div>
      <div class="web-binding-form">
        <input type="text" id="webGroupIdInput" class="web-binding-input" placeholder="輸入已有團體組織 ID (格式如: GRP-88921)">
        <button id="webGroupJoinBtn" class="role-gatekeeper-btn" style="width: 100%; background: transparent; border: 1px solid var(--page-accent); color: var(--page-accent);">輸入 ID 連結並加入</button>
      </div>
    </div>
  `;
  main.insertAdjacentHTML("beforeend", cardHtml);

  document.getElementById("webGroupCreateBtn")?.addEventListener("click", () => {
    const nameInput = document.getElementById("webGroupNameInput");
    const name = nameInput ? nameInput.value.trim() : "";
    if (!name) {
      toast("請輸入有效的團體名稱");
      return;
    }
    const activeUserId = localStorage.getItem("nudgeActiveDemoUserId") || "an_nudge";
    const randomId = 'GRP-' + Math.floor(Math.random() * 100000);
    if (activeUserId && typeof db !== "undefined") {
      db.collection("users").doc(activeUserId).update({
        groupId: randomId,
        groupName: name,
        isGroupOwner: true,
        updatedAt: new Date().toISOString()
      }).then(() => {
        toast(`成功創建「${name}」團體，ID：${randomId}！ 🚀`);
      }).catch(err => {
        console.error("創建團體失敗：", err);
        toast("操作失敗，請稍後再試");
      });
    }
  });

  document.getElementById("webGroupJoinBtn")?.addEventListener("click", () => {
    const groupInput = document.getElementById("webGroupIdInput");
    const groupId = groupInput ? groupInput.value.trim() : "";
    if (!groupId) {
      toast("請輸入有效的團體 ID");
      return;
    }
    const activeUserId = localStorage.getItem("nudgeActiveDemoUserId") || "an_nudge";
    if (activeUserId && typeof db !== "undefined") {
      db.collection("users").doc(activeUserId).update({
        groupId: groupId,
        groupName: "自律小組",
        isGroupOwner: false,
        updatedAt: new Date().toISOString()
      }).then(() => {
        toast(`已成功加入團體 ID：${groupId}！ 🎯`);
      }).catch(err => {
        console.error("加入團體失敗：", err);
        toast("操作失敗，請稍後再試");
      });
    }
  });
}

function renderWebGroupInfo(data) {
  const main = document.querySelector(".main");
  if (!main) return;

  const existingCard = document.getElementById("webGroupInfoCard");
  if (existingCard) {
    existingCard.remove();
  }

  const path = window.location.pathname;
  const isMainGroupsPage = path.includes("groups.html") || path.endsWith("/groups") || (document.body.getAttribute("data-page") === "groups" && !path.includes("groups-"));
  if (!isMainGroupsPage) return;

  const isOwner = data.isGroupOwner;
  const groupName = data.groupName || "自律小組";
  const groupId = data.groupId || "";

  const cardHtml = `
    <div id="webGroupInfoCard" class="web-binding-gated-wrapper" style="text-align: left; max-width: 800px; margin-top: 10px; margin-bottom: 24px; display: flex; align-items: center; justify-content: space-between; gap: 20px; background: rgba(20, 184, 166, 0.08); border: 1px solid rgba(20, 184, 166, 0.25); box-shadow: var(--shadow); border-radius: 16px; padding: 20px 24px;">
      <div>
        <div style="display: flex; align-items: center; gap: 8px; margin-bottom: 6px;">
          <span style="background: rgba(20, 184, 166, 0.2); color: #14b8a6; padding: 2px 8px; border-radius: 6px; font-size: 11px; font-weight: 700; border: 1px solid rgba(20, 184, 166, 0.3);">
            ${isOwner ? '👑 團體建立者 (房主)' : '👥 團體成員'}
          </span>
          <span style="font-family: monospace; font-size: 11px; color: var(--muted);">ID: ${groupId}</span>
        </div>
        <h3 style="margin: 0; font-size: 18px; color: #fff; font-weight: 800;">當前關聯團體：${groupName}</h3>
      </div>
      <button id="webGroupLeaveBtn" style="background: transparent; border: 1px solid #ef4444; color: #ef4444; padding: 8px 16px; border-radius: 8px; font-size: 13px; font-weight: 700; cursor: pointer; transition: all 0.2s;">
        ${isOwner ? '解散此團體' : '退出此小組'}
      </button>
    </div>
  `;

  const header = main.querySelector("header");
  if (header) {
    header.insertAdjacentHTML("afterend", cardHtml);
  } else {
    main.insertAdjacentHTML("afterbegin", cardHtml);
  }

  document.getElementById("webGroupLeaveBtn")?.addEventListener("click", () => {
    if (confirm(`確定要${isOwner ? '解散' : '退出'}當前團體【${groupName}】嗎？`)) {
      const activeUserId = localStorage.getItem("nudgeActiveDemoUserId") || "an_nudge";
      if (activeUserId && typeof db !== "undefined") {
        db.collection("users").doc(activeUserId).update({
          groupId: firebase.firestore.FieldValue.delete(),
          groupName: firebase.firestore.FieldValue.delete(),
          isGroupOwner: firebase.firestore.FieldValue.delete(),
          updatedAt: new Date().toISOString()
        }).then(() => {
          toast("已退出當前團體");
        }).catch(err => {
          console.error("退出團體失敗：", err);
          toast("操作失敗，請稍後再試");
        });
      }
    }
  });
}

function renderWebGroupCreationPage(data) {
  const container = document.getElementById("groupsCreationContainer");
  if (!container) return;

  const isOwner = data.isGroupOwner;
  const groupName = data.groupName || "自律小組";
  const groupId = data.groupId || "";

  if (!groupId) {
    // Member has no group yet. Render the binding form beautifully inside the page!
    container.innerHTML = `
      <div class="workspace-layout">
        <div class="panel">
          <span class="eyebrow">Create Team</span>
          <h2>👥 創建您的自律組織</h2>
          <p>輸入要建立的團隊名稱。系統將為您生成唯一的團隊 ID。您可以在手機 App 端輸入該 ID 加入此團隊並進行同步。</p>
          <div class="web-binding-form" style="margin-top: 20px;">
            <input type="text" id="webGroupNameInputPage" class="web-binding-input" placeholder="例如: 皇家自律班" style="margin-bottom: 12px; width: 100%; max-width: 400px; display: block;">
            <button id="webGroupCreateBtnPage" class="button primary" style="padding: 10px 20px; font-weight: 700; cursor: pointer;">創建新團體並獲取房主權限</button>
          </div>
        </div>
        <aside class="panel">
          <span class="eyebrow">Join Team</span>
          <h2>🔗 加入已有團隊</h2>
          <p>輸入其他房主建立的組織 ID，加入其組織並進行同步。</p>
          <div class="web-binding-form" style="margin-top: 20px;">
            <input type="text" id="webGroupIdInputPage" class="web-binding-input" placeholder="格式如: GRP-88921" style="margin-bottom: 12px; width: 100%; max-width: 400px; display: block;">
            <button id="webGroupJoinBtnPage" class="button ghost" style="padding: 10px 20px; font-weight: 700; cursor: pointer;">輸入 ID 連結並加入</button>
          </div>
        </aside>
      </div>
    `;

    document.getElementById("webGroupCreateBtnPage")?.addEventListener("click", () => {
      const nameInput = document.getElementById("webGroupNameInputPage");
      const name = nameInput ? nameInput.value.trim() : "";
      if (!name) {
        toast("請輸入有效的團體名稱");
        return;
      }
      const activeUserId = localStorage.getItem("nudgeActiveDemoUserId") || "an_nudge";
      const randomId = 'GRP-' + Math.floor(Math.random() * 100000);
      if (activeUserId && typeof db !== "undefined") {
        db.collection("users").doc(activeUserId).update({
          groupId: randomId,
          groupName: name,
          isGroupOwner: true,
          userRole: "group",
          updatedAt: new Date().toISOString()
        }).then(() => {
          toast(`成功創建「${name}」團體，ID：${randomId}！ 🚀`);
          window.location.reload();
        }).catch(err => {
          console.error("創建團體失敗：", err);
          toast("操作失敗，請稍後再試");
        });
      }
    });

    document.getElementById("webGroupJoinBtnPage")?.addEventListener("click", () => {
      const groupInput = document.getElementById("webGroupIdInputPage");
      const groupId = groupInput ? groupInput.value.trim() : "";
      if (!groupId) {
        toast("請輸入有效的團體 ID");
        return;
      }
      const activeUserId = localStorage.getItem("nudgeActiveDemoUserId") || "an_nudge";
      if (activeUserId && typeof db !== "undefined") {
        db.collection("users").doc(activeUserId).update({
          groupId: groupId,
          groupName: "自律小組",
          isGroupOwner: false,
          userRole: "group",
          updatedAt: new Date().toISOString()
        }).then(() => {
          toast(`已成功加入團體 ID：${groupId}！ 🎯`);
          window.location.reload();
        }).catch(err => {
          console.error("加入團體失敗：", err);
          toast("操作失敗，請稍後再試");
        });
      }
    });

    return;
  }

  // Already has a group. Render the management interface with real-time member listing!
  container.innerHTML = `
    <div class="workspace-layout">
      <div class="panel" style="flex: 2;">
        <span class="eyebrow">Team Information</span>
        <div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 20px;">
          <div>
            <h2 style="margin: 0; color: #fff; font-size: 24px; font-weight: 800;">${groupName}</h2>
            <p style="margin: 4px 0 0 0; color: var(--muted); font-size: 14px; font-family: monospace;">團體組織 ID: ${groupId}</p>
          </div>
          <span style="background: rgba(20, 184, 166, 0.15); color: #14b8a6; padding: 4px 12px; border-radius: 8px; font-size: 12px; font-weight: 700; border: 1px solid rgba(20, 184, 166, 0.3);">
            ${isOwner ? '👑 房主 (Owner)' : '👥 成員 (Member)'}
          </span>
        </div>

        <span class="eyebrow">Group Members</span>
        <div class="table-responsive" style="margin-top: 14px;">
          <table class="table" style="width: 100%; border-collapse: collapse; text-align: left;">
            <thead>
              <tr style="border-bottom: 1px solid rgba(255,255,255,0.08); color: var(--muted); font-size: 12px; text-transform: uppercase;">
                <th style="padding: 12px 8px;">成員暱稱 (Nudge ID)</th>
                <th style="padding: 12px 8px;">身分</th>
                <th style="padding: 12px 8px; text-align: center;">今日專注 (分)</th>
                <th style="padding: 12px 8px; text-align: center;">今日步數</th>
                <th style="padding: 12px 8px; text-align: center;">今日睡眠 (時)</th>
                <th style="padding: 12px 8px; text-align: center;">任務完成度</th>
              </tr>
            </thead>
            <tbody id="webGroupMembersListTable" style="font-size: 14px; color: rgba(255,255,255,0.85);">
              <tr>
                <td colspan="6" style="padding: 24px; text-align: center; color: var(--muted);">正在加載團體成員資料...</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
      <aside class="panel" style="flex: 1; display: flex; flex-direction: column; justify-content: space-between;">
        <div>
          <span class="eyebrow">Settings</span>
          <h2>團隊管理選項</h2>
          <p style="margin-top: 8px; color: var(--muted); font-size: 14px;">
            ${isOwner ? '身為團隊建立者，您可以解散該團隊或修改團隊名稱。解散後所有成員將自動移出該組織。' : '您可以退出此小組，退出後將無法同步小組的挑戰與任務模板。'}
          </p>
        </div>
        <div style="margin-top: 24px;">
          <button id="webGroupLeaveBtnPage" class="button" style="width: 100%; background: #ef4444; border: none; color: #fff; padding: 12px; border-radius: 8px; font-weight: 700; cursor: pointer; transition: all 0.2s;">
            ${isOwner ? '🚨 解散此自律團體' : '🚪 退出此自律小組'}
          </button>
        </div>
      </aside>
    </div>
  `;

  // Bind Leave / Disband action
  document.getElementById("webGroupLeaveBtnPage")?.addEventListener("click", () => {
    if (confirm(`確定要${isOwner ? '解散' : '退出'}當前團體【${groupName}】嗎？`)) {
      const activeUserId = localStorage.getItem("nudgeActiveDemoUserId") || "an_nudge";
      if (activeUserId && typeof db !== "undefined") {
        db.collection("users").doc(activeUserId).update({
          groupId: firebase.firestore.FieldValue.delete(),
          groupName: firebase.firestore.FieldValue.delete(),
          isGroupOwner: firebase.firestore.FieldValue.delete(),
          userRole: "personal",
          updatedAt: new Date().toISOString()
        }).then(() => {
          toast("已成功解除團體關聯");
          window.location.reload();
        }).catch(err => {
          console.error("退出團體失敗：", err);
          toast("操作失敗，請稍後再試");
        });
      }
    }
  });

  // Query and list all members of the group in real-time
  db.collection("users").where("groupId", "==", groupId).get().then(snap => {
    const listTable = document.getElementById("webGroupMembersListTable");
    if (!listTable) return;
    listTable.innerHTML = "";

    let totalMembers = snap.size;
    const memberCountEl = document.getElementById("webGroupMemberCount");
    if (memberCountEl) {
      memberCountEl.dataset.count = totalMembers;
      memberCountEl.textContent = totalMembers;
    }

    if (snap.empty) {
      listTable.innerHTML = `<tr><td colspan="6" style="padding: 24px; text-align: center; color: var(--muted);">無任何成員資料</td></tr>`;
      return;
    }

    snap.forEach(doc => {
      const mData = doc.data();
      const mNickname = mData.nickname || "未知使用者";
      const mNudgeId = mData.username || doc.id;
      const mIsOwner = mData.isGroupOwner || false;

      // Extract stats
      const dailySummaries = mData.dailySummaries || [];
      const mTodaySummary = dailySummaries[dailySummaries.length - 1] || {};
      const mSleepHours = mTodaySummary.sleepHours || (mData.sleepHours || 0);
      const mSteps = mTodaySummary.steps || (mData.steps || 0);
      const mFocusMinutes = mTodaySummary.focusMinutes || (mData.focusSeconds ? Math.floor(mData.focusSeconds / 60) : 0);

      // Task completion
      const mTasks = mData.tasks || [];
      const completedTasksCount = mTasks.filter(t => t.isDone || t.done).length;
      const completionRate = mTasks.length > 0 ? Math.round((completedTasksCount / mTasks.length) * 100) : 0;

      listTable.innerHTML += `
        <tr style="border-bottom: 1px solid rgba(255,255,255,0.04); transition: background 0.2s;">
          <td style="padding: 14px 8px;">
            <div style="font-weight: 700; color: #fff;">${mNickname}</div>
            <div style="font-size: 11px; color: var(--muted); font-family: monospace;">${mNudgeId}</div>
          </td>
          <td style="padding: 14px 8px;">
            <span style="font-size: 12px; color: ${mIsOwner ? '#f59e0b' : 'rgba(255,255,255,0.5)'}; font-weight: 600;">
              ${mIsOwner ? '👑 房主' : '👥 成員'}
            </span>
          </td>
          <td style="padding: 14px 8px; text-align: center; font-weight: 600;">${mFocusMinutes}</td>
          <td style="padding: 14px 8px; text-align: center; font-weight: 600; color: #22c7bb;">${mSteps}</td>
          <td style="padding: 14px 8px; text-align: center; font-weight: 600; color: #8d7aff;">${mSleepHours.toFixed(1)}</td>
          <td style="padding: 14px 8px; text-align: center;">
            <div style="display: flex; align-items: center; justify-content: center; gap: 8px;">
              <span style="font-weight: 700; color: #00ffcc; font-size: 13px;">${completionRate}%</span>
              <div style="width: 50px; height: 6px; background: rgba(255,255,255,0.1); border-radius: 3px; overflow: hidden; display: inline-block;">
                <div style="width: ${completionRate}%; height: 100%; background: #00ffcc; border-radius: 3px;"></div>
              </div>
            </div>
          </td>
        </tr>
      `;
    });
  }).catch(err => {
    console.error("Error loading group members: ", err);
  });
}

function getRoleLabel(role) {
  switch (role) {
    case "personal": return "個人/小孩";
    case "guardian": return "家長";
    case "group": return "團體挑戰";
    case "enterprise": return "企業管理";
    case "tutor": return "補習班管理";
    case "school": return "學校班級";
    default: return "未設定";
  }
}

function showGatekeeperOverlay(icon, title, desc, targetRole) {
  const overlayHtml = `
    <div id="roleGatekeeperOverlay" class="role-gatekeeper-overlay">
      <div class="role-gatekeeper-content">
        <div class="role-gatekeeper-inner">
          <div class="role-gatekeeper-icon">${icon}</div>
          <div class="role-gatekeeper-title">${title}</div>
          <div class="role-gatekeeper-desc">${desc}</div>
          <button id="roleGatekeeperBtn" class="role-gatekeeper-btn">一鍵切換為【${getRoleLabel(targetRole)}】身分</button>
        </div>
      </div>
    </div>
  `;
  document.body.insertAdjacentHTML("beforeend", overlayHtml);

  // 綁定按鈕點擊事件
  const btn = document.getElementById("roleGatekeeperBtn");
  if (btn) {
    btn.addEventListener("click", () => {
      const activeUserId = localStorage.getItem("nudgeActiveDemoUserId") || "an_nudge";
      if (activeUserId && typeof db !== "undefined") {
        db.collection("users").doc(activeUserId).update({
          userRole: targetRole,
          updatedAt: new Date().toISOString()
        }).then(() => {
          toast(`自律身份已成功切換為：【${getRoleLabel(targetRole)}】`);
        }).catch(err => {
          console.error("更新角色失敗：", err);
          toast("切換失敗，請稍後再試");
        });
      }
    });
  }
}

// ====================================================
// 🔧 同步伺服器設定
// 本機開發：http://127.0.0.1:5001
// 部署到 Render 後：改成你的 Render URL，例如：
//   https://nudge-sync-server.onrender.com
// ====================================================
const SYNC_SERVER_URL = "https://graduation-project-nudge.onrender.com";

function syncToFlaskServer(data, dailySummaries, tasks) {
  const latestSummary = dailySummaries[dailySummaries.length - 1] || {};
  const completedCount = tasks.filter(t => t.isDone || t.done).length;
  
  // 1. Sync User Profile
  fetch(`${SYNC_SERVER_URL}/api/sync/user`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      user_id: "an_nudge",
      name: data.nickname || data.name || "使用者",
      avatar: "🧑‍🚀",
      status: data.signature || "被專案快搞瘋了"
    })
  }).catch(err => console.log("Flask User Sync Error: ", err));

  // 2. Sync Health
  fetch(`${SYNC_SERVER_URL}/api/sync/health`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      user_id: "an_nudge",
      sleep_hours: latestSummary.sleepHours || 7.5,
      steps: latestSummary.steps || 8000,
      exercise_minutes: latestSummary.exerciseMinutes || 45
    })
  }).catch(err => console.log("Flask Health Sync Error: ", err));

  // 3. Sync Focus & Planet Unlock
  fetch(`${SYNC_SERVER_URL}/api/sync/focus`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      user_id: "an_nudge",
      tasks_completed: completedCount,
      tasks_total: tasks.length,
      focus_minutes: latestSummary.focusMinutes || (data.focusSeconds ? Math.floor(data.focusSeconds / 60) : 40),
      current_goal: data.webToolsState?.guardianInvite?.goal || ""
    })
  })
  .then(res => res.json())
  .then(resData => {
    if (resData.new_planet_unlocked) {
      toast(`🪐 太陽系躍遷！本週自律達標，Flask 後端成功為您解鎖新星球：【${resData.new_planet_unlocked}】！`);
    }
  })
  .catch(err => console.log("Flask Focus Sync Error: ", err));
}

let previousTasksState = null;
let currentUserTasks = [];
let currentUserDailySummaries = [];
let childDocSub = null;
let currentChildNudgeId = null;
let groupOwnerSub = null;
let currentGroupIdListener = null;

function updateParentDashboardWithChildData(childData) {
  const tasks = childData.tasks || [];
  const dailySummaries = childData.dailySummaries || [];
  
  const completedTasksCount = tasks.filter(t => t.isDone || t.done).length;
  const completionRate = tasks.length > 0 ? Math.round((completedTasksCount / tasks.length) * 100) : 0;
  
  const todaySummary = dailySummaries[dailySummaries.length - 1] || {};
  const sleepHours = todaySummary.sleepHours || (childData.sleepHours || 0);
  const steps = todaySummary.steps || (childData.steps || 0);
  const focusMinutes = todaySummary.focusMinutes || (childData.focusSeconds ? Math.floor(childData.focusSeconds / 60) : 0);
  
  const childTasksCountEl = document.getElementById("childTasksCount");
  if (childTasksCountEl) {
    childTasksCountEl.dataset.count = completedTasksCount;
    childTasksCountEl.textContent = `${completedTasksCount} 個`;
  }
  
  const childTasksRingEl = document.getElementById("childTasksRing");
  if (childTasksRingEl) {
    childTasksRingEl.style.setProperty("--p", `${completionRate}%`);
    const ringText = childTasksRingEl.querySelector("strong");
    if (ringText) ringText.textContent = `${completionRate}%`;
  }
  
  const childFocusValEl = document.getElementById("childFocusVal");
  if (childFocusValEl) {
    childFocusValEl.dataset.count = focusMinutes;
    childFocusValEl.textContent = `${focusMinutes} 分`;
  }
  
  const childFocusRingEl = document.getElementById("childFocusRing");
  if (childFocusRingEl) {
    const focusRate = Math.min(Math.round((focusMinutes / 60) * 100), 100);
    childFocusRingEl.style.setProperty("--p", `${focusRate}%`);
    const ringText = childFocusRingEl.querySelector("strong");
    if (ringText) ringText.textContent = `${focusRate}%`;
  }
  
  const childSleepValEl = document.getElementById("childSleepVal");
  if (childSleepValEl) {
    childSleepValEl.textContent = `${sleepHours.toFixed(1)} 小時`;
  }
  
  const childSleepRingEl = document.getElementById("childSleepRing");
  if (childSleepRingEl) {
    const sleepRate = Math.min(Math.round((sleepHours / 8) * 100), 100);
    childSleepRingEl.style.setProperty("--p", `${sleepRate}%`);
    const ringText = childSleepRingEl.querySelector("strong");
    if (ringText) ringText.textContent = `${sleepRate}%`;
  }
  
  const childStepsValEl = document.getElementById("childStepsVal");
  if (childStepsValEl) {
    childStepsValEl.dataset.count = steps;
    childStepsValEl.textContent = `${steps}`;
  }
  
  const childStepsRingEl = document.getElementById("childStepsRing");
  if (childStepsRingEl) {
    const stepsRate = Math.min(Math.round((steps / 10000) * 100), 100);
    childStepsRingEl.style.setProperty("--p", `${stepsRate}%`);
    const ringText = childStepsRingEl.querySelector("strong");
    if (ringText) ringText.textContent = `${stepsRate}%`;
  }
  
  if (dailySummaries.length > 0) {
    const scoresList = dailySummaries.map(s => s.disciplineScore || 0);
    const sleepList = dailySummaries.map(s => s.sleepHours || 0);
    
    const trendChart = document.getElementById("trendChart");
    if (trendChart && scoresList.length > 0) {
      drawLineChart(trendChart, scoresList.slice(-12));
    }
    
    const sleepChart = document.getElementById("sleepChart");
    if (sleepChart && sleepList.length > 0) {
      drawLineChart(sleepChart, sleepList.slice(-7), "#8d7aff");
    }
  }
  
  const weeklyRateEl = document.querySelector(".hero-card strong");
  if (weeklyRateEl) {
    weeklyRateEl.dataset.count = completionRate;
    weeklyRateEl.textContent = `${completionRate}%`;
  }
  
  const chipA = document.querySelector(".chip-a strong");
  if (chipA) {
    chipA.dataset.count = completionRate;
    chipA.textContent = `${completionRate}%`;
  }
}

function syncGroupOwnerDataToLocal(ownerData) {
  const store = JSON.parse(localStorage.getItem("nudgeWebTools") || "{}");
  let changed = false;
  if (ownerData.webToolsState) {
    for (const k of ["challenge", "template"]) {
      if (ownerData.webToolsState[k] && JSON.stringify(store[k]) !== JSON.stringify(ownerData.webToolsState[k])) {
        store[k] = ownerData.webToolsState[k];
        changed = true;
      }
    }
  }
  if (ownerData.webToolsCollection) {
    for (const k of ["studySchedules"]) {
      if (ownerData.webToolsCollection[k] && JSON.stringify(store[k]) !== JSON.stringify(ownerData.webToolsCollection[k])) {
        store[k] = ownerData.webToolsCollection[k];
        changed = true;
      }
    }
  }
  if (changed) {
    localStorage.setItem("nudgeWebTools", JSON.stringify(store));
    if (typeof window.renderSavedList === 'function') {
      window.renderSavedList("[data-study-list]", "studySchedules", "<article><strong>尚未排程</strong><span>新增讀書時段後會出現在這裡。</span></article>");
    }
  }
}

function listenToUser(userId) {
  if (!db) return;
  listenToRequests(userId);
  db.collection("users").doc(userId).onSnapshot((docSnap) => {
    if (!docSnap.exists) return;
    const data = docSnap.data();
    
    updateSidebarProfile(data);

    // Guardian-child sync
    const isGuardian = data.userRole === "guardian";
    const isLinked = data.webToolsState?.guardianInviteStatus?.status === 'linked';
    const childNudgeId = data.webToolsState?.guardianInvite?.relativeId;
    
    if (isGuardian && isLinked && childNudgeId) {
      const childNudgeIdUpper = childNudgeId.trim().toUpperCase();
      if (currentChildNudgeId !== childNudgeIdUpper) {
        currentChildNudgeId = childNudgeIdUpper;
        if (childDocSub) childDocSub();
        childDocSub = db.collection("users")
          .where("username", "==", childNudgeIdUpper)
          .limit(1)
          .onSnapshot((childQuerySnap) => {
            if (!childQuerySnap.empty) {
              const childDoc = childQuerySnap.docs[0];
              const childData = childDoc.data();
              window.linkedChildUid = childDoc.id;
              updateParentDashboardWithChildData(childData);
            }
          }, (err) => console.error("Child doc sub error:", err));
      }
    } else {
      currentChildNudgeId = null;
      window.linkedChildUid = null;
      if (childDocSub) {
        childDocSub();
        childDocSub = null;
      }
    }

    // Group member sync
    const isGroupMember = ["group", "enterprise", "tutor", "school"].includes(data.userRole) && !data.isGroupOwner;
    const groupId = data.groupId;
    if (isGroupMember && groupId) {
      if (currentGroupIdListener !== groupId) {
        currentGroupIdListener = groupId;
        if (groupOwnerSub) groupOwnerSub();
        groupOwnerSub = db.collection("users")
          .where("groupId", "==", groupId)
          .where("isGroupOwner", "==", true)
          .limit(1)
          .onSnapshot((ownerQuerySnap) => {
            if (!ownerQuerySnap.empty) {
              const ownerDoc = ownerQuerySnap.docs[0];
              const ownerData = ownerDoc.data();
              syncGroupOwnerDataToLocal(ownerData);
            }
          }, (err) => console.error("Group owner sub error:", err));
      }
    } else {
      currentGroupIdListener = null;
      if (groupOwnerSub) {
        groupOwnerSub();
        groupOwnerSub = null;
      }
    }
    
    const dailySummaries = data.dailySummaries || [];
    const tasks = data.tasks || [];
    currentUserTasks = tasks;
    currentUserDailySummaries = dailySummaries;
    
    // 如果任務為空，自動在 Firestore 初始化預設自律任務，以達成雙端靜態任務同步
    if (tasks.length === 0) {
      initializeDefaultTasksInFirestore(userId);
      return;
    }
    
    // 📡 網頁端自動偵測任務在手機端達成！
    if (previousTasksState !== null) {
      tasks.forEach(task => {
        const prev = previousTasksState.find(pt => pt.id === task.id);
        if (prev && !prev.isDone && !prev.done && (task.isDone || task.done)) {
          toast(`📡 星艦通訊：偵測到手機完成任務【${task.title || task.name}】，網頁星球已同步點亮建築與發射衛星！`);
        }
      });
    }
    previousTasksState = JSON.parse(JSON.stringify(tasks));
    
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
    
    let completionRate = 0;
    if (tasks.length > 0) {
      const completedCount = tasks.filter(t => t.isDone || t.done).length;
      completionRate = Math.round((completedCount / tasks.length) * 100);
      const chipA = $(".chip-a strong");
      if (chipA) {
        chipA.dataset.count = completionRate;
        chipA.textContent = `${completionRate}%`;
      }
      
      const prosperityElement = document.querySelector(".hero-card strong");
      if (prosperityElement) {
        prosperityElement.dataset.count = completionRate;
        prosperityElement.textContent = `${completionRate}`;
      }
      
      if (document.body.dataset.page === "planet") {
        if (typeof window.bindFirestoreMissions === 'function') {
          window.bindFirestoreMissions(tasks);
        }
      }
    }

    if (completionRate >= 60) {
      const currentPlanetEarned = data.weeklyPlanetEarned || false;
      if (!currentPlanetEarned) {
        const currentPlanetCount = typeof data.planetCount === 'number' ? data.planetCount : 0;
        db.collection("users").doc(userId).update({
          weeklyPlanetEarned: true,
          planetCount: currentPlanetCount + 1
        }).then(() => {
          toast("🎉 太棒了！您本週自律完成度達到 60%，獲得了一顆新星 🪐！已同步至手機 App");
        });
      }
    }
    
    if (document.body.dataset.page === "planet") {
      const todaySummary = dailySummaries[dailySummaries.length - 1] || {};
      const completedCount = tasks.filter(t => t.isDone || t.done).length;
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

    // Propagate user, health, and focus stats to local python Flask server
    syncToFlaskServer(data, dailySummaries, tasks);
    
    // 📡 Web端自動偵測並同步來自手機 App 建立的膠囊、信件、家長狀態等
    let store = JSON.parse(localStorage.getItem("nudgeWebTools") || "{}");
    let changed = false;
    if (data.webToolsState) {
      for (const k in data.webToolsState) {
        if (JSON.stringify(store[k]) !== JSON.stringify(data.webToolsState[k])) {
          store[k] = data.webToolsState[k];
          changed = true;
        }
      }
    }
    if (data.webToolsCollection) {
      for (const k in data.webToolsCollection) {
        if (JSON.stringify(store[k]) !== JSON.stringify(data.webToolsCollection[k])) {
          store[k] = data.webToolsCollection[k];
          changed = true;
        }
      }
    }
    if (changed) {
      localStorage.setItem("nudgeWebTools", JSON.stringify(store));
      if (typeof window.renderSavedList === 'function') {
        window.renderSavedList("[data-capsule-list]", "capsules", "<article><strong>尚未保存</strong><span>建立第一個時間膠囊後會出現在這裡。</span></article>");
        window.renderSavedList("[data-encourage-list]", "encouragements", "<article><strong>尚未送出</strong><span>送出鼓勵卡後會出現在這裡。</span></article>");
        window.renderSavedList("[data-study-list]", "studySchedules", "<article><strong>尚未排程</strong><span>新增讀書時段後會出現在這裡。</span></article>");
      }
    }
  });
}

window.bindFirestoreMissions = function(tasks) {
  const list = document.getElementById("dynamicMissionList");
  if (!list) return;
  
  list.innerHTML = "";
  tasks.slice(0, 36).forEach((task, index) => {
    const title = task.title || task.name || "自律任務";
    const done = task.isDone || task.done || false;
    const taskId = task.id || "";
    const sId = "s" + (index + 1);
    
    let taskType = "general";
    if (/(專案|期末|大考|挑戰)/.test(title)) {
      taskType = "skyscraper";
    } else if (/(書|讀|作業|考試|專注|報告)/.test(title)) {
      taskType = "study";
    } else if (/(健康|水|睡|運動|步)/.test(title)) {
      taskType = "health";
    }

    list.innerHTML += `
      <li class="mission-item" data-task-id="${taskId}">
        <label>
          <input type="checkbox" class="mission-check" data-satellite="${sId}" data-index="${index}" data-task-id="${taskId}" data-task-type="${taskType}" ${done ? 'checked' : ''} />
          <span>${title}</span>
        </label>
        <div class="mission-meta">
          <div class="energy-bar-container">
            <div class="energy-bar" style="width: ${done ? '100%' : '60%'}; background: ${done ? '#00ffcc' : '#f59e0b'};"></div>
          </div>
          <div class="mission-actions" style="display: flex; align-items: center; gap: 8px;">
            <span style="font-size: 11px; color: ${done ? '#00ffcc' : 'rgba(255,255,255,0.4)'}; font-weight: 700;">
              ${done ? '✅ 已同步完成' : '⏳ 行動中'}
            </span>
            <button class="cyber-btn delete-mission-btn" data-task-id="${taskId}" style="font-size: 10px; padding: 2px 6px; border-color: rgba(239, 68, 68, 0.4); color: #ef4444; background: transparent; cursor: pointer; border-radius: 4px; box-shadow: none;">刪除</button>
          </div>
        </div>
      </li>
    `;

    // Toggle active class on satellites in real-time
    const sat = document.querySelector("." + sId);
    const plot = document.querySelector("." + sId.replace("s", "p"));
    const gal = document.querySelector(".g" + (index + 1));
    const uni = document.querySelector(".u" + (index - 23));

    if (done) {
      if (sat) sat.classList.add("active");
      if (gal) gal.classList.add("active");
      if (uni && index >= 24) uni.classList.add("active");
      if (plot) {
        plot.classList.add("built");
        plot.classList.add("built-" + taskType);
      }
    } else {
      if (sat) {
        sat.classList.remove("active", "hidden-comet", "hidden-moon", "hidden-blackhole");
      }
      if (gal) {
        gal.classList.remove("active", "hidden-comet", "hidden-moon", "hidden-blackhole");
      }
      if (uni) {
        uni.classList.remove("active", "hidden-explosion");
      }
      if (plot) {
        plot.classList.remove("built", "built-study", "built-health", "built-general", "built-skyscraper");
      }
    }
  });

  const checks = list.querySelectorAll(".mission-check");
  checks.forEach((check) => {
    check.addEventListener("change", (e) => {
      const taskId = e.target.dataset.taskId;
      const isChecked = e.target.checked;
      const activeUserId = localStorage.getItem("nudgeActiveDemoUserId");
      if (!activeUserId || !db) return;
      
      const docRef = db.collection("users").doc(activeUserId);
      docRef.get().then((docSnap) => {
        if (!docSnap.exists) return;
        const data = docSnap.data();
        const currentTasks = data.tasks || [];
        const updatedTasks = currentTasks.map(t => {
          if (t.id === taskId) {
            return {
              ...t,
              isDone: isChecked,
              done: isChecked,
              completedAt: isChecked ? new Date().toISOString() : null,
              updatedAt: new Date().toISOString()
            };
          }
          return t;
        });
        docRef.update({ tasks: updatedTasks }).then(() => {
          toast(isChecked ? "任務已標記為完成！" : "任務取消完成");
        });
      });
    });
  });

  // 🗑️ 刪除任務事件綁定與同步手機
  const deleteBtns = list.querySelectorAll(".delete-mission-btn");
  deleteBtns.forEach((btn) => {
    btn.addEventListener("click", (e) => {
      e.preventDefault();
      e.stopPropagation();
      const taskId = e.target.dataset.taskId;
      const activeUserId = localStorage.getItem("nudgeActiveDemoUserId");
      if (!activeUserId || !db) return;
      
      if (confirm("確定要刪除此自律任務並同步至手機端嗎？")) {
        const docRef = db.collection("users").doc(activeUserId);
        docRef.get().then((docSnap) => {
          if (!docSnap.exists) return;
          const data = docSnap.data();
          const currentTasks = data.tasks || [];
          const updatedTasks = currentTasks.filter(t => t.id !== taskId);
          docRef.update({ tasks: updatedTasks }).then(() => {
            toast("任務已成功刪除並同步至手機！");
          });
        });
      }
    });
  });

  checks.forEach((check, index) => {
    const taskType = check.dataset.taskType || "general";
    const sId = "s" + (index + 1);
    const sat = $("." + sId);
    const plot = $("." + sId.replace("s", "p"));
    const gal = $(".g" + (index + 1));
    const uni = $(".u" + (index - 23));

    if (check.checked) {
      if (sat && index < 12) sat.classList.add("active");
      if (gal && index < 24) gal.classList.add("active");
      if (uni && index >= 24) uni.classList.add("active");
      if (plot) {
        plot.classList.add("built");
        plot.classList.add("built-" + taskType);
      }
    } else {
      if (sat) sat.classList.remove("active");
      if (gal) gal.classList.remove("active");
      if (uni) uni.classList.remove("active");
      if (plot) plot.classList.remove("built", "built-study", "built-health", "built-general", "built-skyscraper");
    }
  });
};

function generateUUID() {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
    var r = Math.random() * 16 | 0, v = c == 'x' ? r : (r & 0x3 | 0x8);
    return v.toString(16);
  });
}

function addFirestoreTask(taskTitle) {
  const activeUserId = localStorage.getItem("nudgeActiveDemoUserId");
  if (!activeUserId || !db) {
    console.warn("Firebase not initialized or user missing");
    return;
  }
  const docRef = db.collection("users").doc(activeUserId);
  docRef.get().then((docSnap) => {
    if (docSnap.exists) {
      const data = docSnap.data();
      const currentTasks = data.tasks || [];
      const newTask = {
        id: generateUUID(),
        userId: activeUserId,
        title: taskTitle,
        category: "自定義",
        taskType: "fixed",
        priority: "medium",
        isDone: false,
        isSystemTask: false,
        isAutoTracked: false,
        sourceType: "manual",
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString()
      };
      
      currentTasks.push(newTask);
      docRef.update({ tasks: currentTasks }).then(() => {
        toast(`已成功新增任務：${taskTitle}`);
      });
    }
  });
}

function completeFirestoreTask(taskId) {
  const activeUserId = localStorage.getItem("nudgeActiveDemoUserId");
  if (!activeUserId || !db) {
    console.warn("Firebase not initialized or user missing");
    return;
  }
  const docRef = db.collection("users").doc(activeUserId);
  docRef.get().then((docSnap) => {
    if (docSnap.exists) {
      const data = docSnap.data();
      const currentTasks = data.tasks || [];
      
      // Try finding by exact ID first
      let taskIndex = currentTasks.findIndex(t => t.id === taskId);
      
      // If not found, try fuzzy matching by title
      if (taskIndex === -1) {
        taskIndex = currentTasks.findIndex(t => t.title === taskId || t.title.includes(taskId) || taskId.includes(t.title));
      }
      
      if (taskIndex !== -1) {
        if (currentTasks[taskIndex].isDone || currentTasks[taskIndex].done) {
          toast(`📡 星艦回報：任務【${currentTasks[taskIndex].title}】早已是完成狀態！`);
          return;
        }
        
        currentTasks[taskIndex].isDone = true;
        currentTasks[taskIndex].done = true;
        currentTasks[taskIndex].completedAt = new Date().toISOString();
        currentTasks[taskIndex].updatedAt = new Date().toISOString();
        
        docRef.update({ tasks: currentTasks }).then(() => {
          toast(`📡 星艦回報：AI 成功為您標記完成任務【${currentTasks[taskIndex].title}】！`);
        });
      } else {
        toast(`📡 星艦警告：找不到與「${taskId}」匹配的任務。`);
      }
    }
  });
}

const defaultFirestoreTasks = [
  {
    id: "task_default_1",
    userId: "",
    title: "完成 2 小時讀書",
    category: "讀書",
    taskType: "fixed",
    priority: "high",
    isDone: false,
    isSystemTask: false,
    isAutoTracked: false,
    sourceType: "manual"
  },
  {
    id: "task_default_2",
    userId: "",
    title: "步行超過 6000 步",
    category: "運動",
    taskType: "fixed",
    priority: "medium",
    isDone: false,
    isSystemTask: false,
    isAutoTracked: false,
    sourceType: "manual"
  },
  {
    id: "task_default_3",
    userId: "",
    title: "運動 30 分鐘",
    category: "運動",
    taskType: "fixed",
    priority: "medium",
    isDone: false,
    isSystemTask: false,
    isAutoTracked: false,
    sourceType: "manual"
  },
  {
    id: "task_default_4",
    userId: "",
    title: "晚上 11:30 前睡覺",
    category: "睡眠",
    taskType: "fixed",
    priority: "high",
    isDone: false,
    isSystemTask: false,
    isAutoTracked: false,
    sourceType: "manual"
  },
  {
    id: "task_default_5",
    userId: "",
    title: "準備期中報告",
    category: "讀書",
    taskType: "deadline",
    priority: "high",
    isDone: false,
    isSystemTask: false,
    isAutoTracked: false,
    sourceType: "manual"
  }
];

function initializeDefaultTasksInFirestore(userId) {
  if (!db) return;
  const docRef = db.collection("users").doc(userId);
  docRef.get().then((docSnap) => {
    if (docSnap.exists) {
      const data = docSnap.data();
      if (!data.tasks || data.tasks.length === 0) {
        const initializedTasks = defaultFirestoreTasks.map(t => ({
          ...t,
          userId: userId,
          createdAt: new Date().toISOString(),
          updatedAt: new Date().toISOString()
        }));
        docRef.update({ tasks: initializedTasks }).then(() => {
          console.log("Initialized default static tasks in Firestore for user: " + userId);
        });
      }
    }
  });
}

function showWebProfileEditModal(data) {
  let overlay = document.getElementById("globalProfileEditModal");
  if (!overlay) {
    // Inject styles
    if (!document.getElementById("globalProfileEditStyles")) {
      const style = document.createElement("style");
      style.id = "globalProfileEditStyles";
      style.textContent = `
        .global-profile-edit-overlay {
          position: fixed;
          inset: 0;
          background: rgba(10, 15, 30, 0.6);
          backdrop-filter: blur(12px) saturate(180%);
          -webkit-backdrop-filter: blur(12px) saturate(180%);
          display: flex;
          align-items: center;
          justify-content: center;
          z-index: 10000;
          opacity: 0;
          pointer-events: none;
          transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
        }
        .global-profile-edit-overlay.active {
          opacity: 1;
          pointer-events: auto;
        }
        .global-profile-edit-modal {
          background: rgba(22, 28, 45, 0.9);
          border: 1px solid rgba(255, 255, 255, 0.1);
          padding: 2rem;
          border-radius: 24px;
          width: 100%;
          max-width: 440px;
          box-shadow: 0 30px 60px rgba(0, 0, 0, 0.4), inset 0 1px 0 rgba(255, 255, 255, 0.1);
          transform: scale(0.9) translateY(20px);
          transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
          color: #fff;
          font-family: inherit;
        }
        .global-profile-edit-overlay.active .global-profile-edit-modal {
          transform: scale(1) translateY(0);
        }
        .global-profile-edit-modal h2 {
          margin-top: 0;
          margin-bottom: 1.5rem;
          font-size: 1.5rem;
          font-weight: 800;
          background: linear-gradient(135deg, #fff 30%, rgba(255,255,255,0.6) 100%);
          -webkit-background-clip: text;
          -webkit-text-fill-color: transparent;
        }
        .global-form-group {
          margin-bottom: 1.25rem;
          text-align: left;
        }
        .global-form-group label {
          display: block;
          font-size: 0.85rem;
          margin-bottom: 0.5rem;
          color: rgba(255, 255, 255, 0.6);
          font-weight: 600;
        }
        .global-form-group input, .global-form-group select {
          width: 100%;
          padding: 0.75rem 1rem;
          border-radius: 10px;
          border: 1px solid rgba(255, 255, 255, 0.12);
          background: rgba(255, 255, 255, 0.05);
          color: #fff;
          box-sizing: border-box;
          font-size: 0.95rem;
          outline: none;
          transition: border-color 0.2s;
        }
        .global-form-group input:focus, .global-form-group select:focus {
          border-color: var(--c-primary, #7c6ae6);
        }
        .color-swatch-group {
          display: flex;
          flex-wrap: wrap;
          gap: 12px;
          margin-top: 8px;
        }
        .color-swatch {
          width: 32px;
          height: 32px;
          border-radius: 50%;
          cursor: pointer;
          border: 2px solid transparent;
          transition: all 0.2s;
          box-sizing: border-box;
        }
        .color-swatch:hover {
          transform: scale(1.15);
        }
        .color-swatch.active {
          border-color: #fff;
          box-shadow: 0 0 10px var(--swatch-color);
        }
        .global-profile-actions {
          display: flex;
          justify-content: flex-end;
          gap: 1rem;
          margin-top: 2rem;
        }
        .global-profile-btn-cancel {
          background: transparent;
          border: 1px solid rgba(255, 255, 255, 0.15);
          color: rgba(255, 255, 255, 0.8);
          padding: 0.6rem 1.4rem;
          border-radius: 10px;
          cursor: pointer;
          font-weight: 600;
          transition: all 0.2s;
        }
        .global-profile-btn-cancel:hover {
          background: rgba(255, 255, 255, 0.05);
          color: #fff;
        }
        .global-profile-btn-submit {
          background: var(--c-primary, #7c6ae6);
          border: none;
          color: white;
          padding: 0.6rem 1.4rem;
          border-radius: 10px;
          cursor: pointer;
          font-weight: 700;
          transition: all 0.2s;
        }
        .global-profile-btn-submit:hover {
          opacity: 0.9;
          transform: translateY(-1px);
        }
      `;
      document.head.appendChild(style);
    }

    const badgeDefinitions = [
      { key: 'task_starter', name: '任務起步者' },
      { key: 'focus_beginner', name: '專注新手' },
      { key: 'focus_streak', name: '專注連續者' },
      { key: 'task_streak', name: '任務連續者' },
      { key: 'sleep_guard', name: '睡眠守護者' },
      { key: 'step_master', name: '步數達人' },
      { key: 'steady_progress', name: '穩定前進' },
      { key: 'score_keeper', name: '高分維持' },
      { key: 'coin_earner', name: '門檻達人' },
      { key: 'auto_tracker', name: '自動追蹤者' },
      { key: 'health_sync', name: '健康同步者' },
      { key: 'health_task', name: '健康任務實踐者' }
    ];

    const unlockedKeys = data.unlockedBadgeDates ? Object.keys(data.unlockedBadgeDates) : [];
    const unlockedBadges = badgeDefinitions.filter(b => unlockedKeys.includes(b.key));
    const currentTitleKey = data.profileTitleBadgeKey || "";

    const colorOptions = [
      { name: 'purple', hex: '#7C6AE6', label: '紫色' },
      { name: 'blue', hex: '#4F8CFF', label: '藍色' },
      { name: 'teal', hex: '#14B8A6', label: '青色' },
      { name: 'green', hex: '#10B981', label: '綠色' },
      { name: 'orange', hex: '#F59E0B', label: '橘色' },
      { name: 'pink', hex: '#EC4899', label: '粉色' },
      { name: 'red', hex: '#EF4444', label: '紅色' },
      { name: 'indigo', hex: '#6366F1', label: '靛藍' }
    ];

    const currentAccent = data.accentColor || 'purple';

    let badgesSelectHtml = `<option value="">不使用稱號</option>`;
    unlockedBadges.forEach(b => {
      badgesSelectHtml += `<option value="${b.key}" ${currentTitleKey === b.key ? 'selected' : ''}>${b.name}</option>`;
    });

    let swatchesHtml = '';
    colorOptions.forEach(opt => {
      swatchesHtml += `
        <div class="color-swatch ${currentAccent === opt.name ? 'active' : ''}" 
             data-color="${opt.name}" 
             style="background: ${opt.hex}; --swatch-color: ${opt.hex};" 
             title="${opt.label}"></div>
      `;
    });

    const modalHtml = `
      <div class="global-profile-edit-overlay" id="globalProfileEditModal">
        <div class="global-profile-edit-modal">
          <h2>⚙️ 編輯個人名片</h2>
          <div class="global-form-group">
            <label>暱稱</label>
            <input type="text" id="editProfileNickname" value="${data.nickname || ''}" placeholder="請輸入自律暱稱" maxLength="12"/>
          </div>
          <div class="global-form-group">
            <label>個性簽名</label>
            <input type="text" id="editProfileSignature" value="${data.signature || ''}" placeholder="今天也在穩定前進" maxLength="40"/>
          </div>
          <div class="global-form-group">
            <label>專屬頭像主題色</label>
            <div class="color-swatch-group" id="editProfileColors">
              ${swatchesHtml}
            </div>
            <input type="hidden" id="editProfileSelectedColor" value="${currentAccent}"/>
          </div>
          <div class="global-form-group">
            <label>名片稱號（僅能選用已解鎖徽章）</label>
            <select id="editProfileTitle">
              ${badgesSelectHtml}
            </select>
          </div>
          <div class="global-profile-actions">
            <button class="global-profile-btn-cancel" onclick="document.getElementById('globalProfileEditModal').classList.remove('active')">取消</button>
            <button class="global-profile-btn-submit" id="saveProfileEditBtn">儲存名片</button>
          </div>
        </div>
      </div>
    `;
    document.body.insertAdjacentHTML('beforeend', modalHtml);

    // Setup color swatch click events
    const swatches = document.querySelectorAll("#editProfileColors .color-swatch");
    swatches.forEach(sw => {
      sw.addEventListener("click", function() {
        swatches.forEach(s => s.classList.remove("active"));
        this.classList.add("active");
        document.getElementById("editProfileSelectedColor").value = this.getAttribute("data-color");
      });
    });

    document.getElementById("saveProfileEditBtn").addEventListener("click", function() {
      const nickname = document.getElementById("editProfileNickname").value.trim();
      const signature = document.getElementById("editProfileSignature").value.trim();
      const accentColor = document.getElementById("editProfileSelectedColor").value;
      const titleBadgeKey = document.getElementById("editProfileTitle").value;

      if (!nickname) {
        toast("請填寫有效的暱稱");
        return;
      }

      const activeUserId = localStorage.getItem("nudgeActiveDemoUserId") || "an_nudge";
      if (activeUserId && typeof db !== "undefined") {
        db.collection("users").doc(activeUserId).update({
          nickname: nickname,
          signature: signature || "今天也在穩定前進",
          accentColor: accentColor,
          profileTitleBadgeKey: titleBadgeKey,
          updatedAt: new Date().toISOString()
        }).then(() => {
          toast("個人名片更新成功！ ✨");
          document.getElementById('globalProfileEditModal').classList.remove('active');
          window.location.reload();
        }).catch(err => {
          console.error("更新名片失敗：", err);
          toast("更新失敗，請稍後再試");
        });
      }
    });
  }

  // Display modal
  overlay = document.getElementById("globalProfileEditModal");
  // Update form inputs to current state in case they were updated
  document.getElementById("editProfileNickname").value = data.nickname || '';
  document.getElementById("editProfileSignature").value = data.signature || '';
  document.getElementById("editProfileSelectedColor").value = data.accentColor || 'purple';
  
  const swatchesEl = document.querySelectorAll("#editProfileColors .color-swatch");
  swatchesEl.forEach(sw => {
    if (sw.getAttribute("data-color") === (data.accentColor || 'purple')) {
      sw.classList.add("active");
    } else {
      sw.classList.remove("active");
    }
  });

  const selectEl = document.getElementById("editProfileTitle");
  if (selectEl) selectEl.value = data.profileTitleBadgeKey || "";

  overlay.classList.add("active");
}
