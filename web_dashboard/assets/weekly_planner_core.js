(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  root.NudgeWeeklyPlannerCore = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';
  const formatter = new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Taipei', year: 'numeric', month: '2-digit', day: '2-digit' });
  function taipeiDay(now) {
    const parts = Object.fromEntries(formatter.formatToParts(now).map(part => [part.type, part.value]));
    return `${parts.year}-${parts.month}-${parts.day}`;
  }
  function addDays(day, count) {
    const date = new Date(`${day}T00:00:00Z`);
    date.setUTCDate(date.getUTCDate() + count);
    return date.toISOString().slice(0, 10);
  }
  function weekStart(now) {
    const day = taipeiDay(now);
    const weekday = new Date(`${day}T00:00:00Z`).getUTCDay();
    return addDays(day, -(weekday + 6) % 7);
  }
  function weekDays(start) { return Array.from({ length: 7 }, (_, i) => addDays(start, i)); }
  function availableTasks(tasks, uid) {
    if (!Array.isArray(tasks)) return [];
    const seen = new Set();
    return tasks.filter(task => {
      if (!task || typeof task.id !== 'string' || !task.id || task.userId !== uid ||
          typeof task.title !== 'string' || !task.title.trim() || task.isDone || task.done || seen.has(task.id)) return false;
      seen.add(task.id);
      return true;
    });
  }
  function normalizeSlots(raw, taskIds, start) {
    const ids = new Set(taskIds);
    const days = new Set(weekDays(start));
    const seen = new Set();
    const result = {};
    if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return result;
    for (const [day, entries] of Object.entries(raw)) {
      if (!days.has(day) || !Array.isArray(entries)) continue;
      result[day] = entries.filter(id => {
        if (typeof id !== 'string' || !ids.has(id) || seen.has(id)) return false;
        seen.add(id);
        return true;
      }).slice(0, 12);
    }
    return result;
  }
  function assign(slots, id, day, start) {
    if (!weekDays(start).includes(day)) throw new Error('日期不在本週');
    const next = Object.fromEntries(Object.entries(slots).map(([key, ids]) => [key, ids.filter(item => item !== id)]));
    next[day] = [...(next[day] || []), id];
    if (next[day].length > 12) throw new Error('每天最多安排 12 個任務');
    return next;
  }
  function workload(slots, start) {
    return weekDays(start).map(day => ({ day, count: (slots[day] || []).length,
      warning: (slots[day] || []).length >= 5 }));
  }
  return { taipeiDay, addDays, weekStart, weekDays, availableTasks, normalizeSlots, assign, workload };
});
