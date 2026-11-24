(function(root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  root.NudgeTownHudCore = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function() {
  'use strict';
  const required = level => {
    const offset = Math.max(0, Math.min(59, level - 1));
    return Math.round(5.454899668809663 * offset * offset + 186.63549581141635 * offset);
  };
  function progress(level, experience) {
    if (!Number.isSafeInteger(level) || level < 1 || !Number.isSafeInteger(experience) || experience < 0) return null;
    const start = required(level), end = required(Math.min(60, level + 1));
    return { level, experience, fraction: level >= 60 ? 1 :
      Math.max(0, Math.min(1, (experience - start) / (end - start))),
      remaining: level >= 60 ? 0 : Math.max(0, end - experience) };
  }
  function quests(tasks, resolve) {
    const pending = (Array.isArray(tasks) ? tasks : [])
      .filter(t => t && typeof t.title === 'string' && t.title.trim() &&
        t.taskType !== 'deadline' && t.done !== true && t.isDone !== true)
      .slice(0, 3).map(t => t.title.trim());
    return { next: resolve?.(tasks)?.title || '安排今天的一小步', pending };
  }
  function taipeiKey(value) {
    const date = value?.toDate?.() || new Date(value);
    if (!Number.isFinite(date.getTime())) return null;
    const parts = new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Taipei', year: 'numeric',
      month: '2-digit', day: '2-digit' }).formatToParts(date);
    const part = name => parts.find(p => p.type === name)?.value;
    return `${part('year')}-${part('month')}-${part('day')}`;
  }
  function streak(receipts, now, capped = false) {
    const keys = new Set((Array.isArray(receipts) ? receipts : [])
      .map(r => taipeiKey(r?.verifiedAt)).filter(Boolean));
    const today = taipeiKey(now);
    const date = new Date(`${today}T00:00:00Z`);
    if (!keys.has(today)) date.setUTCDate(date.getUTCDate() - 1);
    let count = 0;
    while (keys.has(date.toISOString().slice(0, 10)) && count < 366) {
      count++;
      date.setUTCDate(date.getUTCDate() - 1);
    }
    return { count, lowerBound: capped && count > 0 && count === keys.size };
  }
  function unread(letters) {
    return (Array.isArray(letters) ? letters : []).filter(x => x?.status === 'unread').length;
  }
  return { progress, quests, streak, unread, required };
});
