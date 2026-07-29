const $ = (selector, root = document) => root.querySelector(selector);
const $$ = (selector, root = document) => Array.from(root.querySelectorAll(selector));

function loadWindowModule(globalKey, source, errorMessage) {
  if (window[globalKey]) {
    return Promise.resolve(window[globalKey]);
  }
  window.nudgeModulePromises ||= {};
  if (window.nudgeModulePromises[globalKey]) {
    return window.nudgeModulePromises[globalKey];
  }

  window.nudgeModulePromises[globalKey] = new Promise((resolve, reject) => {
    const script = document.createElement("script");
    script.src = source;
    script.onload = () => resolve(window[globalKey]);
    script.onerror = () => reject(new Error(errorMessage));
    document.head.appendChild(script);
  }).catch(error => {
    delete window.nudgeModulePromises[globalKey];
    throw error;
  });
  return window.nudgeModulePromises[globalKey];
}

function loadRelationshipCapabilities() {
  return loadWindowModule(
    "NudgeRelationshipCapabilities",
    "assets/relationship_capabilities.js?v=1",
    "角色能力模組載入失敗",
  );
}

function loadFamilyLinkContract() {
  return loadWindowModule(
    "NudgeFamilyLinkContract",
    "assets/family_link_contract.js?v=1",
    "家庭連結契約模組載入失敗",
  );
}

function loadGroupContract() {
  return loadWindowModule(
    "NudgeGroupContract",
    "assets/group_contract.js?v=2",
    "團體契約模組載入失敗",
  );
}

function loadRoomActivitySessionContract() {
  return loadWindowModule(
    "NudgeRoomActivitySessionContract",
    "assets/room_activity_session_contract.js?v=2",
    "活動房紀錄契約模組載入失敗",
  );
}

function loadActivityLedgerClient() {
  return loadWindowModule(
    "NudgeActivityLedgerClient",
    "assets/activity_ledger_client.js?v=1",
    "Activity Ledger 模組載入失敗",
  );
}

function isPreviewMode() {
  return localStorage.getItem("nudgePreviewMode") === "true";
}

function buildPreviewProfile() {
  const previewRole = localStorage.getItem("nudgePreviewRole") || "personal";
  const isGroupPreview = previewRole === "groupManager" || previewRole === "groupMember";
  const isFamilyPreview = previewRole === "guardian" || previewRole === "child";
  const rawRole = isGroupPreview ? "group" : previewRole;

  return {
    nickname: "展示使用者",
    myNudgeId: "NDG-PREVIEW",
    username: "NDG-PREVIEW",
    signature: "目前正在查看不會寫入資料的展示介面",
    accentColor: "purple",
    disciplineCoins: 100,
    planetCount: 1,
    userRole: rawRole,
    groupId: isGroupPreview ? "PREVIEW-GROUP" : null,
    groupName: isGroupPreview ? "自律同行示範團" : null,
    isGroupOwner: previewRole === "groupManager",
    webToolsState: isFamilyPreview
      ? {
          guardianInvite: { relativeId: "NDG-FAMILY" },
          guardianInviteStatus: { status: "linked" },
        }
      : {},
  };
}

function buildRelationshipCapabilityInput(data = {}) {
  const preview = isPreviewMode();
  const userId =
    typeof firebase !== "undefined" ? firebase.auth().currentUser?.uid : null;
  const canonicalMember =
    !preview &&
    groupLoaded &&
    window.NudgeGroupContract?.isGroupMember(activeWebGroup, userId);
  const canonicalManager =
    canonicalMember &&
    window.NudgeGroupContract?.isGroupManager(activeWebGroup, userId);

  return {
    rawRole: data.userRole,
    familyLinked:
      Boolean(activeFamilyLink) ||
      (preview && ["guardian", "child"].includes(data.userRole)),
    hasGroup: preview ? Boolean(data.groupId) : Boolean(canonicalMember),
    isGroupOwner: preview
      ? Boolean(data.isGroupOwner)
      : Boolean(canonicalManager),
    isFamilyGuardian: preview
      ? data.userRole === "guardian"
      : activeFamilyLink?.guardianId === userId,
    isFamilyChild: preview
      ? data.userRole === "child"
      : activeFamilyLink?.childId === userId,
    isAuthenticated: localStorage.getItem("nudgeWebLoggedIn") === "true",
    isPreview: preview,
  };
}

function resolveWebCapabilities(data = {}) {
  const resolver =
    window.NudgeRelationshipCapabilities?.resolveRelationshipCapabilities;
  if (!resolver) {
    throw new Error("角色能力模組尚未就緒");
  }

  return resolver(buildRelationshipCapabilityInput(data));
}

function resolveWebRoleGateRedirect(path, data = {}) {
  const resolver =
    window.NudgeRelationshipCapabilities?.resolveRoleGateRedirect;
  if (!resolver) {
    throw new Error("角色能力模組尚未就緒");
  }

  return resolver(path, buildRelationshipCapabilityInput(data));
}

function escapeHtml(value) {
  return String(value ?? "").replace(/[&<>"']/g, character => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': "&quot;",
    "'": "&#39;"
  })[character]);
}

const modules = [
  ["home", "總覽入口", "dashboard.html"],
  ["personal", "個人進階分析", "personal.html"],
  ["guardian", "家長陪伴中心", "guardian.html"],
  ["groups", "團體 / 教育管理", "groups.html"],
  ["rooms", "我的活動房", "rooms.html"],
  ["operations", "商城頁", "operations.html"],
  ["research", "研究中心", "research.html"],
  ["friend", "好友功能", "friend.html"],
  ["planet", "自律星球", "planet.html"],
  ["presentation", "專題發表流程", "presentation.html"],
  ["profile", "個人名片", "profile.html"],
  ["notifications", "通知與邀請", "notifications.html"],
  ["privacy", "隱私與資料", "privacy.html"],
];

