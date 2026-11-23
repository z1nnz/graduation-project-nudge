(function(root) {
  'use strict';
  const routes = Object.freeze([
    {id:'home',file:'personal.html',label:'紀錄館',description:'翻開屬於你的成長篇章。'},
    {id:'trends',file:'personal-trends.html',label:'行動年鑑',description:'週月回顧與可追溯的活動紀錄。',feature:'review'},
    {id:'weather',file:'personal-weather.html',label:'生活天氣',description:'回顧已發生的行動，不預測你的未來。',feature:'review'},
    {id:'pressure',file:'personal-pressure.html',label:'溫柔整理',description:'整理生活節奏；這裡不評估或診斷壓力。',feature:'review'},
    {id:'skills',file:'personal-skill-tree.html',label:'技能書籤',description:'查看有依據的條件；未核定的等級不會顯示。',feature:'review'},
    {id:'strategy',file:'personal-template.html',label:'下一步工坊',description:'保存可編輯的策略，自己決定要不要行動。',feature:'tools'},
    {id:'letter',file:'personal-letter.html',label:'未來的信',description:'寫下此刻，保存、修改或帶走。',feature:'tools'},
    {id:'capsules',file:'personal-time-capsule.html',label:'時間膠囊',description:'封存一封只屬於你、到期才能讀的信。',feature:'capsules'},
  ]);
  const sources = Object.freeze({
    activity:'activity_sessions: authenticated actor, completed only; Cloud-written',
    identity:'discipline_identity_snapshots: authenticated owner; Cloud-written',
    tools:'users/{authenticated uid}/growth_documents: private owner-authored text',
    capsules:'growthCapsule callable: private server-only content, server unlock time',
    rewards:'Not derived here. Personal rewards and relationship outcomes remain separate.',
  });
  function routeFor(file) { return routes.find(r => r.file === file) || routes[0]; }
  function returnRoute(available) { return available ? 'town.html' : 'dashboard.html'; }
  const api = {routes,sources,routeFor,returnRoute};
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.NudgeGrowthMuseumCore = api;
})(typeof globalThis !== 'undefined' ? globalThis : this);
