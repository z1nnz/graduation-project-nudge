(function (root, factory) {
  const api = factory(root.NudgeStoryChaptersCore || (typeof require === 'function' ? require('./story_chapters_core.js') : null));
  if (typeof module === 'object' && module.exports) module.exports = api;
  root.NudgeSeasonalEventCore = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function (story) {
  'use strict';
  const SEASONS = Object.freeze([
    { id: 'winter', title: '冬夜點燈祭', subtitle: '寒冷的路上，也能點亮一盞小燈。', color: '#9dcde2' },
    { id: 'spring', title: '春芽探險季', subtitle: '新芽從每天的小行動開始。', color: '#a7d98c' },
    { id: 'summer', title: '夏日星泉祭', subtitle: '在陽光下找到自己的節奏。', color: '#f7c36c' },
    { id: 'autumn', title: '秋風收穫節', subtitle: '把走過的每一步收藏在季節裡。', color: '#eaa36c' },
  ]);
  const STATIONS = Object.freeze([
    { id: 'gate', name: '季節入口', requiredDays: 0 },
    { id: 'garden', name: '微光花園', requiredDays: 3 },
    { id: 'observatory', name: '星光觀景台', requiredDays: 7 },
  ]);
  function seasonFor(now) {
    const parts = new Intl.DateTimeFormat('en-US', { timeZone: 'Asia/Taipei', year: 'numeric', month: 'numeric' }).formatToParts(now);
    const year = Number(parts.find(item => item.type === 'year')?.value);
    const month = Number(parts.find(item => item.type === 'month')?.value);
    if (!Number.isInteger(year) || !Number.isInteger(month) || month < 1 || month > 12) return null;
    const index = Math.floor((month % 12) / 3);
    return { ...SEASONS[index], key: `${month === 12 ? year + 1 : year}-${SEASONS[index].id}` };
  }
  function progress(receipts, uid, now = new Date()) {
    const season = seasonFor(now);
    const actions = story.verifiedActions(receipts, uid, now);
    const days = new Set(actions.map(action => story.taskDayKey(action.verifiedAt))).size;
    return { season, days, actions: actions.length,
      stations: STATIONS.map(station => ({ ...station, unlocked: days >= station.requiredDays })) };
  }
  return { SEASONS, STATIONS, seasonFor, progress };
});
