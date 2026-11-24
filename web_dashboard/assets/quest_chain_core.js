(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.NudgeQuestChainCore = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';
  // Quest chains (委託冊): a weekly way to look at the player's own
  // Cloud-confirmed activity. A chain never issues coins, XP or badges; its
  // stamps only count `activity_receipts` the Cloud has already verified.
  // Pure functions, no DOM or storage, so Node tests load this directly.

  const DAY_MS = 24 * 60 * 60 * 1000;
  const MAX_ACTIVE = 3;
  const MAX_CERTIFICATES = 60;
  const ACTIVITY_TYPES = Object.freeze(['focus', 'study', 'exercise', 'steps', 'sleep', 'task']);

  // kind 'streak': `target` task days in a row. A finished day without a
  // stamp breaks the run and it starts again from zero.
  // kind 'count': `target` stamps anywhere inside the window. unit 'day'
  // gives at most one stamp per task day; unit 'receipt' one per receipt.
  const TEMPLATES = Object.freeze([
    tpl('focus-streak-3', '三天讀書挑戰', 'streak', 'day', 3, 7, ['focus', 'study'], 25,
      '連續 3 天，每天完成 1 次 25 分鐘以上的雲端確認專注。'),
    tpl('exercise-week-3', '一週運動 3 次', 'count', 'receipt', 3, 7, ['exercise'], 15,
      '7 天內完成 3 次 15 分鐘以上的雲端確認運動。'),
    tpl('sleep-week-5', '早睡好眠 5 天', 'count', 'day', 5, 7, ['sleep'], 7,
      '7 天內有 5 天各有一筆 7 小時以上的雲端確認睡眠。'),
    tpl('tasks-week-10', '完成 10 件任務', 'count', 'receipt', 10, 7, ['task'], 1,
      '7 天內有 10 件任務完成並由雲端確認。'),
    tpl('focus-streak-5', '五日專注長征', 'streak', 'day', 5, 10, ['focus', 'study'], 25,
      '連續 5 天，每天完成 1 次 25 分鐘以上的雲端確認專注。'),
    tpl('steps-week-4', '散步小旅行', 'count', 'day', 4, 7, ['steps'], 6000,
      '7 天內有 4 天各有一筆 6000 步以上的雲端確認步數。'),
    tpl('deep-focus-3', '三次深度專注', 'count', 'receipt', 3, 7, ['focus', 'study'], 50,
      '7 天內完成 3 次 50 分鐘以上的雲端確認專注。'),
    tpl('task-streak-7', '七日委託不斷線', 'streak', 'day', 7, 14, ['task'], 1,
      '連續 7 天，每天至少完成 1 件雲端確認的任務。'),
  ]);

  function tpl(id, title, kind, unit, target, windowDays, types, minMetric, rule) {
    return Object.freeze({ id, title, kind, unit, target, windowDays, types: Object.freeze(types), minMetric, rule });
  }

  function templateById(id) {
    return TEMPLATES.find(t => t.id === id) || null;
  }

  // ---------- task days: 05:00 Asia/Taipei (UTC+8, no DST) ----------

  const DAY_KEY = /^\d{4}-\d{2}-\d{2}$/;

  /** Task day (YYYY-MM-DD) of an instant; a day runs 05:00–04:59 Taipei time. */
  function taskDayKey(value) {
    const ms = value instanceof Date ? value.getTime() : Date.parse(value);
    if (!Number.isFinite(ms)) return null;
    // UTC+8 then minus the 5-hour rollover = UTC+3.
    return new Date(ms + 3 * 60 * 60 * 1000).toISOString().slice(0, 10);
  }

  function isDayKey(value) {
    return typeof value === 'string' && DAY_KEY.test(value) &&
      new Date(`${value}T00:00:00.000Z`).toISOString().slice(0, 10) === value;
  }

  function addDays(day, count) {
    const date = new Date(`${day}T00:00:00.000Z`);
    date.setUTCDate(date.getUTCDate() + count);
    return date.toISOString().slice(0, 10);
  }

  function daysBetween(from, to) {
    return Math.round((Date.parse(`${to}T00:00:00.000Z`) - Date.parse(`${from}T00:00:00.000Z`)) / DAY_MS);
  }

  /** First instant (ISO) of a task day: 05:00 Taipei = 21:00 UTC the day before. */
  function dayStartIso(day) {
    return new Date(Date.parse(`${day}T00:00:00.000Z`) - 3 * 60 * 60 * 1000).toISOString();
  }

  // ---------- receipts ----------

  /**
   * The player's own valid receipts, with superseded ones removed: when the
   * Cloud corrects a receipt, the new one names the old one in
   * `correctionOfReceiptId` and only the newest counts.
   */
  function confirmedReceipts(raw, userId, now) {
    const nowMs = new Date(now).getTime();
    if (!userId || !Number.isFinite(nowMs)) return [];
    const seen = new Set();
    const valid = (Array.isArray(raw) ? raw : []).filter(r => {
      if (!r || typeof r.receiptId !== 'string' || !r.receiptId || r.actorUserId !== userId) return false;
      if (seen.has(r.receiptId) || !ACTIVITY_TYPES.includes(r.activityType)) return false;
      if (typeof r.acceptedMetric !== 'number' || !Number.isFinite(r.acceptedMetric) || r.acceptedMetric < 0) return false;
      const at = typeof r.verifiedAt === 'string' ? Date.parse(r.verifiedAt) : NaN;
      if (!Number.isFinite(at) || at > nowMs) return false;
      seen.add(r.receiptId);
      return true;
    });
    const superseded = new Set(valid.map(r => r.correctionOfReceiptId).filter(id => typeof id === 'string' && id));
    return valid
      .filter(r => !superseded.has(r.receiptId))
      .map(r => ({ receiptId: r.receiptId, activityType: r.activityType, metric: r.acceptedMetric,
        verifiedAt: r.verifiedAt, day: taskDayKey(r.verifiedAt) }));
  }

  function matches(template, receipt) {
    return template.types.includes(receipt.activityType) && receipt.metric >= template.minMetric;
  }

  // ---------- chains ----------

  function deadlineOf(chain, template) {
    return addDays(chain.startDay, template.windowDays - 1);
  }

  /**
   * Progress of one chain.
   * Returns { status, stamps, target, run, restarts, brokenOn, completedDay,
   *           deadline, daysLeft, stampDays }
   * status: 'active' | 'completed' | 'expired' | 'unreachable'
   */
  function chainProgress(chain, receipts, now) {
    const template = templateById(chain && chain.templateId);
    const today = taskDayKey(now);
    if (!template || !today || !isDayKey(chain.startDay)) return null;
    const deadline = deadlineOf(chain, template);
    const last = today < deadline ? today : deadline;
    const inWindow = (receipts || []).filter(r => r.day && r.day >= chain.startDay && r.day <= deadline && matches(template, r));
    const byDay = new Map();
    for (const r of inWindow) byDay.set(r.day, (byDay.get(r.day) || 0) + 1);

    let run = 0;
    let restarts = 0;
    let brokenOn = null;
    let completedDay = null;
    let stampDays = [];

    if (template.kind === 'streak') {
      for (let day = chain.startDay; day <= last; day = addDays(day, 1)) {
        if (byDay.has(day)) {
          run += 1;
          stampDays.push(day);
          if (run >= template.target) { completedDay = day; break; }
        } else if (day < today && run > 0) {
          // A finished day without a stamp breaks the streak.
          restarts += 1;
          brokenOn = day;
          run = 0;
          stampDays = [];
        }
      }
    } else {
      const days = [...byDay.keys()].sort();
      if (template.unit === 'day') {
        for (const day of days) {
          if (stampDays.length >= template.target) break;
          stampDays.push(day);
        }
      } else {
        const ordered = inWindow.slice().sort((a, b) => a.verifiedAt.localeCompare(b.verifiedAt));
        for (const r of ordered) {
          if (stampDays.length >= template.target) break;
          stampDays.push(r.day);
        }
      }
      run = stampDays.length;
      if (run >= template.target) completedDay = stampDays[stampDays.length - 1];
    }

    const stamps = completedDay ? template.target : run;
    const todayStamped = byDay.has(today);
    // Days still open for a new stamp (today counts if it has none yet).
    const openDays = today > deadline ? 0 : daysBetween(today, deadline) + (todayStamped ? 0 : 1);
    let status = 'active';
    if (completedDay) status = 'completed';
    else if (today > deadline) status = 'expired';
    else if (template.unit === 'day' || template.kind === 'streak') {
      if (stamps + openDays < template.target) status = 'unreachable';
    }
    return {
      status, stamps, target: template.target, run, restarts, brokenOn, completedDay, deadline,
      daysLeft: today > deadline ? 0 : daysBetween(today, deadline) + 1, stampDays,
    };
  }

  function newChainId(templateId, startDay, attempt) {
    return `${templateId}:${startDay}:${attempt}`;
  }

  /** Create a chain from a template. Throws a player-readable Error when not allowed. */
  function createChain(templateId, now, existing) {
    const template = templateById(templateId);
    if (!template) throw new Error('找不到這個委託範本。');
    const today = taskDayKey(now);
    if (!today) throw new Error('無法判斷今天的日期。');
    const chains = Array.isArray(existing) ? existing : [];
    const active = chains.filter(c => !c.closed);
    if (active.some(c => c.templateId === templateId)) throw new Error('這條委託已經在進行中。');
    if (active.length >= MAX_ACTIVE) throw new Error(`同時最多進行 ${MAX_ACTIVE} 條委託，先完成或放下一條吧。`);
    const attempt = chains.filter(c => c.templateId === templateId).length + 1;
    return Object.freeze({ id: newChainId(templateId, today, attempt), templateId, startDay: today, attempt, closed: false });
  }

  /**
   * Restart a chain that can no longer finish (expired or unreachable) from
   * today. A finished or still-reachable chain is returned unchanged.
   */
  function restartChain(chain, progress, now) {
    const today = taskDayKey(now);
    if (!chain || !progress || !today) return chain;
    if (progress.status !== 'expired' && progress.status !== 'unreachable') return chain;
    const attempt = (Number(chain.attempt) || 1) + 1;
    return Object.freeze({ ...chain, id: newChainId(chain.templateId, today, attempt), startDay: today, attempt, closed: false });
  }

  function certificateFor(chain, progress) {
    const template = templateById(chain && chain.templateId);
    if (!template || !progress || progress.status !== 'completed') return null;
    return Object.freeze({
      id: chain.id, templateId: template.id, title: template.title,
      startDay: chain.startDay, completedDay: progress.completedDay, stamps: progress.target,
    });
  }

  /** Earliest task-day start that any open chain needs receipts from. */
  function receiptWindowStart(chains, now) {
    const today = taskDayKey(now);
    const starts = (chains || []).filter(c => !c.closed && isDayKey(c.startDay)).map(c => c.startDay);
    return dayStartIso(starts.length ? starts.sort()[0] : today);
  }

  // ---------- local store (per account) ----------

  function normalizeStore(raw) {
    const out = { chains: [], certificates: [], seenStamps: {} };
    if (!raw || typeof raw !== 'object') return out;
    const ids = new Set();
    for (const c of Array.isArray(raw.chains) ? raw.chains : []) {
      if (!c || typeof c.id !== 'string' || ids.has(c.id) || !templateById(c.templateId) || !isDayKey(c.startDay)) continue;
      ids.add(c.id);
      out.chains.push({ id: c.id, templateId: c.templateId, startDay: c.startDay,
        attempt: Number.isSafeInteger(c.attempt) && c.attempt > 0 ? c.attempt : 1, closed: c.closed === true });
    }
    out.chains = out.chains.slice(-40);
    const certIds = new Set();
    for (const c of Array.isArray(raw.certificates) ? raw.certificates : []) {
      const template = c && templateById(c.templateId);
      if (!template || typeof c.id !== 'string' || certIds.has(c.id) || !isDayKey(c.completedDay) || !isDayKey(c.startDay)) continue;
      certIds.add(c.id);
      out.certificates.push({ id: c.id, templateId: template.id, title: template.title,
        startDay: c.startDay, completedDay: c.completedDay, stamps: template.target });
    }
    out.certificates = out.certificates.slice(-MAX_CERTIFICATES);
    if (raw.seenStamps && typeof raw.seenStamps === 'object') {
      for (const [id, value] of Object.entries(raw.seenStamps)) {
        if (ids.has(id) && Number.isSafeInteger(value) && value >= 0 && value <= 30) out.seenStamps[id] = value;
      }
    }
    return out;
  }

  /** Add certificates for newly completed chains; returns { store, earned }. */
  function collectCertificates(store, progressById) {
    const have = new Set(store.certificates.map(c => c.id));
    const earned = [];
    for (const chain of store.chains) {
      const cert = certificateFor(chain, progressById[chain.id]);
      if (cert && !have.has(cert.id)) { earned.push(cert); have.add(cert.id); }
    }
    if (!earned.length) return { store, earned };
    return { store: { ...store, certificates: [...store.certificates, ...earned].slice(-MAX_CERTIFICATES) }, earned };
  }

  // ---------- townsfolk request (鎮民的請託) ----------

  const TOWNSFOLK = Object.freeze([
    { id: 'olly', name: '歐莉', role: '告示板管理員', portrait: 'assets/town/guide.png',
      line: t => `今天能幫我一個忙嗎？「${t}」，慢慢來就好。` },
    { id: 'baker', name: '麵包師阿穗', role: '麵包店老闆', portrait: 'assets/avatar/characters/character_1.png',
      line: t => `烤爐熱好了！在等麵包的時候，你要不要先做「${t}」？` },
    { id: 'keeper', name: '燈塔守衛諾亞', role: '夜間守衛', portrait: 'assets/avatar/characters/character_2.png',
      line: t => `天黑前我會一直點著燈。你今天的那一盞是「${t}」吧？` },
    { id: 'gardener', name: '園丁小芽', role: '花園照顧者', portrait: 'assets/avatar/characters/character_3.png',
      line: t => `花要一點一點長。今天就從「${t}」開始，好嗎？` },
    { id: 'post', name: '郵差米洛', role: '小鎮郵差', portrait: 'assets/avatar/characters/character_4.png',
      line: t => `我這裡有一封寫給你的委託：「${t}」。完成了記得在清單打勾喔。` },
  ]);

  const AUTO_SOURCES = new Set(['sleepHours', 'steps', 'exerciseMinutes', 'focusMinutes', 'studyRoom']);

  function hash(text) {
    // FNV-1a, 32-bit: stable across browsers and Node.
    let h = 0x811c9dc5;
    for (let i = 0; i < text.length; i += 1) {
      h ^= text.charCodeAt(i);
      h = Math.imul(h, 0x01000193) >>> 0;
    }
    return h >>> 0;
  }

  /** The player's own tasks that belong to today (fixed daily ones and deadlines due today). */
  function todaysTasks(tasks, userId, now) {
    const today = taskDayKey(now);
    if (!today || !userId) return [];
    const seen = new Set();
    return (Array.isArray(tasks) ? tasks : []).filter(task => {
      if (!task || typeof task !== 'object' || typeof task.id !== 'string' || !task.id || seen.has(task.id)) return false;
      if (task.userId !== undefined && task.userId !== userId) return false;
      if (typeof task.title !== 'string' || !task.title.trim()) return false;
      if (task.isAutoTracked === true || AUTO_SOURCES.has(task.sourceType)) return false;
      if (task.taskType === 'deadline' && taskDayKey(task.dueDate) !== today) return false;
      seen.add(task.id);
      return true;
    });
  }

  /**
   * Today's request: one of the player's own tasks for today, told by a
   * townsperson. Same task and speaker all day (rendezvous hash on uid, day
   * and task id), so ticking other tasks does not reshuffle it.
   * Returns null when there is no task for today.
   */
  function townsfolkRequest(tasks, userId, now) {
    const today = taskDayKey(now);
    const pool = todaysTasks(tasks, userId, now);
    if (!pool.length) return null;
    let best = null;
    let bestScore = -1;
    for (const task of pool) {
      const score = hash(`${userId}|${today}|${task.id}`);
      if (score > bestScore) { best = task; bestScore = score; }
    }
    const npc = TOWNSFOLK[hash(`${userId}|${today}|npc`) % TOWNSFOLK.length];
    const title = best.title.trim().slice(0, 80);
    return {
      day: today, taskId: best.id, taskTitle: title,
      done: best.isDone === true || best.done === true,
      npc: { id: npc.id, name: npc.name, role: npc.role, portrait: npc.portrait },
      line: npc.line(title),
    };
  }

  return Object.freeze({
    TEMPLATES, MAX_ACTIVE, TOWNSFOLK,
    templateById, taskDayKey, isDayKey, addDays, daysBetween, dayStartIso,
    confirmedReceipts, chainProgress, createChain, restartChain, certificateFor,
    receiptWindowStart, normalizeStore, collectCertificates, todaysTasks, townsfolkRequest,
  });
});
