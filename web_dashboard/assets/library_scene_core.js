(function (root, factory) {
  const api = factory();
  if (typeof module === "object" && module.exports) module.exports = api;
  else root.NudgeLibrarySceneCore = api;
})(typeof globalThis !== "undefined" ? globalThis : this, function () {
  "use strict";
  const DAY = 86400000,
    SHIFT = 10800000;
  const key = (ms) => new Date(ms + SHIFT).toISOString().slice(0, 10);
  function range(now, count = 12) {
    if (!Number.isInteger(count) || count < 1 || count > 52)
      throw Error("Invalid shelf size");
    const ms = new Date(now).getTime();
    if (!Number.isFinite(ms)) throw Error("Invalid time");
    const logical = new Date(ms + SHIFT),
      today = Date.parse(key(ms) + "T00:00:00Z") - SHIFT,
      monday = today - ((logical.getUTCDay() + 6) % 7) * DAY;
    return {
      start: new Date(monday - (count - 1) * 7 * DAY).toISOString(),
      end: new Date(ms).toISOString(),
      monday,
      count,
    };
  }
  function shelf(rows, now, count = 12) {
    const r = range(now, count),
      unique = new Map();
    for (const row of rows) {
      if (
        !row ||
        typeof row.id !== "string" ||
        !row.id ||
        unique.has(row.id) ||
        !["focus", "study", "exercise", "steps", "sleep", "task"].includes(
          row.type,
        ) ||
        !Number.isFinite(row.value) ||
        row.value < 0 ||
        !Number.isFinite(Date.parse(row.endedAt)) ||
        row.endedAt < r.start ||
        row.endedAt > r.end
      )
        continue;
      unique.set(row.id, row);
    }
    const books = [];
    for (let i = 0; i < count; i++) {
      const start = r.monday - (count - 1 - i) * 7 * DAY,
        days = [];
      for (let d = 0; d < 7; d++) {
        const date = key(start + d * DAY),
          daily = [...unique.values()].filter(
            (row) => key(Date.parse(row.endedAt)) === date,
          ),
          sum = (types) =>
            daily
              .filter((row) => types.includes(row.type))
              .reduce((n, row) => n + row.value, 0);
        days.push({
          date,
          focus: sum(["focus", "study"]),
          sleep: sum(["sleep"]),
          steps: sum(["steps"]),
          exercise: sum(["exercise"]),
          tasks: sum(["task"]),
          recorded: daily.length > 0,
        });
      }
      const sum = (k) => days.reduce((n, d) => n + d[k], 0),
        focus = sum("focus"),
        exercise = sum("exercise"),
        tasks = sum("tasks");
      books.push({
        start: days[0].date,
        end: days[6].date,
        days,
        focus,
        sleep: sum("sleep"),
        steps: sum("steps"),
        exercise,
        tasks,
        empty: days.every((d) => !d.recorded),
        thickness: Math.min(
          42,
          18 + Math.floor(focus / 60 + exercise / 30 + tasks) * 2,
        ),
      });
    }
    const maxima = Object.fromEntries(
      ["focus", "sleep", "steps"].map((k) => [
        k,
        Math.max(1, ...books.map((b) => b[k])),
      ]),
    );
    return { books, maxima, range: r };
  }
  return Object.freeze({ range, shelf });
});
