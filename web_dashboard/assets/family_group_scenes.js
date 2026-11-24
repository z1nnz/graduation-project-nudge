// Family courtyard (family-courtyard.html) and group hall (group-hall.html).
// Page-specific: reuses db / functions / firebase from app.js, never edits it,
// and only uses the existing canonical records and Rules:
//   family_links/{id}{,/encouragements,/goals,/summaries/current,/bond_events}
//   groups/{id}{,/challenges/current{,/participants},/study_schedules,
//                /templates,/member_summaries}
// Guardians and managers propose; children and members decide and act.
// Relationship growth stays in relationship_outcomes and never becomes
// personal XP, coins or rewards.
(function (root, factory) {
  const api = factory();
  if (typeof module === "object" && module.exports) module.exports = api;
  if (root) root.NudgeFamilyGroupScenes = api;
})(typeof window !== "undefined" ? window : null, function () {
  "use strict";

  const consentKeys = Object.freeze(["summary", "weeklyReport", "taskCategories", "healthTrends"]);
  const consentLabels = Object.freeze({
    summary: "整體摘要",
    weeklyReport: "週報",
    taskCategories: "任務類別",
    healthTrends: "健康趨勢",
  });
  const encouragementTemplates = Object.freeze([
    Object.freeze({ key: "proud", title: "以你為榮", message: "看見你一步一步前進，真的很棒。" }),
    Object.freeze({ key: "rest", title: "休息也重要", message: "累了就停一下，我一直都在。" }),
    Object.freeze({ key: "together", title: "一起加油", message: "今天也陪你一起慢慢來。" }),
  ]);

  // Only fields the child consented to right now. Anything else, including
  // fields Rules would already hide, is dropped before it can be exported.
  function consentedReport(summary, scopes) {
    const report = {};
    if (!summary || !scopes) return report;
    for (const key of consentKeys) {
      if (scopes[key] === true && summary[key] !== undefined) report[key] = summary[key];
    }
    return report;
  }

  function hasAnyConsent(scopes) {
    return consentKeys.some(key => scopes?.[key] === true);
  }

  // The summary document the child must write together with a consent change
  // so that Rules' futureSummaryObeysConsent holds: revoked keys are removed.
  function summaryAfterConsent({ currentSummary, scopes, childId, now = new Date() }) {
    const next = { schemaVersion: 1, childId, updatedAt: now.toISOString() };
    for (const key of consentKeys) {
      if (scopes[key] === true && currentSummary?.[key] !== undefined) next[key] = currentSummary[key];
    }
    return next;
  }

  function nextConsentScopes(current, key, enabled) {
    if (!consentKeys.includes(key)) throw new Error("未知的分享範圍");
    const scopes = {};
    for (const item of consentKeys) scopes[item] = current?.[item] === true;
    scopes[key] = enabled === true;
    return scopes;
  }

  function bondEventId(type, sourceId) {
    return type === "acknowledgement" ? `encouragement_${sourceId}` : `goal_${sourceId}`;
  }

  // Consented-only group result: members who withdrew are simply absent.
  function groupResultDigest(summaries) {
    const shared = summaries.filter(item => item?.status === "shared" && item.summary);
    if (!shared.length) return { sharedCount: 0, averageScore: null, completedTasks: 0 };
    const total = shared.reduce((sum, item) => sum + Number(item.summary.disciplineScore || 0), 0);
    return {
      sharedCount: shared.length,
      averageScore: Math.round(total / shared.length),
      completedTasks: shared.reduce((sum, item) => sum + Number(item.summary.completedTasks || 0), 0),
    };
  }

  function nextParticipation({ current, challenge, memberId, groupId, now = new Date() }) {
    const at = now.toISOString();
    if (!current || current.challengeId !== challenge.challengeId) {
      return {
        schemaVersion: 1, groupId, challengeId: challenge.challengeId, memberId,
        status: "joined", completedDays: 0, totalDays: challenge.days, joinedAt: at, updatedAt: at,
      };
    }
    if (current.status === "completed") return null;
    const completedDays = Math.min(challenge.days, Number(current.completedDays || 0) + 1);
    const next = { ...current, completedDays, totalDays: challenge.days, updatedAt: at };
    if (completedDays >= challenge.days) {
      next.status = "completed";
      next.completedAt = at;
    } else {
      next.status = "joined";
      delete next.completedAt;
    }
    return next;
  }

  return Object.freeze({
    consentKeys, consentLabels, encouragementTemplates, consentedReport, hasAnyConsent,
    summaryAfterConsent, nextConsentScopes, bondEventId, groupResultDigest, nextParticipation,
  });
});

