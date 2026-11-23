(function (root) {
  'use strict';

  const DAY_MS = 24 * 60 * 60 * 1000;
  const WINDOW_DAYS = 28;
  const MILESTONES = Object.freeze([
    { id: 'first-light', title: '點亮第一盞燈', requiredDays: 1 },
    { id: 'small-path', title: '走出一條小徑', requiredDays: 3 },
    { id: 'star-road', title: '抵達星光路口', requiredDays: 7 },
  ]);

  function taipeiParts(value) {
    const date = value instanceof Date ? value : new Date(value);
    if (!Number.isFinite(date.getTime())) return null;
    const parts = new Intl.DateTimeFormat('en-US', {
      timeZone: 'Asia/Taipei', year: 'numeric', month: '2-digit', day: '2-digit',
    }).formatToParts(date);
    const item = key => Number(parts.find(part => part.type === key)?.value);
    return { year: item('year'), month: item('month'), day: item('day') };
  }

  // Nudge's task day rolls over at 05:00 Asia/Taipei.
  function taskDayKey(value) {
    const instant = new Date(value);
    if (!Number.isFinite(instant.getTime())) return null;
    const parts = taipeiParts(new Date(instant.getTime() - 5 * 60 * 60 * 1000));
    if (!parts) return null;
    return `${parts.year}-${String(parts.month).padStart(2, '0')}-${String(parts.day).padStart(2, '0')}`;
  }

  function windowStart(now = new Date()) {
    const today = taskDayKey(now);
    if (!today) return null;
    const day = new Date(`${today}T00:00:00.000Z`);
    day.setUTCDate(day.getUTCDate() - WINDOW_DAYS + 1);
    // The first included task day begins at 05:00 Asia/Taipei (previous UTC day at 21:00).
    return new Date(day.getTime() - 3 * 60 * 60 * 1000).toISOString();
  }

  function verifiedActions(rawReceipts, userId, now = new Date()) {
    const nowMs = new Date(now).getTime();
    const firstDay = taskDayKey(windowStart(now));
    if (!Number.isFinite(nowMs) || !firstDay || !userId) return [];
    const seen = new Set();
    return (rawReceipts || []).filter(receipt => {
      if (!receipt || !receipt.receiptId || receipt.actorUserId !== userId ||
          seen.has(receipt.receiptId) || !Number.isFinite(receipt.acceptedMetric) ||
          receipt.acceptedMetric <= 0 || !['task', 'focus', 'study', 'exercise', 'steps', 'sleep'].includes(receipt.activityType)) return false;
      const at = new Date(receipt.verifiedAt).getTime();
      const day = taskDayKey(receipt.verifiedAt);
      if (!Number.isFinite(at) || at > nowMs || !day || day < firstDay || day > taskDayKey(now)) return false;
      seen.add(receipt.receiptId);
      return true;
    }).sort((a, b) => b.verifiedAt.localeCompare(a.verifiedAt));
  }

  function progress(rawReceipts, userId, now = new Date()) {
    const actions = verifiedActions(rawReceipts, userId, now);
    const days = [...new Set(actions.map(item => taskDayKey(item.verifiedAt)))];
    const chapters = MILESTONES.map((chapter, index) => ({
      ...chapter,
      unlocked: days.length >= (index === 0 ? 0 : MILESTONES[index - 1].requiredDays),
      completed: days.length >= chapter.requiredDays,
      currentDays: Math.min(days.length, chapter.requiredDays),
    }));
    return { actions: actions.length, days: days.length, chapters, latestAt: actions[0]?.verifiedAt || null };
  }

  const api = { MILESTONES, WINDOW_DAYS, taskDayKey, windowStart, verifiedActions, progress };
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.NudgeStoryChaptersCore = api;
})(typeof globalThis !== 'undefined' ? globalThis : this);
