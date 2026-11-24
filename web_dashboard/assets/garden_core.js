(function (root) {
  'use strict';
  // Pure rules for the Lv 10 starlight garden. No DOM, no writes: the garden
  // only reflects the signed-in user's own Cloud-confirmed activity
  // (activity_sessions, actorUserId = self, status = completed).
  //
  // Each plant kind grows from one activity type. Every week (Monday, with the
  // day changing at 05:00 Asia/Taipei) gets its own plant per kind, and the
  // plant's stage (1–5) comes from how much of that activity the week holds.
  // Watering is only an animation: nothing here reads or changes it.

  const MIN_LEVEL = 10;
  const DAY = 86400000;
  // Asia/Taipei is UTC+8 with no daylight saving; the logical day starts at
  // 05:00 local, i.e. UTC+3 shifted midnight.
  const LOGICAL_SHIFT = 3 * 3600000;
  const LOCAL_SHIFT = 8 * 3600000;
  const STAGES = 5;
  const WEEKS_SHOWN = 6;
  const QUERY_LIMIT = 500;

  // thresholds[i] is the weekly total needed for stage i + 1.
  const PLANTS = Object.freeze([
    plant('flower', '花', '星光花', '專注', ['focus', 'study'], 'minutes', '分鐘', 1440, [1, 25, 75, 150, 300]),
    plant('tree', '樹', '小橡樹', '運動', ['exercise'], 'minutes', '分鐘', 1440, [1, 20, 60, 120, 200]),
    plant('moonflower', '月', '月光花', '睡眠', ['sleep'], 'hours', '小時', 24, [1, 7, 21, 35, 49]),
    plant('meadow', '草', '草地', '步數', ['steps'], 'steps', '步', 200000, [1, 5000, 20000, 40000, 70000]),
  ]);

  const STAGE_NAMES = Object.freeze(['種子', '嫩芽', '花苞', '初開', '盛開']);
  const TREE_STAGE_NAMES = Object.freeze(['種子', '嫩芽', '小樹苗', '小樹', '大樹']);
  const MEADOW_STAGE_NAMES = Object.freeze(['幾根草', '一小叢', '一片草', '草地', '花草地']);

  const SEASONS = Object.freeze({
    spring: Object.freeze({ id: 'spring', name: '春天', note: '嫩綠的春天' }),
    summer: Object.freeze({ id: 'summer', name: '夏天', note: '金黃的夏日' }),
    autumn: Object.freeze({ id: 'autumn', name: '秋天', note: '琥珀色的秋天' }),
    winter: Object.freeze({ id: 'winter', name: '冬天', note: '紫色的冬夜' }),
  });

  function plant(id, short, name, verb, types, unit, unitLabel, max, thresholds) {
    return Object.freeze({
      id, short, name, verb, types: Object.freeze(types), unit, unitLabel, max,
      thresholds: Object.freeze(thresholds), sprite: `garden/${id}_stages.png`,
    });
  }

  function level(value) {
    const n = Math.floor(Number(value));
    return Number.isFinite(n) && n >= 1 ? n : 1;
  }

  /** Whether the garden is open for this level, with the text to show. */
  function access(avatarLevel) {
    const current = level(avatarLevel);
    if (current >= MIN_LEVEL) return { unlocked: true, level: current, reason: '' };
    return {
      unlocked: false,
      level: current,
      reason: `角色 Lv ${MIN_LEVEL} 才能進入星光花園，你目前是 Lv ${current}，還差 ${MIN_LEVEL - current} 級。`,
    };
  }

  function plantForType(type) {
    return PLANTS.find(p => p.types.includes(type)) || null;
  }

  function plantById(id) {
    return PLANTS.find(p => p.id === id) || null;
  }

  /** Logical day key (YYYY-MM-DD) of a moment, with 05:00 Taipei as the day change. */
  function dayKey(ms) {
    return new Date(ms + LOGICAL_SHIFT).toISOString().slice(0, 10);
  }

  /** Start (UTC ms) of the logical Monday-based week holding this moment. */
  function weekStart(ms) {
    const logical = new Date(ms + LOGICAL_SHIFT);
    const midnight = Date.UTC(logical.getUTCFullYear(), logical.getUTCMonth(), logical.getUTCDate()) - LOGICAL_SHIFT;
    return midnight - ((logical.getUTCDay() + 6) % 7) * DAY;
  }

  /** ISO week number and year of the logical week starting at `start`. */
  function weekNumber(start) {
    const monday = new Date(start + LOGICAL_SHIFT);
    const thursday = Date.UTC(monday.getUTCFullYear(), monday.getUTCMonth(), monday.getUTCDate() + 3);
    const year = new Date(thursday).getUTCFullYear();
    const week = 1 + Math.floor((thursday - Date.UTC(year, 0, 1)) / (7 * DAY));
    return { year, week };
  }

  function monthDay(ms) {
    const d = new Date(ms + LOGICAL_SHIFT);
    return `${d.getUTCMonth() + 1}/${d.getUTCDate()}`;
  }

  /** Human label for a week: "11/17–11/23". */
  function weekRange(start) {
    return `${monthDay(start)}–${monthDay(start + 6 * DAY)}`;
  }

  /** The weeks the garden shows (oldest first) and the query window for them. */
  function weekWindow(nowMs, count = WEEKS_SHOWN) {
    const now = Number(nowMs);
    if (!Number.isFinite(now)) throw new Error('A valid time is required.');
    const current = weekStart(now);
    const weeks = [];
    for (let i = count - 1; i >= 0; i -= 1) weeks.push(current - i * 7 * DAY);
    return { weeks, start: new Date(weeks[0]).toISOString(), end: new Date(now).toISOString() };
  }

  /** Season of the moment by Taipei calendar month. */
  function season(nowMs) {
    const month = new Date(Number(nowMs) + LOCAL_SHIFT).getUTCMonth() + 1;
    if (month >= 3 && month <= 5) return SEASONS.spring;
    if (month >= 6 && month <= 8) return SEASONS.summer;
    if (month >= 9 && month <= 11) return SEASONS.autumn;
    return SEASONS.winter;
  }

  const ISO = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/;
  function isIso(value) {
    return typeof value === 'string' && ISO.test(value) && Number.isFinite(Date.parse(value))
      && new Date(value).toISOString() === value;
  }

  /**
   * Validate one activity_sessions document for the garden. Returns
   * { row } for a usable session, { ignored: true } for a valid kind the
   * garden does not grow (task, custom), or null for anything malformed.
   * The caller still checks id === sha256(activityFingerprint).
   */
  function parseSession(id, data, uid, nowMs) {
    if (!data || typeof data !== 'object' || typeof id !== 'string' || !/^[a-f0-9]{64}$/.test(id)) return null;
    if (data.actorUserId !== uid || !uid || data.status !== 'completed') return null;
    if (typeof data.activitySessionId !== 'string' || !data.activitySessionId) return null;
    if (typeof data.activityFingerprint !== 'string' || !data.activityFingerprint) return null;
    if (!isIso(data.startedAt) || !isIso(data.endedAt)) return null;
    const ended = Date.parse(data.endedAt);
    if (Date.parse(data.startedAt) > ended || ended > Number(nowMs)) return null;
    if (!['app', 'web', 'device', 'health'].includes(data.source)) return null;
    if (data.activityType === 'task' || data.activityType === 'custom') return { ignored: true };
    const kind = plantForType(data.activityType);
    if (!kind) return null;
    const value = data.metricValue;
    if (data.metricUnit !== kind.unit || typeof value !== 'number' || !Number.isFinite(value) || value < 0 || value > kind.max) {
      return null;
    }
    return {
      row: {
        id, plant: kind.id, type: data.activityType, value, endedAt: data.endedAt,
        day: dayKey(ended), week: weekStart(ended), source: data.source,
      },
    };
  }

  /** Stage 0 (bare soil) to 5 for a weekly total of one plant kind. */
  function stageFor(kind, total) {
    const p = typeof kind === 'string' ? plantById(kind) : kind;
    if (!p || !(total > 0)) return 0;
    let stage = 0;
    for (const threshold of p.thresholds) if (total >= threshold) stage += 1;
    return stage;
  }

  /** What the next stage needs, or null at full growth. */
  function nextStage(kind, total) {
    const p = typeof kind === 'string' ? plantById(kind) : kind;
    const stage = stageFor(p, total);
    if (stage >= STAGES) return null;
    const need = p.thresholds[stage] - (total > 0 ? total : 0);
    return { stage: stage + 1, need: round(need) };
  }

  function round(n) {
    return Math.round(n * 10) / 10;
  }

  function stageName(kind, stage) {
    const p = typeof kind === 'string' ? plantById(kind) : kind;
    if (stage <= 0) return '空土';
    const names = p.id === 'tree' ? TREE_STAGE_NAMES : p.id === 'meadow' ? MEADOW_STAGE_NAMES : STAGE_NAMES;
    return names[Math.min(stage, STAGES) - 1];
  }

  /**
   * Build the garden: one plot per (plant kind, week), oldest week first.
   * Sessions outside the shown weeks are left out; each id counts once.
   */
  function grow(rows, weeks) {
    const seen = new Set();
    const buckets = new Map();
    for (const row of rows || []) {
      if (!row || seen.has(row.id)) continue;
      seen.add(row.id);
      const key = `${row.plant}|${row.week}`;
      if (!buckets.has(key)) buckets.set(key, []);
      buckets.get(key).push(row);
    }
    return PLANTS.map(kind => ({
      plant: kind.id,
      plots: weeks.map(week => {
        const sessions = (buckets.get(`${kind.id}|${week}`) || [])
          .slice().sort((a, b) => (a.endedAt < b.endedAt ? -1 : a.endedAt > b.endedAt ? 1 : 0));
        const total = round(sessions.reduce((sum, r) => sum + r.value, 0));
        const stage = stageFor(kind, total);
        return {
          plant: kind.id, week, total, count: sessions.length, stage,
          days: new Set(sessions.map(r => r.day)).size, sessions,
        };
      }),
    }));
  }

  /** The plot's story: which week and which action grew it. */
  function describe(plot) {
    const kind = plantById(plot.plant);
    const { week } = weekNumber(plot.week);
    const when = `第 ${week} 週（${weekRange(plot.week)}）`;
    if (!plot.stage) {
      return `${when}還沒有雲端確認的${kind.verb}紀錄，${kind.name}的位置還是空土。`;
    }
    const amount = `${formatNumber(plot.total)} ${kind.unitLabel}`;
    return `${when}由 ${plot.count} 筆雲端確認的${kind.verb}紀錄（${plot.days} 天、共 ${amount}）長出，`
      + `現在是第 ${plot.stage} 階段「${stageName(kind, plot.stage)}」。`;
  }

  function formatNumber(n) {
    return Number(n).toLocaleString('zh-Hant-TW', { maximumFractionDigits: 1 });
  }

  const api = {
    MIN_LEVEL, STAGES, WEEKS_SHOWN, QUERY_LIMIT, PLANTS, SEASONS,
    access, level, plantForType, plantById, dayKey, weekStart, weekNumber, weekRange, weekWindow,
    season, parseSession, stageFor, nextStage, stageName, grow, describe, formatNumber,
  };
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.NudgeGardenCore = api;
})(typeof globalThis !== 'undefined' ? globalThis : this);