// Authentication Check
const pathName = window.location.pathname;
const isPublicPage = pathName.endsWith("/") || pathName.endsWith("index.html") || pathName.endsWith("dashboard.html") || pathName.endsWith("login.html") || pathName.includes("admin_dashboard.html");
if (!isPublicPage && localStorage.getItem("nudgeWebLoggedIn") !== "true") {
  localStorage.setItem("nudgePostLoginRedirect", pathName.split("/").pop() || "dashboard.html");
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
  if (path.includes("dashboard.html")) {
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
    logoutBtn.textContent = "登出帳號";
    logoutBtn.addEventListener("click", (e) => {
      e.preventDefault();
      localStorage.removeItem("nudgeWebLoggedIn");
      localStorage.removeItem("nudgeActiveDemoUserId");

      if (typeof firebase !== 'undefined' && firebase.auth) {
        firebase.auth().signOut().then(() => {
          window.location.href = "dashboard.html"; // 登出後回到總覽頁面
        }).catch(err => {
          console.error("Firebase sign out failed:", err);
          window.location.href = "dashboard.html";
        });
      } else {
        window.location.href = "dashboard.html";
      }
    });
    nav.appendChild(logoutBtn);
  } else {
    // 若未登入，也可選擇顯示「登入」按鈕
    const loginBtn = document.createElement("a");
    loginBtn.href = "login.html";
    loginBtn.style.marginTop = "16px";
    loginBtn.style.color = "var(--page-accent)";
    loginBtn.textContent = "登入 / 註冊";
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
    if (node.dataset.animateCount !== "true") {
      node.textContent = `${target}${suffix}`;
      return;
    }
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
  if (!window.location.pathname.endsWith("guardian-report.html")) {
    drawLineChart($("#sleepChart"), [5.8, 6.1, 5.6, 6.8, 7.0, 6.4, 7.2], "#8d7aff");
  }
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
  if (isPreviewMode()) return;

  // Sync to Firestore if user logged in
  const activeUserId = localStorage.getItem("nudgeActiveDemoUserId");
  if (activeUserId && typeof db !== 'undefined' && db) {
    db.collection("users").doc(activeUserId).update({
      [`webToolsState.${key}`]: current[key]
    }).catch(e => console.warn("Firestore update error:", e));

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
    const message = $('[data-guardian-message]', guardianTool).value.trim();
    setOutput(
      guardianTool,
      `<strong>${escapeHtml(goal)}</strong><p>陪伴訊息：「${escapeHtml(message)}」孩子接受後才會匯入任務；資料分享範圍仍由孩子控制。</p>`,
    );
    toast("目標預覽已更新");
  });
  guardianTool?.querySelector('[data-action="send-guardian"]')?.addEventListener("click", async () => {
    const goal = $('[data-guardian-goal]', guardianTool).value;
    const message = $('[data-guardian-message]', guardianTool).value.trim();
    try {
      await sendWebFamilyGoal(goal, message);
      toast("共同目標已送出，等待孩子決定");
    } catch (error) {
      console.error(error);
      toast(error.message || "共同目標送出失敗");
    }
  });

  let challengeText = "";
  challengeTool?.querySelector('[data-action="generate-challenge"]')?.addEventListener("click", async () => {
    const group = activeWebGroup?.name ||
      $('[data-challenge-group]', challengeTool).value.trim() ||
      "未命名團體";
    const type = $('[data-challenge-type]', challengeTool).value;
    const days = Number($('[data-challenge-days]', challengeTool).value || 7);
    const reward = $('[data-challenge-reward]', challengeTool).value;
    challengeText = `${group} ${days} 日${type}\n獎勵：${reward}\n規則：每日完成目標得 1 點，連續完成加成，排行榜只顯示前 10 名。`;
    setOutput(
      challengeTool,
      `<strong>${group}：${days} 日${type}</strong><p>獎勵為 ${reward}，系統會自動產生排行榜、提醒節奏與活動週報。</p>`,
    );
    if (isPreviewMode()) {
      saveDemoState("challenge", { group, type, days, reward });
      toast("展示模式：挑戰草稿已建立");
      return;
    }
    try {
      await publishCanonicalWebGroupChallenge({ type, days, reward });
      toast("團體挑戰已同步到成員 App");
    } catch (error) {
      console.error(error);
      toast(error.message || "團體挑戰發布失敗");
    }
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
          <strong>${escapeHtml(item.title)}</strong>
          <span>${escapeHtml(item.meta)}</span>
          <button class="${key === "studySchedules" && item.id && !isPreviewMode() ? "delete-group-schedule-btn" : "delete-btn"}" data-key="${key}" data-index="${index}" data-schedule-id="${escapeHtml(item.id || "")}" style="position: absolute; right: 10px; top: 10px; background: transparent; border: none; color: #ff3b3b; cursor: pointer; font-family: monospace;">[刪除]</button>
        </article>
      `)
      .join("");
  };
  window.renderSavedList = renderSavedList;

  // Delegate delete events globally
  document.body.addEventListener("click", (e) => {
    if (e.target.matches(".delete-group-schedule-btn")) {
      const scheduleId = e.target.dataset.scheduleId;
      deleteCanonicalWebStudySchedule(scheduleId)
        .then(() => toast("已刪除團體自律時段"))
        .catch(error => {
          console.error(error);
          toast(error.message || "時段刪除失敗");
        });
      return;
    }
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
    if (isPreviewMode()) return;

    // Sync to Firestore if user logged in
    const activeUserId = localStorage.getItem("nudgeActiveDemoUserId");
    if (activeUserId && typeof db !== 'undefined' && db) {
      db.collection("users").doc(activeUserId).update({
        [`webToolsCollection.${key}`]: items,
        [`webToolsCollection.${key}UpdatedAt`]: current[`${key}UpdatedAt`]
      }).catch(e => console.warn("Firestore update error:", e));

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
  encouragementTool?.querySelector('[data-action="send-encouragement"]')?.addEventListener("click", async () => {
    const card = encouragementTool.querySelector('.generated-card');
    if (card) {
      card.classList.add("toss-animation");
      setTimeout(() => {
        card.classList.remove("toss-animation");
      }, 400);
    }

    const type = $('[data-encourage-type]', encouragementTool)?.value || "今天也辛苦了";
    const msg = $('[data-encourage-message]', encouragementTool)?.value.trim() || "";
    try {
      await sendWebFamilyEncouragement(type, msg);
      toast("鼓勵卡已同步到孩子 App");
    } catch (error) {
      console.error(error);
      toast(error.message || "鼓勵卡送出失敗");
    }
  });

  studyScheduleTool?.querySelector('[data-action="save-study-schedule"]')?.addEventListener("click", async () => {
    const title = $('[data-study-title]', studyScheduleTool).value.trim() || "未命名共讀";
    const time = $('[data-study-time]', studyScheduleTool).value || "未設定";
    const duration = $('[data-study-duration]', studyScheduleTool).value;
    const room = $('[data-study-room]', studyScheduleTool).value;
    setOutput(studyScheduleTool, `<strong>${title}</strong><p>${time}，${duration}，將建立${room}並排程提醒。</p>`);
    const meta = `${time} / ${duration} / ${room}`;
    if (isPreviewMode()) {
      const store = JSON.parse(localStorage.getItem("nudgeWebTools") || "{}");
      const studySchedules = store.studySchedules || [];
      studySchedules.unshift({ title, meta });
      saveToolCollection("studySchedules", studySchedules.slice(0, 50));
      renderSavedList("[data-study-list]", "studySchedules", "<article><strong>尚未排程</strong><span>新增讀書時段後會出現在這裡。</span></article>");
      toast("展示模式：讀書時段已建立");
      return;
    }
    try {
      await publishCanonicalWebStudySchedule({ title, meta });
      toast("讀書時段已同步到成員 App");
    } catch (error) {
      console.error(error);
      toast(error.message || "讀書時段發布失敗");
    }
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
        <div class="ai-header-title">Nudge 智慧助理</div>
        <div>
          <button class="ai-close-btn" id="aiCloseBtn">✕</button>
        </div>
      </div>

      <div class="ai-chat-body" id="aiChatBody">
        <div class="ai-msg">你好，我可以協助整理頁面重點、說明資料狀態，或建議下一步自律行動。</div>
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
      ? `目前使用者的自律任務列表如下：\n` + currentUserTasks.map(t => `- 任務名稱: "${t.title}" (ID: ${t.id}, 狀態: ${t.isDone || t.done ? '已完成' : '未完成'})`).join('\n')
      : `目前無活躍任務。`;

    const summariesContext = (currentUserDailySummaries && currentUserDailySummaries.length > 0)
      ? `近期每日自律數據摘要如下：\n` + currentUserDailySummaries.slice(-5).map(s => `- 日期: ${s.date}, 步數: ${s.steps}, 睡眠: ${s.sleepHours}小時, 專注: ${s.focusMinutes}分鐘, 完成任務: ${s.completedTasks}/${s.totalTasks}`).join('\n')
      : `無近期數據。`;

    const systemText = `你是一個名為 Nudge 的智慧助理，同時也是溫和且專業的「Nudge 自律導師」。你負責協助使用者理解目前頁面、整理自律資料，並提供下一步時間管理與自律任務建議。回答要簡潔、有操作性，不要給出落落長的文章。
如果使用者要求開始專注、倒數計時，請加上：[ACTION:START_FOCUS:分鐘數]
如果使用者要求新增任務，請加上：[ACTION:ADD_TASK:任務名稱]
如果使用者要求前往某個頁面(例如總覽、家長中心、營運後台等)，請加上：[ACTION:NAVIGATE:該頁面網址.html] (頁面包含: dashboard.html, personal.html, guardian.html, groups.html, operations.html, planet.html, friend.html)。
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
      const plot = satClass ? $("." + satClass.replace("s", "p")) : null; // for city view

      if (e.target.checked) {
        if (plot) {
          plot.classList.add("built");
          plot.classList.add("built-" + taskType);
        }
        showCombo(false);
      } else {
        if (plot) {
          plot.classList.remove("built", "built-study", "built-health", "built-general", "built-skyscraper");
        }
        currentCombo = 0;
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

  const loadExamTemplates = () => {
    const store = JSON.parse(localStorage.getItem("nudgeWebTools") || "{}");
    return store.groupTemplates || [];
  };

  const renderExamTemplates = (templates = loadExamTemplates()) => {
    templateListContainer.innerHTML = templates.length
      ? templates.map(tpl => `
      <article>
        <button type="button" class="delete-template-btn" data-template-id="${escapeHtml(tpl.id || "")}" title="刪除">×</button>
        <small>${escapeHtml(`${tpl.days || 7} 天`)}</small>
        <strong>${escapeHtml(tpl.type || "未命名模板")}</strong>
        <span>${escapeHtml(tpl.effort || "")}</span>
        <span>${escapeHtml(tpl.strategy || "")}</span>
      </article>
    `).join("")
      : `<article><small>尚未發布</small><strong>建立第一個團體模板</strong><span>發布後，成員 App 會讀取同一份團體資料。</span></article>`;

    $$(".delete-template-btn", templateListContainer).forEach(btn => {
      btn.addEventListener("click", async (e) => {
        const templateId = e.currentTarget.dataset.templateId;
        if (isPreviewMode() || !templateId) {
          toast("展示模式不會刪除正式資料");
          return;
        }
        try {
          await deleteCanonicalWebGroupTemplate(templateId);
          toast("已刪除團體模板");
        } catch (error) {
          console.error(error);
          toast(error.message || "模板刪除失敗");
        }
      });
    });
  };
  window.renderCanonicalGroupTemplates = renderExamTemplates;

  renderExamTemplates();

  const addBtn = $('[data-action="add-template"]');
  if (addBtn) {
    addBtn.addEventListener("click", async () => {
      const daysInput = $('[data-template-days]');
      const typeInput = $('[data-template-title]');
      const effortInput = $('[data-template-desc]');
      const strategyInput = $('[data-template-strategy]');
      const payload = {
        type: typeInput.value.trim(),
        days: Number(daysInput.value || 7),
        effort: effortInput.value.trim(),
        strategy: strategyInput.value.trim(),
      };

      if (isPreviewMode()) {
        toast("展示模式：模板預覽已建立，不會寫入正式資料");
        return;
      }
      try {
        await publishCanonicalWebGroupTemplate(payload);
        typeInput.value = "";
        effortInput.value = "";
        strategyInput.value = "";
        toast("團體模板已同步到成員 App");
      } catch (error) {
        console.error(error);
        toast(error.message || "模板發布失敗");
      }
    });
  }
}

window.addEventListener("DOMContentLoaded", () => {
  try { injectSidebarControls(); } catch(e){}
  try { injectModuleMenu(); } catch(e){}
  try { injectAdminSwitch(); } catch(e){ console.warn("Admin switch init failed:", e); }
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
  try { renderCanonicalGroupRanking(); } catch(e){}
  try { renderCanonicalWebGroupMembers(); } catch(e){}
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
  if (window.__nudgeAdminSwitchInitialized) return;
  window.__nudgeAdminSwitchInitialized = true;

  const existingBtn1 = document.querySelector('.admin-switch-btn');
  if (existingBtn1) existingBtn1.remove();
  const existingBtn2 = document.querySelector('.exit-admin-btn');
  if (existingBtn2) existingBtn2.remove();

  const isAdminPage = window.location.pathname.includes('admin_dashboard.html');

  if (!document.getElementById('globalAdminSwitchStyle')) {
    const style = document.createElement('style');
    style.id = 'globalAdminSwitchStyle';
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
  }

  const main = document.querySelector('.main');
  if (main) main.style.position = 'relative';
  const btnContainer = main || document.body;

  if (isAdminPage) {
    const btn = document.createElement('button');
    btn.className = 'global-admin-switch-btn';
    btn.innerHTML = '⚙ 切回前台';
    btn.onclick = () => window.location.href = 'dashboard.html';
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
                <input type="text" id="gAdminUsername" placeholder="請使用 Firebase 帳號登入" />
              </div>
              <div class="global-form-group">
                <label>密碼</label>
                <input type="password" id="gAdminPassword" placeholder="請輸入後台帳號密碼" />
              </div>
              <div class="global-error-msg" id="gLoginError">請輸入帳號與密碼。</div>
              <div class="global-login-actions">
                <button class="global-btn-cancel" onclick="document.getElementById('globalLoginModal').classList.remove('active')">取消</button>
                <button class="global-btn-submit" id="gAdminSubmitBtn" onclick="gAttemptLogin()">登入</button>
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

    window.gAttemptLogin = async function() {
      const user = document.getElementById('gAdminUsername').value.trim();
      const pass = document.getElementById('gAdminPassword').value;
      const errorNode = document.getElementById('gLoginError');
      const submitBtn = document.getElementById('gAdminSubmitBtn');
      if (!user || !pass) {
        errorNode.textContent = '請輸入帳號與密碼。';
        errorNode.style.display = 'block';
        return;
      }

      try {
        errorNode.style.display = 'none';
        submitBtn.disabled = true;
        submitBtn.textContent = '登入中...';

        await loadFirebaseSDKs();
        if (typeof firebase === 'undefined' || !firebase.auth) {
          throw new Error('Firebase 尚未載入，請確認網路連線後重試。');
        }
        if (!firebase.apps.length) {
          firebase.initializeApp(firebaseConfig);
        }

        const auth = firebase.auth();
        await auth.setPersistence(firebase.auth.Auth.Persistence.LOCAL);
        const credential = await auth.signInWithEmailAndPassword(user, pass);
        localStorage.setItem('nudgeWebLoggedIn', 'true');
        localStorage.setItem('nudgeActiveDemoUserId', credential.user.uid);
        localStorage.removeItem('nudgePostLoginRedirect');
        window.location.href = 'admin_dashboard.html';
      } catch (err) {
        submitBtn.disabled = false;
        submitBtn.textContent = '登入';
        errorNode.textContent = '後台登入失敗：' + err.message;
        errorNode.style.display = 'block';
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

async function bootFirebaseBackedData() {
  try {
    await Promise.all([
      loadRelationshipCapabilities(),
      loadFamilyLinkContract(),
      loadGroupContract(),
    ]);
  } catch (error) {
    console.error(error);
    return;
  }

  setTimeout(() => {
    try { injectAdminSwitch(); } catch(e){ console.warn("Admin switch init failed:", e); }
  }, 100);

  // Render initial sidebar profile card from cache immediately
  const cachedData = isPreviewMode() ? buildPreviewProfile() : {
    nickname: localStorage.getItem("nudgeNicknameCache") || "自律使用者",
    myNudgeId: localStorage.getItem("nudgeActiveDemoUserId") || "NDG-Guest",
    username: localStorage.getItem("nudgeActiveDemoUserId") || "NDG-Guest",
    signature: localStorage.getItem("nudgeSignatureCache") || "今天也在穩定前進",
    accentColor: localStorage.getItem("nudgeAccentColorCache") || "purple",
    profileTitleBadgeKey: localStorage.getItem("nudgeTitleBadgeCache") || "",
    disciplineCoins: parseInt(localStorage.getItem("nudgeCoinsCache") || "100"),
    planetCount: parseInt(localStorage.getItem("nudgePlanetsCache") || "1"),
    userRole: localStorage.getItem("nudgeRoleCache") || "personal"
  };
  try { updateSidebarProfile(cachedData); } catch(e){}
  if (isPreviewMode()) injectPreviewRoleBanner(cachedData);

  if (document.body.dataset.page === "operations") {
    const prosperityElement = document.querySelector(".hero-card strong");
    if (prosperityElement) {
      const coins = localStorage.getItem("nudgeCoinsCache") || "0";
      prosperityElement.dataset.count = coins;
      prosperityElement.textContent = coins;
    }
  }

  try { initializeFirebaseWeb(); } catch(e){}
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", bootFirebaseBackedData);
} else {
  bootFirebaseBackedData();
}

// ─── Firebase / Firestore Real-time Sync Integration ──────────────────────────

const firebaseConfig = {
  apiKey: "AIzaSyCsvP-r0EygpkhH0Zwzfrl4uFzy6LcbsTQ",
  authDomain: "nudge-discipline-app.firebaseapp.com",
  projectId: "nudge-discipline-app",
  storageBucket: "nudge-discipline-app.firebasestorage.app",
  messagingSenderId: "497972469632",
  appId: "1:497972469632:web:cb87819a70c7cb8f2f6b65"
};

function loadWebRuntimeConfig() {
  if (window.nudgeRuntimeConfigPromise) {
    return window.nudgeRuntimeConfigPromise;
  }
  if (window.NUDGE_RUNTIME_CONFIG) {
    return Promise.resolve(window.NUDGE_RUNTIME_CONFIG);
  }
  window.nudgeRuntimeConfigPromise = new Promise(resolve => {
    const source = "assets/runtime-config.js";
    const existing = document.querySelector(`script[src="${source}"]`);
    if (existing) {
      existing.addEventListener(
        "load",
        () => resolve(window.NUDGE_RUNTIME_CONFIG || {}),
        { once: true },
      );
      existing.addEventListener("error", () => resolve({}), { once: true });
      return;
    }
    const script = document.createElement("script");
    script.src = source;
    script.onload = () => resolve(window.NUDGE_RUNTIME_CONFIG || {});
    script.onerror = () => {
      console.warn(
        "Web runtime config is missing; App Check protected features are disabled.",
      );
      resolve({});
    };
    document.head.appendChild(script);
  });
  return window.nudgeRuntimeConfigPromise;
}

function configureFirebaseAppCheckDebugToken() {
  const localHost = ["localhost", "127.0.0.1", "::1"].includes(
    window.location.hostname,
  );
  const token = window.NUDGE_FIREBASE_APP_CHECK_DEBUG_TOKEN;
  const validToken =
    token === true ||
    (typeof token === "string" && token.trim().length >= 8);
  if (!localHost || !validToken) {
    return false;
  }
  self.FIREBASE_APPCHECK_DEBUG_TOKEN =
    token === true ? true : token.trim();
  console.info("Firebase App Check debug provider enabled for localhost.");
  return true;
}

function loadFirebaseSDKs() {
  if (window.nudgeFirebaseSdkPromise) {
    return window.nudgeFirebaseSdkPromise;
  }
  const loadScript = (source, isReady) => {
    if (isReady()) return Promise.resolve();
    return new Promise((resolve, reject) => {
      const existing = document.querySelector(`script[src="${source}"]`);
      if (existing) {
        existing.addEventListener("load", resolve, { once: true });
        existing.addEventListener("error", reject, { once: true });
        return;
      }
      const script = document.createElement("script");
      script.src = source;
      script.onload = resolve;
      script.onerror = reject;
      document.head.appendChild(script);
    });
  };
  const sdk = "https://www.gstatic.com/firebasejs/9.22.0";
  window.nudgeFirebaseSdkPromise = (async () => {
    await loadScript(
      `${sdk}/firebase-app-compat.js`,
      () => Boolean(window.firebase),
    );
    await loadScript(
      `${sdk}/firebase-auth-compat.js`,
      () => Boolean(window.firebase?.auth),
    );
    await loadScript(
      `${sdk}/firebase-firestore-compat.js`,
      () => Boolean(window.firebase?.firestore),
    );
    await loadScript(
      `${sdk}/firebase-storage-compat.js`,
      () => Boolean(window.firebase?.storage),
    );
    await loadScript(
      `${sdk}/firebase-functions-compat.js`,
      () => Boolean(window.firebase?.functions),
    );
    await loadScript(
      `${sdk}/firebase-app-check-compat.js`,
      () => Boolean(window.firebase?.appCheck),
    );
  })();
  return window.nudgeFirebaseSdkPromise;
}

let db = null;
let storage = null;
let functions = null;
const CURRENT_PRIVACY_POLICY_VERSION = "2026-07-29";
let webActivityLedgerOutbox = null;
let webPrivacyConsentSub = null;
let currentWebPrivacyConsent = null;
let webPrivacyDataRequestSub = null;
let currentWebPrivacyDataRequests = [];
let webPrivacyDataRequestUpdating = false;
let webNotificationPreferenceSub = null;
let currentWebNotificationPreferences = null;
let webNotificationPreferenceUpdating = false;
let webUserNotificationSub = null;
let currentWebUserNotifications = [];
const WEB_NOTIFICATION_CHANNELS = {
  tasks: {
    title: "任務提醒",
    description: "提醒尚未完成的今日可執行任務。",
    enabled: true,
    timeLabel: "20:30",
  },
  sleep: {
    title: "睡眠提醒",
    description: "睡前提醒，幫助健康任務穩定累積。",
    enabled: true,
    timeLabel: "23:00",
  },
  rooms: {
    title: "自律房提醒",
    description: "提醒你回到正在共同進步的活動房。",
    enabled: true,
    timeLabel: "19:30",
  },
  deadline: {
    title: "截止日提醒",
    description: "截止日前提醒拆任務與驗收。",
    enabled: true,
    timeLabel: "09:00",
  },
};
const WEB_NOTIFICATION_TIME_OPTIONS = [
  "07:30",
  "09:00",
  "12:30",
  "18:30",
  "19:30",
  "20:30",
  "22:30",
  "23:00",
];
let activeFamilyLink = null;
let activeFamilyLinks = [];
let currentFamilySummary = null;
let currentFamilyRelationshipOutcome = null;
let currentFamilyRelationshipMemories = [];
let currentWebUserData = null;
let familyLinkLoaded = false;
let activeWebGroup = null;
let activeWebGroups = [];
let activeWebGroupSummaries = [];
let activeWebGroupChallengeParticipants = [];
let currentGroupRelationshipOutcome = null;
let groupLoaded = false;
let familyLinkSub = null;
let familyEncouragementSub = null;
let familyGoalSub = null;
let familySummarySub = null;
let familyOutcomeSub = null;
let familyMemoriesSub = null;
let groupDocSub = null;
let groupChallengeSub = null;
let groupChallengeParticipantsSub = null;
let groupSchedulesSub = null;
let groupTemplatesSub = null;
let groupMemberSummariesSub = null;
let groupOutcomeSub = null;
let listeningWebGroupId = undefined;
let webRoomsSub = null;
let webRoomMemberSub = null;
let webRoomSessionsSub = null;
let webRoomContributionsSub = null;
let webRoomMessagesSub = null;
let webRoomEventsSub = null;
let activeWebRoom = null;
let activeWebRoomMember = null;
let activeWebRoomMembers = [];
let activeWebRoomSession = null;
let activeWebRoomContribution = null;

function configuredAppCheckSiteKey() {
  return String(
    window.NUDGE_RUNTIME_CONFIG?.firebaseAppCheckSiteKey ||
    window.NUDGE_FIREBASE_APP_CHECK_SITE_KEY ||
    document.querySelector('meta[name="firebase-app-check-site-key"]')?.content ||
    "",
  ).trim();
}

function initializeFirebaseAppCheck() {
  const siteKey = configuredAppCheckSiteKey();
  if (!firebase.appCheck || !siteKey) {
    console.warn(
      "Firebase App Check site key is not configured; protected Cloud ingestion will remain queued.",
    );
    return false;
  }
  try {
    firebase.appCheck().activate(siteKey, true);
    return true;
  } catch (error) {
    if (!String(error?.message || "").includes("already been activated")) {
      console.warn("Firebase App Check initialization failed:", error);
      return false;
    }
    return true;
  }
}

async function ensureWebActivityLedgerOutbox() {
  if (webActivityLedgerOutbox) return webActivityLedgerOutbox;
  const ledger = await loadActivityLedgerClient();
  webActivityLedgerOutbox = ledger.createActivityLedgerOutbox({
    storage: localStorage,
    getActorId: () => firebase.auth().currentUser?.uid || null,
    call: async payload => {
      if (!functions || !firebase.auth().currentUser) {
        const error = new Error("Activity Ledger 尚未連線或使用者尚未登入。");
        error.code = "functions/unauthenticated";
        throw error;
      }
      if (!configuredAppCheckSiteKey()) {
        const error = new Error(
          "Activity Ledger 等待 Firebase App Check 正式設定。",
        );
        error.code = "functions/unavailable";
        throw error;
      }
      const response = await functions.httpsCallable("recordActivity")(payload);
      return response.data;
    },
  });
  return webActivityLedgerOutbox;
}

async function queueWebRoomLedgerTransition({
  session,
  previousStatus = null,
  nextStatus,
}) {
  const ledger = await loadActivityLedgerClient();
  const evidence = ledger.buildRoomActivityEvidence({
    session,
    previousStatus,
    nextStatus,
  });
  const outbox = await ensureWebActivityLedgerOutbox();
  await outbox.enqueue(evidence);
  outbox.flush().then(report => {
    if (report.retryBlocked) {
      toast("活動已保存，Cloud Ledger 將在連線恢復後重送");
    }
  }).catch(error => {
    console.warn("Activity Ledger flush failed:", error);
  });
}

window.queueWebStandaloneFocusLedgerEvent = async ({
  sessionId,
  eventType,
  elapsedSeconds,
  occurredAt = new Date(),
}) => {
  const ledger = await loadActivityLedgerClient();
  const evidence = ledger.buildStandaloneFocusEvidence({
    sessionId,
    eventType,
    elapsedSeconds,
    occurredAt,
  });
  const outbox = await ensureWebActivityLedgerOutbox();
  await outbox.enqueue(evidence);
  outbox.flush().then(report => {
    if (report.retryBlocked) {
      toast("專注事件已離線保存，登入或連線恢復後會自動同步");
    }
  }).catch(error => {
    console.warn("Standalone focus Ledger flush failed:", error);
  });
  return { queued: true };
};

function roomUsesTrustedHealthAdapter(room = {}) {
  return Boolean(
    window.NudgeRoomActivitySessionContract
      ?.requiresTrustedHealthAdapter(room),
  );
}

function roomActivityKind(room = {}) {
  const roomType = String(room.roomType || "study");
  if (roomType === "study") return "focus";
  if (["sleep", "exercise", "steps", "custom"].includes(roomType)) {
    return roomType;
  }
  return "custom";
}

function roomMetricUnit(room = {}) {
  const source = String(room.goalSourceType || "");
  if (source === "sleepHours") return "hours";
  if (source === "steps") return "steps";
  if (source === "exerciseMinutes") return "minutes";
  return "minutes";
}

function roomSessionTargetValue(room = {}) {
  const value = Math.max(0.1, Number(room.dailyGoalValue || 1));
  return room.goalSourceType === "studyRoom" ? value * 60 : value;
}

function roomTypeLabel(room = {}) {
  return ({
    study: "專注",
    sleep: "睡眠",
    exercise: "運動",
    steps: "步數",
    custom: "自訂自律",
  })[room.roomType] || "自律";
}

function roomSessionStatusLabel(status) {
  return ({
    active: "進行中",
    paused: "已暫停",
    completed: "已完成",
    cancelled: "已取消",
    verified: "Ledger 已驗證",
  })[status] || "尚未開始";
}

function renderWebRoomSessionPanel() {
  const panel = $("[data-room-session-panel]");
  if (!panel) return;
  if (!activeWebRoom) {
    panel.innerHTML = `
      <div class="room-empty-state">
        <span>選擇一個活動房</span>
        <strong>你的活動節奏由你決定</strong>
        <p>從左側選擇已加入的房間，再開始自己的紀錄。</p>
      </div>`;
    return;
  }

  const memberApproved = activeWebRoomMember?.approvalStatus === "approved";
  const trustedHealthOnly = roomUsesTrustedHealthAdapter(activeWebRoom);
  const legacyStatus = activeWebRoomSession?.status;
  const status =
    activeWebRoomContribution &&
    (!legacyStatus || ["completed", "cancelled"].includes(legacyStatus))
      ? "verified"
      : legacyStatus;
  const metricValue = Number(
    activeWebRoomContribution?.metricValue ??
    activeWebRoomSession?.metricValue ??
    0,
  );
  const unit =
    activeWebRoomContribution?.metricUnit ||
    activeWebRoomSession?.metricUnit ||
    roomMetricUnit(activeWebRoom);
  const target = Number(
    activeWebRoomSession?.targetValue ||
    activeWebRoom.dailyGoalValue ||
    1,
  );
  const progress = Math.min(100, Math.max(0, target > 0 ? metricValue / target * 100 : 0));
  const controls = !memberApproved
    ? `<div class="room-approval-note">等待房間管理者核准加入；核准後，你仍然自行控制自己的活動。</div>`
    : trustedHealthOnly
      ? `<div class="room-approval-note">此房間使用受信任健康資料；請從 App 觸發 Health Connect／Apple Health 同步，Web 不接受手動輸入。</div>`
    : !status || ["completed", "cancelled", "verified"].includes(status)
      ? `<button class="primary-btn" type="button" data-room-start>開始我的紀錄</button>`
      : `
        ${status === "active"
          ? `<button class="secondary-btn" type="button" data-room-transition="paused">暫停</button>`
          : `<button class="primary-btn" type="button" data-room-transition="active">繼續</button>`}
        <button class="primary-btn" type="button" data-room-transition="completed">完成</button>
        <button class="secondary-btn" type="button" data-room-transition="cancelled">取消本輪</button>`;

  panel.innerHTML = `
    <div class="room-session-heading">
      <div>
        <span class="eyebrow">${escapeHtml(roomTypeLabel(activeWebRoom))} Activity</span>
        <h2>${escapeHtml(activeWebRoom.name || "未命名活動房")}</h2>
        <p>${escapeHtml(activeWebRoom.description || "和同儕在各自的節奏裡一起前進。")}</p>
      </div>
      <span class="room-session-status status-${escapeHtml(status || "idle")}">${escapeHtml(roomSessionStatusLabel(status))}</span>
    </div>
    <div class="room-progress-card">
      <div><span>我的進度</span><strong>${metricValue.toLocaleString("zh-TW")} / ${target.toLocaleString("zh-TW")} ${escapeHtml(unit)}</strong></div>
      <div class="room-progress-track"><span style="width:${progress}%"></span></div>
    </div>
    <label class="room-metric-input">
      <span>這一輪累積值</span>
      <input type="number" min="${metricValue}" step="0.1" value="${metricValue}" data-room-metric-value ${trustedHealthOnly ? "disabled" : ""} />
      <small>${trustedHealthOnly ? "只顯示由健康 Adapter 驗證的數值" : `${escapeHtml(unit)}，進度只能向前增加`}</small>
    </label>
    <div class="room-session-controls">${controls}</div>
    <p class="room-control-note">${trustedHealthOnly
      ? "房間管理者只能查看經同意的彙整貢獻，不能修改健康數值或替成員同步。"
      : "房間管理者負責規則與成員資格；由你自己開始、暫停與完成，事件會送入 Cloud Activity Ledger。"}</p>`;

  $("[data-room-start]", panel)?.addEventListener("click", () => {
    startWebRoomSession().catch(error => toast(error.message || "無法開始活動"));
  });
  $$("[data-room-transition]", panel).forEach(button => {
    button.addEventListener("click", () => {
      transitionWebRoomSession(button.dataset.roomTransition)
        .catch(error => toast(error.message || "無法更新活動"));
    });
  });
}

function stopWebRoomInteractionListeners() {
  if (webRoomMessagesSub) webRoomMessagesSub();
  if (webRoomEventsSub) webRoomEventsSub();
  webRoomMessagesSub = null;
  webRoomEventsSub = null;
  const messageList = $("[data-room-message-list]");
  const eventList = $("[data-room-event-list]");
  if (messageList) {
    messageList.innerHTML =
      `<p class="room-inline-empty">選擇已核准的活動房後即可查看對話。</p>`;
  }
  if (eventList) {
    eventList.innerHTML =
      `<p class="room-inline-empty">選擇已核准的活動房後即可查看歷程。</p>`;
  }
}

function stopWebRoomDetailListeners() {
  if (webRoomMemberSub) webRoomMemberSub();
  if (webRoomSessionsSub) webRoomSessionsSub();
  if (webRoomContributionsSub) webRoomContributionsSub();
  webRoomMemberSub = null;
  webRoomSessionsSub = null;
  webRoomContributionsSub = null;
  stopWebRoomInteractionListeners();
}

function renderWebRoomMembers() {
  const list = $("[data-room-member-list]");
  if (!list) return;
  if (!activeWebRoomMembers.length) {
    list.innerHTML = `<p class="room-inline-empty">尚未載入成員資料。</p>`;
    return;
  }
  const userId = firebase.auth().currentUser?.uid;
  const isOwner = activeWebRoom?.ownerId === userId;
  list.innerHTML = activeWebRoomMembers.map(member => {
    const displayName = escapeHtml(member.displayName || "自律夥伴");
    const role = member.role === "owner" ? "房主" : "成員";
    const approval = member.approvalStatus === "approved" ? "已核准" : "待審核";
    const presence = {
      studying: "活動中",
      resting: "休息中",
      offline: "離線",
    }[member.presenceStatus] || "離線";
    const actions = isOwner && member.memberId !== userId
      ? `<div class="room-member-actions">
          ${member.approvalStatus === "approved"
            ? `<button type="button" data-room-transfer-owner="${escapeHtml(member.memberId)}">移交房主</button>`
            : ""}
          <button type="button" data-room-remove-member="${escapeHtml(member.memberId)}">移除</button>
        </div>`
      : "";
    return `<article class="room-member-row">
      <div><strong>${displayName}</strong><span>${role} · ${approval} · ${presence}</span></div>
      ${actions}
    </article>`;
  }).join("");
  $$("[data-room-transfer-owner]", list).forEach(button => {
    button.addEventListener("click", () => {
      transferWebRoomOwnership(button.dataset.roomTransferOwner)
        .catch(error => toast(error.message || "房主移交失敗"));
    });
  });
  $$("[data-room-remove-member]", list).forEach(button => {
    button.addEventListener("click", () => {
      removeWebRoomMember(button.dataset.roomRemoveMember)
        .catch(error => toast(error.message || "移除成員失敗"));
    });
  });
}

function listenToWebRoomInteractions(roomId) {
  const userId = firebase.auth().currentUser?.uid;
  if (!db || !userId || !roomId) return;
  stopWebRoomInteractionListeners();
  webRoomMessagesSub = db.collection("rooms").doc(roomId)
    .collection("messages")
    .orderBy("createdAt", "desc")
    .limit(60)
    .onSnapshot(snapshot => {
      const list = $("[data-room-message-list]");
      if (!list) return;
      const messages = snapshot.docs.map(doc => ({ ...doc.data(), id: doc.id }));
      list.innerHTML = messages.length
        ? messages.map(message => `
          <article class="room-message${message.senderId === userId ? " mine" : ""}">
            <strong>${escapeHtml(message.senderName || "自律夥伴")}</strong>
            <p>${escapeHtml(message.text || "")}</p>
          </article>`).join("")
        : `<p class="room-inline-empty">還沒有訊息，先送出一句鼓勵吧。</p>`;
    }, error => console.warn("Room message sync failed:", error));

  webRoomEventsSub = db.collection("rooms").doc(roomId)
    .collection("events")
    .orderBy("createdAt", "desc")
    .limit(40)
    .onSnapshot(snapshot => {
      const list = $("[data-room-event-list]");
      if (!list) return;
      const events = snapshot.docs.map(doc => doc.data());
      list.innerHTML = events.length
        ? events.map(event => `
          <article class="room-event-row">
            <span>${escapeHtml(event.type || "system")}</span>
            <p>${escapeHtml(event.text || "")}</p>
          </article>`).join("")
        : `<p class="room-inline-empty">活動歷程會在這裡同步顯示。</p>`;
    }, error => console.warn("Room event sync failed:", error));
}

function buildWebRoomEvent(type, text) {
  const userId = firebase.auth().currentUser?.uid;
  if (!userId || !activeWebRoom || !activeWebRoomMember) {
    throw new Error("尚未載入房間成員身分");
  }
  const now = new Date().toISOString();
  const eventId = `event_${userId}_${Date.now()}`.replaceAll("/", "_");
  return {
    id: eventId,
    roomId: activeWebRoom.id,
    actorId: userId,
    actorName: String(activeWebRoomMember.displayName || "自律夥伴").slice(0, 40),
    text: String(text || "").slice(0, 500),
    type,
    createdAt: now,
  };
}

async function writeWebRoomEvent(type, text) {
  if (!db || !activeWebRoom) throw new Error("尚未選擇活動房");
  const event = buildWebRoomEvent(type, text);
  await db.collection("rooms").doc(activeWebRoom.id)
    .collection("events").doc(event.id).set(event);
}

async function sendWebRoomMessage(rawText, type = "text") {
  const userId = firebase.auth().currentUser?.uid;
  if (!db || !userId || !activeWebRoom) throw new Error("尚未選擇活動房");
  if (activeWebRoomMember?.approvalStatus !== "approved") {
    throw new Error("成員資格尚未核准");
  }
  const text = String(rawText || "").trim();
  if (!text) throw new Error("請輸入訊息");
  const now = new Date().toISOString();
  const messageId = `message_${userId}_${Date.now()}`.replaceAll("/", "_");
  const senderName = String(activeWebRoomMember.displayName || "自律夥伴")
    .slice(0, 40);
  const roomRef = db.collection("rooms").doc(activeWebRoom.id);
  const message = {
      id: messageId,
      roomId: activeWebRoom.id,
      senderId: userId,
      senderName,
      text: text.slice(0, 500),
      type,
      createdAt: now,
    };
  const event = buildWebRoomEvent(
    type === "sticker" ? "sticker" : "message",
    type === "sticker" ? `${senderName} 送出鼓勵貼圖 ${text}` : `${senderName} 傳送了一則訊息`,
  );
  const batch = db.batch();
  batch.set(roomRef.collection("messages").doc(messageId), message);
  batch.set(roomRef.collection("events").doc(event.id), event);
  await batch.commit();
}

function bindWebRoomInteractionControls() {
  const sendButton = $("[data-room-message-send]");
  const input = $("[data-room-message-input]");
  if (sendButton && sendButton.dataset.bound !== "true") {
    sendButton.dataset.bound = "true";
    const submit = async () => {
      const text = input?.value || "";
      try {
        await sendWebRoomMessage(text);
        if (input) input.value = "";
      } catch (error) {
        toast(error.message || "訊息傳送失敗");
      }
    };
    sendButton.addEventListener("click", submit);
    input?.addEventListener("keydown", event => {
      if (event.key === "Enter" && !event.shiftKey) {
        event.preventDefault();
        submit();
      }
    });
  }
  $$("[data-room-sticker]").forEach(button => {
    if (button.dataset.bound === "true") return;
    button.dataset.bound = "true";
    button.addEventListener("click", () => {
      sendWebRoomMessage(button.dataset.roomSticker, "sticker")
        .catch(error => toast(error.message || "貼圖傳送失敗"));
    });
  });
}

async function transferWebRoomOwnership(newOwnerId) {
  const userId = firebase.auth().currentUser?.uid;
  if (!db || !userId || !activeWebRoom || activeWebRoom.ownerId !== userId) {
    throw new Error("只有房主可以移交");
  }
  const nextOwner = activeWebRoomMembers.find(
    member => member.memberId === newOwnerId && member.approvalStatus === "approved",
  );
  if (!nextOwner || newOwnerId === userId || nextOwner.role === "owner") {
    throw new Error("新房主必須是另一位已核准成員");
  }
  const roomRef = db.collection("rooms").doc(activeWebRoom.id);
  const batch = db.batch();
  const now = new Date().toISOString();
  batch.update(roomRef, {
    ownerId: newOwnerId,
    ownerName: nextOwner.displayName,
    updatedAt: now,
  });
  batch.update(roomRef.collection("members").doc(userId), {
    role: "member",
    updatedAt: now,
  });
  batch.update(roomRef.collection("members").doc(newOwnerId), {
    role: "owner",
    updatedAt: now,
  });
  const event = buildWebRoomEvent(
    "system",
    `房主已移交給 ${nextOwner.displayName}`,
  );
  batch.set(roomRef.collection("events").doc(event.id), event);
  await batch.commit();
  toast("房主已完成移交");
}

async function removeWebRoomMember(memberId) {
  const userId = firebase.auth().currentUser?.uid;
  if (!db || !userId || !activeWebRoom || activeWebRoom.ownerId !== userId) {
    throw new Error("只有房主可以移除成員");
  }
  const target = activeWebRoomMembers.find(member => member.memberId === memberId);
  if (!target || memberId === userId || target.role === "owner") {
    throw new Error("不能移除自己或目前房主");
  }
  const roomRef = db.collection("rooms").doc(activeWebRoom.id);
  const batch = db.batch();
  batch.update(roomRef, {
    memberIds: firebase.firestore.FieldValue.arrayRemove(memberId),
    updatedAt: new Date().toISOString(),
  });
  batch.delete(roomRef.collection("members").doc(memberId));
  const event = buildWebRoomEvent(
    "system",
    `${target.displayName || "成員"} 已被移出房間`,
  );
  batch.set(roomRef.collection("events").doc(event.id), event);
  await batch.commit();
  toast("成員已移除");
}

function selectWebRoom(roomId, room) {
  const userId = firebase.auth().currentUser?.uid;
  if (!db || !userId || !roomId) return;
  activeWebRoom = { ...room, id: roomId };
  activeWebRoomMember = null;
  activeWebRoomMembers = [];
  activeWebRoomSession = null;
  activeWebRoomContribution = null;
  stopWebRoomDetailListeners();
  webRoomMemberSub = db.collection("rooms").doc(roomId)
    .collection("members")
    .onSnapshot(snapshot => {
      activeWebRoomMembers = snapshot.docs.map(doc => ({
        ...doc.data(),
        memberId: doc.id,
      }));
      activeWebRoomMember =
        activeWebRoomMembers.find(member => member.memberId === userId) || null;
      renderWebRoomMembers();
      renderWebRoomSessionPanel();
      if (activeWebRoomMember?.approvalStatus !== "approved") {
        if (webRoomSessionsSub) webRoomSessionsSub();
        webRoomSessionsSub = null;
        stopWebRoomInteractionListeners();
        return;
      }
      if (!webRoomContributionsSub) {
        webRoomContributionsSub = db.collection("room_contributions")
          .where("actorUserId", "==", userId)
          .onSnapshot(snapshot => {
            const contributions = snapshot.docs
              .map(doc => ({ ...doc.data(), contributionId: doc.id }))
              .filter(contribution => contribution.roomId === roomId)
              .sort((a, b) =>
                String(b.createdAt || "").localeCompare(
                  String(a.createdAt || ""),
                ));
            activeWebRoomContribution = contributions[0] || null;
            renderWebRoomSessionPanel();
          }, error => {
            console.warn("Activity Ledger contribution sync failed:", error);
            toast("Cloud Ledger 貢獻同步失敗");
          });
      }
      if (!webRoomMessagesSub || !webRoomEventsSub) {
        listenToWebRoomInteractions(roomId);
      }
      if (roomUsesTrustedHealthAdapter(activeWebRoom)) {
        if (webRoomSessionsSub) webRoomSessionsSub();
        webRoomSessionsSub = null;
        activeWebRoomSession = null;
        renderWebRoomSessionPanel();
        return;
      }
      if (webRoomSessionsSub) return;
      webRoomSessionsSub = db.collection("rooms").doc(roomId)
        .collection("activity_sessions")
        .where("actorId", "==", userId)
        .onSnapshot(snapshot => {
          const sessions = snapshot.docs
            .map(doc => ({ ...doc.data(), sessionId: doc.id }))
            .sort((a, b) => String(b.updatedAt || "").localeCompare(String(a.updatedAt || "")));
          activeWebRoomSession =
            sessions.find(
              session => session.sessionId === activeWebRoomMember?.activeSessionId,
            ) ||
            sessions.find(session => ["completed", "cancelled"].includes(session.status)) ||
            null;
          renderWebRoomSessionPanel();
        }, error => {
          console.warn("Activity session sync failed:", error);
          toast("活動紀錄同步失敗");
        });
    }, error => {
      console.warn("Room membership sync failed:", error);
      toast("房間成員資格同步失敗");
    });
  renderWebRoomSessionPanel();
}

function listenToWebRooms(userId) {
  const list = $("[data-room-list]");
  if (!db || !list || !userId) return;
  bindWebRoomInteractionControls();
  if (webRoomsSub) webRoomsSub();
  webRoomsSub = db.collection("rooms")
    .where("memberIds", "array-contains", userId)
    .onSnapshot(snapshot => {
      const rooms = snapshot.docs
        .map(doc => ({ ...doc.data(), id: doc.id }))
        .filter(room => room.status !== "closed")
        .sort((a, b) => String(b.updatedAt || "").localeCompare(String(a.updatedAt || "")));
      if (!rooms.length) {
        list.innerHTML = `
          <div class="room-empty-state">
            <span>目前沒有活動房</span>
            <strong>先從 App 探索或建立房間</strong>
            <p>加入後，這裡會顯示相同的成員資格與活動紀錄。</p>
          </div>`;
        activeWebRoom = null;
        activeWebRoomMember = null;
        activeWebRoomMembers = [];
        activeWebRoomSession = null;
        activeWebRoomContribution = null;
        stopWebRoomDetailListeners();
        renderWebRoomMembers();
        renderWebRoomSessionPanel();
        return;
      }
      list.innerHTML = rooms.map(room => `
        <button class="room-list-card${activeWebRoom?.id === room.id ? " active" : ""}" type="button" data-room-id="${escapeHtml(room.id)}">
          <span>${escapeHtml(roomTypeLabel(room))}</span>
          <strong>${escapeHtml(room.name || "未命名活動房")}</strong>
          <small>${Number(room.memberIds?.length || 0)} 位成員 · ${escapeHtml(room.joinMode === "approval" ? "加入需審核" : "開放加入")}</small>
        </button>`).join("");
      $$("[data-room-id]", list).forEach(button => {
        button.addEventListener("click", () => {
          const room = rooms.find(item => item.id === button.dataset.roomId);
          if (room) selectWebRoom(room.id, room);
        });
      });
      const selected = rooms.find(room => room.id === activeWebRoom?.id) || rooms[0];
      selectWebRoom(selected.id, selected);
    }, error => {
      console.warn("Room list sync failed:", error);
      list.innerHTML = `<div class="room-empty-state"><strong>無法同步活動房</strong><p>請確認登入狀態或稍後重試。</p></div>`;
    });
}

async function startWebRoomSession() {
  const userId = firebase.auth().currentUser?.uid;
  if (!db || !userId || !activeWebRoom) throw new Error("尚未選擇活動房");
  if (activeWebRoomMember?.approvalStatus !== "approved") {
    throw new Error("成員資格尚未核准");
  }
  if (roomUsesTrustedHealthAdapter(activeWebRoom)) {
    throw new Error("健康型房間只能從 App 的受信任健康來源同步");
  }
  const contract = await loadRoomActivitySessionContract();
  const safeIdentity = `${userId}_${activeWebRoom.id}_${Date.now()}`.replaceAll("/", "_");
  const session = contract.start({
    sessionId: safeIdentity,
    roomId: activeWebRoom.id,
    actorId: userId,
    activityKind: roomActivityKind(activeWebRoom),
    metricUnit: roomMetricUnit(activeWebRoom),
    targetValue: roomSessionTargetValue(activeWebRoom),
    source: "web",
    now: new Date(),
  });
  const roomRef = db.collection("rooms").doc(activeWebRoom.id);
  const batch = db.batch();
  batch.update(roomRef.collection("members").doc(userId), {
    activeSessionId: session.sessionId,
    updatedAt: session.updatedAt,
  });
  batch.set(
    roomRef.collection("activity_sessions").doc(session.sessionId),
    session,
  );
  const event = buildWebRoomEvent(
    "start",
    `${activeWebRoomMember.displayName || "成員"} 開始活動`,
  );
  batch.set(roomRef.collection("events").doc(event.id), event);
  await queueWebRoomLedgerTransition({
    session,
    nextStatus: "active",
  });
  await batch.commit();
  toast("已開始你的活動紀錄");
}

async function transitionWebRoomSession(nextStatus) {
  const userId = firebase.auth().currentUser?.uid;
  if (!db || !userId || !activeWebRoom || !activeWebRoomSession) {
    throw new Error("目前沒有可更新的活動");
  }
  if (roomUsesTrustedHealthAdapter(activeWebRoom)) {
    throw new Error("健康型房間只能從 App 的受信任健康來源同步");
  }
  const contract = await loadRoomActivitySessionContract();
  const metricInput = $("[data-room-metric-value]");
  const metricValue = Number(metricInput?.value ?? activeWebRoomSession.metricValue);
  const next = contract.transition(activeWebRoomSession, {
    actorId: userId,
    nextStatus,
    metricValue,
    now: new Date(),
  });
  const roomRef = db.collection("rooms").doc(activeWebRoom.id);
  const event = buildWebRoomEvent(
    nextStatus === "completed"
      ? "complete"
      : nextStatus === "paused"
        ? "pause"
        : nextStatus === "cancelled"
          ? "cancel"
          : "start",
    `${activeWebRoomMember.displayName || "成員"} ${roomSessionStatusLabel(nextStatus)}`,
  );
  const batch = db.batch();
  if (["completed", "cancelled"].includes(next.status)) {
    batch.update(roomRef.collection("members").doc(userId), {
      activeSessionId: null,
      updatedAt: next.updatedAt,
    });
    batch.set(
      roomRef.collection("activity_sessions").doc(next.sessionId),
      next,
    );
  } else {
    batch.set(
      roomRef.collection("activity_sessions").doc(next.sessionId),
      next,
    );
  }
  batch.set(roomRef.collection("events").doc(event.id), event);
  await queueWebRoomLedgerTransition({
    session: next,
    previousStatus: activeWebRoomSession.status,
    nextStatus,
  });
  await batch.commit();
  toast(nextStatus === "completed" ? "這輪活動已完成" : "活動狀態已同步");
}

function stopFamilyInteractionListeners() {
  if (familyEncouragementSub) familyEncouragementSub();
  if (familyGoalSub) familyGoalSub();
  if (familySummarySub) familySummarySub();
  if (familyOutcomeSub) familyOutcomeSub();
  if (familyMemoriesSub) familyMemoriesSub();
  familyEncouragementSub = null;
  familyGoalSub = null;
  familySummarySub = null;
  familyOutcomeSub = null;
  familyMemoriesSub = null;
  currentFamilyRelationshipOutcome = null;
  currentFamilyRelationshipMemories = [];
}

function relationshipSelectionKey(scope, userId) {
  return `nudgeSelected${scope === "family" ? "Family" : "Group"}:${userId}`;
}

function relationshipMembershipDocumentId(scopeType, scopeId, userId) {
  const values = [scopeType, scopeId, userId].map(value => String(value || ""));
  if (
    !["family", "group"].includes(values[0]) ||
    values.some(value => !value || value.includes("/"))
  ) {
    throw new Error("Membership 識別碼不完整");
  }
  return `${values[0]}--${values[1]}--${values[2]}`;
}

function buildWebRelationshipMembership({
  scopeType,
  scopeId,
  scopeName,
  userId,
  role,
  status = "active",
  endedBy = null,
  now = new Date().toISOString(),
}) {
  const membershipId = relationshipMembershipDocumentId(
    scopeType,
    scopeId,
    userId,
  );
  return {
    schemaVersion: 1,
    membershipId,
    scopeType,
    scopeId,
    scopeName,
    userId,
    role,
    status,
    createdAt: now,
    updatedAt: now,
    ...(status === "active" ? { activeFrom: now } : {}),
    ...(status === "ended"
      ? { activeUntil: now, endedBy: endedBy || userId }
      : {}),
  };
}

async function syncMyWebRelationshipMemberships(userId) {
  if (!db || firebase.auth().currentUser?.uid !== userId) return;
  const now = new Date().toISOString();
  const memberships = [
    ...activeFamilyLinks.map(link =>
      buildWebRelationshipMembership({
        scopeType: "family",
        scopeId: link.id,
        scopeName: `家庭連結 ${link.id.slice(-8)}`,
        userId,
        role: link.guardianId === userId ? "guardian" : "child",
        now,
      }),
    ),
    ...activeWebGroups.map(group =>
      buildWebRelationshipMembership({
        scopeType: "group",
        scopeId: group.id,
        scopeName: group.name || "未命名團體",
        userId,
        role: group.ownerId === userId ? "manager" : "member",
        now,
      }),
    ),
  ];
  if (!memberships.length) return;
  const batch = db.batch();
  memberships.forEach(membership => {
    batch.set(
      db.collection("relationship_memberships").doc(membership.membershipId),
      membership,
      { merge: true },
    );
  });
  await batch.commit();
}

function activateWebFamilyLink(link, userId) {
  const changed = activeFamilyLink?.id !== link?.id;
  activeFamilyLink = link || null;
  window.activeFamilyLink = activeFamilyLink;
  window.linkedChildUid =
    activeFamilyLink?.guardianId === userId ? activeFamilyLink.childId : null;
  if (changed) {
    stopFamilyInteractionListeners();
    currentFamilySummary = null;
    if (activeFamilyLink) listenToFamilyInteractions(activeFamilyLink.id);
  }
  renderWebRelationshipContextSwitcher(userId);
  renderFamilyLinkState();
  renderFamilyReportState();
  renderFamilyRelationshipOutcome();
  if (currentWebUserData) updateSidebarProfile(currentWebUserData);
}

function listenToFamilyLink(userId) {
  if (!db) return;
  if (familyLinkSub) familyLinkSub();
  stopFamilyInteractionListeners();
  activeFamilyLink = null;
  activeFamilyLinks = [];
  familyLinkLoaded = false;
  window.activeFamilyLink = null;

  familyLinkSub = db.collection("family_links")
    .where("participantIds", "array-contains", userId)
    .onSnapshot(snapshot => {
      familyLinkLoaded = true;
      activeFamilyLinks = snapshot.docs
        .filter(doc => doc.data().status === "active")
        .map(doc => ({ id: doc.id, ...doc.data() }))
        .sort((a, b) =>
          String(b.updatedAt || "").localeCompare(String(a.updatedAt || "")),
        );
      syncMyWebRelationshipMemberships(userId).catch(error => {
        console.warn("Formal family membership sync failed:", error);
      });
      if (activeFamilyLinks.length === 0) {
        activeFamilyLink = null;
        currentFamilySummary = null;
        window.activeFamilyLink = null;
        window.linkedChildUid = null;
        stopFamilyInteractionListeners();
        renderWebRelationshipContextSwitcher(userId);
        renderFamilyLinkState();
        renderFamilyReportState();
        renderFamilyRelationshipOutcome();
        if (currentWebUserData) updateSidebarProfile(currentWebUserData);
        return;
      }

      const selectedId = localStorage.getItem(
        relationshipSelectionKey("family", userId),
      );
      const selected =
        activeFamilyLinks.find(link => link.id === selectedId) ||
        activeFamilyLinks[0];
      activateWebFamilyLink(selected, userId);
    }, error => {
      console.error("Family link listen error:", error);
    });
}

function listenToFamilyInteractions(linkId) {
  stopFamilyInteractionListeners();
  familyEncouragementSub = db.collection("family_links")
    .doc(linkId)
    .collection("encouragements")
    .orderBy("createdAt", "desc")
    .onSnapshot(snapshot => {
      const items = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
      const list = document.querySelector("[data-encourage-list]");
      if (list) {
        list.innerHTML = items.length
          ? items.map(item => `
              <article>
                <strong>${escapeHtml(item.title || "今天也辛苦了")}</strong>
                <span>${item.status === "acknowledged" ? "孩子已回應 · 羈絆 +3 XP" : "已送達孩子 App"}</span>
              </article>
            `).join("")
          : "<article><strong>尚未送出</strong><span>送出鼓勵卡後會出現在這裡。</span></article>";
      }
      const count = document.querySelector('[data-family-encouragement-count]');
      if (count) count.textContent = String(items.length);
    });

  familyGoalSub = db.collection("family_links")
    .doc(linkId)
    .collection("goals")
    .orderBy("createdAt", "desc")
    .onSnapshot(snapshot => {
      const items = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
      const pending = items.filter(item => item.status === "proposed");
      const count = document.querySelector('[data-family-goal-count]');
      if (count) count.textContent = String(pending.length);
      const latest = document.querySelector('[data-family-latest-goal]');
      if (latest) {
        latest.textContent = items.length
          ? `${items[0].title} · ${
              items[0].status === "proposed"
                ? "等待孩子決定"
                : items[0].status === "accepted"
                  ? "孩子已接受"
                  : items[0].status === "declined"
                    ? "孩子已婉拒"
                    : "已完成"
            }`
          : "目前沒有共同目標。";
      }
    });

  familySummarySub = db.collection("family_links")
    .doc(linkId)
    .collection("summaries")
    .doc("current")
    .onSnapshot(snapshot => {
      currentFamilySummary = snapshot.exists ? snapshot.data() : null;
      renderFamilyReportState();
    });

  const outcomeRef = db.collection("relationship_outcomes")
    .doc(`family--${linkId}`);
  familyOutcomeSub = outcomeRef.onSnapshot(snapshot => {
    currentFamilyRelationshipOutcome = snapshot.exists
      ? snapshot.data()
      : null;
    renderFamilyRelationshipOutcome();
  });
  familyMemoriesSub = outcomeRef
    .collection("memories")
    .orderBy("happenedAt", "desc")
    .limit(30)
    .onSnapshot(snapshot => {
      currentFamilyRelationshipMemories = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data(),
      }));
      renderFamilyRelationshipOutcome();
    });
}

function stopGroupPublicationListeners() {
  if (groupChallengeSub) groupChallengeSub();
  if (groupChallengeParticipantsSub) groupChallengeParticipantsSub();
  if (groupSchedulesSub) groupSchedulesSub();
  if (groupTemplatesSub) groupTemplatesSub();
  if (groupMemberSummariesSub) groupMemberSummariesSub();
  if (groupOutcomeSub) groupOutcomeSub();
  groupChallengeSub = null;
  groupChallengeParticipantsSub = null;
  groupSchedulesSub = null;
  groupTemplatesSub = null;
  groupMemberSummariesSub = null;
  groupOutcomeSub = null;
  activeWebGroupSummaries = [];
  activeWebGroupChallengeParticipants = [];
  currentGroupRelationshipOutcome = null;
}

function effectiveWebGroupProfile() {
  const data = currentWebUserData || {};
  const userId =
    typeof firebase !== "undefined" ? firebase.auth().currentUser?.uid : null;
  const isMember =
    window.NudgeGroupContract?.isGroupMember(activeWebGroup, userId) === true;
  if (!isMember) {
    return {
      ...data,
      groupId: null,
      groupName: null,
      isGroupOwner: false,
    };
  }
  return {
    ...data,
    groupId: activeWebGroup.id,
    groupName: activeWebGroup.name,
    isGroupOwner:
      window.NudgeGroupContract.isGroupManager(activeWebGroup, userId),
  };
}

function refreshCanonicalGroupUi() {
  const groupNameInput = document.querySelector("[data-challenge-group]");
  if (groupNameInput && activeWebGroup) {
    groupNameInput.value = activeWebGroup.name;
  }
  const heroCount = document.querySelector(".hero-card [data-count]");
  if (
    heroCount &&
    (window.location.pathname.includes("groups-challenge") ||
      window.location.pathname.endsWith("/groups.html"))
  ) {
    heroCount.textContent = String(activeWebGroup?.memberIds?.length || 0);
  }
  const groupSummary = document.querySelector("[data-group-summary]");
  if (groupSummary) {
    groupSummary.textContent = activeWebGroup
      ? `${activeWebGroup.name} 的正式成員名單已同步。`
      : "等待正式團體資料同步。";
  }
  if (currentWebUserData) {
    updateSidebarProfile(effectiveWebGroupProfile());
    renderWebGrowthTracks(currentWebUserData, false);
  }
  renderCanonicalGroupOverview();
  renderCanonicalWebGroupMembers();
  renderCanonicalGroupRanking();
  renderGroupRelationshipOutcome();
}

function renderCanonicalGroupOverview() {
  if (!document.querySelector("[data-group-publications]")) return;
  const store = JSON.parse(localStorage.getItem("nudgeWebTools") || "{}");
  const canReadPublications = isPreviewMode() || Boolean(activeWebGroup);
  const challenge = canReadPublications ? store.challenge || null : null;
  const schedules = canReadPublications && Array.isArray(store.studySchedules)
    ? store.studySchedules
    : [];
  const templates = canReadPublications && Array.isArray(store.groupTemplates)
    ? store.groupTemplates
    : [];

  const challengeList = document.querySelector("[data-group-challenge-list]");
  if (challengeList) {
    const challengeId = challenge?.challengeId || null;
    const participants = challengeId
      ? activeWebGroupChallengeParticipants.filter(
          item => item.challengeId === challengeId,
        )
      : [];
    const completedCount = participants.filter(
      item => item.status === "completed",
    ).length;
    const userId =
      typeof firebase !== "undefined" ? firebase.auth().currentUser?.uid : null;
    const mine = participants.find(item => item.memberId === userId);
    const participationCopy = mine
      ? mine.status === "completed"
        ? "你已完成這次挑戰"
        : `你的進度 ${Number(mine.completedDays || 0)} / ${Number(mine.totalDays || challenge?.days || 0)} 天`
      : "由你自己決定是否參加";
    challengeList.innerHTML = challenge
      ? `<article><strong>${escapeHtml(challenge.type || "自律挑戰")} · ${escapeHtml(challenge.days || 0)} 天</strong><span>${escapeHtml(challenge.groupName || activeWebGroup?.name || "目前團體")}｜${participants.length} 人參加、${completedCount} 人完成｜${escapeHtml(participationCopy)}</span><small>團體進度不另發個人 XP／自律幣；目標獎勵待團體結算。</small>${challenge.schemaVersion === 2 && !mine ? '<button class="button primary" type="button" data-join-current-challenge>我要參加</button>' : challenge.schemaVersion !== 2 ? '<small>此為舊版挑戰，請管理者重新發布後再參加。</small>' : ""}</article>`
      : "<article><strong>尚未發布</strong><span>管理者發布後會同步顯示。</span></article>";
    challengeList
      .querySelector("[data-join-current-challenge]")
      ?.addEventListener("click", async event => {
        const button = event.currentTarget;
        button.disabled = true;
        try {
          await joinCanonicalWebGroupChallenge(challenge);
          toast("已參加挑戰；App 會同步匯入每日任務");
        } catch (error) {
          console.error(error);
          button.disabled = false;
          toast(error.message || "參加挑戰失敗");
        }
      });
  }

  const scheduleList = document.querySelector("[data-group-schedule-list]");
  if (scheduleList) {
    scheduleList.innerHTML = schedules.length
      ? schedules
          .map(
            schedule =>
              `<article><strong>${escapeHtml(schedule.title || "共同自律時段")}</strong><span>${escapeHtml(schedule.meta || "由成員自行開始與完成")}</span></article>`,
          )
          .join("")
      : "<article><strong>尚未排程</strong><span>成員仍可依自己的時間開始活動。</span></article>";
  }

  const templateList = document.querySelector("[data-group-template-list]");
  if (templateList) {
    templateList.innerHTML = templates.length
      ? templates
          .map(
            template =>
              `<article><strong>${escapeHtml(template.type || "自律")} · ${escapeHtml(template.days || 0)} 天</strong><span>${escapeHtml(template.effort || "未設定核心任務")}｜${escapeHtml(template.strategy || "未設定準備策略")}</span></article>`,
          )
          .join("")
      : "<article><strong>尚未發布</strong><span>正式模板會同步到 Web 與 App。</span></article>";
  }
}

function syncCanonicalGroupPublicationsToLocal({
  challenge,
  schedules,
  templates,
} = {}) {
  const store = JSON.parse(localStorage.getItem("nudgeWebTools") || "{}");
  if (challenge !== undefined) {
    if (challenge) store.challenge = challenge;
    else delete store.challenge;
  }
  if (schedules !== undefined) {
    store.studySchedules = schedules;
    if (window.location.pathname.includes("groups-study-schedule")) {
      const count = document.querySelector(".hero-card [data-count]");
      if (count) count.textContent = String(schedules.length);
    }
  }
  if (templates !== undefined) {
    store.groupTemplates = templates;
    if (window.location.pathname.includes("groups-templates")) {
      const count = document.querySelector(".hero-card [data-count]");
      if (count) count.textContent = String(templates.length);
    }
  }
  localStorage.setItem("nudgeWebTools", JSON.stringify(store));
  renderCanonicalGroupOverview();

  if (typeof window.renderSavedList === "function") {
    window.renderSavedList(
      "[data-study-list]",
      "studySchedules",
      "<article><strong>尚未排程</strong><span>新增讀書時段後會出現在這裡。</span></article>",
    );
  }
  if (typeof window.renderCanonicalGroupTemplates === "function") {
    window.renderCanonicalGroupTemplates(templates ?? store.groupTemplates ?? []);
  }
}

function clearCanonicalGroupPublications() {
  syncCanonicalGroupPublicationsToLocal({
    challenge: null,
    schedules: [],
    templates: [],
  });
}

function listenToGroupPublications(groupId) {
  stopGroupPublicationListeners();
  const groupRef = db.collection("groups").doc(groupId);
  groupChallengeSub = groupRef
    .collection("challenges")
    .doc("current")
    .onSnapshot(snapshot => {
      syncCanonicalGroupPublicationsToLocal({
        challenge: snapshot.exists ? { id: snapshot.id, ...snapshot.data() } : null,
      });
    });
  groupChallengeParticipantsSub = groupRef
    .collection("challenges")
    .doc("current")
    .collection("participants")
    .onSnapshot(snapshot => {
      activeWebGroupChallengeParticipants = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data(),
      }));
      renderCanonicalGroupOverview();
    });
  groupSchedulesSub = groupRef
    .collection("study_schedules")
    .orderBy("createdAt", "desc")
    .limit(50)
    .onSnapshot(snapshot => {
      syncCanonicalGroupPublicationsToLocal({
        schedules: snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() })),
      });
    });
  groupTemplatesSub = groupRef
    .collection("templates")
    .orderBy("updatedAt", "desc")
    .limit(50)
    .onSnapshot(snapshot => {
      syncCanonicalGroupPublicationsToLocal({
        templates: snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() })),
      });
    });
  groupMemberSummariesSub = groupRef
    .collection("member_summaries")
    .onSnapshot(snapshot => {
      activeWebGroupSummaries = snapshot.docs
        .map(doc => ({ id: doc.id, ...doc.data() }))
        .sort(
          (a, b) =>
            Number(b.summary?.disciplineScore || 0) -
            Number(a.summary?.disciplineScore || 0),
        );
      renderCanonicalWebGroupMembers();
      renderCanonicalGroupRanking();
    });
  groupOutcomeSub = db.collection("relationship_outcomes")
    .doc(`group--${groupId}`)
    .onSnapshot(snapshot => {
      currentGroupRelationshipOutcome = snapshot.exists
        ? snapshot.data()
        : null;
      renderGroupRelationshipOutcome();
    });
}