(function () {
  "use strict";
  if (typeof window === "undefined" || typeof document === "undefined") return;
  const page = document.body?.dataset.page;
  if (!["family-courtyard", "group-hall"].includes(page)) return;
  const api = window.NudgeFamilyGroupScenes;
  const $ = (selector, rootNode = document) => rootNode.querySelector(selector);
  const esc = value => String(value ?? "").replace(/[&<>"']/g, ch => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;",
  })[ch]);
  const store = () => (typeof db !== "undefined" ? db : null);
  const say = message => (typeof toast === "function" ? toast(message) : console.info(message));
  const scopeType = page === "family-courtyard" ? "family" : "group";
  const subs = [];
  const scopeSubs = [];
  const state = { userId: null, memberships: [], selected: null, pending: false, data: {} };

  function stop(list) {
    while (list.length) { try { list.pop()(); } catch (_) { /* stopped */ } }
  }

  function resetScope() {
    stop(scopeSubs);
    state.data = {};
  }

  function stopAll() {
    stop(subs);
    resetScope();
    state.userId = null;
    state.memberships = [];
    state.selected = null;
    window.NudgeSafety?.setFamily(null);
    window.NudgeSafety?.setGroup(null, false);
    render();
  }

  async function run(task, fallback) {
    if (state.pending) return;
    state.pending = true;
    render();
    try {
      await task();
    } catch (error) {
      console.warn(fallback, error);
      say(error?.code === "permission-denied" ? "權限已變更，請重新整理" : (error.message || fallback));
    } finally {
      state.pending = false;
      render();
    }
  }

  function refreshOutcomeBestEffort() {
    if (typeof functions === "undefined" || !functions || !state.selected) return;
    functions.httpsCallable("refreshRelationshipOutcome")({
      scopeType, scopeId: state.selected.scopeId,
    }).catch(error => console.warn("Relationship outcome refresh skipped:", error));
  }

  function listen(ref, key, mapper = snap => (snap.exists ? snap.data() : null)) {
    scopeSubs.push(ref.onSnapshot(
      snap => { state.data[key] = mapper(snap); render(); },
      error => { console.warn(`${key} sync failed:`, error); state.data[key] = null; state.data[`${key}Denied`] = true; render(); },
    ));
  }
  const docs = snap => snap.docs.map(doc => ({ ...doc.data(), id: doc.id }));

  function selectScope(membership) {
    resetScope();
    state.selected = membership;
    window.NudgeSafety?.setFamily(null);
    window.NudgeSafety?.setGroup(null, false);
    if (!membership) { render(); return; }
    const id = membership.scopeId;
    const fs = store();
    if (scopeType === "family") {
      const link = fs.collection("family_links").doc(id);
      listen(link, "link", snapshot => {
        const data = snapshot.data();
        void window.NudgeSafety?.setFamily(data?.status === "active" ? id : null);
        return data;
      });
      listen(link.collection("encouragements").orderBy("createdAt", "desc").limit(20), "encouragements", docs);
      listen(link.collection("goals").orderBy("createdAt", "desc").limit(20), "goals", docs);
      listen(link.collection("summaries").doc("current"), "summary");
    } else {
      const group = fs.collection("groups").doc(id);
      listen(group, "group", snapshot => {
        const data = snapshot.data();
        window.NudgeSafety?.setGroup(data?.status === "active" ? id : null, data?.ownerId === state.userId);
        return data;
      });
      listen(group.collection("challenges").doc("current"), "challenge");
      listen(group.collection("challenges").doc("current").collection("participants").doc(state.userId), "participation");
      listen(group.collection("study_schedules"), "schedules", docs);
      listen(group.collection("templates"), "templates", docs);
      listen(group.collection("member_summaries"), "summaries", docs);
    }
    listen(fs.collection("relationship_outcomes").doc(`${scopeType}--${id}`), "outcome");
    render();
  }

  // ─── Family courtyard ──────────────────────────────────────────────
  function renderFamily() {
    const link = state.data.link;
    const isGuardian = state.selected?.role === "guardian";
    const busy = state.pending ? "disabled" : "";
    const scopes = link?.consentScopes || {};
    const active = link?.status === "active";

    const encouragements = (state.data.encouragements || []).map(card => `
      <article class="social-scene-card">
        <h3>${esc(card.title)}</h3><p>${esc(card.message)}</p>
        <span class="social-badge${card.status === "acknowledged" ? " is-muted" : ""}">${card.status === "acknowledged" ? "孩子已收下" : "等待孩子收下"}</span>
        ${!isGuardian && active && card.status === "sent" ? `<div class="social-actions"><button type="button" data-family-ack="${esc(card.id)}" ${busy}>收下這張卡</button></div>` : ""}
      </article>`).join("") || `<p class="visit-empty">還沒有鼓勵卡。</p>`;

    const goalLabel = { proposed: "等待孩子決定", accepted: "孩子已接受", declined: "孩子婉拒", completed: "已完成" };
    const goals = (state.data.goals || []).map(goal => `
      <article class="social-scene-card">
        <h3>${esc(goal.title)}</h3>${goal.message ? `<p>${esc(goal.message)}</p>` : ""}
        <span class="social-badge${goal.status === "proposed" ? "" : " is-muted"}">${esc(goalLabel[goal.status] || goal.status)}</span>
        ${!isGuardian && active && goal.status === "proposed" ? `<div class="social-actions"><button type="button" data-family-goal="${esc(goal.id)}" data-goal-next="accepted" ${busy}>接受</button><button type="button" data-family-goal="${esc(goal.id)}" data-goal-next="declined" ${busy}>婉拒</button></div>` : ""}
        ${!isGuardian && active && goal.status === "accepted" ? `<div class="social-actions"><button type="button" data-family-goal="${esc(goal.id)}" data-goal-next="completed" ${busy}>我完成了</button></div>` : ""}
      </article>`).join("") || `<p class="visit-empty">還沒有共同目標。</p>`;

    const consentPanel = isGuardian
      ? `<p>${api.hasAnyConsent(scopes) ? "孩子目前同意分享：" + api.consentKeys.filter(k => scopes[k]).map(k => api.consentLabels[k]).join("、") : "孩子目前沒有開放任何摘要；你看不到也無法匯出。"}</p>`
      : `<div class="social-actions" role="group" aria-label="分享範圍">${api.consentKeys.map(key => `
          <label class="visit-toggle"><input type="checkbox" data-family-consent="${key}" ${scopes[key] ? "checked" : ""} ${active ? "" : "disabled"} ${busy} /><span>${esc(api.consentLabels[key])}</span></label>`).join("")}</div>
        <p class="visit-note">由你決定家長能看到哪些摘要；關閉後立即撤回，家長也無法再匯出。</p>`;

    const report = isGuardian ? api.consentedReport(state.data.summary, scopes) : {};
    const outcome = state.data.outcome;
    const html = `
      <section class="scene-panel"><span class="eyebrow">${isGuardian ? "Guardian" : "Child"}</span>
        <h2>${esc(state.selected.scopeName)} 的家庭庭院</h2>
        <p>${isGuardian ? "你可以送出鼓勵卡、提出共同目標；接受與開始都由孩子自己決定。" : "家長的卡片與提議會出現在這裡；要不要接受、何時開始都由你決定。"}</p>
        ${active ? "" : `<p class="visit-closed">這段家庭連結已結束，只保留紀錄。</p>`}
        <p class="visit-note">家庭樹成長：${outcome ? `第 ${esc(outcome.level ?? "—")} 階` : "尚未建立"}（只屬於家庭關係，不會變成個人 XP 或金幣）</p>
      </section>
      <section class="scene-panel"><span class="eyebrow">Encouragement</span><h2>鼓勵卡</h2>
        ${isGuardian && active ? `<div class="social-actions" role="group" aria-label="送出鼓勵卡">${api.encouragementTemplates.map(t => `<button type="button" data-family-encourage="${esc(t.key)}" ${busy}>${esc(t.title)}</button>`).join("")}</div>` : ""}
        ${encouragements}</section>
      <section class="scene-panel"><span class="eyebrow">Shared goals</span><h2>共同目標</h2>
        ${isGuardian && active ? `<form class="social-actions" data-family-goal-form><label class="sr-only" for="familyGoalTitle">目標名稱</label><input id="familyGoalTitle" maxlength="60" required placeholder="提出一個共同目標，例如：週末一起散步" data-family-goal-title /><button type="submit" ${busy}>提出</button></form>` : ""}
        ${goals}</section>
      <section class="scene-panel"><span class="eyebrow">Consent</span><h2>分享同意</h2>${consentPanel}
        ${isGuardian ? `<div class="social-actions"><button type="button" data-family-export ${Object.keys(report).length && !state.pending ? "" : "disabled"}>匯出目前獲准的週報摘要</button></div>
        <p class="visit-note">只會匯出孩子此刻同意的欄位；撤回後不再顯示或匯出。</p>` : ""}
      </section>`;
    return html;
  }

  async function sendEncouragement(key) {
    const template = api.encouragementTemplates.find(item => item.key === key);
    const link = state.data.link;
    const payload = window.NudgeFamilyLinkContract.buildEncouragementPayload({
      guardianId: link.guardianId, childId: link.childId, title: template.title, message: template.message,
    });
    await store().collection("family_links").doc(state.selected.scopeId).collection("encouragements").add(payload);
    say("鼓勵卡已送出");
  }

  async function proposeGoal(title) {
    const link = state.data.link;
    const payload = window.NudgeFamilyLinkContract.buildSharedGoalPayload({
      guardianId: link.guardianId, childId: link.childId, title, message: "",
    });
    if (!payload.title) throw new Error("請輸入目標名稱");
    await store().collection("family_links").doc(state.selected.scopeId).collection("goals").add(payload);
    say("已提出，等待孩子決定");
  }

  async function acknowledge(id) {
    const fs = store();
    const linkRef = fs.collection("family_links").doc(state.selected.scopeId);
    const now = new Date().toISOString();
    const batch = fs.batch();
    batch.update(linkRef.collection("encouragements").doc(id), { status: "acknowledged", acknowledgedAt: now });
    batch.set(linkRef.collection("bond_events").doc(api.bondEventId("acknowledgement", id)), {
      schemaVersion: 1, type: "acknowledgement", sourceId: id, actorId: state.userId, points: 3, createdAt: now,
    });
    await batch.commit();
    refreshOutcomeBestEffort();
  }

  async function decideGoal(id, next) {
    const fs = store();
    const linkRef = fs.collection("family_links").doc(state.selected.scopeId);
    const now = new Date().toISOString();
    const fields = { status: next, updatedAt: now, [`${next}At`]: now };
    const batch = fs.batch();
    batch.update(linkRef.collection("goals").doc(id), fields);
    if (next === "completed") {
      batch.set(linkRef.collection("bond_events").doc(api.bondEventId("goalCompleted", id)), {
        schemaVersion: 1, type: "goalCompleted", sourceId: id, actorId: state.userId, points: 10, createdAt: now,
      });
    }
    await batch.commit();
    if (next === "completed") refreshOutcomeBestEffort();
  }

  async function changeConsent(key, enabled) {
    const fs = store();
    const link = state.data.link;
    const scopes = api.nextConsentScopes(link.consentScopes, key, enabled);
    const linkRef = fs.collection("family_links").doc(state.selected.scopeId);
    const batch = fs.batch();
    batch.update(linkRef, { consentScopes: scopes, updatedAt: new Date().toISOString() });
    batch.set(linkRef.collection("summaries").doc("current"), api.summaryAfterConsent({
      currentSummary: state.data.summary, scopes, childId: link.childId,
    }));
    await batch.commit();
    say(enabled ? "已開放這項摘要" : "已撤回，家長立即看不到");
  }

  function exportReport() {
    const report = api.consentedReport(state.data.summary, state.data.link?.consentScopes);
    if (!Object.keys(report).length) throw new Error("目前沒有獲准匯出的摘要");
    const blob = new Blob([JSON.stringify({
      familyName: state.selected.scopeName, exportedAt: new Date().toISOString(), consentedSummary: report,
    }, null, 2)], { type: "application/json" });
    const link = document.createElement("a");
    link.href = URL.createObjectURL(blob);
    link.download = `nudge-family-weekly-${new Date().toISOString().slice(0, 10)}.json`;
    link.click();
    setTimeout(() => URL.revokeObjectURL(link.href), 1000);
  }

  // ─── Group hall ────────────────────────────────────────────────────
  function renderGroup() {
    const isManager = state.selected?.role === "manager";
    const busy = state.pending ? "disabled" : "";
    const challenge = state.data.challenge;
    const mine = state.data.participation;
    const joinedCurrent = mine && challenge && mine.challengeId === challenge.challengeId;
    const digest = api.groupResultDigest(state.data.summaries || []);
    const mySummary = (state.data.summaries || []).find(item => item.memberId === state.userId);
    const templates = state.data.templates || [];
    const schedules = (state.data.schedules || []).slice(0, 8);

    const challengeCard = challenge?.status === "active"
      ? `<article class="social-scene-card"><h3>${esc(challenge.type || "團體挑戰")} · ${esc(challenge.days)} 天</h3>
          <p>由管理者發起；要不要參加、何時打卡都由你決定。挑戰不會發放個人 XP。</p>
          ${joinedCurrent ? `<p>你的進度：${esc(mine.completedDays)} / ${esc(mine.totalDays)} 天${mine.status === "completed" ? "（已完成）" : ""}</p>` : ""}
          <div class="social-actions">
            ${!joinedCurrent ? `<button type="button" data-group-join ${busy}>參加挑戰</button>` : ""}
            ${joinedCurrent && mine.status !== "completed" ? `<button type="button" data-group-checkin ${busy}>今天完成一天</button><button type="button" data-group-quit ${busy}>退出挑戰</button>` : ""}
          </div></article>`
      : `<p class="visit-empty">目前沒有進行中的挑戰。${isManager ? "可以從下方模板發起一個邀請。" : ""}</p>`;

    return `
      <section class="scene-panel"><span class="eyebrow">${isManager ? "Manager" : "Member"}</span>
        <h2>${esc(state.selected.scopeName)} 團體會館</h2>
        <p>${isManager ? "你可以提出挑戰、共同時段與模板；成員自行決定是否參與與開始。" : "管理者的邀請會在這裡；參與、打卡、分享成果都由你自己決定。"}</p>
        <p class="visit-note">團體星球：${state.data.outcome ? `第 ${esc(state.data.outcome.level ?? "—")} 階` : "尚未建立"}（團體成長不會變成個人 XP）</p>
      </section>
      <section class="scene-panel"><span class="eyebrow">Challenge</span><h2>團體挑戰</h2>${challengeCard}
        ${isManager && templates.length ? `<div class="social-actions" role="group" aria-label="從模板發起挑戰">${templates.map(t => `<button type="button" data-group-template="${esc(t.id)}" ${busy}>以「${esc(t.type)} · ${esc(t.days)} 天」發起</button>`).join("")}</div>` : ""}
      </section>
      <section class="scene-panel"><span class="eyebrow">Shared sessions</span><h2>共同時段</h2>
        ${schedules.length ? schedules.map(s => `<article class="social-scene-card"><h3>${esc(s.title)}</h3><p>${esc(s.meta)}</p></article>`).join("") : `<p class="visit-empty">還沒有共同時段。</p>`}
        ${isManager ? `<form class="social-actions" data-group-schedule-form><label class="sr-only" for="groupScheduleTitle">時段名稱</label><input id="groupScheduleTitle" maxlength="60" required placeholder="例如：週三晚上一起讀書" data-group-schedule-title /><label class="sr-only" for="groupScheduleMeta">時間說明</label><input id="groupScheduleMeta" maxlength="80" required placeholder="例如：19:30–21:00" data-group-schedule-meta /><button type="submit" ${busy}>提出共同時段</button></form>` : ""}
      </section>
      <section class="scene-panel"><span class="eyebrow">Results</span><h2>成果摘要</h2>
        <p>${digest.sharedCount ? `${digest.sharedCount} 位成員同意分享；平均自律分數 ${digest.averageScore}，共完成 ${digest.completedTasks} 項任務。` : "目前沒有成員分享成果摘要。"}</p>
        <p class="visit-note">只統計成員自行分享的摘要；撤回後立即不再計入。</p>
        ${!isManager ? (mySummary ? `<div class="social-actions"><button type="button" data-group-withdraw ${busy}>撤回我的成果摘要</button></div>` : `<p class="visit-note">你目前沒有分享；要分享請在 App 的團體頁選擇。</p>`) : ""}
      </section>`;
  }

  function groupRef() { return store().collection("groups").doc(state.selected.scopeId); }

  async function joinOrCheckIn() {
    const next = api.nextParticipation({
      current: state.data.participation, challenge: state.data.challenge, memberId: state.userId, groupId: state.selected.scopeId,
    });
    if (!next) return;
    await groupRef().collection("challenges").doc("current").collection("participants").doc(state.userId).set(next);
    if (next.status === "completed") refreshOutcomeBestEffort();
  }

  async function quitChallenge() {
    await groupRef().collection("challenges").doc("current").collection("participants").doc(state.userId).delete();
  }

  async function publishFromTemplate(templateId) {
    const template = (state.data.templates || []).find(item => item.id === templateId);
    const group = state.data.group;
    if (!template || !group) throw new Error("模板不存在");
    await groupRef().collection("challenges").doc("current").set({
      schemaVersion: 2,
      challengeId: `challenge_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`,
      groupId: state.selected.scopeId,
      groupName: group.name,
      type: String(template.type || "團體挑戰").slice(0, 60),
      days: Number(template.days),
      reward: "團體星球成長",
      status: "active",
      publishedBy: group.ownerId,
      updatedAt: new Date().toISOString(),
    });
    say("已發起挑戰邀請；成員會自行決定是否參加");
  }

  async function proposeSchedule(title, meta) {
    const group = state.data.group;
    if (!title.trim() || !meta.trim()) throw new Error("請填寫時段名稱與時間");
    await groupRef().collection("study_schedules").add({
      schemaVersion: 1, groupId: state.selected.scopeId, title: title.trim().slice(0, 60), meta: meta.trim().slice(0, 80),
      status: "scheduled", publishedBy: group.ownerId, createdAt: new Date().toISOString(),
    });
  }

  async function withdrawSummary() {
    await groupRef().collection("member_summaries").doc(state.userId).delete();
    say("已撤回，成果摘要不再計入");
  }

  // ─── Shared shell ──────────────────────────────────────────────────
  function render() {
    const host = $("[data-social-scene]");
    const picker = $("[data-social-scope-picker]");
    if (!host) return;
    const active = state.memberships.filter(m => m.status === "active");
    if (picker) {
      picker.hidden = active.length < 2;
      picker.innerHTML = active.map(m => `<option value="${esc(m.scopeId)}" ${state.selected?.scopeId === m.scopeId ? "selected" : ""}>${esc(m.scopeName)}</option>`).join("");
    }
    if (!state.userId) { host.innerHTML = `<p class="visit-empty">登入後顯示你的${scopeType === "family" ? "家庭" : "團體"}。</p>`; return; }
    if (!state.selected) {
      host.innerHTML = `<p class="visit-empty">${scopeType === "family" ? "你還沒有家庭連結。可到「家長陪伴中心」送出或接受邀請。" : "你還沒有加入團體。可到「團體 / 教育管理」接受邀請。"}</p>`;
      return;
    }
    const denied = state.data.linkDenied || state.data.groupDenied;
    host.innerHTML = denied
      ? `<p class="visit-closed">你已無法存取這個${scopeType === "family" ? "家庭" : "團體"}，資料已清除。</p>`
      : (scopeType === "family" ? (state.data.link ? renderFamily() : `<p class="visit-empty">載入中…</p>`) : (state.data.group ? renderGroup() : `<p class="visit-empty">載入中…</p>`));
  }

  function start(uid) {
    const fs = store();
    if (!fs || !uid || state.userId) return;
    state.userId = uid;
    subs.push(fs.collection("relationship_memberships").where("userId", "==", uid).onSnapshot(snapshot => {
      state.memberships = snapshot.docs.flatMap(doc => {
        try { return [window.NudgeRelationshipMembershipContract.parse(doc.id, doc.data(), uid)]; } catch (_) { return []; }
      }).filter(m => m.scopeType === scopeType);
      const active = state.memberships.filter(m => m.status === "active");
      const keep = active.find(m => m.scopeId === state.selected?.scopeId);
      const requested = new URLSearchParams(window.location.search).get(scopeType);
      const next = keep || active.find(m => m.scopeId === requested) || active[0] || null;
      if (next?.scopeId !== state.selected?.scopeId || next?.role !== state.selected?.role) selectScope(next);
      else render();
    }, error => console.warn("Membership sync failed:", error)));
    render();
  }

  document.addEventListener("click", event => {
    const t = event.target.closest("button");
    if (!t || !$("[data-social-scene]")?.contains(t)) return;
    if (t.dataset.familyEncourage) run(() => sendEncouragement(t.dataset.familyEncourage), "鼓勵卡送出失敗");
    else if (t.dataset.familyAck) run(() => acknowledge(t.dataset.familyAck), "收下失敗");
    else if (t.dataset.familyGoal) run(() => decideGoal(t.dataset.familyGoal, t.dataset.goalNext), "目標更新失敗");
    else if (t.hasAttribute("data-family-export")) run(async () => exportReport(), "匯出失敗");
    else if (t.hasAttribute("data-group-join") || t.hasAttribute("data-group-checkin")) run(joinOrCheckIn, "挑戰更新失敗");
    else if (t.hasAttribute("data-group-quit")) run(quitChallenge, "退出失敗");
    else if (t.dataset.groupTemplate) run(() => publishFromTemplate(t.dataset.groupTemplate), "發起失敗");
    else if (t.hasAttribute("data-group-withdraw")) run(withdrawSummary, "撤回失敗");
  });
  document.addEventListener("change", event => {
    const box = event.target.closest("[data-family-consent]");
    if (box) run(() => changeConsent(box.dataset.familyConsent, box.checked), "同意設定失敗");
    if (event.target.matches("[data-social-scope-picker]")) {
      selectScope(state.memberships.find(m => m.scopeId === event.target.value && m.status === "active") || null);
    }
  });
  document.addEventListener("submit", event => {
    if (event.target.matches("[data-family-goal-form]")) {
      event.preventDefault();
      const title = $("[data-family-goal-title]").value;
      run(async () => { await proposeGoal(title); $("[data-family-goal-title]") && ($("[data-family-goal-title]").value = ""); }, "提出失敗");
    } else if (event.target.matches("[data-group-schedule-form]")) {
      event.preventDefault();
      run(() => proposeSchedule($("[data-group-schedule-title]").value, $("[data-group-schedule-meta]").value), "提出失敗");
    }
  });

  render();
  document.addEventListener("firebase-ready", () => {
    const user = firebase.auth().currentUser;
    if (user && !user.isAnonymous) start(user.uid);
    firebase.auth().onAuthStateChanged(next => {
      if (!next) stopAll();
      else if (next.uid !== state.userId) { stopAll(); start(next.uid); }
    });
  });
})();
