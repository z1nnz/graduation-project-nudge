(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.NudgePlanetCore = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';
  // Pure rules for the discipline planet page (planet.html, #82 slice 3).
  //
  // The planet shows only the signed-in account's own users/{uid} record.
  // `unlockedPlanets` names real unlocks. Older accounts may only have
  // `planetCount`; that count is real, but which kinds of planets it meant was
  // never recorded, so the Web shows that many plain planets and says so
  // instead of inventing kinds (the old page filled names from a fixed pool).

  const BASE = '新手星球';
  const COLORS = Object.freeze({
    綠洲星球: '#34d399', 熔岩星球: '#ef4444', 冰雪星球: '#60a5fa',
    沙漠星球: '#fbbf24', 水晶星球: '#a78bfa', 暗物質星球: '#8b5cf6',
  });
  const PLAIN = '#cbd5e1';
  const MAX_SHOWN = 24;

  function planets(data) {
    if (Array.isArray(data?.unlockedPlanets)) {
      const named = data.unlockedPlanets.filter(p => typeof p === 'string' && p.trim() && p !== BASE);
      return {
        source: 'named',
        count: named.length,
        nodes: named.slice(0, MAX_SHOWN).map(name => ({ name, color: COLORS[name] || PLAIN })),
        note: named.length ? '' : '還沒有解鎖新的星球。完成雲端確認的任務與專注，星系會慢慢長出來。',
      };
    }
    const count = Number(data?.planetCount);
    if (Number.isSafeInteger(count) && count > 0) {
      return {
        source: 'count',
        count,
        nodes: Array.from({ length: Math.min(count, MAX_SHOWN) }, () => ({ name: '星球（類型未記錄）', color: PLAIN })),
        note: `舊版紀錄顯示你有 ${count} 顆星球；當時沒有記錄星球類型，所以這裡用同一種外觀顯示。`,
      };
    }
    return { source: 'none', count: 0, nodes: [], note: '還沒有解鎖新的星球。完成雲端確認的任務與專注，星系會慢慢長出來。' };
  }

  return Object.freeze({ planets, BASE, COLORS, MAX_SHOWN });
});
