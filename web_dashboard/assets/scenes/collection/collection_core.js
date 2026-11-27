(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.NudgeCollectionCore = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';
  // Same rule as lib/models/collection_book.dart (test/collection_web_test.js
  // keeps them equal): one keepsake per day with 25+ focus minutes, a rare
  // one on a 2-hour day, chosen by an FNV-1a hash of the date.
  const COMMON_MINUTES = 25;
  const RARE_MINUTES = 120;
  const CATALOG = Object.freeze([
    ['acorn', '橡實'], ['leaf', '楓葉書籤'], ['shell', '小貝殼'], ['pencil', '短鉛筆'], ['tea', '熱紅茶'], ['candle', '小蠟燭'],
    ['clover', '四葉草'], ['feather', '羽毛筆'], ['mushroom', '蘑菇'], ['cookie', '餅乾'], ['button', '舊鈕扣'], ['stamp', '郵票'],
    ['marble', '彈珠'], ['ribbon', '緞帶'], ['key', '小鑰匙'], ['flower', '押花'],
    ['star', '流星碎片', true], ['crown', '紙皇冠', true], ['compass', '冒險羅盤', true], ['crystal', '月光水晶', true],
    ['lantern', '燈籠', true], ['scroll', '古老卷軸', true], ['rainbow', '彩虹瓶', true], ['egg', '神秘蛋', true],
  ].map(([id, name, rare]) => Object.freeze({ id, name, rare: Boolean(rare) })));
  const commons = CATALOG.filter(k => !k.rare);
  const rares = CATALOG.filter(k => k.rare);

  function fnv1a(text) {
    let h = 0x811c9dc5;
    for (let i = 0; i < text.length; i++) {
      h ^= text.charCodeAt(i);
      h = Math.imul(h, 0x01000193) >>> 0;
    }
    return h >>> 0;
  }

  /** Drops from day summaries ({date: 'yyyy-MM-dd', focusMinutes}), newest first. */
  function drops(days) {
    const out = [];
    const seen = new Set();
    for (const d of days || []) {
      if (!d || typeof d.date !== 'string' || seen.has(d.date)) continue;
      seen.add(d.date);
      const m = Number(d.focusMinutes) || 0;
      if (m < COMMON_MINUTES) continue;
      const pool = m >= RARE_MINUTES ? rares : commons;
      out.push({ date: d.date, item: pool[fnv1a(d.date) % pool.length] });
    }
    return out.sort((a, b) => (a.date < b.date ? 1 : a.date > b.date ? -1 : 0));
  }

  return { COMMON_MINUTES, RARE_MINUTES, CATALOG, fnv1a, drops };
});