function listenToCanonicalWebGroup(userId, projectedGroupId) {
  if (!db) return;
  const nextGroupId = projectedGroupId || null;
  const listenerKey = `${userId}:${nextGroupId || ""}`;
  if (
    listeningWebGroupId === listenerKey &&
    groupDocSub
  ) {
    return;
  }
  listeningWebGroupId = listenerKey;
  if (groupDocSub) groupDocSub();
  stopGroupPublicationListeners();
  activeWebGroup = null;
  activeWebGroups = [];
  groupLoaded = false;
  clearCanonicalGroupPublications();

  groupDocSub = db
    .collection("groups")
    .where("memberIds", "array-contains", userId)
    .onSnapshot(
    snapshot => {
      groupLoaded = true;
      const activeGroups = snapshot.docs
        .map(doc => ({ id: doc.id, ...doc.data() }))
        .filter(group =>
          window.NudgeGroupContract?.isGroupMember(group, userId),
        )
        .sort((a, b) =>
          String(a.name || "").localeCompare(String(b.name || "")),
        );
      activeWebGroups = activeGroups;
      syncMyWebRelationshipMemberships(userId).catch(error => {
        console.warn("Formal group membership sync failed:", error);
      });
      if (activeGroups.length === 0) {
        activeWebGroup = null;
        renderWebRelationshipContextSwitcher(userId);
        stopGroupPublicationListeners();
        clearCanonicalGroupPublications();
        refreshCanonicalGroupUi();
        return;
      }
      const selectedId = localStorage.getItem(
        relationshipSelectionKey("group", userId),
      );
      const group =
        activeGroups.find(candidate => candidate.id === selectedId) ||
        activeGroups.find(candidate => candidate.id === nextGroupId) ||
        activeGroups[0];
      activateWebGroup(group, userId);
    },
    error => {
      console.error("Canonical group listen error:", error);
      groupLoaded = true;
      activeWebGroup = null;
      activeWebGroups = [];
      renderWebRelationshipContextSwitcher(userId);
      stopGroupPublicationListeners();
      clearCanonicalGroupPublications();
      refreshCanonicalGroupUi();
    },
  );
}

function activateWebGroup(group, userId) {
  const groupChanged = activeWebGroup?.id !== group?.id;
  if (groupChanged) {
    stopGroupPublicationListeners();
    clearCanonicalGroupPublications();
  }
  activeWebGroup = group || null;
  if (groupChanged && activeWebGroup) {
    listenToGroupPublications(activeWebGroup.id);
  }
  renderWebRelationshipContextSwitcher(userId);
  refreshCanonicalGroupUi();
}

function webRelationshipRole(scope, relationship, userId) {
  if (scope === "family") {
    return relationship.guardianId === userId ? "家長" : "孩子";
  }
  return relationship.ownerId === userId ? "團體管理者" : "團體成員";
}

async function refreshWebRelationshipOutcome(scopeType, scopeId) {
  const user = firebase.auth().currentUser;
  if (!user || !functions) {
    throw new Error("請先登入並完成 Cloud Functions 初始化。");
  }
  if (!["family", "group"].includes(scopeType) || !scopeId) {
    throw new Error("目前沒有可更新的家庭或團體關係。");
  }
  const response = await functions.httpsCallable(
    "refreshRelationshipOutcome",
  )({ scopeType, scopeId });
  const outcome = response?.data?.outcome;
  if (
    !outcome ||
    outcome.scopeType !== scopeType ||
    outcome.scopeId !== scopeId
  ) {
    throw new Error("Cloud 回傳的關係成果與目前情境不一致。");
  }
  if (scopeType === "family") {
    currentFamilyRelationshipOutcome = outcome;
    currentFamilyRelationshipMemories = Array.isArray(response.data.memories)
      ? response.data.memories
      : [];
    renderFamilyRelationshipOutcome();
  } else {
    currentGroupRelationshipOutcome = outcome;
    renderGroupRelationshipOutcome();
  }
  return outcome;
}

function renderFamilyRelationshipOutcome() {
  const root = document.querySelector("[data-family-outcome]");
  if (!root) return;
  const userId = firebase.auth().currentUser?.uid;
  const isGuardian =
    Boolean(activeFamilyLink) && activeFamilyLink.guardianId === userId;
  const role = document.querySelector("[data-family-role]");
  if (role) {
    role.textContent = activeFamilyLink
      ? `${isGuardian ? "家長" : "孩子"}介面`
      : "等待家庭連結";
  }
  document.querySelectorAll("[data-family-guardian-tools]").forEach(node => {
    node.hidden = !isGuardian;
  });
  const surfaceTitle = document.querySelector("[data-family-surface-title]");
  if (surfaceTitle) {
    surfaceTitle.textContent = isGuardian
      ? "家長陪伴工具"
      : activeFamilyLink
        ? "我的家庭自主與共同回憶"
        : "家庭陪伴與自主中心";
  }
  const surfaceDescription = document.querySelector(
    "[data-family-surface-description]",
  );
  if (surfaceDescription) {
    surfaceDescription.textContent = isGuardian
      ? "只查看孩子已同意的摘要，並透過鼓勵與共同目標陪伴。"
      : activeFamilyLink
        ? "你可以調整資料同意、回應鼓勵並決定是否接受共同目標。"
        : "登入後會依正式家庭 Membership 顯示家長或孩子介面。";
  }

  const outcome = currentFamilyRelationshipOutcome;
  const title = root.querySelector("[data-family-outcome-title]");
  const description = root.querySelector("[data-family-outcome-description]");
  const metrics = root.querySelector("[data-family-outcome-metrics]");
  const memories = root.querySelector("[data-family-memory-list]");
  if (title) {
    title.textContent = outcome?.characterOutcome?.title || "家庭樹尚未生成";
  }
  if (description) {
    description.textContent =
      outcome?.characterOutcome?.description ||
      "家庭樹由 Cloud 驗證的共同目標與雙向回應生成，不使用個人 XP。";
  }
  if (metrics) {
    const growth = outcome?.growth || {};
    const values = outcome?.metrics || {};
    metrics.innerHTML = outcome
      ? `<article><strong>Lv.${Number(growth.level || 1)} · ${Number(growth.xp || 0)} 關係 XP</strong><span>${growth.nextLevelXp == null ? "已達目前最高階段" : `下一階段 ${Number(growth.nextLevelXp)} XP`}</span></article>
         <article><strong>${Number(values.completedGoals || 0)} 個共同目標</strong><span>${Number(values.acknowledgements || 0)} 次雙向回應 · ${Number(values.memoryCount || 0)} 段共同回憶</span></article>`
      : "<article><strong>尚未計算</strong><span>登入後按「重新計算」建立正式成果。</span></article>";
  }
  if (memories) {
    memories.innerHTML = currentFamilyRelationshipMemories.length
      ? currentFamilyRelationshipMemories.slice(0, 5).map(memory =>
          `<article><strong>${escapeHtml(memory.title || "家庭共同回憶")}</strong><span>+${Number(memory.points || 0)} 關係 XP</span></article>`,
        ).join("")
      : "<article><strong>尚無共同回憶</strong><span>完成共同目標或回應鼓勵卡後會出現在這裡。</span></article>";
  }
  const button = root.querySelector("[data-refresh-family-outcome]");
  if (button) {
    button.disabled = !activeFamilyLink;
    button.onclick = async () => {
      button.disabled = true;
      try {
        await refreshWebRelationshipOutcome("family", activeFamilyLink.id);
        toast("家庭樹與共同回憶已更新");
      } catch (error) {
        console.error(error);
        toast(error.message || "家庭樹更新失敗");
      } finally {
        button.disabled = !activeFamilyLink;
      }
    };
  }
}

function renderGroupRelationshipOutcome() {
  const root = document.querySelector("[data-group-outcome]");
  if (!root) return;
  const userId = firebase.auth().currentUser?.uid;
  const isManager =
    Boolean(activeWebGroup) && activeWebGroup.ownerId === userId;
  const role = document.querySelector("[data-group-role]");
  if (role) {
    role.textContent = activeWebGroup
      ? `${isManager ? "管理者" : "成員"}介面 · ${activeWebGroup.name || "目前團體"}`
      : "等待正式團體";
  }
  document.querySelectorAll("[data-group-manager-tools]").forEach(node => {
    node.hidden = !isManager;
  });
  const surfaceTitle = document.querySelector("[data-group-surface-title]");
  if (surfaceTitle) {
    surfaceTitle.textContent = isManager
      ? "團體管理與共同進度"
      : activeWebGroup
        ? "我的團體任務與共同進度"
        : "團體共同進度中心";
  }
  const surfaceDescription = document.querySelector(
    "[data-group-surface-description]",
  );
  if (surfaceDescription) {
    surfaceDescription.textContent = isManager
      ? "管理者可以發布規則與模板，但不能替成員開始或完成活動。"
      : activeWebGroup
        ? "你自行選擇參與並完成活動，團體只彙整已同意分享的成果。"
        : "登入後會依正式團體 Membership 顯示管理者或成員介面。";
  }

  const outcome = currentGroupRelationshipOutcome;
  const title = root.querySelector("[data-group-outcome-title]");
  const description = root.querySelector("[data-group-outcome-description]");
  const metrics = root.querySelector("[data-group-outcome-metrics]");
  if (title) {
    title.textContent = outcome?.characterOutcome?.title || "團體星球尚未生成";
  }
  if (description) {
    description.textContent =
      outcome?.characterOutcome?.description ||
      "團體星球由有效成員、主動分享與目前挑戰參與紀錄生成。";
  }
  if (metrics) {
    const growth = outcome?.growth || {};
    const values = outcome?.metrics || {};
    metrics.innerHTML = outcome
      ? `<article><strong>Lv.${Number(growth.level || 1)} · ${Number(growth.xp || 0)} 關係 XP</strong><span>${growth.nextLevelXp == null ? "已達目前最高階段" : `下一階段 ${Number(growth.nextLevelXp)} XP`}</span></article>
         <article><strong>${Number(values.memberCount || 0)} 位有效成員 · ${Number(values.sharedMemberCount || 0)} 位主動分享</strong><span>${Number(values.joinedChallengeCount || 0)} 人參與目前挑戰 · ${Number(values.completedChallengeCount || 0)} 人完成</span></article>`
      : "<article><strong>尚未計算</strong><span>登入後按「重新計算」建立正式成果。</span></article>";
  }
  const button = root.querySelector("[data-refresh-group-outcome]");
  if (button) {
    button.disabled = !activeWebGroup;
    button.onclick = async () => {
      button.disabled = true;
      try {
        await refreshWebRelationshipOutcome("group", activeWebGroup.id);
        toast("團體星球已更新");
      } catch (error) {
        console.error(error);
        toast(error.message || "團體星球更新失敗");
      } finally {
        button.disabled = !activeWebGroup;
      }
    };
  }
}

