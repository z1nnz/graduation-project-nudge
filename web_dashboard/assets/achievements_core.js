(function(root,factory){const api=factory();if(typeof module==='object'&&module.exports)module.exports=api;else root.NudgeAchievementsCore=api;})(typeof globalThis!=='undefined'?globalThis:this,function(){
  'use strict';
  // Presentation tiers only; unlocks and dates come from the existing App field.
  const definitions=[
    ['task_starter','任務起步者','完成第一個任務','common',0],['focus_beginner','專注新手','累積專注 25 分鐘','common',1],
    ['health_sync','健康同步者','連結健康資料','common',7],['room_joiner','自律房參與者','加入一個自律房','common',13],
    ['focus_streak','專注連續者','連續 3 天有專注','uncommon',5],['task_streak','任務連續者','連續 3 天完成任務','uncommon',6],
    ['sleep_guard','睡眠守護者','最近 7 筆日摘要有 3 天睡滿 7 小時','uncommon',3],['step_master','步數達人','最近 7 筆日摘要有 3 天達 8,000 步','uncommon',2],
    ['auto_tracker','自動追蹤者','最近 7 筆日摘要自動追蹤完成 5 次','uncommon',15],['health_task','健康任務實踐者','最近 7 筆日摘要健康任務完成 5 次','uncommon',8],
    ['steady_progress','穩定前進','最近 7 筆日摘要有 3 天分數達 70','rare',9],['score_keeper','高分維持','最近 7 筆日摘要平均分數達 70','rare',10],
    ['coin_earner','門檻達人','最近 7 筆日摘要累積獲得 80 金幣','rare',20],['room_focus','自律房推進者','自律房累積專注 120 分鐘','rare',17],
    ['room_leader','房內領先者','在任一自律房的專注紀錄領先','legendary',11],['room_social','活躍自律房','參與成員至少 3 人的自律房','legendary',23],
  ].map(([key,name,condition,rarity,icon])=>Object.freeze({key,name,condition,rarity,icon}));
  const tiers=Object.freeze({common:'普通',uncommon:'少見',rare:'稀有',legendary:'傳說'});
  function date(value,now=Date.now()){
    if(typeof value!=='string'||!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?(?:Z|[+-]\d{2}:\d{2})?$/.test(value))return null;
    const [y,m,d]=value.slice(0,10).split('-').map(Number),ms=Date.parse(value);
    if(m<1||m>12||d<1||d>new Date(Date.UTC(y,m,0)).getUTCDate()||!Number.isFinite(ms)||ms>now)return null;
    return value.slice(0,10);
  }
  function records(data,now){const dates=data?.unlockedBadgeDates;return definitions.map(d=>{const unlockedAt=date(dates&&typeof dates==='object'&&!Array.isArray(dates)?dates[d.key]:null,now);return {...d,unlockedAt,unlocked:!!unlockedAt};});}
  function canEquip(data,key,now){return records(data,now).some(r=>r.key===key&&r.unlocked);}
  return Object.freeze({definitions,tiers,date,records,canEquip});
});
