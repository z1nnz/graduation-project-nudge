(function(root,factory){const api=factory();if(typeof module==='object'&&module.exports)module.exports=api;else root.NudgeShareCardCore=api;})(typeof globalThis!=='undefined'?globalThis:this,function(){
  'use strict';
  const DAY=86400000,SHIFT=10800000;
  const dayKey=value=>new Date(new Date(value).getTime()+SHIFT).toISOString().slice(0,10);
  function weekRange(now){const endDay=dayKey(now),endMidnight=Date.parse(endDay+'T00:00:00.000Z');return {start:new Date(endMidnight-6*DAY-SHIFT).toISOString(),end:new Date(endMidnight+DAY-SHIFT).toISOString(),endDay};}
  function week(rows,now){
    const range=weekRange(now),seen=new Set(),days=[];
    for(let back=6;back>=0;back--){const date=new Date(Date.parse(range.endDay+'T00:00:00Z')-back*DAY).toISOString().slice(0,10);days.push({date,focus:0,quests:0});}
    for(const r of rows){if(!r||seen.has(r.id)||!Number.isFinite(r.value)||r.value<0||!Number.isFinite(Date.parse(r.endedAt)))continue;seen.add(r.id);const d=days.find(d=>d.date===dayKey(r.endedAt));if(!d)continue;if(['focus','study'].includes(r.type))d.focus+=r.value;if(r.type==='task'&&r.value===1)d.quests++;}
    const totalFocus=days.reduce((n,d)=>n+d.focus,0),quests=days.reduce((n,d)=>n+d.quests,0),activeDays=days.filter(d=>d.focus>0||d.quests>0).length;
    const best=days.reduce((best,d)=>d.focus>(best?.focus||0)?d:best,null);
    return {days,totalFocus,quests,activeDays,bestDay:best?.date||null};
  }
  function nickname(value){const s=typeof value==='string'?value.trim().replace(/[\u0000-\u001f\u007f]/g,'').slice(0,24):'';return !s||s.includes('@')?'小鎮旅人':s;}
  // Return only drawable fields. Account ids, email, roles, family and groups
  // cannot pass through, even if supplied on the source profile.
  function card({kind='weekly',profile={},summary,badge,visible={}}){
    if(!['weekly','achievement'].includes(kind))throw Error('Invalid card kind');
    const index=profile.avatarProfile?.faceShapeIndex;
    const result={kind,width:1080,height:1350,nickname:nickname(profile.nickname),character:Number.isInteger(index)&&index>=0&&index<18&&index!==11?index:null};
    if(kind==='achievement'){
      if(!badge?.unlocked||typeof badge.name!=='string'||!/^\d{4}-\d{2}-\d{2}$/.test(badge.unlockedAt)||!Number.isInteger(badge.icon)||badge.icon<0||badge.icon>23)throw Error('Cloud-unlocked badge required');
      return {...result,badge:{name:badge.name.slice(0,40),date:visible.badgeDate===false?null:badge.unlockedAt,icon:badge.icon}};
    }
    if(!summary||summary.days?.length!==7)throw Error('A complete confirmed week is required');
    const focus=visible.focus!==false,quests=visible.quests!==false,maxFocus=Math.max(1,...summary.days.map(d=>d.focus));
    return {...result,days:summary.days.map(d=>({date:d.date,focus:focus?d.focus:null,quests:quests?d.quests:null,books:focus?(d.focus===0?0:Math.min(8,Math.max(1,Math.floor(1+7*d.focus/maxFocus)))):null})),
      totalFocus:focus?summary.totalFocus:null,quests:quests?summary.quests:null,bestDay:focus&&visible.bestDay!==false?summary.bestDay:null,
      companion:visible.companion===false?null:focus&&quests?(summary.activeDays===0?'新的冒險隨時可以開始！':summary.activeDays===7?'這週每一天都有前進！':`這週有 ${summary.activeDays} 天一起前進。`):'每一個小行動，都值得溫柔記下。'};
  }
  function layout(){return {width:1080,height:1350,padding:72,character:{x:720,y:310,w:256,h:384},daySlots:Array.from({length:7},(_,i)=>({x:80+i*132,y:780,w:128,h:300})),footerY:1240};}
  return Object.freeze({dayKey,weekRange,week,nickname,card,layout});
});