function renderWebRelationshipContextSwitcher(userId) {
  const panel = getOrCreateSidePanel();
  if (!panel) return;
  panel.querySelector(".relationship-context-switcher")?.remove();
  if (isPreviewMode() || (!activeFamilyLinks.length && !activeWebGroups.length)) {
    return;
  }

  const familyOptions = activeFamilyLinks.map(link => {
    const shortId = link.id.length <= 8 ? link.id : link.id.slice(-8);
    const selected = activeFamilyLink?.id === link.id ? "selected" : "";
    return `<option value="${escapeHtml(link.id)}" ${selected}>家庭連結 ${escapeHtml(shortId)} · ${webRelationshipRole("family", link, userId)}</option>`;
  }).join("");
  const groupOptions = activeWebGroups.map(group => {
    const selected = activeWebGroup?.id === group.id ? "selected" : "";
    return `<option value="${escapeHtml(group.id)}" ${selected}>${escapeHtml(group.name || "未命名團體")} · ${webRelationshipRole("group", group, userId)}</option>`;
  }).join("");
  panel.insertAdjacentHTML("beforeend", `
    <section class="relationship-context-switcher" style="margin-top: 10px; border-top: 1px solid rgba(255,255,255,0.08); padding-top: 10px;">
      <span class="eyebrow">目前關係情境</span>
      ${familyOptions ? `<label style="display:block; margin-top:8px; font-size:11px;">家庭<select data-relationship-family class="module-select" style="width:100%; margin-top:4px;">${familyOptions}</select></label>` : ""}
      ${groupOptions ? `<label style="display:block; margin-top:8px; font-size:11px;">團體<select data-relationship-group class="module-select" style="width:100%; margin-top:4px;">${groupOptions}</select></label>` : ""}
    </section>
  `);

  panel.querySelector("[data-relationship-family]")?.addEventListener(
    "change",
    event => {
      const selected = activeFamilyLinks.find(
        link => link.id === event.target.value,
      );
      if (!selected) return;
      localStorage.setItem(
        relationshipSelectionKey("family", userId),
        selected.id,
      );
      activateWebFamilyLink(selected, userId);
      toast("已切換家庭情境");
    },
  );
  panel.querySelector("[data-relationship-group]")?.addEventListener(
    "change",
    event => {
      const selected = activeWebGroups.find(
        group => group.id === event.target.value,
      );
      if (!selected) return;
      localStorage.setItem(
        relationshipSelectionKey("group", userId),
        selected.id,
      );
      activateWebGroup(selected, userId);
      toast("已切換團體情境");
    },
  );
}

function renderFamilyLinkState() {
  const consent = activeFamilyLink?.consentScopes || {};
  document.querySelectorAll("[data-family-consent]").forEach(node => {
    const enabled = consent[node.dataset.familyConsent] === true;
    node.textContent = enabled ? "孩子已同意" : "孩子未開放";
    node.classList.toggle("primary", enabled);
    node.classList.toggle("ghost", !enabled);
  });
  const summary = document.querySelector("[data-family-consent-summary]");
  if (summary) {
    const labels = [
      consent.summary && "今日總覽",
      consent.weeklyReport && "每週回顧",
      consent.taskCategories && "任務類別",
      consent.healthTrends && "健康趨勢",
    ].filter(Boolean);
    summary.textContent = labels.length ? labels.join("、") : "尚未開放";
  }
  if (currentWebUserData) {
    renderWebGrowthTracks(currentWebUserData, false);
  }
}

function renderFamilyReportState() {
  const consent = activeFamilyLink?.consentScopes || {};
  const shared = currentFamilySummary || {};
  const summary = consent.summary ? shared.summary : null;
  const health = consent.healthTrends ? shared.healthTrends : null;
  const weekly = consent.weeklyReport && Array.isArray(shared.weeklyReport)
    ? shared.weeklyReport
    : [];
  const completionRate = summary?.totalTasks > 0
    ? Math.round((summary.completedTasks / summary.totalTasks) * 100)
    : null;

  const setText = (selector, value) => {
    const node = document.querySelector(selector);
    if (node) node.textContent = value;
  };
  setText(
    "[data-family-report-completion]",
    completionRate === null ? "未開放" : `${completionRate}%`,
  );
  setText(
    "#childTasksCount",
    summary ? `${summary.completedTasks} / ${summary.totalTasks}` : "未開放",
  );
  setText(
    "#childFocusVal",
    summary ? `${summary.focusMinutes} 分` : "未開放",
  );
  setText(
    "#childSleepVal",
    health ? `${Number(health.sleepHours || 0).toFixed(1)} 小時` : "未開放",
  );
  setText(
    "#childStepsVal",
    health ? `${health.steps || 0}` : "未開放",
  );

  const insight = document.querySelector("[data-family-report-insight]");
  if (insight) {
    insight.textContent = !currentFamilySummary
      ? "等待孩子 App 同步已同意的摘要資料。"
      : health
        ? "健康趨勢已由孩子開放。請用關心與討論回應，不以數字責備。"
        : "孩子尚未開放健康趨勢；可以直接關心感受，不追問原始數據。";
  }

  const chart = document.querySelector("#sleepChart");
  if (chart && weekly.length > 0) {
    drawLineChart(
      chart,
      weekly.map(item => Number(item.disciplineScore || 0)),
      "#8d7aff",
    );
  } else if (chart) {
    chart.getContext("2d").clearRect(0, 0, chart.width, chart.height);
  }
}

function requireGuardianFamilyLink() {
  const userId =
    typeof firebase !== "undefined" ? firebase.auth().currentUser?.uid : null;
  if (!activeFamilyLink || !userId) {
    throw new Error("請先建立有效的家庭連結");
  }
  if (activeFamilyLink.guardianId !== userId) {
    throw new Error("只有此連結的家長可以使用這項功能");
  }
  return activeFamilyLink;
}

async function sendWebFamilyEncouragement(title, message) {
  const link = requireGuardianFamilyLink();
  const payload = window.NudgeFamilyLinkContract.buildEncouragementPayload({
    guardianId: link.guardianId,
    childId: link.childId,
    title,
    message,
  });
  await db.collection("family_links")
    .doc(link.id)
    .collection("encouragements")
    .add(payload);
}

async function sendWebFamilyGoal(title, message) {
  const link = requireGuardianFamilyLink();
  const payload = window.NudgeFamilyLinkContract.buildSharedGoalPayload({
    guardianId: link.guardianId,
    childId: link.childId,
    title,
    message,
  });
  await db.collection("family_links")
    .doc(link.id)
    .collection("goals")
    .add(payload);
}

function initializeFirebaseWeb() {
  loadWebRuntimeConfig()
    .then(() => {
      configureFirebaseAppCheckDebugToken();
      return loadFirebaseSDKs();
    })
    .then(() => {
      if (typeof firebase !== 'undefined') {
        try {
          if (!firebase.apps.length) {
            firebase.initializeApp(firebaseConfig);
          }
          initializeFirebaseAppCheck();
          db = firebase.firestore();
          storage = firebase.storage ? firebase.storage() : null;
          functions = firebase.functions
            ? firebase.app().functions("asia-east1")
            : null;
          console.log("Firebase initialized successfully on Web Center");

          const auth = firebase.auth();
          const isPublic = () => {
            const currentPath = window.location.pathname;
            return currentPath.endsWith("/") || currentPath.endsWith("index.html") || currentPath.endsWith("dashboard.html") || currentPath.endsWith("login.html") || currentPath.includes("admin_dashboard.html");
          };
          const clearWebSession = () => {
            localStorage.removeItem("nudgeWebLoggedIn");
            localStorage.removeItem("nudgeActiveDemoUserId");
          };
          const redirectToLogin = () => {
            const currentPath = window.location.pathname;
            localStorage.setItem("nudgePostLoginRedirect", currentPath.split("/").pop() || "dashboard.html");
            window.location.href = "login.html";
          };
          const handleUser = (user) => {
            if (user) {
              console.log("Authenticated user detected:", user.uid);
              if (!user.isAnonymous) {
                localStorage.removeItem("nudgePreviewMode");
                localStorage.removeItem("nudgePreviewRole");
                localStorage.setItem("nudgeWebLoggedIn", "true");
                localStorage.setItem("nudgeActiveDemoUserId", user.uid);
              }
              startListeningToFirestoreData();
              ensureWebActivityLedgerOutbox()
                .then(outbox => outbox.flush())
                .catch(error => {
                  console.warn("Activity Ledger resume failed:", error);
                });
              document.dispatchEvent(new Event('firebase-ready'));
              return;
            }

            console.log("No authenticated user detected.");
            if (isPreviewMode()) {
              const previewData = buildPreviewProfile();
              updateSidebarProfile(previewData);
              injectPreviewRoleBanner(previewData);
              document.dispatchEvent(new Event('firebase-ready'));
              return;
            }
            clearWebSession();
            if (!isPublic()) {
              redirectToLogin();
              return;
            }
            document.dispatchEvent(new Event('firebase-ready'));
          };

          auth.setPersistence(firebase.auth.Auth.Persistence.LOCAL)
            .catch(err => {
              console.warn("Auth persistence setup failed:", err);
            })
            .then(() => {
              auth.onAuthStateChanged((user) => {
                if (user || localStorage.getItem("nudgeWebLoggedIn") !== "true") {
                  handleUser(user);
                  return;
                }

                setTimeout(() => handleUser(auth.currentUser), 800);
              });
            });
        } catch (e) {
          console.warn("Firebase initialization failed, falling back to mock data: ", e);
          startListeningToFirestoreData();
          document.dispatchEvent(new Event('firebase-ready'));
        }
      } else {
        console.log("Firebase SDK not loaded, using local demo data");
        startListeningToFirestoreData();
        document.dispatchEvent(new Event('firebase-ready'));
      }
    })
    .catch(error => {
      console.warn("Firebase SDK loading failed:", error);
      document.dispatchEvent(new Event('firebase-ready'));
    });
}

function startListeningToFirestoreData() {
  if (!db) return;

  const currentUser = firebase.auth().currentUser;
  const loggedInUid = currentUser ? currentUser.uid : null;
  if (!loggedInUid) return;

  // The authenticated UID is the only writable identity. Friend/profile views
  // are loaded separately and never replace the active account.
  localStorage.setItem("nudgeActiveDemoUserId", loggedInUid);
  listenToUser(loggedInUid);
  listenToWebPrivacyConsent(loggedInUid);
  listenToWebPrivacyDataRequests(loggedInUid);
  listenToWebNotificationPreferences(loggedInUid);
  listenToWebUserNotifications(loggedInUid);
}

function webNotificationDate(value) {
  if (value && typeof value.toDate === "function") return value.toDate();
  const parsed = value ? new Date(value) : null;
  return parsed && !Number.isNaN(parsed.getTime()) ? parsed : null;
}

function listenToWebUserNotifications(userId) {
  if (webUserNotificationSub) webUserNotificationSub();
  currentWebUserNotifications = [];
  webUserNotificationSub = db.collection("user_notifications")
    .where("recipientUserId", "==", userId)
    .orderBy("createdAt", "desc")
    .limit(100)
    .onSnapshot(snapshot => {
      currentWebUserNotifications = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data(),
      }));
      renderWebUserNotifications();
    }, error => {
      console.error("User notification listen error:", error);
      currentWebUserNotifications = [];
      renderWebUserNotifications(error.message || "無法讀取站內通知");
    });
}

function renderWebUserNotifications(errorMessage = "") {
  const root = document.querySelector("[data-user-notifications]");
  if (!root) return;
  if (errorMessage) {
    root.innerHTML = `<div style="padding:16px; color:#fca5a5;">${escapeHtml(errorMessage)}</div>`;
    return;
  }
  if (currentWebUserNotifications.length === 0) {
    root.innerHTML = `
      <div style="padding:24px; text-align:center; color:var(--muted);">
        目前沒有站內通知。新的家庭／團體邀請與處理結果會顯示在這裡。
      </div>
    `;
    return;
  }
  root.innerHTML = currentWebUserNotifications.slice(0, 30)
    .map(notification => {
      const unread = notification.status === "unread";
      const createdAt = webNotificationDate(notification.createdAt);
      return `
        <article style="padding:16px 0; border-top:1px solid rgba(148,163,184,.14); display:grid; grid-template-columns:minmax(0,1fr) auto; gap:16px; align-items:start;">
          <div>
            <div style="display:flex; flex-wrap:wrap; gap:8px; align-items:center; margin-bottom:6px;">
              <strong style="color:#fff;">${escapeHtml(notification.title || "站內通知")}</strong>
              <span style="font-size:11px; padding:4px 8px; border-radius:999px; background:${unread ? "rgba(59,130,246,.15)" : "rgba(34,197,94,.12)"}; color:${unread ? "#93c5fd" : "#86efac"};">
                ${unread ? "未讀" : notification.status === "resolved" ? "邀請已處理" : "已讀"}
              </span>
            </div>
            <p style="margin:0; color:var(--muted); font-size:13px;">${escapeHtml(notification.body || "")}</p>
            <small style="display:block; margin-top:7px; color:rgba(148,163,184,.75);">
              ${escapeHtml(createdAt ? createdAt.toLocaleString("zh-TW") : "時間未提供")}
            </small>
          </div>
          ${unread ? `
            <button
              type="button"
              class="secondary-btn"
              data-user-notification-read="${escapeHtml(notification.id)}"
              style="white-space:nowrap;"
            >標示已讀</button>
          ` : ""}
        </article>
      `;
    })
    .join("");
}

async function markWebUserNotificationRead(notificationId) {
  if (!firebase.auth().currentUser || !functions) {
    throw new Error("請先登入並完成 Cloud Functions 初始化。");
  }
  const response = await functions.httpsCallable("markNotificationRead")({
    notificationId,
  });
  const result = response?.data;
  if (
    result?.notificationId !== notificationId ||
    result?.status !== "read" ||
    !result?.auditEventId
  ) {
    throw new Error("站內通知已讀結果無法驗證。");
  }
  return result;
}

document.addEventListener("click", event => {
  const button = event.target.closest("[data-user-notification-read]");
  if (!button) return;
  const notificationId = button.dataset.userNotificationRead || "";
  button.disabled = true;
  markWebUserNotificationRead(notificationId)
    .then(result => {
      toast(`已標示已讀 · Audit ${result.auditEventId.slice(-8)}`);
    })
    .catch(error => {
      console.error(error);
      button.disabled = false;
      toast(error.message || "無法更新站內通知");
    });
});

function defaultWebNotificationChannels() {
  return Object.fromEntries(
    Object.entries(WEB_NOTIFICATION_CHANNELS).map(([key, channel]) => [
      key,
      {
        enabled: channel.enabled,
        timeLabel: channel.timeLabel,
      },
    ]),
  );
}

function effectiveWebNotificationChannels() {
  const source = currentWebNotificationPreferences?.channels;
  const keys = Object.keys(WEB_NOTIFICATION_CHANNELS);
  if (
    !source ||
    keys.some(
      key =>
        typeof source[key]?.enabled !== "boolean" ||
        !/^(?:[01]\d|2[0-3]):[0-5]\d$/.test(source[key]?.timeLabel || ""),
    )
  ) {
    return defaultWebNotificationChannels();
  }
  return Object.fromEntries(
    keys.map(key => [
      key,
      {
        enabled: source[key].enabled,
        timeLabel: source[key].timeLabel,
      },
    ]),
  );
}

function listenToWebNotificationPreferences(userId) {
  if (webNotificationPreferenceSub) webNotificationPreferenceSub();
  currentWebNotificationPreferences = null;
  webNotificationPreferenceSub = db.collection("notification_preferences")
    .doc(userId)
    .onSnapshot(snapshot => {
      currentWebNotificationPreferences = snapshot.exists
        ? snapshot.data()
        : null;
      renderWebNotificationPreferences();
    }, error => {
      console.error("Notification preference listen error:", error);
      currentWebNotificationPreferences = null;
      renderWebNotificationPreferences(
        error.message || "無法讀取 Cloud 通知設定",
      );
    });
}

function renderWebNotificationPreferences(errorMessage = "") {
  const root = document.querySelector("[data-notification-preferences]");
  if (!root) return;
  const channels = effectiveWebNotificationChannels();
  const cloudVerified =
    currentWebNotificationPreferences?.schemaVersion === 1 &&
    currentWebNotificationPreferences?.userId ===
      firebase.auth().currentUser?.uid;
  const pushConfigured =
    currentWebNotificationPreferences?.delivery?.pushConfigured === true;
  const statusText = errorMessage || (
    cloudVerified
      ? "App／Web 已同步，變更會寫入 Cloud 稽核"
      : "尚無 Cloud 紀錄；第一次變更時會建立"
  );

  root.innerHTML = `
    <div style="display:flex; flex-wrap:wrap; gap:8px; margin-bottom:18px;">
      <span style="padding:7px 11px; border-radius:999px; background:rgba(16,185,129,.12); color:#34d399; font-size:12px; font-weight:700;">
        ${escapeHtml(statusText)}
      </span>
      <span style="padding:7px 11px; border-radius:999px; background:rgba(99,102,241,.12); color:#a5b4fc; font-size:12px; font-weight:700;">
        ${pushConfigured ? "裝置推播已配置" : "目前為本機排程／站內通知"}
      </span>
    </div>
    ${Object.entries(WEB_NOTIFICATION_CHANNELS).map(([key, metadata]) => {
      const channel = channels[key];
      return `
        <div style="display:grid; grid-template-columns:minmax(0,1fr) auto auto; gap:14px; align-items:center; padding:15px 0; border-top:1px solid rgba(148,163,184,.14);">
          <div>
            <strong style="display:block; color:#fff; margin-bottom:4px;">${escapeHtml(metadata.title)}</strong>
            <span style="font-size:12px; color:var(--muted);">${escapeHtml(metadata.description)}</span>
          </div>
          <select
            data-notification-channel="${escapeHtml(key)}"
            data-notification-field="timeLabel"
            ${webNotificationPreferenceUpdating ? "disabled" : ""}
            style="background:rgba(15,23,42,.75); color:#fff; border:1px solid rgba(148,163,184,.25); border-radius:8px; padding:8px;"
          >
            ${WEB_NOTIFICATION_TIME_OPTIONS.map(time => `
              <option value="${time}" ${channel.timeLabel === time ? "selected" : ""}>${time}</option>
            `).join("")}
          </select>
          <label style="display:flex; align-items:center; gap:7px; color:#e2e8f0; font-size:13px; font-weight:700;">
            <input
              type="checkbox"
              data-notification-channel="${escapeHtml(key)}"
              data-notification-field="enabled"
              ${channel.enabled ? "checked" : ""}
              ${webNotificationPreferenceUpdating ? "disabled" : ""}
            />
            ${channel.enabled ? "開啟" : "關閉"}
          </label>
        </div>
      `;
    }).join("")}
  `;
}

async function updateWebNotificationPreferences(channels) {
  const user = firebase.auth().currentUser;
  if (!user || !functions) {
    throw new Error("請先登入並完成 Cloud Functions 初始化。");
  }
  const clientRequestId =
    `notification_${Date.now()}_${Math.random().toString(36).slice(2, 10)}`;
  const response = await functions
    .httpsCallable("updateNotificationPreferences")({
      channels,
      clientRequestId,
      sourceSurface: "web",
    });
  const result = response?.data;
  if (
    !result?.auditEventId ||
    result?.preferences?.userId !== user.uid ||
    result?.preferences?.schemaVersion !== 1
  ) {
    throw new Error("Cloud 通知設定結果無法驗證。");
  }
  currentWebNotificationPreferences = result.preferences;
  return result;
}

document.addEventListener("change", async event => {
  const input = event.target.closest(
    "[data-notification-channel][data-notification-field]",
  );
  if (!input || webNotificationPreferenceUpdating) return;
  const channelKey = input.dataset.notificationChannel;
  const field = input.dataset.notificationField;
  const channels = effectiveWebNotificationChannels();
  if (!channels[channelKey] || !["enabled", "timeLabel"].includes(field)) {
    return;
  }
  channels[channelKey] = {
    ...channels[channelKey],
    [field]: field === "enabled" ? input.checked : input.value,
  };

  webNotificationPreferenceUpdating = true;
  renderWebNotificationPreferences();
  try {
    const result = await updateWebNotificationPreferences(channels);
    toast(
      `通知設定已同步 · Audit ${result.auditEventId.slice(-8)}`,
    );
  } catch (error) {
    console.error(error);
    toast(error.message || "通知設定同步失敗");
  } finally {
    webNotificationPreferenceUpdating = false;
    renderWebNotificationPreferences();
  }
});

function listenToWebPrivacyConsent(userId) {
  if (webPrivacyConsentSub) webPrivacyConsentSub();
  currentWebPrivacyConsent = null;
  webPrivacyConsentSub = db.collection("privacy_consents")
    .doc(userId)
    .onSnapshot(snapshot => {
      currentWebPrivacyConsent = snapshot.exists ? snapshot.data() : null;
      renderWebPrivacyConsent();
    }, error => {
      console.error("Privacy consent listen error:", error);
      currentWebPrivacyConsent = null;
      renderWebPrivacyConsent(error.message || "無法讀取 Cloud 同意狀態");
    });
}

function isCurrentWebHealthConsent() {
  return (
    currentWebPrivacyConsent?.status === "accepted" &&
    currentWebPrivacyConsent?.policyVersion ===
      CURRENT_PRIVACY_POLICY_VERSION &&
    currentWebPrivacyConsent?.scopes?.healthIngestion === true
  );
}

function renderWebPrivacyConsent(errorMessage = "") {
  const root = document.querySelector("[data-privacy-consent]");
  if (!root) return;
  const accepted = isCurrentWebHealthConsent();
  const status = root.querySelector("[data-privacy-status]");
  const version = root.querySelector("[data-privacy-version]");
  const updated = root.querySelector("[data-privacy-updated]");
  if (status) status.textContent = accepted ? "已同意並由 Cloud 稽核" : "未同意或已撤回";
  if (version) {
    version.textContent =
      currentWebPrivacyConsent?.policyVersion ||
      CURRENT_PRIVACY_POLICY_VERSION;
  }
  if (updated) {
    const rawUpdatedAt = currentWebPrivacyConsent?.updatedAt;
    const updatedAt =
      typeof rawUpdatedAt?.toDate === "function"
        ? rawUpdatedAt.toDate()
        : rawUpdatedAt
          ? new Date(rawUpdatedAt)
          : null;
    updated.textContent = errorMessage || (
      updatedAt && !Number.isNaN(updatedAt.getTime())
        ? `最後更新：${updatedAt.toLocaleString("zh-TW")}`
        : "尚無 Cloud 同意紀錄"
    );
  }
  const acceptButton = root.querySelector("[data-privacy-accept]");
  const revokeButton = root.querySelector("[data-privacy-revoke]");
  if (acceptButton) acceptButton.disabled = accepted;
  if (revokeButton) revokeButton.disabled = !accepted;
}

async function updateWebPrivacyConsent(accepted) {
  if (!firebase.auth().currentUser || !functions) {
    throw new Error("請先登入並完成 Cloud Functions 初始化。");
  }
  const clientRequestId =
    `privacy_${Date.now()}_${Math.random().toString(36).slice(2, 10)}`;
  const response = await functions.httpsCallable("recordPrivacyConsent")({
    action: accepted ? "accept" : "revoke",
    policyVersion: CURRENT_PRIVACY_POLICY_VERSION,
    clientRequestId,
    sourceSurface: "web",
  });
  const result = response?.data;
  if (
    !result?.auditEventId ||
    result?.consent?.policyVersion !== CURRENT_PRIVACY_POLICY_VERSION
  ) {
    throw new Error("Cloud 同意結果無法驗證。");
  }
  currentWebPrivacyConsent = result.consent;
  renderWebPrivacyConsent();
  return result;
}

document.querySelector("[data-privacy-accept]")?.addEventListener(
  "click",
  async event => {
    const button = event.currentTarget;
    button.disabled = true;
    try {
      const result = await updateWebPrivacyConsent(true);
      toast(`已記錄健康資料同意 · Audit ${result.auditEventId.slice(-8)}`);
    } catch (error) {
      console.error(error);
      toast(error.message || "隱私同意未完成");
      renderWebPrivacyConsent();
    }
  },
);

document.querySelector("[data-privacy-revoke]")?.addEventListener(
  "click",
  async event => {
    const button = event.currentTarget;
    button.disabled = true;
    try {
      const result = await updateWebPrivacyConsent(false);
      toast(`已撤回後續健康 ingestion · Audit ${result.auditEventId.slice(-8)}`);
    } catch (error) {
      console.error(error);
      toast(error.message || "撤回未完成");
      renderWebPrivacyConsent();
    }
  },
);

function webPrivacyRequestDate(value) {
  if (value && typeof value.toDate === "function") return value.toDate();
  const parsed = value ? new Date(value) : null;
  return parsed && !Number.isNaN(parsed.getTime()) ? parsed : null;
}

function webPrivacyRequestStatus(request) {
  return {
    processing: "產生中",
    ready: "可下載",
    expired: "已到期",
    failed: "產生失敗",
    pending: "等待冷靜期",
    in_review: "承辦審核中",
    deleting: "正在刪除帳號資料",
    deletion_failed: "刪除未完成，等待安全重試",
    cancelled: "已取消",
    rejected: "未受理",
    completed: "已完成並留存證明",
  }[request.status] || request.status || "未知";
}

function listenToWebPrivacyDataRequests(userId) {
  if (webPrivacyDataRequestSub) webPrivacyDataRequestSub();
  currentWebPrivacyDataRequests = [];
  webPrivacyDataRequestSub = db.collection("privacy_data_requests")
    .where("userId", "==", userId)
    .onSnapshot(snapshot => {
      currentWebPrivacyDataRequests = snapshot.docs
        .map(doc => ({ id: doc.id, ...doc.data() }))
        .sort((a, b) => {
          const aTime = webPrivacyRequestDate(a.requestedAt)?.getTime() || 0;
          const bTime = webPrivacyRequestDate(b.requestedAt)?.getTime() || 0;
          return bTime - aTime;
        });
      renderWebPrivacyDataRequests();
    }, error => {
      console.error("Privacy data request listen error:", error);
      const list = document.querySelector("[data-privacy-request-list]");
      if (list) {
        list.innerHTML = `<p>申請紀錄讀取失敗：${escapeHtml(error.message || "未知錯誤")}</p>`;
      }
    });
}

function renderWebPrivacyDataRequests() {
  const root = document.querySelector("[data-privacy-data-rights]");
  if (!root) return;
  const list = root.querySelector("[data-privacy-request-list]");
  const requestButtons = root.querySelectorAll(
    "[data-privacy-request-export], [data-privacy-request-deletion]",
  );
  requestButtons.forEach(button => {
    button.disabled = webPrivacyDataRequestUpdating;
  });
  if (!list) return;
  if (!currentWebPrivacyDataRequests.length) {
    list.innerHTML = "<p>尚無正式資料權利申請。</p>";
    return;
  }
  list.innerHTML = currentWebPrivacyDataRequests.slice(0, 10).map(request => {
    const isExport = request.type === "export";
    const requestedAt = webPrivacyRequestDate(request.requestedAt);
    const expiresAt = webPrivacyRequestDate(request.expiresAt);
    const canDownload =
      isExport &&
      request.status === "ready" &&
      expiresAt &&
      expiresAt.getTime() > Date.now();
    const canCancel =
      request.type === "account_deletion" &&
      ["pending", "in_review"].includes(request.status);
    return `
      <article class="mini-card">
        <span class="eyebrow">${isExport ? "DATA EXPORT" : "ACCOUNT DELETION"}</span>
        <h3>${isExport ? "帳號資料匯出" : "帳號刪除申請"} · ${escapeHtml(webPrivacyRequestStatus(request))}</h3>
        <p>申請：${escapeHtml(requestedAt ? requestedAt.toLocaleString("zh-TW") : "未提供")}
          ${expiresAt ? `<br>到期：${escapeHtml(expiresAt.toLocaleString("zh-TW"))}` : ""}
          ${request.caseId ? `<br>案件編號：${escapeHtml(request.caseId)}` : ""}
          ${request.resolutionNote ? `<br>承辦說明：${escapeHtml(request.resolutionNote)}` : ""}
        </p>
        ${canDownload ? `<button class="button primary" type="button" data-privacy-download="${escapeHtml(request.id)}">下載 JSON</button>` : ""}
        ${canCancel ? `<button class="button ghost" type="button" data-privacy-cancel="${escapeHtml(request.id)}">取消刪除申請</button>` : ""}
      </article>
    `;
  }).join("");
  list.querySelectorAll("[data-privacy-download]").forEach(button => {
    button.addEventListener("click", () =>
      downloadWebPrivacyExport(button.dataset.privacyDownload)
    );
  });
  list.querySelectorAll("[data-privacy-cancel]").forEach(button => {
    button.addEventListener("click", () =>
      cancelWebPrivacyRequest(button.dataset.privacyCancel)
    );
  });
}

function webPrivacyClientRequestId(prefix) {
  return `${prefix}_${Date.now()}_${Math.random().toString(36).slice(2, 10)}`;
}

async function callWebPrivacyData(name, payload) {
  if (!firebase.auth().currentUser || !functions) {
    throw new Error("請先登入並完成 Cloud Functions 初始化。");
  }
  const response = await functions.httpsCallable(name)(payload);
  if (!response?.data?.auditEventId) {
    throw new Error("Cloud 隱私資料結果缺少稽核事件。");
  }
  return response.data;
}

