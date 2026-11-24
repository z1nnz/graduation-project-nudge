(function(root,factory){
  const api=factory();
  if(typeof module==='object'&&module.exports)module.exports=api;else root.NudgeYearbookCore=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(){
  'use strict';
  const SHIFT=3*3600000; // Asia/Taipei UTC+8, 05:00 boundary.
  function logicalDay(value){const ms=new Date(value).getTime();if(!Number.isFinite(ms))throw Error('Invalid timestamp');return new Date(ms+SHIFT).toISOString().slice(0,10);}
  function monthRange(year,month){
    if(!Number.isInteger(year)||year<2000||year>9998||!Number.isInteger(month)||month<1||month>12)throw Error('Invalid month');
    return {start:new Date(Date.UTC(year,month-1,1)-SHIFT).toISOString(),end:new Date(Date.UTC(year,month,1)-SHIFT).toISOString()};
  }
  function totals(rows){const sum=types=>rows.filter(r=>types.includes(r.type)).reduce((n,r)=>n+r.value,0);return {focus:sum(['focus','study']),exercise:sum(['exercise']),sleep:sum(['sleep']),tasks:sum(['task'])};}
  // Authenticated, hash-validated, server-confirmed session rows only. Monday
  // weeks crossing months are split; each logical day belongs to one chapter.
  function chapter(rows,year,month){
    const range=monthRange(year,month),unique=new Map();
    for(const r of rows){
      if(!r||typeof r.id!=='string'||!r.id||!['focus','study','exercise','sleep','task','steps'].includes(r.type)||!Number.isFinite(r.value)||r.value<0||!Number.isFinite(Date.parse(r.endedAt)))continue;
      if(r.endedAt>=range.start&&r.endedAt<range.end)unique.set(r.id,r);
    }
    const days=[],weeks=[],count=new Date(Date.UTC(year,month,0)).getUTCDate();
    for(let date=1;date<=count;date++){
      const utc=Date.UTC(year,month-1,date),key=new Date(utc).toISOString().slice(0,10),sessions=[...unique.values()].filter(r=>logicalDay(r.endedAt)===key);
      const entry={key,rows:sessions,totals:totals(sessions)};days.push(entry);
      if(!weeks.length||new Date(utc).getUTCDay()===1)weeks.push({days:[]});weeks[weeks.length-1].days.push(entry);
    }
    for(const w of weeks){w.start=w.days[0].key;w.end=w.days[w.days.length-1].key;w.rows=w.days.flatMap(d=>d.rows);w.empty=!w.rows.length;w.totals=totals(w.rows);}
    return {year,month,range,days,weeks};
  }
  function pageIndex(value,length){return Math.max(0,Math.min(Math.max(0,length-1),Math.trunc(Number(value)||0)));}
  return Object.freeze({logicalDay,monthRange,totals,chapter,pageIndex});
});