async function requestWebPrivacyDataAction(action, reason = "") {
  return callWebPrivacyData("requestPrivacyDataAction", {
    action,
    reason,
    clientRequestId: webPrivacyClientRequestId("privacy_data"),
    sourceSurface: "web",
  });
}

async function withWebPrivacyDataBusy(operation) {
  if (webPrivacyDataRequestUpdating) return;
  webPrivacyDataRequestUpdating = true;
  renderWebPrivacyDataRequests();
  try {
    await operation();
  } catch (error) {
    console.error(error);
    toast(error.message || "隱私資料操作未完成");
  } finally {
    webPrivacyDataRequestUpdating = false;
    renderWebPrivacyDataRequests();
  }
}

document.querySelector("[data-privacy-request-export]")?.addEventListener(
  "click",
  () => withWebPrivacyDataBusy(async () => {
    const result = await requestWebPrivacyDataAction("request_export");
    toast(`資料匯出已建立 · Audit ${result.auditEventId.slice(-8)}`);
  }),
);

document.querySelector("[data-privacy-request-deletion]")?.addEventListener(
  "click",
  () => {
    if (!window.confirm(
      "送出後會進入 7 天冷靜期，冷靜期內仍可取消。正式執行開始後帳號會停用；若作業失敗，承辦者會依案件編號安全重試。確定送出？",
    )) {
      return;
    }
    const reason = window.prompt("刪除原因（選填，最多 1000 字）", "") || "";
    withWebPrivacyDataBusy(async () => {
      const result = await requestWebPrivacyDataAction(
        "request_account_deletion",
        reason.slice(0, 1000),
      );
      toast(`刪除申請已受理 · Audit ${result.auditEventId.slice(-8)}`);
    });
  },
);

function cancelWebPrivacyRequest(requestId) {
  if (!window.confirm("取消後帳號與雲端資料會維持原狀。確定取消申請？")) return;
  withWebPrivacyDataBusy(async () => {
    const result = await callWebPrivacyData("cancelPrivacyDataRequest", {
      requestId,
      clientRequestId: webPrivacyClientRequestId("privacy_cancel"),
      sourceSurface: "web",
    });
    toast(`已取消刪除申請 · Audit ${result.auditEventId.slice(-8)}`);
  });
}

function downloadWebPrivacyExport(requestId) {
  withWebPrivacyDataBusy(async () => {
    const result = await callWebPrivacyData("getPrivacyExportDownload", {
      requestId,
      clientRequestId: webPrivacyClientRequestId("privacy_download"),
      sourceSurface: "web",
    });
    if (!/^https:\/\//.test(result.downloadUrl || "")) {
      throw new Error("Cloud 未提供安全下載連結。");
    }
    const link = document.createElement("a");
    link.href = result.downloadUrl;
    link.rel = "noopener";
    link.target = "_blank";
    link.download = `nudge-data-export-${Date.now()}.json`;
    document.body.appendChild(link);
    link.click();
    link.remove();
    toast(`已開啟資料匯出 · Audit ${result.auditEventId.slice(-8)}`);
  });
}

function getOrCreateSidePanel() {
  let panel = $(".demo-user-container");
  if (!panel) {
    const sidebar = $(".sidebar");
    if (sidebar) {
      const brandHeader = sidebar.querySelector(".sidebar-header-row") || sidebar.querySelector(".brand");
      if (brandHeader) {
        brandHeader.insertAdjacentHTML('afterend', '<section class="demo-user-container" style="margin-top: 14px; margin-bottom: 14px; padding: 0 16px;"></section>');
      } else {
        sidebar.insertAdjacentHTML('afterbegin', '<section class="demo-user-container" style="margin-top: 14px; margin-bottom: 14px; padding: 0 16px;"></section>');
      }
      panel = $(".demo-user-container");
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
  if (data) {
    if (data.nickname) localStorage.setItem("nudgeNicknameCache", data.nickname);
    if (data.signature) localStorage.setItem("nudgeSignatureCache", data.signature);
    if (data.accentColor) localStorage.setItem("nudgeAccentColorCache", data.accentColor);
    if (data.profileTitleBadgeKey) localStorage.setItem("nudgeTitleBadgeCache", data.profileTitleBadgeKey);
    if (typeof data.disciplineCoins === 'number') localStorage.setItem("nudgeCoinsCache", data.disciplineCoins);
    if (typeof data.planetCount === 'number') localStorage.setItem("nudgePlanetsCache", data.planetCount);
    if (data.userRole) localStorage.setItem("nudgeRoleCache", data.userRole);
  }

  updateRoleAwareNavigation(data);

  const existingCard = document.querySelector(".sidebar-profile-container");
  if (existingCard) {
    existingCard.remove();
  }

  // 門禁安全保護判斷
  checkPagePermissions(data);
}

function updateRoleAwareNavigation(data) {
  const capabilities = resolveWebCapabilities(data);
  const nav = document.querySelector(".sidebar .nav");
  if (!nav) return;

  const guardianLink = nav.querySelector('a[href*="guardian"]');
  if (guardianLink) {
    if (capabilities.isGuardian) {
      guardianLink.href = "guardian.html";
      guardianLink.textContent = "家長陪伴中心";
    } else if (capabilities.isChild) {
      guardianLink.href = "guardian-link.html";
      guardianLink.textContent = "家庭連結與隱私";
    } else {
      guardianLink.href = "guardian-link.html";
      guardianLink.textContent = "建立家庭連結";
    }
  }

  const groupLink = nav.querySelector('a[href*="groups"]');
  if (groupLink) {
    if (capabilities.canManageGroup) {
      groupLink.href = "groups.html";
      groupLink.textContent = "團體管理控制台";
    } else if (capabilities.canParticipateInGroup) {
      groupLink.href = "groups.html";
      groupLink.textContent = "團體任務與進度";
    } else {
      groupLink.href = "groups-link.html";
      groupLink.textContent = "加入或建立團體";
    }
  }
}

function applyRoleSpecificCopy(data, capabilities) {
  const isGroupPage = window.location.pathname.includes("/groups");
  if (isGroupPage) {
    const challengeGroupInput = document.querySelector("[data-challenge-group]");
    if (challengeGroupInput && data.groupName) {
      challengeGroupInput.value = data.groupName;
    }
  }
  if (!window.location.pathname.endsWith("/groups.html")) {
    return;
  }

  const heading = document.querySelector(".hero h1");
  const description = document.querySelector(".hero h1 + p");
  if (heading) heading.textContent = capabilities.groupSurfaceTitle;
  if (description) {
    description.textContent = capabilities.canManageGroup
      ? "建立挑戰、排程與任務模板；成員在 App 端各自開始、暫停並完成，不需等待管理者開房。"
      : "查看共同目標、同儕進度與每週摘要；你可以在 App 端依自己的時間完成團體活動。";
  }

  const managerOnlyDestinations = [
    "groups-challenge.html",
    "groups-study-schedule.html",
    "groups-templates.html",
  ];
  document.querySelectorAll(".subnav a").forEach((link) => {
    const destination = link.getAttribute("href") || "";
    const managerOnly = managerOnlyDestinations.includes(destination);
    const shouldHide = managerOnly && !capabilities.canManageGroup;
    link.hidden = shouldHide;
  });
  document.querySelectorAll(".center-hub .hub-card").forEach((card) => {
    const destination = card.getAttribute("href") || "";
    const managerOnly = managerOnlyDestinations.includes(destination);
    const shouldHide = managerOnly && !capabilities.canManageGroup;
    card.hidden = shouldHide;
  });

  const careTitle = document.querySelector("#groupCareNote h2");
  const careCopy = document.querySelector("#groupCareNote > p");
  if (careTitle) {
    careTitle.textContent = capabilities.canManageGroup
      ? "設計規則，讓成員自己前進。"
      : "跟著團體前進，也保留自己的節奏。";
  }
  if (careCopy) {
    careCopy.textContent = capabilities.canManageGroup
      ? "管理者負責建立共同目標、挑戰規則與可見範圍，不負責替成員開始或結束每一次活動。"
      : "你的開始、暫停與完成都由自己決定；團體只提供共同目標、同儕回饋與進度摘要。";
  }
}

function injectPreviewRoleBanner(data) {
  if (!isPreviewMode()) return;
  const main = document.querySelector(".main");
  if (!main) return;

  document.getElementById("previewRoleBanner")?.remove();
  const capabilities = resolveWebCapabilities(data);
  const banner = document.createElement("section");
  banner.id = "previewRoleBanner";
  banner.className = "preview-role-banner";
  banner.innerHTML = `
    <div>
      <span class="eyebrow">展示模式 · 不會寫入資料</span>
      <strong>目前介面：${escapeHtml(getRoleLabel(data.userRole || "personal"))}${capabilities.role === "groupManager" ? "（管理者）" : capabilities.role === "groupMember" ? "（成員）" : ""}</strong>
    </div>
    <div class="preview-role-actions" aria-label="切換展示身分">
      <button type="button" data-preview-role="personal">個人</button>
      <button type="button" data-preview-role="child">孩子</button>
      <button type="button" data-preview-role="guardian">家長</button>
      <button type="button" data-preview-role="groupMember">團體成員</button>
      <button type="button" data-preview-role="groupManager">團體管理者</button>
    </div>
  `;
  main.insertAdjacentElement("afterbegin", banner);

  banner.querySelectorAll("[data-preview-role]").forEach((button) => {
    const isActive =
      button.dataset.previewRole ===
      (localStorage.getItem("nudgePreviewRole") || "personal");
    button.classList.toggle("active", isActive);
    button.addEventListener("click", () => {
      localStorage.setItem("nudgePreviewRole", button.dataset.previewRole);
      window.location.href = "dashboard.html";
    });
  });

  document
    .querySelectorAll(
      ".main input, .main textarea, .main select, .main button:not([data-preview-role])",
    )
    .forEach((control) => {
      control.disabled = true;
      control.setAttribute("aria-disabled", "true");
      control.title = "展示模式不會寫入或變更任何資料";
    });
}

function showRelativeRequiredBanner() {
  if (document.getElementById("guardianLinkRequiredBanner")) return;
  const main = document.querySelector(".main");
  if (!main) return;
  const banner = document.createElement("div");
  banner.id = "guardianLinkRequiredBanner";
  banner.style.cssText = "background: rgba(245,158,11,0.1); border: 1px solid rgba(245,158,11,0.3); border-radius: 16px; padding: 16px 24px; margin-top: 34px; font-weight: 700; color: #f59e0b; text-align: center;";
  banner.innerHTML = `🔒 家長陪伴功能目前未啟用。請前往「<a href="guardian-link.html" style="color: #ff9e00; text-decoration: underline;">連結親屬</a>」完成親屬帳號綁定，以啟用週報、鼓勵卡與共同目標！`;
  main.insertAdjacentElement("beforeend", banner);
}

function showGroupRequiredBanner() {
  if (document.getElementById("groupLinkRequiredBanner")) return;
  const main = document.querySelector(".main");
  if (!main) return;
  const banner = document.createElement("div");
  banner.id = "groupLinkRequiredBanner";
  banner.style.cssText = "background: rgba(59,130,246,0.1); border: 1px solid rgba(59,130,246,0.3); border-radius: 16px; padding: 16px 24px; margin-top: 34px; font-weight: 700; color: #3b82f6; text-align: center;";
  banner.innerHTML = `🔒 團體管理功能目前未啟用。請前往「<a href="groups-link.html" style="color: #3b82f6; text-decoration: underline;">連結組織</a>」完成組織加入或創建，以解鎖團隊管理與專注挑戰功能！`;
  main.insertAdjacentElement("beforeend", banner);
}

function checkPagePermissions(data) {
  const userRole = data.userRole || "personal";
  const capabilities = resolveWebCapabilities(data);
  const path = window.location.pathname;
  const isGuardianPage = path.includes("guardian") || document.body.getAttribute("data-page") === "guardian";
  const isGroupsPage = path.includes("groups") || document.body.getAttribute("data-page") === "groups";
  const isLinkPage = path.includes("guardian-link.html") || path.includes("groups-link.html");
  if (isGuardianPage && !isPreviewMode() && !familyLinkLoaded) return;
  if (isGroupsPage && !isPreviewMode() && !groupLoaded) return;
  const roleGateRedirect = resolveWebRoleGateRedirect(path, data);

  if (roleGateRedirect) {
    window.location.replace(roleGateRedirect);
    return;
  }

  // 1. 導覽列發光推薦與引導橫幅
  updateNavigationRecommendation(capabilities);
  applyRoleSpecificCopy(data, capabilities);

  // 2. 移除舊的防護遮罩
  const existingOverlay = document.getElementById("roleGatekeeperOverlay");
  if (existingOverlay) {
    existingOverlay.remove();
  }

  // 3. 移除網頁端舊的綁定卡片並恢復主體顯示（非連結頁面時才移除）
  if (!isLinkPage) {
    const existingBindingCard = document.getElementById("webBindingGatedCard");
    if (existingBindingCard) {
      existingBindingCard.remove();
    }
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

  // For guardian and groups pages, always allow access.
  if (isGuardianPage) {
    const isLinked =
      Boolean(activeFamilyLink) ||
      (isPreviewMode() && ["guardian", "child"].includes(data.userRole));
    const isGuardianLinkPage = window.location.pathname.includes("guardian-link.html");

    // Add subnav link dynamically if not present
    const subnav = document.querySelector(".subnav");
    if (subnav && !document.getElementById("guardianLinkTab") && !subnav.querySelector('a[href*="guardian-link"]')) {
      subnav.insertAdjacentHTML("beforeend", `<a id="guardianLinkTab" href="guardian-link.html" class="${isGuardianLinkPage ? 'active' : ''}">連結親屬</a>`);
    }

    if (capabilities.isChild && isGuardianLinkPage) {
      document.querySelectorAll(".subnav a").forEach((link) => {
        link.hidden = !link.getAttribute("href")?.includes("guardian-link");
      });
      const heading = document.querySelector(".hero h1");
      const description = document.querySelector(".hero h1 + p");
      const eyebrow = document.querySelector(".hero .eyebrow");
      if (eyebrow) eyebrow.textContent = "Family Link & Privacy";
      if (heading) heading.textContent = "你的家庭連結與資料隱私。";
      if (description) {
        description.textContent =
          "由你決定是否接受家長連結、分享哪些趨勢資料，也可以隨時解除；家長看不到未經同意的原始健康資料。";
      }
    }

    // Set side stats text in hero-card
    const bindStatusTextNode = document.getElementById("guardianBindStatusText");
    if (bindStatusTextNode) {
      bindStatusTextNode.textContent = isLinked ? "已連結" : "未連結";
      bindStatusTextNode.style.color = isLinked ? "#10b981" : "#ef4444";
    }

    if (!isLinked) {
      // Remove linked banner if any
      const existingBanner = document.getElementById("webGuardianLinkedBanner");
      if (existingBanner) existingBanner.remove();

      if (isGuardianLinkPage) {
        if (!document.getElementById("webBindingGatedCard")) {
          showWebRelativeBindingCard(false);
        }
        showRelativeRequiredBanner();
        // Update descriptions to show role
        const descNode = document.getElementById("webBindingDesc");
        if (descNode) {
          descNode.innerHTML = `🛡️ 當前身分：<strong style="color: #10b981;">${getRoleLabel(userRole)}</strong><br><br>您還未與家人進行親屬綁定。請在下方輸入對方的 Nudge ID 發送申請，或在列表處理待同意的申請。連結後即可查看對方專注、睡眠與健康數據。`;
        }
      } else {
        const isOverviewPage = window.location.pathname.endsWith("guardian.html") || window.location.pathname.endsWith("guardian");
        if (isOverviewPage) {
          const careNote = document.getElementById("guardianCareNote");
          if (careNote) {
            careNote.style.display = "block";
            careNote.style.textAlign = "center";
            careNote.style.cursor = "pointer";
            careNote.innerHTML = `
              <a href="guardian-link.html" style="text-decoration: none; color: #f59e0b; font-weight: 700; font-size: 16px; line-height: 1.6; display: block; width: 100%;">
                🔒 家長陪伴功能目前未啟用。請前往「<span style="color: #ff9e00; text-decoration: underline;">連結親屬</span>」完成親屬帳號綁定，以啟用週報、鼓勵卡與共同目標！
              </a>
            `;
          }
          const existingRequired = document.getElementById("guardianLinkRequiredBanner");
          if (existingRequired) existingRequired.remove();
        } else {
          showRelativeRequiredBanner();
        }
        // Remove binding card if any on home page
        const existingCard = document.getElementById("webBindingGatedCard");
        if (existingCard) existingCard.remove();
      }
    } else {
      const existingRequired = document.getElementById("guardianLinkRequiredBanner");
      if (existingRequired) existingRequired.remove();
      const existingCard = document.getElementById("webBindingGatedCard");
      if (existingCard) existingCard.remove();

      const careNote = document.getElementById("guardianCareNote");
      if (careNote) {
        careNote.style.display = "";
        careNote.style.textAlign = "";
        careNote.style.cursor = "";
      }
      if (!isGuardianLinkPage) {
        if (!document.getElementById("webGuardianLinkedBanner")) {
          showGuardianLinkedBanner(data);
        }
      } else {
        const descNode = document.getElementById("webBindingDesc");
        if (descNode) {
          descNode.innerHTML = `🛡️ 您已成功與家人 <strong>${data.webToolsState?.guardianInvite?.relativeId || ''}</strong> 進行親屬綁定！您可以前往「<a href="guardian.html" style="color: #ff9e00; text-decoration: underline;">中心總覽</a>」開始查看自律數據。`;
        }
        const formNode = document.getElementById("webBindingForm");
        if (formNode) formNode.style.display = "none";
      }
    }
    return;
  }

  if (isGroupsPage) {
    const hasGroup = capabilities.hasGroup;
    const isGroupsLinkPage = window.location.pathname.includes("groups-link.html");

    // Add subnav link dynamically if not present
    const subnav = document.querySelector(".subnav");
    if (subnav && !document.getElementById("groupsLinkTab") && !subnav.querySelector('a[href*="groups-link"]')) {
      subnav.insertAdjacentHTML("beforeend", `<a id="groupsLinkTab" href="groups-link.html" class="${isGroupsLinkPage ? 'active' : ''}">連結組織</a>`);
    }

    const groupsStatusTextNode = document.getElementById("groupsBindStatusText");
    if (groupsStatusTextNode) {
      groupsStatusTextNode.textContent = hasGroup ? "已連結" : "未連結";
      groupsStatusTextNode.style.color = hasGroup ? "#10b981" : "#ef4444";
    }

    if (window.location.pathname.includes("groups-creation.html")) {
      if (hasGroup) {
        renderWebGroupCreationPage(data);
      } else {
        showGroupRequiredBanner();
        const container = document.getElementById("groupsCreationContainer");
        if (container) {
          container.innerHTML = `
            <div class="panel" style="padding: 30px;">
              <h2>🔒 尚未加入團體</h2>
              <p>請先前往「<a href="groups-link.html" style="color: #3b82f6; text-decoration: underline;">連結組織</a>」頁面建立新團體或輸入 ID 加入，以解鎖團隊建立與成員管理功能！</p>
            </div>
          `;
        }
      }
      return;
    }

    if (!hasGroup) {
      if (isGroupsLinkPage) {
        if (!document.getElementById("webBindingGatedCard")) {
          showWebGroupBindingCard(false);
        }
        showGroupRequiredBanner();
      } else {
        const isOverviewPage = window.location.pathname.endsWith("groups.html") || window.location.pathname.endsWith("groups");
        if (isOverviewPage) {
          const careNote = document.getElementById("groupCareNote");
          if (careNote) {
            careNote.style.display = "block";
            careNote.style.textAlign = "center";
            careNote.style.cursor = "pointer";
            careNote.innerHTML = `
              <a href="groups-link.html" style="text-decoration: none; color: #3b82f6; font-weight: 700; font-size: 16px; line-height: 1.6; display: block; width: 100%;">
                🔒 團體管理功能目前未啟用。請前往「<span style="color: #3b82f6; text-decoration: underline;">連結組織</span>」完成組織加入或創建，以解鎖團隊管理與專注挑戰功能！
              </a>
            `;
          }
          const existingRequired = document.getElementById("groupLinkRequiredBanner");
          if (existingRequired) existingRequired.remove();
        } else {
          showGroupRequiredBanner();
        }
        const existingCard = document.getElementById("webBindingGatedCard");
        if (existingCard) existingCard.remove();
      }
    } else {
      const existingRequired = document.getElementById("groupLinkRequiredBanner");
      if (existingRequired) existingRequired.remove();

      const careNote = document.getElementById("groupCareNote");
      if (careNote) {
        careNote.style.display = "";
        careNote.style.textAlign = "";
        careNote.style.cursor = "";
      }

      if (isGroupsLinkPage) {
        const linkContainer = document.getElementById("groupsLinkContainer");
        if (linkContainer) {
          linkContainer.style.maxWidth = "none";
        }
        renderWebGroupCreationPage(data);
      } else {
        const existingCard = document.getElementById("webBindingGatedCard");
        if (existingCard) existingCard.remove();
        renderWebGroupInfo(data);
      }
    }
    return;
  }
}

function updateNavigationRecommendation(capabilities) {
  // 清除舊的發光
  document.querySelectorAll(".nav a").forEach(a => a.classList.remove("recommend-glow"));

  const isHome = document.body.getAttribute("data-page") === "home" || window.location.pathname.includes("index");
  const main = document.querySelector(".main");

  // 移除舊橫幅
  const oldBanner = document.getElementById("recommendBanner");
  if (oldBanner) {
    oldBanner.remove();
  }

  if (capabilities.isGuardian) {
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
  } else if (capabilities.canManageGroup) {
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
  } else if (capabilities.canParticipateInGroup) {
    document.querySelectorAll(".nav a").forEach(a => {
      if (a.getAttribute("href") === "groups.html") {
        a.classList.add("recommend-glow");
      }
    });
    if (isHome && main) {
      const bannerHtml = `
        <div id="recommendBanner" class="recommend-banner">
          <div class="recommend-banner-content">
            <span class="recommend-banner-icon">🤝</span>
            <div class="recommend-banner-text">
              <strong>您目前是團體成員身分</strong>
              <p>前往團體中心查看共同目標與同儕進度；每次活動仍由你依自己的時間開始與完成。</p>
            </div>
          </div>
          <button class="recommend-banner-btn" onclick="window.location.href='groups.html'">查看團體進度</button>
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

let currentIncomingGroupRequests = [];
let incomingGroupRequestsSub = null;

function listenToRequests(userId) {
  if (!db) return;
  if (incomingRequestsSub) incomingRequestsSub();
  if (outgoingRequestsSub) outgoingRequestsSub();
  if (incomingGroupRequestsSub) incomingGroupRequestsSub();

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
        autoUpdateWebLinkage(userId, accepted[0]);
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
        autoUpdateWebLinkage(userId, accepted[0]);
      } else {
        checkAndAutoClearWebLinkage(userId);
      }
      refreshWebBindingCardUI();
    }, err => console.error("Outgoing requests listen error: ", err));

  incomingGroupRequestsSub = db.collection("group_requests")
    .where("receiverId", "==", userId)
    .where("status", "==", "pending")
    .onSnapshot(snapshot => {
      const docs = [];
      snapshot.forEach(doc => {
        docs.push({ id: doc.id, ...doc.data() });
      });
      currentIncomingGroupRequests = docs;
      refreshWebBindingCardUI();
    }, err => console.error("Incoming group requests listen error: ", err));
}

function autoUpdateWebLinkage(userId, request) {
  const isSender = request.senderId === userId;
  const relativeNudgeId = isSender
    ? request.receiverNudgeId
    : request.senderNudgeId;
  const relativeRole = isSender ? request.receiverRole : request.senderRole;
  const store = JSON.parse(localStorage.getItem("nudgeWebTools") || "{}");
  const isAlreadyLinked = store.guardianInviteStatus?.status === 'linked' && store.guardianInvite?.relativeId === relativeNudgeId;
  if (isAlreadyLinked) return;

  db.collection("users").doc(userId).update({
    "webToolsState.guardianInvite": {
      "linkId": request.id,
      "goal": "共同健康與專注",
      "permission": "只看總覽",
      "message": "親屬帳號已連結。",
      "relativeId": relativeNudgeId,
      "relativeRole": relativeRole
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

  if (document.getElementById("notificationsPageContainer")) {
    renderNotificationsPage();
  }

  // 顯示全域的親屬綁定邀請通知橫幅
  const main = document.querySelector(".main");
  if (!main) return;

  let banner = document.getElementById("globalGuardianRequestBanner");
  if (currentIncomingRequests.length > 0) {
    if (!banner) {
      banner = document.createElement("div");
      banner.id = "globalGuardianRequestBanner";
      banner.style.cssText = "background: rgba(245, 158, 11, 0.1); border: 1px solid rgba(245, 158, 11, 0.3); border-radius: 12px; padding: 12px 20px; margin: 16px 0 24px 0; display: flex; align-items: center; justify-content: space-between; gap: 16px;";

      const firstSection = main.querySelector("header.hero, section, .page-section, div:not(#globalGuardianRequestBanner)");
      if (firstSection) {
        firstSection.insertAdjacentElement("beforebegin", banner);
      } else {
        main.insertAdjacentElement("afterbegin", banner);
      }
    }

    const req = currentIncomingRequests[0];
    const senderName = req.senderNickname || "使用者";
    const senderNudge = req.senderNudgeId || "";
    const senderRole = getRoleLabel(req.senderRole || "personal");

    banner.innerHTML = `
      <div style="display: flex; align-items: center; gap: 12px;">
        <span style="font-size: 24px;">🔔</span>
        <div>
          <strong style="color: #f59e0b; display: block; margin-bottom: 4px;">收到親屬綁定邀請</strong>
          <span style="color: rgba(255,255,255,0.85); font-size: 14px;">${escapeHtml(senderName)} (${escapeHtml(senderNudge)}) [身分：${escapeHtml(senderRole)}] 邀請與您建立親屬連結。接收邀請後將開始雙向數據同步。</span>
        </div>
      </div>
      <div style="display: flex; gap: 8px;">
        <button data-request-action="approve-guardian" data-request-id="${escapeHtml(req.id)}" style="background: #10b981; border: none; color: #fff; padding: 6px 14px; border-radius: 6px; font-size: 13px; font-weight: 700; cursor: pointer;">同意</button>
        <button data-request-action="decline-guardian" data-request-id="${escapeHtml(req.id)}" style="background: transparent; border: 1px solid #ef4444; color: #ef4444; padding: 6px 14px; border-radius: 6px; font-size: 13px; font-weight: 700; cursor: pointer;">拒絕</button>
      </div>
    `;
  } else {
    if (banner) banner.remove();
  }

  // 顯示全域的團體綁定邀請通知橫幅
  let groupBanner = document.getElementById("globalGroupRequestBanner");
  if (currentIncomingGroupRequests.length > 0) {
    if (document.getElementById("webGroupRequestsContainer")) {
      renderGroupRequestsList();
    }

    if (!groupBanner) {
      groupBanner = document.createElement("div");
      groupBanner.id = "globalGroupRequestBanner";
      groupBanner.style.cssText = "background: rgba(20, 184, 166, 0.1); border: 1px solid rgba(20, 184, 166, 0.3); border-radius: 12px; padding: 12px 20px; margin: 16px 0 24px 0; display: flex; align-items: center; justify-content: space-between; gap: 16px;";

      const firstSection = main.querySelector("header.hero, section, .page-section, div:not(#globalGuardianRequestBanner):not(#globalGroupRequestBanner)");
      if (firstSection) {
        firstSection.insertAdjacentElement("beforebegin", groupBanner);
      } else {
        main.insertAdjacentElement("afterbegin", groupBanner);
      }
    }

    const req = currentIncomingGroupRequests[0];
    const senderName = req.senderNickname || "使用者";
    const senderNudge = req.senderNudgeId || "";
    const groupName = req.groupName || "自律團體";
    const groupId = req.groupId || "";

    groupBanner.innerHTML = `
      <div style="display: flex; align-items: center; gap: 12px;">
        <span style="font-size: 24px;">👥</span>
        <div>
          <strong style="color: #14b8a6; display: block; margin-bottom: 4px;">收到團體邀請</strong>
          <span style="color: rgba(255,255,255,0.85); font-size: 14px;">${escapeHtml(senderName)} (${escapeHtml(senderNudge)}) 邀請您加入團隊【${escapeHtml(groupName)}】(ID: ${escapeHtml(groupId)})。同意後將會與團隊同步您的挑戰進度！</span>
        </div>
      </div>
      <div style="display: flex; gap: 8px;">
        <button data-request-action="approve-group" data-request-id="${escapeHtml(req.id)}" data-group-id="${escapeHtml(groupId)}" data-group-name="${escapeHtml(groupName)}" style="background: #14b8a6; border: none; color: #fff; padding: 6px 14px; border-radius: 6px; font-size: 13px; font-weight: 700; cursor: pointer;">同意加入</button>
        <button data-request-action="decline-group" data-request-id="${escapeHtml(req.id)}" style="background: transparent; border: 1px solid #ef4444; color: #ef4444; padding: 6px 14px; border-radius: 6px; font-size: 13px; font-weight: 700; cursor: pointer;">拒絕</button>
      </div>
    `;
  } else {
    if (groupBanner) groupBanner.remove();
  }
}

function sendWebGroupRequest(targetNudgeId, groupId, groupName) {
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

    if (targetNudgeIdUpper === myNudgeId.toUpperCase()) {
      toast("不能邀請自己");
      return;
    }

    db.collection("public_profiles").where("username", "==", targetNudgeIdUpper).limit(1).get().then(querySnap => {
      if (querySnap.empty) {
        toast("找不到該 Nudge ID 的使用者");
        return;
      }
      const receiverSnap = querySnap.docs[0];
      const receiverId = receiverSnap.id;

      db.collection("group_requests")
        .where("senderId", "==", activeUserId)
        .where("receiverId", "==", receiverId)
        .where("status", "==", "pending")
        .get()
        .then(outgoingCheck => {
          if (!outgoingCheck.empty) {
            toast("已發送過邀請，請耐心等待對方同意");
            return;
          }

          db.collection("group_requests").add({
            senderId: activeUserId,
            senderNudgeId: myNudgeId,
            senderNickname: myNickname,
            receiverId: receiverId,
            groupId: groupId,
            groupName: groupName,
            status: "pending",
            createdAt: new Date().toISOString()
          }).then(() => {
            toast(`已成功向 ${targetNudgeIdUpper} 發送團隊邀請！`);
            document.getElementById("webGroupInviteInput").value = "";
          }).catch(err => {
            console.error(err);
            toast("發送邀請失敗");
          });
        });
    });
  }).catch(err => console.error(err));
}

function approveWebGroupRequest(requestId, groupId, groupName) {
  const activeUserId = localStorage.getItem("nudgeActiveDemoUserId") || "an_nudge";
  if (!db || !activeUserId) return;

  joinCanonicalWebGroup(activeUserId, groupId, requestId).then(() => {
    toast(`已成功加入${groupName ? `「${groupName}」` : ""}團隊！ 🎉`);
    window.location.reload();
  }).catch(err => {
    console.error(err);
    toast("同意失敗");
  });
}

function declineWebGroupRequest(requestId) {
  if (!db) return;
  db.collection("group_requests").doc(requestId).update({
    status: "declined",
    updatedAt: new Date().toISOString()
  }).then(() => {
    toast("已拒絕該邀請");
  }).catch(err => {
    console.error(err);
    toast("操作失敗");
  });
}

window.approveWebGroupRequest = approveWebGroupRequest;
window.declineWebGroupRequest = declineWebGroupRequest;

document.addEventListener("click", event => {
  const button = event.target.closest("[data-request-action]");
  if (!button) return;
  const action = button.dataset.requestAction;
  const requestId = button.dataset.requestId || "";
  if (action === "approve-group") {
    approveWebGroupRequest(
      requestId,
      button.dataset.groupId || "",
      button.dataset.groupName || ""
    );
  } else if (action === "decline-group") {
    declineWebGroupRequest(requestId);
  } else if (action === "approve-guardian") {
    approveWebGuardianRequest(requestId);
  } else if (action === "decline-guardian") {
    declineWebGuardianRequest(requestId);
  } else if (action === "cancel-guardian") {
    cancelWebGuardianRequest(requestId);
  }
});

function renderGroupRequestsList() {
  const container = document.getElementById("webGroupRequestsContainer");
  if (!container) return;

  let html = "";
  if (currentIncomingGroupRequests.length > 0) {
    html += `
      <div class="web-pending-section" style="margin-top: 24px; text-align: left; padding-top: 16px; border-top: 1px solid rgba(255,255,255,0.1);">
        <h4 style="font-size: 13px; color: #14b8a6; margin-bottom: 12px; font-weight: 700;">待處理的團體邀請：</h4>
    `;
    currentIncomingGroupRequests.forEach(req => {
      const senderName = req.senderNickname || "使用者";
      const senderNudge = req.senderNudgeId || "";
      const groupName = req.groupName || "自律小組";
      const groupId = req.groupId || "";
      html += `
        <div class="web-pending-item" style="display: flex; align-items: center; justify-content: space-between; padding: 12px; background: rgba(20, 184, 166, 0.08); border: 1px solid rgba(20, 184, 166, 0.2); border-radius: 8px; margin-bottom: 8px;">
          <div>
            <div style="font-size: 14px; color: #fff; font-weight: 700; margin-bottom: 4px;">團隊：${escapeHtml(groupName)}</div>
            <div style="font-size: 12px; color: rgba(255,255,255,0.6);">邀請人：${escapeHtml(senderName)} (${escapeHtml(senderNudge)})</div>
          </div>
          <div style="display: flex; gap: 8px;">
            <button data-request-action="approve-group" data-request-id="${escapeHtml(req.id)}" data-group-id="${escapeHtml(groupId)}" data-group-name="${escapeHtml(groupName)}" style="background: #14b8a6; border: none; color: #fff; padding: 6px 12px; border-radius: 6px; font-size: 12px; cursor: pointer; font-weight: 700;">同意</button>
            <button data-request-action="decline-group" data-request-id="${escapeHtml(req.id)}" style="background: transparent; border: 1px solid #ef4444; color: #ef4444; padding: 6px 12px; border-radius: 6px; font-size: 12px; cursor: pointer; font-weight: 700;">拒絕</button>
          </div>
        </div>
      `;
    });
    html += `</div>`;
  } else {
    html = `
      <div style="margin-top: 24px; padding-top: 16px; border-top: 1px solid rgba(255,255,255,0.1); font-size: 13px; color: var(--muted);">
        目前沒有待處理的團體邀請。
      </div>
    `;
  }
  container.innerHTML = html;
}

function renderNotificationsPage() {
  const container = document.getElementById("notificationsPageContainer");
  if (!container) return;

  const totalPending = currentIncomingRequests.length + currentIncomingGroupRequests.length;
  const countEl = document.getElementById("totalPendingCount");
  if (countEl) countEl.textContent = totalPending;

  if (totalPending === 0) {
    container.innerHTML = `
      <div style="text-align: center; padding: 40px; color: var(--muted);">
        <span style="font-size: 48px; display: block; margin-bottom: 12px; opacity: 0.5;">📭</span>
        <strong style="font-size: 16px;">目前沒有任何待處理的邀請</strong>
        <p style="margin-top: 8px;">當您收到親屬綁定或團隊邀請時，會顯示在這裡。</p>
      </div>
    `;
    return;
  }

  let html = "";

  if (currentIncomingRequests.length > 0) {
    html += `
      <div style="margin-bottom: 32px;">
        <h3 style="color: #f59e0b; margin-bottom: 16px; display: flex; align-items: center; gap: 8px;">
          <span style="font-size: 20px;">🛡️</span> 親屬綁定邀請
        </h3>
    `;
    currentIncomingRequests.forEach(req => {
      const senderName = req.senderNickname || "使用者";
      const senderNudge = req.senderNudgeId || "";
      const senderRole = getRoleLabel(req.senderRole || "personal");
      html += `
        <div style="display: flex; align-items: center; justify-content: space-between; padding: 16px; background: rgba(245, 158, 11, 0.08); border: 1px solid rgba(245, 158, 11, 0.2); border-radius: 12px; margin-bottom: 12px;">
          <div>
            <div style="font-size: 15px; color: #fff; font-weight: 700; margin-bottom: 4px;">邀請人：${escapeHtml(senderName)} (${escapeHtml(senderNudge)})</div>
            <div style="font-size: 13px; color: rgba(255,255,255,0.7);">對方目前身分：<strong style="color: #f59e0b;">${escapeHtml(senderRole)}</strong></div>
          </div>
          <div style="display: flex; gap: 10px;">
            <button data-request-action="approve-guardian" data-request-id="${escapeHtml(req.id)}" style="background: #10b981; border: none; color: #fff; padding: 8px 16px; border-radius: 8px; font-weight: 700; cursor: pointer;">同意</button>
            <button data-request-action="decline-guardian" data-request-id="${escapeHtml(req.id)}" style="background: transparent; border: 1px solid #ef4444; color: #ef4444; padding: 8px 16px; border-radius: 8px; font-weight: 700; cursor: pointer;">拒絕</button>
          </div>
        </div>
      `;
    });
    html += `</div>`;
  }

  if (currentIncomingGroupRequests.length > 0) {
    html += `
      <div style="margin-bottom: 32px;">
        <h3 style="color: #14b8a6; margin-bottom: 16px; display: flex; align-items: center; gap: 8px;">
          <span style="font-size: 20px;">👥</span> 團隊組織邀請
        </h3>
    `;
    currentIncomingGroupRequests.forEach(req => {
      const senderName = req.senderNickname || "使用者";
      const senderNudge = req.senderNudgeId || "";
      const groupName = req.groupName || "自律小組";
      const groupId = req.groupId || "";
      html += `
        <div style="display: flex; align-items: center; justify-content: space-between; padding: 16px; background: rgba(20, 184, 166, 0.08); border: 1px solid rgba(20, 184, 166, 0.2); border-radius: 12px; margin-bottom: 12px;">
          <div>
            <div style="font-size: 15px; color: #fff; font-weight: 700; margin-bottom: 4px;">團隊：${escapeHtml(groupName)} (ID: ${escapeHtml(groupId)})</div>
            <div style="font-size: 13px; color: rgba(255,255,255,0.7);">邀請人：${escapeHtml(senderName)} (${escapeHtml(senderNudge)})</div>
          </div>
          <div style="display: flex; gap: 10px;">
            <button data-request-action="approve-group" data-request-id="${escapeHtml(req.id)}" data-group-id="${escapeHtml(groupId)}" data-group-name="${escapeHtml(groupName)}" style="background: #14b8a6; border: none; color: #fff; padding: 8px 16px; border-radius: 8px; font-weight: 700; cursor: pointer;">加入</button>
            <button data-request-action="decline-group" data-request-id="${escapeHtml(req.id)}" style="background: transparent; border: 1px solid #ef4444; color: #ef4444; padding: 8px 16px; border-radius: 8px; font-weight: 700; cursor: pointer;">拒絕</button>
          </div>
        </div>
      `;
    });
    html += `</div>`;
  }

  container.innerHTML = html;
}

function sendWebGuardianRequest(targetNudgeId) {
  const activeUserId = firebase.auth().currentUser?.uid;
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

    db.collection("public_profiles").where("username", "==", targetNudgeIdUpper).limit(1).get().then(querySnap => {
      if (querySnap.empty) {
        toast("找不到該 Nudge ID 的使用者");
        return;
      }
      const receiverSnap = querySnap.docs[0];
      const receiverId = receiverSnap.id;
      const receiverData = receiverSnap.data();
      const receiverNudgeId = receiverData.username || "";
      const receiverRole = receiverData.familyRole || "personal";

      try {
        window.NudgeFamilyLinkContract.buildFamilyLinkPayload({
          senderId: activeUserId,
          senderRole: myRole,
          receiverId,
          receiverRole,
        });
      } catch (error) {
        toast("家庭連結必須由一個家長帳號與一個孩子帳號組成");
        return;
      }

      if (
        activeFamilyLinks.some(link =>
          Array.isArray(link.participantIds) &&
          link.participantIds.includes(receiverId),
        )
      ) {
        toast("你們已經有有效的家庭連結");
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
                receiverRole: receiverRole,
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
  const currentUserId = firebase.auth().currentUser?.uid;
  const requestRef = db.collection("guardian_requests").doc(requestId);
  const linkRef = db.collection("family_links").doc(requestId);
  db.runTransaction(async transaction => {
    const requestSnap = await transaction.get(requestRef);
    if (!requestSnap.exists) throw new Error("找不到親屬綁定申請");
    const request = requestSnap.data();
    if (!currentUserId || request.receiverId !== currentUserId) {
      throw new Error("只有邀請接收者可以同意連結");
    }
    const now = new Date().toISOString();
    const link = window.NudgeFamilyLinkContract.buildFamilyLinkPayload({
      senderId: request.senderId,
      senderRole: request.senderRole,
      receiverId: request.receiverId,
      receiverRole:
        request.receiverRole ||
        (request.senderRole === "guardian" ? "child" : "guardian"),
      now,
    });
    transaction.update(requestRef, {
      status: "accepted",
      updatedAt: now,
    });
    transaction.set(linkRef, link);
    [link.guardianId, link.childId].forEach(participantId => {
      const role = participantId === link.guardianId ? "guardian" : "child";
      const membership = buildWebRelationshipMembership({
        scopeType: "family",
        scopeId: requestId,
        scopeName: `家庭連結 ${requestId.slice(-8)}`,
        userId: participantId,
        role,
        now,
      });
      transaction.set(
        db.collection("relationship_memberships").doc(
          membership.membershipId,
        ),
        membership,
      );
    });
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
    status: "cancelled",
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
          <span style="font-size: 13px; color: #fff;">${escapeHtml(senderName)} (${escapeHtml(senderNudge)})</span>
          <div style="display: flex; gap: 8px;">
            <button data-request-action="approve-guardian" data-request-id="${escapeHtml(req.id)}" style="background: #10b981; border: none; color: #fff; padding: 4px 10px; border-radius: 4px; font-size: 12px; cursor: pointer; font-weight: 600;">同意</button>
            <button data-request-action="decline-guardian" data-request-id="${escapeHtml(req.id)}" style="background: transparent; border: 1px solid #ef4444; color: #ef4444; padding: 4px 10px; border-radius: 4px; font-size: 12px; cursor: pointer; font-weight: 600;">拒絕</button>
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
            <span style="color: #f59e0b;">⏳</span> 已向 ${escapeHtml(req.receiverNudgeId)} 發送申請，等待同意中...
          </span>
          <button data-request-action="cancel-guardian" data-request-id="${escapeHtml(req.id)}" style="background: transparent; border: 1px solid rgba(255, 255, 255, 0.3); color: rgba(255,255,255,0.6); padding: 4px 10px; border-radius: 4px; font-size: 12px; cursor: pointer; font-weight: 600;">取消</button>
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

function showWebRelativeBindingCard(atTop) {
  const main = document.querySelector(".main");
  if (!main || document.getElementById("webBindingGatedCard")) return;

  const cardHtml = `
    <div id="webBindingGatedCard" class="web-binding-gated-wrapper" style="margin-bottom: 24px;">
      <h2>🛡️ 親屬帳號連結</h2>
      <p id="webBindingDesc">您還未與家人進行親屬綁定。請在下方輸入對方的 Nudge ID 發送申請，或在列表處理待同意的申請。連結後即可查看對方專注、睡眠與健康數據。</p>

      <div id="webRequestsContainer" style="margin-bottom: 20px;"></div>

      <div id="webBindingForm" class="web-binding-form">
        <input type="text" id="webRelativeIdInput" class="web-binding-input" placeholder="輸入對方的 Nudge ID (例如: NDG_XXXXXX)">
        <button id="webRelativeBindBtn" class="role-gatekeeper-btn" style="width: 100%;">發送綁定申請</button>
      </div>
    </div>
  `;

  if (atTop) {
    // Insert at the very top of main, before any existing sections
    const firstSection = main.querySelector("section, .page-section, div:not(.hero)");
    if (firstSection) {
      firstSection.insertAdjacentHTML("beforebegin", cardHtml);
    } else {
      main.insertAdjacentHTML("afterbegin", cardHtml);
    }
  } else {
    main.insertAdjacentHTML("beforeend", cardHtml);
  }

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

function showGuardianLinkedBanner(data) {
  const main = document.querySelector(".main");
  if (!main) return;
  const relativeId = data.webToolsState?.guardianInvite?.relativeId || "";
  const banner = document.createElement("div");
  banner.id = "webGuardianLinkedBanner";
  banner.style.cssText = "background: rgba(16,185,129,0.1); border: 1px solid rgba(16,185,129,0.3); border-radius: 16px; padding: 16px 24px; margin-bottom: 24px; display: flex; align-items: center; gap: 16px; justify-content: space-between;";
  banner.innerHTML = `
    <div><span style="font-size: 18px; margin-right: 10px;">✅</span><strong style="color: #10b981;">已與 ${relativeId} 連結</strong><span style="color: var(--muted); font-size: 13px; margin-left: 12px;">共同目標與鼓勵已啟用；可見資料依孩子同意範圍</span></div>
    <button onclick="unlinkWebGuardian()" style="background: transparent; border: 1px solid #ef4444; color: #ef4444; border-radius: 10px; padding: 6px 14px; font-weight: 700; cursor: pointer; font-size: 13px;">解除親屬連結</button>
  `;
  const firstSection = main.querySelector("section, .page-section");
  if (firstSection) {
    firstSection.insertAdjacentElement("beforebegin", banner);
  } else {
    main.insertAdjacentElement("afterbegin", banner);
  }
}

async function unlinkWebGuardian() {
  const userId = localStorage.getItem("nudgeActiveDemoUserId");
  if (!db || !userId) {
    toast("請先登入再解除親屬連結");
    return;
  }
  if (!window.confirm("確定解除親屬連結？雙方將停止共享陪伴資料。")) return;
  try {
    if (activeFamilyLink) {
      const batch = db.batch();
      const now = new Date().toISOString();
      batch.update(db.collection("family_links").doc(activeFamilyLink.id), {
        status: "ended",
        endedBy: userId,
        endedAt: now,
        updatedAt: now,
      });
      batch.update(
        db.collection("guardian_requests").doc(activeFamilyLink.id),
        { status: "ended", updatedAt: now },
      );
      [activeFamilyLink.guardianId, activeFamilyLink.childId].forEach(
        participantId => {
          const membership = buildWebRelationshipMembership({
            scopeType: "family",
            scopeId: activeFamilyLink.id,
            scopeName: `家庭連結 ${activeFamilyLink.id.slice(-8)}`,
            userId: participantId,
            role:
              participantId === activeFamilyLink.guardianId
                ? "guardian"
                : "child",
            status: "ended",
            endedBy: userId,
            now,
          });
          batch.set(
            db.collection("relationship_memberships").doc(
              membership.membershipId,
            ),
            membership,
            { merge: true },
          );
        },
      );
      batch.update(db.collection("users").doc(userId), {
        "webToolsState.guardianInvite": firebase.firestore.FieldValue.delete(),
        "webToolsState.guardianInviteStatus": firebase.firestore.FieldValue.delete(),
        updatedAt: now,
      });
      await batch.commit();
      toast("已解除親屬連結");
      return;
    }

    const [incoming, outgoing] = await Promise.all([
      db.collection("guardian_requests").where("receiverId", "==", userId).get(),
      db.collection("guardian_requests").where("senderId", "==", userId).get()
    ]);
    const batch = db.batch();
    const requestIds = new Set();
    [...incoming.docs, ...outgoing.docs].forEach(doc => {
      if (requestIds.has(doc.id)) return;
      requestIds.add(doc.id);
      batch.delete(doc.ref);
    });
    batch.update(db.collection("users").doc(userId), {
      "webToolsState.guardianInvite": firebase.firestore.FieldValue.delete(),
      "webToolsState.guardianInviteStatus": firebase.firestore.FieldValue.delete(),
      updatedAt: new Date().toISOString()
    });
    await batch.commit();
    toast("已解除親屬連結");
  } catch (error) {
    console.error("解除親屬連結失敗：", error);
    toast("解除失敗，請稍後再試");
  }
}

window.unlinkWebGuardian = unlinkWebGuardian;

function requireCanonicalWebGroupManager() {
  const userId =
    typeof firebase !== "undefined" ? firebase.auth().currentUser?.uid : null;
  if (!userId || !activeWebGroup) {
    throw new Error("請先加入有效團體");
  }
  if (!window.NudgeGroupContract?.isGroupManager(activeWebGroup, userId)) {
    throw new Error("只有目前團體的管理者可以發布團體內容");
  }
  return { group: activeWebGroup, userId };
}

async function publishCanonicalWebGroupChallenge({ type, days, reward }) {
  const { group, userId } = requireCanonicalWebGroupManager();
  const now = new Date().toISOString();
  const payload = window.NudgeGroupContract.buildGroupChallenge({
    group,
    publisherId: userId,
    challengeId: `challenge_${Date.now()}_${userId.slice(0, 8)}`,
    type,
    days,
    reward,
    now,
  });
  await db.collection("groups")
    .doc(group.id)
    .collection("challenges")
    .doc("current")
    .set(payload);
}

async function joinCanonicalWebGroupChallenge(challenge) {
  const userId =
    typeof firebase !== "undefined" ? firebase.auth().currentUser?.uid : null;
  if (
    !userId ||
    !activeWebGroup ||
    !window.NudgeGroupContract?.isGroupMember(activeWebGroup, userId)
  ) {
    throw new Error("請先加入有效團體");
  }
  const existing = activeWebGroupChallengeParticipants.find(
    item =>
      item.memberId === userId &&
      item.challengeId === challenge?.challengeId,
  );
  if (existing) return existing;
  const payload = window.NudgeGroupContract.buildGroupChallengeParticipation({
    group: activeWebGroup,
    challenge,
    memberId: userId,
  });
  await db.collection("groups")
    .doc(activeWebGroup.id)
    .collection("challenges")
    .doc("current")
    .collection("participants")
    .doc(userId)
    .set(payload);
  return payload;
}

async function publishCanonicalWebStudySchedule({ title, meta }) {
  const { group, userId } = requireCanonicalWebGroupManager();
  const payload = window.NudgeGroupContract.buildGroupStudySchedule({
    group,
    publisherId: userId,
    title,
    meta,
  });
  await db.collection("groups")
    .doc(group.id)
    .collection("study_schedules")
    .add(payload);
}

async function deleteCanonicalWebStudySchedule(scheduleId) {
  const { group } = requireCanonicalWebGroupManager();
  if (!scheduleId) throw new Error("找不到要刪除的時段");
  await db.collection("groups")
    .doc(group.id)
    .collection("study_schedules")
    .doc(scheduleId)
    .delete();
}

async function publishCanonicalWebGroupTemplate({
  type,
  days,
  effort,
  strategy,
}) {
  const { group, userId } = requireCanonicalWebGroupManager();
  const payload = window.NudgeGroupContract.buildGroupTemplate({
    group,
    publisherId: userId,
    type,
    days,
    effort,
    strategy,
  });
  await db.collection("groups")
    .doc(group.id)
    .collection("templates")
    .add(payload);
}

async function deleteCanonicalWebGroupTemplate(templateId) {
  const { group } = requireCanonicalWebGroupManager();
  await db.collection("groups")
    .doc(group.id)
    .collection("templates")
    .doc(templateId)
    .delete();
}

function generateWebGroupId() {
  return `GRP-${Date.now().toString(36).toUpperCase()}`;
}

async function createCanonicalWebGroup(userId, name) {
  const normalizedName = String(name || "").trim();
  if (!normalizedName) throw new Error("團體名稱不可空白");
  const groupId = generateWebGroupId();
  const batch = db.batch();
  const now = new Date().toISOString();
  batch.set(db.collection("groups").doc(groupId), {
    id: groupId,
    name: normalizedName,
    ownerId: userId,
    memberIds: [userId],
    status: "active",
    createdAt: now,
    updatedAt: now
  });
  const membership = buildWebRelationshipMembership({
    scopeType: "group",
    scopeId: groupId,
    scopeName: normalizedName,
    userId,
    role: "manager",
    now,
  });
  batch.set(
    db.collection("relationship_memberships").doc(membership.membershipId),
    membership,
  );
  await batch.commit();
  localStorage.setItem(relationshipSelectionKey("group", userId), groupId);
  return groupId;
}

async function joinCanonicalWebGroup(userId, groupIdInput, requestId = null) {
  const groupId = String(groupIdInput || "").trim().toUpperCase();
  if (!groupId) throw new Error("團體 ID 不可空白");
  const result = await db.runTransaction(async transaction => {
    const groupRef = db.collection("groups").doc(groupId);
    const groupSnapshot = await transaction.get(groupRef);
    if (!groupSnapshot.exists) throw new Error("找不到此團體 ID");
    const group = groupSnapshot.data();
    if (group.status !== "active") throw new Error("此團體目前無法加入");
    if (!group.name) throw new Error("團體資料不完整");
    const now = new Date().toISOString();
    transaction.update(groupRef, {
      memberIds: firebase.firestore.FieldValue.arrayUnion(userId),
      updatedAt: now
    });
    const membership = buildWebRelationshipMembership({
      scopeType: "group",
      scopeId: groupId,
      scopeName: group.name,
      userId,
      role: group.ownerId === userId ? "manager" : "member",
      now,
    });
    transaction.set(
      db.collection("relationship_memberships").doc(membership.membershipId),
      membership,
      { merge: true },
    );
    if (requestId) {
      transaction.update(db.collection("group_requests").doc(requestId), {
        status: "accepted",
        updatedAt: now
      });
    }
    return { groupId, groupName: group.name };
  });
  localStorage.setItem(relationshipSelectionKey("group", userId), groupId);
  return result;
}

async function leaveCanonicalWebGroup(userId, groupId) {
  const fallbackGroup = activeWebGroups.find(group => group.id !== groupId);
  await db.runTransaction(async transaction => {
    const groupRef = db.collection("groups").doc(groupId);
    const summaryRef = groupRef.collection("member_summaries").doc(userId);
    const participationRef = groupRef
      .collection("challenges")
      .doc("current")
      .collection("participants")
      .doc(userId);
    const groupSnapshot = await transaction.get(groupRef);
    const now = new Date().toISOString();
    if (groupSnapshot.exists) {
      const group = groupSnapshot.data();
      const memberIds = Array.isArray(group.memberIds) ? group.memberIds : [];
      if (group.ownerId === userId && memberIds.length > 1) {
        throw new Error("團體仍有其他成員，請先移除成員或轉移管理權");
      }
      if (group.ownerId === userId) {
        transaction.delete(groupRef);
      } else {
        transaction.update(groupRef, {
          memberIds: firebase.firestore.FieldValue.arrayRemove(userId),
          updatedAt: now
        });
      }
      const membership = buildWebRelationshipMembership({
        scopeType: "group",
        scopeId: groupId,
        scopeName: group.name,
        userId,
        role: group.ownerId === userId ? "manager" : "member",
        status: "ended",
        endedBy: userId,
        now,
      });
      transaction.set(
        db.collection("relationship_memberships").doc(
          membership.membershipId,
        ),
        membership,
        { merge: true },
      );
    }
    transaction.delete(summaryRef);
    transaction.delete(participationRef);
  });
  if (fallbackGroup) {
    localStorage.setItem(
      relationshipSelectionKey("group", userId),
      fallbackGroup.id,
    );
  } else {
    localStorage.removeItem(relationshipSelectionKey("group", userId));
  }
}

async function removeCanonicalWebGroupMember(memberId) {
  const { group, userId } = requireCanonicalWebGroupManager();
  const groupRef = db.collection("groups").doc(group.id);
  const summaryRef = groupRef.collection("member_summaries").doc(memberId);
  const participationRef = groupRef
    .collection("challenges")
    .doc("current")
    .collection("participants")
    .doc(memberId);
  return db.runTransaction(async transaction => {
    const groupSnapshot = await transaction.get(groupRef);
    if (!groupSnapshot.exists) {
      throw new Error("團體資料不存在");
    }
    const currentGroup = { id: groupSnapshot.id, ...groupSnapshot.data() };
    const update = window.NudgeGroupContract.buildMemberRemoval({
      group: currentGroup,
      managerId: userId,
      memberId,
    });
    const now = new Date().toISOString();
    const membership = buildWebRelationshipMembership({
      scopeType: "group",
      scopeId: group.id,
      scopeName: group.name,
      userId: memberId,
      role: group.ownerId === memberId ? "manager" : "member",
      status: "ended",
      endedBy: userId,
      now,
    });
    transaction.update(groupRef, update);
    transaction.set(
      db.collection("relationship_memberships").doc(membership.membershipId),
      membership,
      { merge: true },
    );
    transaction.delete(summaryRef);
    transaction.delete(participationRef);
  });
}

async function transferCanonicalWebGroupOwnership(nextManagerId) {
  const { group, userId } = requireCanonicalWebGroupManager();
  const groupRef = db.collection("groups").doc(group.id);
  return db.runTransaction(async transaction => {
    const groupSnapshot = await transaction.get(groupRef);
    if (!groupSnapshot.exists) {
      throw new Error("團體資料不存在");
    }
    const currentGroup = { id: groupSnapshot.id, ...groupSnapshot.data() };
    const update = window.NudgeGroupContract.buildOwnershipTransfer({
      group: currentGroup,
      managerId: userId,
      nextManagerId,
    });
    const now = new Date().toISOString();
    transaction.update(groupRef, update);
    [
      buildWebRelationshipMembership({
        scopeType: "group",
        scopeId: group.id,
        scopeName: group.name,
        userId,
        role: "member",
        now,
      }),
      buildWebRelationshipMembership({
        scopeType: "group",
        scopeId: group.id,
        scopeName: group.name,
        userId: nextManagerId,
        role: "manager",
        now,
      }),
    ].forEach(membership => {
      transaction.set(
        db.collection("relationship_memberships").doc(
          membership.membershipId,
        ),
        membership,
        { merge: true },
      );
    });
  });
}

async function migrateLegacyWebGroup(userId, userData) {
  if (!userData?.isGroupOwner || !userData.groupId || !userData.groupName) return;
  const groupRef = db.collection("groups").doc(userData.groupId);
  const existing = await groupRef.get();
  if (existing.exists) return;
  const now = new Date().toISOString();
  const membership = buildWebRelationshipMembership({
    scopeType: "group",
    scopeId: userData.groupId,
    scopeName: userData.groupName,
    userId,
    role: "manager",
    now,
  });
  const batch = db.batch();
  batch.set(groupRef, {
    id: userData.groupId,
    name: userData.groupName,
    ownerId: userId,
    memberIds: [userId],
    status: "active",
    migratedFromUserProjection: true,
    createdAt: now,
    updatedAt: now,
  });
  batch.set(
    db.collection("relationship_memberships").doc(membership.membershipId),
    membership,
  );
  await batch.commit();
}

async function ensureCanonicalWebMembership(userId, userData) {
  if (!userData?.groupId || userData.isGroupOwner) return;
  const groupRef = db.collection("groups").doc(userData.groupId);
  const groupSnapshot = await groupRef.get();
  if (!groupSnapshot.exists || groupSnapshot.data().status !== "active") return;
  const group = { id: groupSnapshot.id, ...groupSnapshot.data() };
  const memberIds = group.memberIds || [];
  const now = new Date().toISOString();
  const membership = buildWebRelationshipMembership({
    scopeType: "group",
    scopeId: group.id,
    scopeName: group.name,
    userId,
    role: group.ownerId === userId ? "manager" : "member",
    now,
  });
  const batch = db.batch();
  if (!memberIds.includes(userId)) {
    batch.update(groupRef, {
      memberIds: firebase.firestore.FieldValue.arrayUnion(userId),
      updatedAt: now,
    });
  }
  batch.set(
    db.collection("relationship_memberships").doc(membership.membershipId),
    membership,
    { merge: true },
  );
  await batch.commit();
}

function showWebGroupBindingCard(atTop) {
  const main = document.querySelector(".main");
  if (!main || document.getElementById("webBindingGatedCard")) return;

  const cardHtml = `
    <div id="webBindingGatedCard" class="web-binding-gated-wrapper" style="margin-bottom: 24px;">
      <h2>👥 團體自律組織連結</h2>
      <p>請先創建新的自律團體（獲取最高房主權限並生成團體 ID），或輸入已有組織 ID 加入，以解鎖專注挑戰、共同目標等功能：</p>
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

  if (atTop) {
    const firstSection = main.querySelector("section, .page-section, div:not(.hero)");
    if (firstSection) {
      firstSection.insertAdjacentHTML("beforebegin", cardHtml);
    } else {
      main.insertAdjacentHTML("afterbegin", cardHtml);
    }
  } else {
    main.insertAdjacentHTML("beforeend", cardHtml);
  }

  document.getElementById("webGroupCreateBtn")?.addEventListener("click", () => {
    const nameInput = document.getElementById("webGroupNameInput");
    const name = nameInput ? nameInput.value.trim() : "";
    if (!name) {
      toast("請輸入有效的團體名稱");
      return;
    }
    const activeUserId = localStorage.getItem("nudgeActiveDemoUserId") || "an_nudge";
    if (activeUserId && typeof db !== "undefined") {
      createCanonicalWebGroup(activeUserId, name).then((groupId) => {
        toast(`成功創建「${name}」團體，ID：${groupId}！ 🚀`);
      }).catch(err => {
        console.error("創建團體失敗：", err);
        toast("操作失敗，請稍後再試");
      });
    }
  });

  document.getElementById("webGroupJoinBtn")?.addEventListener("click", () => {
    const groupInput = document.getElementById("webGroupIdInput");
    const groupId = groupInput ? groupInput.value.trim().toUpperCase() : "";
    if (!groupId) {
      toast("請輸入有效的團體 ID");
      return;
    }
    const activeUserId = localStorage.getItem("nudgeActiveDemoUserId") || "an_nudge";
    if (activeUserId && typeof db !== "undefined") {
      joinCanonicalWebGroup(activeUserId, groupId).then((group) => {
        toast(`已成功加入「${group.groupName}」！ 🎯`);
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
          <span style="font-family: monospace; font-size: 11px; color: var(--muted);">ID: ${escapeHtml(groupId)}</span>
        </div>
        <h3 style="margin: 0; font-size: 18px; color: #fff; font-weight: 800;">當前關聯團體：${escapeHtml(groupName)}</h3>
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
        leaveCanonicalWebGroup(activeUserId, groupId).then(() => {
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
  const container = document.getElementById("groupsCreationContainer") || document.getElementById("groupsLinkContainer");
  if (!container) return;

  const activeUserId =
    typeof firebase !== "undefined" ? firebase.auth().currentUser?.uid : null;
  const isOwner =
    window.NudgeGroupContract?.isGroupManager(
      activeWebGroup,
      activeUserId,
    ) === true ||
    (isPreviewMode() && data.isGroupOwner === true);
  const groupName = activeWebGroup?.name || data.groupName || "自律小組";
  const groupId = activeWebGroup?.id || data.groupId || "";

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
          <div id="webGroupRequestsContainer"></div>
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
      if (activeUserId && typeof db !== "undefined") {
        createCanonicalWebGroup(activeUserId, name).then((groupId) => {
          toast(`成功創建「${name}」團體，ID：${groupId}！ 🚀`);
          window.location.reload();
        }).catch(err => {
          console.error("創建團體失敗：", err);
          toast("操作失敗，請稍後再試");
        });
      }
    });

    document.getElementById("webGroupJoinBtnPage")?.addEventListener("click", () => {
      const groupInput = document.getElementById("webGroupIdInputPage");
      const groupId = groupInput ? groupInput.value.trim().toUpperCase() : "";
      if (!groupId) {
        toast("請輸入有效的團體 ID");
        return;
      }
      const activeUserId = localStorage.getItem("nudgeActiveDemoUserId") || "an_nudge";
      if (activeUserId && typeof db !== "undefined") {
        joinCanonicalWebGroup(activeUserId, groupId).then((group) => {
          toast(`已成功加入「${group.groupName}」！ 🎯`);
          window.location.reload();
        }).catch(err => {
          console.error("加入團體失敗：", err);
          toast("操作失敗，請稍後再試");
        });
      }
    });

    renderGroupRequestsList();
    return;
  }

  // Already has a group. Render the management interface with real-time member listing!
  container.innerHTML = `
    <div class="workspace-layout">
      <div class="panel" style="flex: 2;">
        <span class="eyebrow">Team Information</span>
        <div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 20px;">
          <div>
            <h2 style="margin: 0; color: #fff; font-size: 24px; font-weight: 800;">${escapeHtml(groupName)}</h2>
            <p style="margin: 4px 0 0 0; color: var(--muted); font-size: 14px; font-family: monospace;">團體組織 ID: ${escapeHtml(groupId)}</p>
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
                <th style="padding: 12px 8px;">正式成員</th>
                <th style="padding: 12px 8px;">身分</th>
                <th style="padding: 12px 8px; text-align: center;">分享狀態</th>
                <th style="padding: 12px 8px; text-align: center;">紀律分數</th>
                <th style="padding: 12px 8px;">成果摘要</th>
                <th style="padding: 12px 8px; text-align: right;">管理</th>
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
            ${isOwner ? '你可以邀請、移除成員或轉移管理權；只有團體剩下你一人時才能解散，避免成員關係被意外清除。' : '您可以退出此小組，退出後將無法同步小組的挑戰與任務模板。'}
          </p>
          ${isOwner ? `
            <div style="margin-top: 24px; padding-top: 24px; border-top: 1px dashed rgba(255,255,255,0.1);">
              <span class="eyebrow">Invite Member</span>
              <h3 style="font-size: 16px; margin-bottom: 8px;">邀請新成員加入</h3>
              <div style="display: flex; flex-direction: column; gap: 12px;">
                <input type="text" id="webGroupInviteInput" class="web-binding-input" placeholder="輸入要邀請的 Nudge ID" style="width: 100%;">
                <button id="webGroupInviteBtn" class="button primary" style="width: 100%; font-weight: 700;">發送團隊邀請</button>
              </div>
            </div>
          ` : ''}
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
        leaveCanonicalWebGroup(activeUserId, groupId).then(() => {
          toast("已成功解除團體關聯");
          window.location.reload();
        }).catch(err => {
          console.error("退出團體失敗：", err);
          toast("操作失敗，請稍後再試");
        });
      }
    }
  });

  document.getElementById("webGroupInviteBtn")?.addEventListener("click", () => {
    const inviteInput = document.getElementById("webGroupInviteInput");
    const targetId = inviteInput ? inviteInput.value.trim() : "";
    if (!targetId) {
      toast("請輸入有效的 Nudge ID");
      return;
    }
    sendWebGroupRequest(targetId, groupId, groupName);
  });

  renderCanonicalWebGroupMembers();
}

function renderCanonicalWebGroupMembers() {
  const listTable = document.getElementById("webGroupMembersListTable");
  if (!listTable) return;
  const group = activeWebGroup;
  if (!group || !Array.isArray(group.memberIds)) {
    listTable.innerHTML = `<tr><td colspan="6" style="padding: 24px; text-align: center; color: var(--muted);">等待正式團體成員名單同步。</td></tr>`;
    return;
  }
  const currentUserId =
    typeof firebase !== "undefined" ? firebase.auth().currentUser?.uid : null;
  const canManage =
    window.NudgeGroupContract?.isGroupManager(group, currentUserId) === true;
  const summariesByMember = new Map(
    activeWebGroupSummaries.map(summary => [summary.memberId, summary]),
  );

  listTable.innerHTML = group.memberIds
    .map(memberId => {
      const summaryDoc = summariesByMember.get(memberId);
      const summary = summaryDoc?.summary || null;
      const isOwner = memberId === group.ownerId;
      const completed = Number(summary?.completedTasks || 0);
      const total = Number(summary?.totalTasks || 0);
      const rate = total > 0 ? Math.round((completed / total) * 100) : 0;
      const actions = canManage && !isOwner
        ? `<div style="display:flex; gap:6px; justify-content:flex-end;">
            <button type="button" class="button ghost" data-group-member-action="transfer" data-member-id="${escapeHtml(memberId)}">轉移管理權</button>
            <button type="button" class="button ghost" data-group-member-action="remove" data-member-id="${escapeHtml(memberId)}">移除</button>
          </div>`
        : "—";
      return `
        <tr style="border-bottom:1px solid rgba(255,255,255,0.04);">
          <td style="padding:14px 8px;">
            <div style="font-weight:700;color:#fff;">${escapeHtml(summaryDoc?.displayName || memberId)}</div>
            <div style="font-size:11px;color:var(--muted);font-family:monospace;">${escapeHtml(memberId)}</div>
          </td>
          <td style="padding:14px 8px;">${isOwner ? "👑 管理者" : "👥 成員"}</td>
          <td style="padding:14px 8px;text-align:center;color:${summary ? "#10b981" : "var(--muted)"};">${summary ? "已同意" : "未分享"}</td>
          <td style="padding:14px 8px;text-align:center;font-weight:800;">${summary ? escapeHtml(summary.disciplineScore || 0) : "—"}</td>
          <td style="padding:14px 8px;color:var(--muted);">${summary ? `${escapeHtml(summary.focusMinutes || 0)} 分鐘專注・${escapeHtml(summary.steps || 0)} 步・任務 ${escapeHtml(rate)}%` : "不讀取私人使用者資料"}</td>
          <td style="padding:14px 8px;text-align:right;">${actions}</td>
        </tr>`;
    })
    .join("");

  listTable
    .querySelectorAll("[data-group-member-action]")
    .forEach(button => {
      button.addEventListener("click", async () => {
        const memberId = button.dataset.memberId;
        const action = button.dataset.groupMemberAction;
        const prompt = action === "transfer"
          ? `確定將團體管理權轉移給 ${memberId}？`
          : `確定移除 ${memberId}？成果摘要也會一併撤除。`;
        if (!confirm(prompt)) return;
        try {
          if (action === "transfer") {
            await transferCanonicalWebGroupOwnership(memberId);
            toast("團體管理權已轉移");
          } else {
            await removeCanonicalWebGroupMember(memberId);
            toast("團體成員已移除");
          }
        } catch (error) {
          console.error(error);
          toast(error.message || "成員異動失敗");
        }
      });
    });
}

function renderCanonicalGroupRanking() {
  const rankingList = document.querySelector("[data-group-ranking-list]");
  if (!rankingList) return;
  const rankingName = document.querySelector("[data-group-ranking-name]");
  const rankingCopy = document.querySelector("[data-group-ranking-copy]");
  const summaryCopy = document.querySelector("[data-group-ranking-summary]");
  const exportButton = document.getElementById("groupSummaryExportBtn");
  const memberCount = activeWebGroup?.memberIds?.length || 0;
  const summaries = activeWebGroup
    ? activeWebGroupSummaries.filter(summary =>
        activeWebGroup.memberIds.includes(summary.memberId),
      )
    : [];

  if (!summaries.length) {
    if (rankingName) rankingName.textContent = "尚未產生";
    if (rankingCopy) {
      rankingCopy.textContent = `0 / ${memberCount} 位成員已同意分享。`;
    }
    rankingList.innerHTML = `
      <div class="center-node">
        <div class="node-label">等待成員同意</div>
      </div>`;
    if (summaryCopy) {
      summaryCopy.textContent =
        "目前沒有可驗證的團體成果資料。未分享的成員不會以 0 分列入排行。";
    }
    if (exportButton) {
      exportButton.disabled = true;
      exportButton.textContent = "尚無可匯出摘要";
      exportButton.onclick = null;
    }
    return;
  }

  const ranked = [...summaries].sort(
    (a, b) =>
      Number(b.summary?.disciplineScore || 0) -
      Number(a.summary?.disciplineScore || 0),
  );
  const top = ranked[0];
  if (rankingName) {
    rankingName.textContent = top.displayName || top.memberId;
  }
  if (rankingCopy) {
    rankingCopy.textContent =
      `${top.summary?.disciplineScore || 0} 分・僅計入 ${ranked.length} 位已同意成員。`;
  }
  rankingList.innerHTML = `
    <div class="saved-list" style="width:min(100%,680px);max-height:360px;">
      ${ranked
        .map((item, index) => {
          const summary = item.summary || {};
          const total = Number(summary.totalTasks || 0);
          const completed = Number(summary.completedTasks || 0);
          const rate = total > 0 ? Math.round((completed / total) * 100) : 0;
          return `<article style="display:grid;grid-template-columns:48px 1fr auto;align-items:center;gap:12px;">
            <strong style="font-size:20px;color:var(--page-accent);">#${index + 1}</strong>
            <span><strong>${escapeHtml(item.displayName || item.memberId)}</strong><span>${escapeHtml(summary.focusMinutes || 0)} 分鐘專注・${escapeHtml(summary.steps || 0)} 步・任務 ${escapeHtml(rate)}%</span></span>
            <strong>${escapeHtml(summary.disciplineScore || 0)} 分</strong>
          </article>`;
        })
        .join("")}
    </div>`;

  const averageScore = Math.round(
    ranked.reduce(
      (sum, item) => sum + Number(item.summary?.disciplineScore || 0),
      0,
    ) / ranked.length,
  );
  if (summaryCopy) {
    summaryCopy.textContent =
      `${ranked.length} / ${memberCount} 位成員已同意分享，目前平均紀律分數 ${averageScore} 分。未分享者不列入分母或排行。`;
  }
  if (exportButton) {
    exportButton.disabled = false;
    exportButton.textContent = "匯出已同意成果摘要";
    exportButton.onclick = () => {
      const header =
        "排名,顯示名稱,紀律分數,專注分鐘,步數,睡眠時數,完成任務,任務總數";
      const rows = ranked.map((item, index) => {
        const summary = item.summary || {};
        const safeName = String(item.displayName || item.memberId)
          .replaceAll('"', '""');
        return [
          index + 1,
          `"${safeName}"`,
          summary.disciplineScore || 0,
          summary.focusMinutes || 0,
          summary.steps || 0,
          summary.sleepHours || 0,
          summary.completedTasks || 0,
          summary.totalTasks || 0,
        ].join(",");
      });
      downloadTextFile(
        "nudge-group-consented-results.csv",
        `\uFEFF${[header, ...rows].join("\n")}`,
      );
    };
  }
}

function getRoleLabel(role) {
  switch (role) {
    case "personal": return "個人";
    case "child": return "孩子";
    case "guardian": return "家長";
    case "group": return "團體";
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

function formatDate(date) {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

function getMonday5AMOfThisWeek(date) {
  const day = date.getDay(); // 0 is Sunday, 1 is Monday, ..., 6 is Saturday
  const weekday = day === 0 ? 7 : day;
  const daysToSubtract = weekday - 1;
  const monday = new Date(date.getFullYear(), date.getMonth(), date.getDate());
  monday.setDate(monday.getDate() - daysToSubtract);
  return new Date(monday.getFullYear(), monday.getMonth(), monday.getDate(), 5, 0, 0);
}

function calculateWeeklyTaskCompletionRateWeb(weekStartMonday, dailySummaries) {
  let completed = 0;
  let total = 0;
  for (let i = 0; i < 7; i++) {
    const curDate = new Date(weekStartMonday.getTime());
    curDate.setDate(curDate.getDate() + i);
    const dateStr = formatDate(curDate);
    const summary = dailySummaries.find(s => s.date === dateStr);
    if (summary) {
      completed += (summary.completedTasks || 0);
      total += (summary.totalTasks || 0);
    }
  }
  if (total === 0) return 0.0;
  return (completed / total) * 100.0;
}

function checkWeeklyPlanetSettlementWeb(data, activeUserId) {
  if (!db || !activeUserId) return;
  const now = new Date();
  const currentMonday5AM = getMonday5AMOfThisWeek(now);

  // The target completed settlement Monday is the last Monday 5:00 AM before now
  const targetSettlementMonday = now < currentMonday5AM
      ? new Date(currentMonday5AM.getTime() - 7 * 24 * 60 * 60 * 1000)
      : currentMonday5AM;

  let nextWeekStartMonday;
  const lastSettledStr = data.lastSettledWeekMonday;
  const dailySummaries = data.dailySummaries || [];

  if (!lastSettledStr) {
    if (dailySummaries.length > 0) {
      const sorted = [...dailySummaries].sort((a, b) => a.date.localeCompare(b.date));
      const firstParts = sorted[0].date.split('-');
      const firstDate = new Date(parseInt(firstParts[0]), parseInt(firstParts[1]) - 1, parseInt(firstParts[2]));
      nextWeekStartMonday = getMonday5AMOfThisWeek(firstDate);
    } else {
      nextWeekStartMonday = new Date(getMonday5AMOfThisWeek(now).getTime() - 7 * 24 * 60 * 60 * 1000);
    }
  } else {
    const lastParts = lastSettledStr.split('-');
    const lastSettled = new Date(parseInt(lastParts[0]), parseInt(lastParts[1]) - 1, parseInt(lastParts[2]), 5, 0, 0);
    nextWeekStartMonday = new Date(lastSettled.getTime() + 7 * 24 * 60 * 60 * 1000);
  }

  let changed = false;
  let planetCount = typeof data.planetCount === 'number' ? data.planetCount : 0;
  let unlockedPlanets = data.unlockedPlanets || ["新手星球"];
  let weeklyPlanetEarned = data.weeklyPlanetEarned || false;
  let lastSettledWeekMonday = lastSettledStr || "";

  while (nextWeekStartMonday < targetSettlementMonday || nextWeekStartMonday.getTime() === targetSettlementMonday.getTime()) {
    const weeklyRate = calculateWeeklyTaskCompletionRateWeb(nextWeekStartMonday, dailySummaries);
    if (weeklyRate >= 70.0) {
      planetCount += 1;
      weeklyPlanetEarned = true;

      const planetsPool = ["綠洲星球", "熔岩星球", "冰雪星球", "沙漠星球", "水晶星球", "暗物質星球"];
      const available = planetsPool.filter(p => !unlockedPlanets.includes(p));
      if (available.length > 0) {
        const randomPlanet = available[Math.floor(Math.random() * available.length)];
        unlockedPlanets.push(randomPlanet);
      }
    } else {
      weeklyPlanetEarned = false;
    }

    lastSettledWeekMonday = formatDate(nextWeekStartMonday);
    changed = true;

    nextWeekStartMonday.setDate(nextWeekStartMonday.getDate() + 7);
  }

  if (changed) {
    db.collection("users").doc(activeUserId).update({
      planetCount: planetCount,
      unlockedPlanets: unlockedPlanets,
      weeklyPlanetEarned: weeklyPlanetEarned,
      lastSettledWeekMonday: lastSettledWeekMonday,
      updatedAt: new Date().toISOString()
    }).then(() => {
      console.log("Weekly settlement executed on web successfully.");
    }).catch(err => {
      console.error("Failed to update settlement on web:", err);
    });
  }
}

function updateLitPlanets(planetCount) {
  for (let i = 1; i <= 12; i++) {
    const sat = document.querySelector(".mission-satellite.s" + i);
    if (sat) {
      if (i <= planetCount) {
        sat.classList.add("active");
      } else {
        sat.classList.remove("active", "hidden-comet", "hidden-moon", "hidden-blackhole");
      }
    }
  }

  for (let i = 1; i <= 24; i++) {
    const gal = document.querySelector(".galaxy-planet.g" + i);
    if (gal) {
      if (i <= planetCount) {
        gal.classList.add("active");
      } else {
        gal.classList.remove("active", "hidden-comet", "hidden-moon", "hidden-blackhole");
      }
    }
  }

  for (let i = 1; i <= 12; i++) {
    const uni = document.querySelector(".universe-planet.u" + i);
    if (uni) {
      if (i <= planetCount - 24) {
        uni.classList.add("active");
      } else {
        uni.classList.remove("active", "hidden-explosion");
      }
    }
  }
}

function buildWebPublicAvatarProfile(rawAvatar) {
  const avatar = rawAvatar && typeof rawAvatar === "object" ? rawAvatar : {};
  const keys = [
    "skinToneIndex",
    "faceShapeIndex",
    "hairStyleIndex",
    "hairColorIndex",
    "eyeStyleIndex",
    "eyebrowStyleIndex",
    "mouthStyleIndex",
    "outfitStyleIndex",
    "outfitColorIndex",
    "accessoryIndex",
    "backgroundColorIndex",
    "avatarIconIndex",
  ];
  return Object.fromEntries(
    keys.map(key => [key, Number.isInteger(avatar[key]) ? avatar[key] : 0]),
  );
}

function buildWebPublicProfile(userId, data) {
  const fallbackNudgeId = `NDG_${userId.substring(0, 6).toUpperCase()}`;
  const username = String(data.username || data.myNudgeId || fallbackNudgeId)
    .trim()
    .slice(0, 40);
  const myNudgeId = String(data.myNudgeId || username)
    .trim()
    .slice(0, 40);
  const rawFamilyRole = data.userRole;
  const familyRole = ["guardian", "child"].includes(rawFamilyRole)
    ? rawFamilyRole
    : "personal";
  const rawPlanetCount = Number.isFinite(data.planetCount)
    ? Math.floor(data.planetCount)
    : 0;
  const accentColor = [
    "purple",
    "blue",
    "teal",
    "green",
    "orange",
    "pink",
    "red",
    "indigo",
  ].includes(data.accentColor)
    ? data.accentColor
    : "purple";
  return {
    schemaVersion: 1,
    userId,
    username: username || fallbackNudgeId,
    myNudgeId: myNudgeId || fallbackNudgeId,
    nickname: String(data.nickname || "自律使用者").trim().slice(0, 40) || "自律使用者",
    signature: String(data.signature || "").trim().slice(0, 160),
    avatarProfile: buildWebPublicAvatarProfile(data.avatarProfile),
    accentColor,
    planetCount: Math.max(0, rawPlanetCount),
    familyRole,
    profileTitleBadgeKey: String(data.profileTitleBadgeKey || "").slice(0, 80),
    unlockedBadgeDates:
      data.unlockedBadgeDates &&
      typeof data.unlockedBadgeDates === "object" &&
      !Array.isArray(data.unlockedBadgeDates)
        ? data.unlockedBadgeDates
        : {},
    updatedAt: new Date().toISOString(),
  };
}

async function syncWebPublicProfile(userId, data) {
  if (!db || !userId) return;
  await db.collection("public_profiles")
    .doc(userId)
    .set(buildWebPublicProfile(userId, data));
}

function listenToUser(userId) {
  if (!db) return;
  listenToRequests(userId);
  if (document.body.dataset.page === "rooms") {
    listenToWebRooms(userId);
  }
  const authenticatedUid = firebase.auth().currentUser?.uid;
  if (authenticatedUid && authenticatedUid === userId) {
    listenToFamilyLink(userId);
  }

  // Check if profile page is viewing a friend's profile
  if (document.body.dataset.page === "profile") {
    const urlParams = new URLSearchParams(window.location.search);
    const viewUserId = urlParams.get('userId');
    const viewNudgeId = urlParams.get('nudgeId');

    if (viewUserId && viewUserId !== userId) {
      // Load friend profile by UID
      db.collection("public_profiles").doc(viewUserId).get().then(snap => {
        if (snap.exists) {
          try { renderWebProfilePage(snap.data(), true, viewUserId); } catch(e) { console.error("Friend profile render error:", e); }
        }
      });
    } else if (viewNudgeId) {
      // Load friend profile by Nudge ID
      db.collection("public_profiles").where("myNudgeId", "==", viewNudgeId.toUpperCase()).limit(1).get().then(snap => {
        if (!snap.empty) {
          const friendDoc = snap.docs[0];
          try { renderWebProfilePage(friendDoc.data(), true, friendDoc.id); } catch(e) { console.error("Friend profile render error:", e); }
        }
      });
    }
  }
  db.collection("users").doc(userId).onSnapshot((docSnap) => {
    if (!docSnap.exists) {
      // Create a default user document in Firestore!
      const defaultData = {
        id: userId,
        nickname: "新自律使用者",
        myNudgeId: 'NDG_' + userId.substring(0, 6).toUpperCase(),
        username: 'NDG_' + userId.substring(0, 6).toUpperCase(),
        disciplineCoins: 100,
        planetCount: 0,
        weeklyPlanetEarned: false,
        tasks: [],
        dailySummaries: [],
        accentColor: "purple",
        signature: "今天也在穩定前進",
        profileTitleBadgeKey: "",
        userRole: "personal",
        isStudying: false,
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString()
      };
      db.collection("users").doc(userId).set(defaultData).then(() => {
        console.log("Default user document created for newly signed-in user:", userId);
      }).catch(err => {
        console.error("Failed to create default user document:", err);
      });
      return;
    }
    const data = docSnap.data();
    currentWebUserData = data;
    syncWebPublicProfile(userId, data).catch(error => {
      console.warn("Public profile sync skipped:", error);
    });

    migrateLegacyWebGroup(userId, data).catch(error => {
      console.warn("Legacy group migration skipped:", error);
    });
    ensureCanonicalWebMembership(userId, data).catch(error => {
      console.warn("Canonical group membership repair skipped:", error);
    });

    updateSidebarProfile(data);

    if (document.body.dataset.page === "profile") {
      // Check if we're viewing own profile or a friend's profile via query params
      const urlParams = new URLSearchParams(window.location.search);
      const viewUserId = urlParams.get('userId');
      const viewNudgeId = urlParams.get('nudgeId');

      if ((viewUserId && viewUserId !== userId) || viewNudgeId) {
        // Visitor mode: load friend's profile from Firestore (handled separately below)
        // Don't overwrite own data into profile page
      } else {
        try { renderWebProfilePage(data, false, userId); } catch(e) { console.error("Profile page render error:", e); }
      }
    }

    // Family content and consent are synchronized through the canonical
    // family_links record. Parent pages never subscribe to the child's raw
    // user document.

    // Group role and shared publications come from the canonical Group record.
    // User-document group fields only locate the record during migration.
    listenToCanonicalWebGroup(userId, data.groupId);

    const dailySummaries = data.dailySummaries || [];
    const tasks = data.tasks || [];
    currentUserTasks = tasks;
    currentUserDailySummaries = dailySummaries;

    // Settle weekly planets and update lit visual planet orbits
    try {
      checkWeeklyPlanetSettlementWeb(data, userId);
    } catch (e) {
      console.error("Weekly settlement run error on web:", e);
    }

    try {
      updateLitPlanets(data.planetCount || 0);
    } catch (e) {
      console.error("Failed to update lit planets from count:", e);
    }

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
        if (document.body.dataset.page === "operations") {
          const coins = typeof data.disciplineCoins === 'number' ? data.disciplineCoins : 0;
          prosperityElement.dataset.count = coins;
          prosperityElement.textContent = `${coins}`;
        } else if (document.body.dataset.page === "planet") {
          prosperityElement.dataset.count = completionRate;
          prosperityElement.textContent = `${completionRate}`;
        }
      }

      if (document.body.dataset.page === "planet") {
        if (typeof window.bindFirestoreMissions === 'function') {
          window.bindFirestoreMissions(tasks);
        }
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
        if (k === "challenge" || k === "template") continue;
        if (JSON.stringify(store[k]) !== JSON.stringify(data.webToolsState[k])) {
          store[k] = data.webToolsState[k];
          changed = true;
        }
      }
    }
    if (data.webToolsCollection) {
      for (const k in data.webToolsCollection) {
        if (k === "studySchedules") continue;
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

function parseTaskDueDateStart(dueDate) {
  if (!dueDate) return null;
  if (typeof dueDate.toDate === "function") {
    const date = dueDate.toDate();
    return new Date(date.getFullYear(), date.getMonth(), date.getDate());
  }
  if (typeof dueDate === "string") {
    const match = dueDate.match(/^(\d{4})-(\d{2})-(\d{2})/);
    if (match) {
      return new Date(Number(match[1]), Number(match[2]) - 1, Number(match[3]));
    }
  }
  const parsed = new Date(dueDate);
  if (Number.isNaN(parsed.getTime())) return null;
  return new Date(parsed.getFullYear(), parsed.getMonth(), parsed.getDate());
}

function isDeadlineTaskReadyForWeb(task) {
  const taskType = task.taskType || "fixed";
  if (taskType !== "deadline") return true;

  const due = parseTaskDueDateStart(task.dueDate);
  if (!due) return false;

  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  return today >= due;
}

window.bindFirestoreMissions = function(tasks) {
  const list = document.getElementById("dynamicMissionList");
  if (!list) return;

  list.innerHTML = "";
  tasks.slice(0, 36).forEach((task, index) => {
    const title = task.title || task.name || "自律任務";
    const done = task.isDone || task.done || false;
    const isDeadlineTask = (task.taskType || "fixed") === "deadline";
    const deadlineReady = isDeadlineTaskReadyForWeb(task);
    const canToggle = !isDeadlineTask || deadlineReady || done;
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
          <input type="checkbox" class="mission-check" data-satellite="${sId}" data-index="${index}" data-task-id="${taskId}" data-task-type="${taskType}" ${done ? 'checked' : ''} ${canToggle ? '' : 'disabled'} />
          <span>${title}</span>
        </label>
        <div class="mission-meta">
          <div class="energy-bar-container">
            <div class="energy-bar" style="width: ${done ? '100%' : '60%'}; background: ${done ? '#00ffcc' : '#f59e0b'};"></div>
          </div>
          <div class="mission-actions" style="display: flex; align-items: center; gap: 8px;">
            <span style="font-size: 11px; color: ${done ? '#00ffcc' : 'rgba(255,255,255,0.4)'}; font-weight: 700;">
              ${done ? '✅ 已同步完成' : isDeadlineTask && !deadlineReady ? '📅 尚未到驗收日' : '⏳ 行動中'}
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
      if (plot) {
        plot.classList.add("built");
        plot.classList.add("built-" + taskType);
      }
    } else {
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
        const selectedTask = currentTasks.find(t => t.id === taskId);
        if (isChecked && selectedTask && !isDeadlineTaskReadyForWeb(selectedTask)) {
          e.target.checked = false;
          toast("截止日任務尚未到驗收日，暫時不能勾選完成");
          return;
        }
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
    const plot = $("." + sId.replace("s", "p"));

    if (check.checked) {
      if (plot) {
        plot.classList.add("built");
        plot.classList.add("built-" + taskType);
      }
    } else {
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

function renderWebGrowthTracks(data = {}, isFriend = false) {
  const personalValue = document.getElementById("profilePersonalGrowthValue");
  const familyTrack = document.getElementById("profileFamilyGrowth");
  const familyValue = document.getElementById("profileFamilyGrowthValue");
  const groupTrack = document.getElementById("profileGroupGrowth");
  const groupValue = document.getElementById("profileGroupGrowthValue");
  if (!personalValue && !familyTrack && !groupTrack) return;

  const avatarLevel = Number(data.avatarLevel);
  const avatarExperience = Number(data.avatarExperience);
  if (personalValue) {
    personalValue.textContent =
      Number.isFinite(avatarLevel) && Number.isFinite(avatarExperience)
        ? `Lv.${avatarLevel} · ${avatarExperience} EXP`
        : "等待 App 同步角色進度";
  }

  const userId =
    typeof firebase !== "undefined" ? firebase.auth().currentUser?.uid : null;
  const showFamily = !isFriend && Boolean(activeFamilyLink);
  if (familyTrack) familyTrack.hidden = !showFamily;
  if (showFamily && familyValue) {
    familyValue.textContent =
      activeFamilyLink.guardianId === userId
        ? "家長 · 已建立家庭連結"
        : "孩子 · 已建立家庭連結";
  }

  const showGroup =
    !isFriend &&
    window.NudgeGroupContract?.isGroupMember(activeWebGroup, userId) === true;
  if (groupTrack) groupTrack.hidden = !showGroup;
  if (showGroup && groupValue) {
    const role = window.NudgeGroupContract.isGroupManager(activeWebGroup, userId)
      ? "管理者"
      : "成員";
    groupValue.textContent = `${role} · ${activeWebGroup.name || "已加入團體"}`;
  }
}

function renderWebProfilePage(data, isFriend, friendUid) {
  const nickname = data.nickname || "自律使用者";
  const signature = data.signature || "今天也在穩定前進";
  const nudgeId = data.myNudgeId || data.username || (friendUid ? 'NDG_' + friendUid.substring(0, 6).toUpperCase() : "NDG-Guest");
  const coins = typeof data.disciplineCoins === 'number' ? data.disciplineCoins : 0;
  const planets = typeof data.planetCount === 'number' ? data.planetCount : 0;
  const profileTitleBadgeKey = data.profileTitleBadgeKey || "";
  const unlockedBadgeDates = data.unlockedBadgeDates || {};
  renderWebGrowthTracks(data, isFriend);

  let accentColor = "#7c6ae6";
  if (data.accentColor) {
    if (typeof data.accentColor === 'number') {
      const hex = (data.accentColor & 0x00FFFFFF).toString(16).padStart(6, '0');
      accentColor = `#${hex}`;
    } else {
      const colorMap = {
        'purple': '#7C6AE6',
        'blue': '#4F8CFF',
        'teal': '#14B8A6',
        'green': '#10B981',
        'orange': '#F59E0B',
        'pink': '#EC4899',
        'red': '#EF4444',
        'indigo': '#6366F1'
      };
      accentColor = colorMap[data.accentColor] || colorMap.purple;
    }
  }

  // Update DOM components
  const mainAvatar = document.getElementById("profileMainAvatar");
  if (mainAvatar) {
    if (data.avatarProfile && typeof data.avatarProfile.avatarIconIndex === 'number') {
      mainAvatar.innerHTML = `<img src="assets/avatar/icons/icon_${data.avatarProfile.avatarIconIndex}.png" style="width:100%; height:100%; object-fit:cover; border-radius:50%;" />`;
    } else {
      mainAvatar.textContent = nickname.substring(0, 1).toUpperCase();
    }
    mainAvatar.style.background = accentColor;
    mainAvatar.style.boxShadow = `0 10px 25px ${accentColor}40`;
  }
  const miniAvatar = document.getElementById("profileMiniAvatar");
  if (miniAvatar) {
    if (data.avatarProfile && typeof data.avatarProfile.avatarIconIndex === 'number') {
      miniAvatar.innerHTML = `<img src="assets/avatar/icons/icon_${data.avatarProfile.avatarIconIndex}.png" style="width:100%; height:100%; object-fit:cover; border-radius:50%;" />`;
    } else {
      miniAvatar.textContent = nickname.substring(0, 1).toUpperCase();
    }
    miniAvatar.style.background = accentColor;
  }
  const mainName = document.getElementById("profileMainName");
  if (mainName) mainName.textContent = nickname;

  const mainSignature = document.getElementById("profileMainSignature");
  if (mainSignature) mainSignature.textContent = `"${signature}"`;

  const nodeNudgeId = document.getElementById("profileNudgeId");
  if (nodeNudgeId) nodeNudgeId.textContent = nudgeId;

  const coinsVal = document.getElementById("profileCoinsVal");
  if (coinsVal) coinsVal.textContent = coins;

  const planetsVal = document.getElementById("profilePlanetsVal");
  if (planetsVal) planetsVal.textContent = planets;

  // Cover photo banner gradient
  const coverBanner = document.getElementById("profileCoverBanner");
  if (coverBanner) {
    coverBanner.style.background = `linear-gradient(135deg, ${accentColor} 0%, #1e144a 50%, #03050a 100%)`;
  }

  // Online status calculation
  const onlineStatusNode = document.getElementById("profileOnlineStatus");
  if (onlineStatusNode) {
    let onlineStatus = "⚪ 離線";
    let statusColor = "#64748b";
    if (data.isStudying) {
      onlineStatus = "🟢 正在專注中";
      statusColor = "#10b981";
    } else {
      if (!isFriend) {
        onlineStatus = "🟢 在線上";
        statusColor = "#10b981";
      } else {
        let lastActive = null;
        if (data.updatedAt) {
          if (typeof data.updatedAt.toDate === 'function') {
            lastActive = data.updatedAt.toDate();
          } else if (data.updatedAt.seconds) {
            lastActive = new Date(data.updatedAt.seconds * 1000);
          } else {
            lastActive = new Date(data.updatedAt);
          }
        }
        const now = new Date();
        if (lastActive && (now - lastActive < 5 * 60 * 1000)) { // 5 minutes
          onlineStatus = "🟢 在線上";
          statusColor = "#10b981";
        } else {
          onlineStatus = "⚪ 離線";
          statusColor = "#64748b";
        }
      }
    }
    onlineStatusNode.textContent = onlineStatus;
    onlineStatusNode.style.color = statusColor;
  }

  // Active badge/title
  const badgeNames = {
    'task_starter': '任務起步者',
    'focus_beginner': '專注新手',
    'focus_streak': '專注連續者',
    'task_streak': '任務連續者',
    'sleep_guard': '睡眠守護者',
    'step_master': '步數達人',
    'steady_progress': '穩定前進',
    'score_keeper': '高分維持',
    'coin_earner': '門檻達人',
    'auto_tracker': '自動追蹤者',
    'health_sync': '健康同步者',
    'health_task': '健康任務實踐者'
  };
  const badgeName = badgeNames[profileTitleBadgeKey] || "";
  const mainBadge = document.getElementById("profileMainBadge");
  if (mainBadge) {
    if (badgeName) {
      mainBadge.textContent = `🏆 ${badgeName}`;
      mainBadge.style.display = "inline-flex";
    } else {
      mainBadge.style.display = "none";
    }
  }

  // Badges grid
  const badgesGrid = document.getElementById("profileUnlockedBadges");
  if (badgesGrid) {
    const badgeIcons = {
      'task_starter': '🚀',
      'focus_beginner': '🎯',
      'focus_streak': '🔥',
      'task_streak': '⚡',
      'sleep_guard': '🌙',
      'step_master': '👟',
      'steady_progress': '📈',
      'score_keeper': '🎖️',
      'coin_earner': '🪙',
      'auto_tracker': '📡',
      'health_sync': '❤️',
      'health_task': '💪'
    };
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
    const unlockedKeys = Object.keys(unlockedBadgeDates);
    const html = badgeDefinitions.map(b => {
      const isUnlocked = unlockedKeys.includes(b.key);
      return `
        <div class="badge-item" style="opacity: ${isUnlocked ? 1 : 0.25}; cursor: ${isUnlocked ? 'pointer' : 'default'};" title="${isUnlocked ? '已解鎖' : '未解鎖'}">
          <span class="badge-icon">${badgeIcons[b.key] || '🏆'}</span>
          <span class="badge-name" style="color: ${isUnlocked ? '#fff' : 'var(--muted)'};">${b.name}</span>
        </div>
      `;
    }).join('');
    badgesGrid.innerHTML = html;
  }

  // Edit card button and planet jump button
  const editBtn = document.getElementById("profileEditCardBtn");
  const saveBtn = document.getElementById("profileSaveCardBtn");
  const cancelBtn = document.getElementById("profileCancelEditBtn");
  const likeBtn = document.getElementById("profileLikeBtn");
  const jumpPlanetBtn = document.getElementById("profileJumpPlanetBtn");
  const visitorBanner = document.getElementById("profileVisitorBanner");
  const createPostCard = document.querySelector(".fb-create-post-card");

  if (isFriend) {
    // Visitor mode: hide edit, show like, show visitor banner, show jump planet button
    if (editBtn) editBtn.style.display = "none";
    if (saveBtn) saveBtn.style.display = "none";
    if (cancelBtn) cancelBtn.style.display = "none";
    if (likeBtn) likeBtn.style.display = "none";
    if (createPostCard) createPostCard.style.display = "none";
    if (visitorBanner) {
      visitorBanner.style.display = "block";
      const visitorName = document.getElementById("profileVisitorName");
      if (visitorName) visitorName.textContent = data.nickname || "自律使用者";
    }
    if (jumpPlanetBtn) {
      jumpPlanetBtn.style.display = "inline-flex";
      jumpPlanetBtn.onclick = () => {
        const uid = friendUid || (new URLSearchParams(window.location.search)).get('userId') || '';
        window.location.href = uid ? `planet.html?userId=${uid}` : 'planet.html';
      };
    }
  } else {
    // Own profile mode: show edit, hide like, hide visitor banner, hide jump planet button
    if (editBtn) editBtn.style.display = "inline-flex";
    if (likeBtn) likeBtn.style.display = "none";
    if (createPostCard) createPostCard.style.display = "flex";
    if (visitorBanner) visitorBanner.style.display = "none";
    if (jumpPlanetBtn) jumpPlanetBtn.style.display = "none";

    // Setup Inline Edit Elements reference
    const mainNameEl = document.getElementById("profileMainName");
    const mainSigEl = document.getElementById("profileMainSignature");
    const mainBadgeEl = document.getElementById("profileMainBadge");

    const nicknameInput = document.getElementById("editProfileNicknameInline");
    const signatureInput = document.getElementById("editProfileSignatureInline");
    const badgeSelect = document.getElementById("editProfileTitleInline");
    const colorPickerContainer = document.getElementById("inlineColorPickerContainer");
    const colorSwatchesEl = document.getElementById("inlineColorPickerSwatches");
    const selectedColorInput = document.getElementById("editProfileSelectedColorInline");

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
    if (selectedColorInput) selectedColorInput.value = currentAccent;

    // Render Swatches
    if (colorSwatchesEl) {
      colorSwatchesEl.innerHTML = colorOptions.map(opt => `
        <div class="color-swatch ${currentAccent === opt.name ? 'active' : ''}"
             data-color="${opt.name}"
             style="background: ${opt.hex}; --swatch-color: ${opt.hex};"
             title="${opt.label}"></div>
      `).join('');

      const swatches = colorSwatchesEl.querySelectorAll(".color-swatch");
      swatches.forEach(sw => {
        sw.addEventListener("click", function() {
          swatches.forEach(s => s.classList.remove("active"));
          this.classList.add("active");
          if (selectedColorInput) selectedColorInput.value = this.getAttribute("data-color");
        });
      });
    }

    // Populate unlocked titles
    if (badgeSelect) {
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
      const unlockedKeys = Object.keys(unlockedBadgeDates);
      const unlockedBadges = badgeDefinitions.filter(b => unlockedKeys.includes(b.key));

      let badgesSelectHtml = `<option value="">不使用稱號</option>`;
      unlockedBadges.forEach(b => {
        badgesSelectHtml += `<option value="${b.key}" ${profileTitleBadgeKey === b.key ? 'selected' : ''}>${b.name}</option>`;
      });
      badgeSelect.innerHTML = badgesSelectHtml;
    }

    // Wire up inline edit toggle
    if (editBtn) {
      editBtn.onclick = () => {
        if (mainNameEl) mainNameEl.style.display = "none";
        if (mainSigEl) mainSigEl.style.display = "none";
        if (mainBadgeEl) mainBadgeEl.style.display = "none";

        if (nicknameInput) {
          nicknameInput.value = nickname;
          nicknameInput.style.display = "block";
        }
        if (signatureInput) {
          signatureInput.value = signature;
          signatureInput.style.display = "block";
        }
        if (badgeSelect) badgeSelect.style.display = "block";
        if (colorPickerContainer) colorPickerContainer.style.display = "flex";

        editBtn.style.display = "none";
        if (saveBtn) saveBtn.style.display = "inline-flex";
        if (cancelBtn) cancelBtn.style.display = "inline-flex";
      };
    }

    // Cancel inline editing
    if (cancelBtn) {
      cancelBtn.onclick = () => {
        if (mainNameEl) mainNameEl.style.display = "";
        if (mainSigEl) mainSigEl.style.display = "";
        if (badgeName && mainBadgeEl) mainBadgeEl.style.display = "inline-flex";

        if (nicknameInput) nicknameInput.style.display = "none";
        if (signatureInput) signatureInput.style.display = "none";
        if (badgeSelect) badgeSelect.style.display = "none";
        if (colorPickerContainer) colorPickerContainer.style.display = "none";

        if (editBtn) editBtn.style.display = "inline-flex";
        if (saveBtn) saveBtn.style.display = "none";
        if (cancelBtn) cancelBtn.style.display = "none";
      };
    }

    // Save inline editing
    if (saveBtn) {
      saveBtn.onclick = () => {
        const newNickname = nicknameInput.value.trim();
        const newSignature = signatureInput.value.trim();
        const newAccentColor = selectedColorInput.value;
        const newTitleBadgeKey = badgeSelect.value;

        if (!newNickname) {
          toast("請填寫有效的暱稱");
          return;
        }

        const activeUserId = localStorage.getItem("nudgeActiveDemoUserId") || "an_nudge";
        if (activeUserId && typeof db !== "undefined") {
          saveBtn.disabled = true;
          saveBtn.textContent = "儲存中...";
          db.collection("users").doc(activeUserId).update({
            nickname: newNickname,
            signature: newSignature || "今天也在穩定前進",
            accentColor: newAccentColor,
            profileTitleBadgeKey: newTitleBadgeKey,
            updatedAt: new Date().toISOString()
          }).then(() => {
            toast("個人名片更新成功！ ✨");
            window.location.reload();
          }).catch(err => {
             console.error("更新名片失敗：", err);
             toast("更新失敗，請稍後再試");
             saveBtn.disabled = false;
             saveBtn.textContent = "💾 儲存名片";
          });
        }
      };
    }
  }

  // Dynamic Timeline Feed
  const feedContainer = document.getElementById("profileTimelineFeed");
  if (feedContainer) {
    if (isFriend) {
      feedContainer.innerHTML = `
        <div class="fb-empty-feed" style="text-align:center;padding:40px 20px;color:var(--muted);">
          <span class="icon" style="font-size:42px;display:block;margin-bottom:12px;">🔒</span>
          <strong>私人自律動態不會公開讀取</strong>
          <p>目前公開名片只顯示本人選定的基本資料；任務、睡眠、步數與動態仍留在私人帳號。</p>
        </div>
      `;
      return;
    }
    const dailySummaries = data.dailySummaries || [];
    const welcomePost = data.welcomePost || {};
    const customPosts = data.customPosts || [];
    const tasks = data.tasks || [];
    const completedCount = tasks.filter(t => t.isDone || t.done).length;

    // Check if the current user viewing the profile is the owner
    const activeUserId = localStorage.getItem("nudgeActiveDemoUserId") || "an_nudge";
    const profileUserId = new URLSearchParams(window.location.search).get('userId') || new URLSearchParams(window.location.search).get('id') || activeUserId;
    const isOwner = (activeUserId === profileUserId);

    let allPosts = [];

    dailySummaries.forEach((summary, idx) => {
      if (summary.isDeleted) return;
      allPosts.push({
        id: summary.date,
        isWelcome: false,
        timestamp: new Date(summary.date).getTime() || 0,
        dateStr: summary.date || `第 ${dailySummaries.length - idx} 天`,
        content: summary.customText || getSummaryText(summary),
        likes: summary.likes || 0,
        likedBy: summary.likedBy || [],
        comments: summary.comments || [],
        metrics: {
          focusMin: summary.focusMinutes || 0,
          sleepHr: summary.sleepHours || 0,
          stepCount: summary.steps || 0,
          completedCount: summary.completedTasks || 0
        }
      });
    });

    customPosts.forEach(cp => {
      if (cp.isDeleted) return;
      const d = new Date(cp.timestamp);
      const dateStr = d.toLocaleDateString('zh-TW', { month: 'short', day: 'numeric', hour: '2-digit', minute:'2-digit' });
      allPosts.push({
        id: cp.id,
        isWelcome: false,
        isCustom: true,
        timestamp: cp.timestamp,
        dateStr: dateStr,
        content: cp.content,
        likes: cp.likes || 0,
        likedBy: cp.likedBy || [],
        comments: cp.comments || [],
        metrics: null
      });
    });

    if (!welcomePost.isDeleted) {
      allPosts.push({
        id: 'welcome',
        isWelcome: true,
        timestamp: 0, // Always oldest
        dateStr: '剛剛',
        content: welcomePost.customText || '今天正式啟用了 Nudge 自律名片！目前已設定自律目標，並準備在手機 App 端同步專注、睡眠與步數進度，開啟自律宇宙的全新生活！ 🪐✨',
        likes: welcomePost.likes || 0,
        likedBy: welcomePost.likedBy || [],
        comments: welcomePost.comments || [],
        metrics: null
      });
    }

    allPosts.sort((a, b) => b.timestamp - a.timestamp);
    let postsHtml = '';

    function getSummaryText(summary) {
      const score = summary.disciplineScore || 0;
      if (score >= 90) return `今天自律狀態爆表！達成了 ${score} 的高分！特別是完成了所有核心挑戰，感覺充滿能量！ 🚀✨`;
      if (score >= 75) return `今天的自律進度很穩定，得分為 ${score}。番茄鐘專注與健康運動都有乖乖執行，繼續保持這個節奏！ 💪`;
      return `今天自律得分為 ${score}。雖然有些項目稍微落後，但沒關係，自律是個長跑，明天再接再厲！ 🌟`;
    }

    if (allPosts.length > 0) {
      allPosts.forEach(post => {
        let metricsHtml = '';
        if (post.metrics) {
          metricsHtml = `
            <div class="fb-post-metrics-grid">
              <div class="fb-metric-pill focus"><span class="icon">⏱️</span><div class="fb-metric-details"><span class="fb-metric-label">專注時間</span><span class="fb-metric-val">${post.metrics.focusMin} 分鐘</span></div></div>
              <div class="fb-metric-pill sleep"><span class="icon">🌙</span><div class="fb-metric-details"><span class="fb-metric-label">睡眠時數</span><span class="fb-metric-val">${post.metrics.sleepHr} 小時</span></div></div>
              <div class="fb-metric-pill steps"><span class="icon">👣</span><div class="fb-metric-details"><span class="fb-metric-label">今日步數</span><span class="fb-metric-val">${post.metrics.stepCount} 步</span></div></div>
              <div class="fb-metric-pill tasks"><span class="icon">✅</span><div class="fb-metric-details"><span class="fb-metric-label">完成任務</span><span class="fb-metric-val">${post.metrics.completedCount} 個任務</span></div></div>
            </div>
          `;
        }

        let commentsHtml = '';
        if (post.comments.length > 0) {
          commentsHtml = `<div class="fb-post-comments-section">`;
          post.comments.forEach((c, cIndex) => {
            const avatarChar = c.author ? c.author.substring(0, 1).toUpperCase() : '👤';
            const activeUserName = localStorage.getItem("nudgeActiveDemoUserName") || "訪客";
            const canDeleteComment = isOwner || c.author === activeUserName;
            const deleteBtnHtml = canDeleteComment ? `<div style="font-size: 12px; color: var(--muted); cursor: pointer; margin-left: auto; align-self: flex-start; padding: 4px;" onclick="window.deleteComment('${post.id}', ${post.isWelcome}, ${post.isCustom}, ${cIndex})">✕</div>` : '';

            commentsHtml += `
              <div class="fb-post-comment-item">
                <div class="fb-post-comment-avatar" style="background: var(--page-accent, #7c6ae6)">${avatarChar}</div>
                <div class="fb-post-comment-content" style="display: flex; gap: 8px;">
                  <div style="flex-grow: 1;">
                    <div class="fb-post-comment-author">${c.author}</div>
                    <div class="fb-post-comment-text">${c.text}</div>
                  </div>
                  ${deleteBtnHtml}
                </div>
              </div>
            `;
          });
          commentsHtml += `</div>`;
        }

        const dropdownHtml = isOwner ? `
          <div class="fb-post-dropdown-container">
            <div style="color: var(--muted); font-size: 18px; cursor: pointer; padding: 0 8px;" onclick="window.togglePostMenu('${post.id}')">•••</div>
            <div class="fb-post-dropdown-menu" id="post-menu-${post.id}">
              <div class="fb-post-dropdown-item" onclick="window.editPost('${post.id}', ${post.isWelcome}, ${post.isCustom})">✏️ 修改貼文</div>
              <div class="fb-post-dropdown-item delete" onclick="window.deletePost('${post.id}', ${post.isWelcome}, ${post.isCustom})">🗑️ 刪除貼文</div>
            </div>
          </div>
        ` : ``;

        const hasLiked = post.likedBy.includes(activeUserId === profileUserId ? (localStorage.getItem("nudgeActiveDemoUserName") || "訪客") : "訪客"); // Wait, activeUserName is what's used
        const activeUserName = localStorage.getItem("nudgeActiveDemoUserName") || "訪客";
        const isLiked = post.likedBy.includes(activeUserName);
        const likeBtnStyle = isLiked ? 'color: var(--page-accent, #a855f7); font-weight: bold; background: rgba(168, 85, 247, 0.1);' : '';
        const likeBtnText = isLiked ? '👍 已讚' : '👍 讚';

        postsHtml += `
          <article class="fb-post-card">
            <div class="fb-post-header">
              <div class="fb-post-author-info">
                <div class="fb-mini-avatar" style="background: ${accentColor};">${nickname.substring(0, 1).toUpperCase()}</div>
                <div>
                  <div style="display: flex; align-items: center; gap: 8px;">
                    <span class="fb-post-author-name">${nickname}</span>
                    ${badgeName ? `<span class="fb-profile-badge" style="font-size: 10px; padding: 2px 8px;">🏆 ${badgeName}</span>` : ''}
                  </div>
                  <span class="fb-post-time">${post.dateStr}</span>
                </div>
              </div>
              ${dropdownHtml}
            </div>
            <div class="fb-post-content" id="post-content-${post.id}">${post.content}</div>
            ${metricsHtml}
            <div class="fb-post-feedback-summary">
              <span>👍 ${post.likes} 人按讚</span>
              <span>${post.comments.length} 則留言 • 0 次分享</span>
            </div>
            <div class="fb-post-feedback-actions">
              <button class="fb-post-action-btn" style="${likeBtnStyle}" onclick="window.toggleLikePost('${post.id}', ${post.isWelcome}, ${post.isCustom})">${likeBtnText}</button>
              <button class="fb-post-action-btn" onclick="window.addCommentToPost('${post.id}', ${post.isWelcome}, ${post.isCustom})">💬 留言</button>
              <button class="fb-post-action-btn" onclick="window.sharePost('${post.id}')">↪️ 分享</button>
            </div>
            ${commentsHtml}
          </article>
        `;
      });
    } else {
      postsHtml = `<div style="text-align: center; color: var(--muted); padding: 40px;">目前沒有任何動態。</div>`;
    }

    feedContainer.innerHTML = postsHtml;
  }
}
