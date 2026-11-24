(function(root){
  'use strict';
  const {el,button,say,confirmed,connect,sessions,signedOut}=root.NudgeGrowthWorld,core=root.NudgeShareCardCore;
  const $=id=>document.getElementById(id),canvas=$('shareCanvas'),g=canvas.getContext('2d'),controls=$('shareControls');let ctx=null,profile=null,summary=null,badges=[],version=0,ready=null,url=null;
  function invalidate(){++version;ready=null;$('shareDownload').disabled=true;if(url)URL.revokeObjectURL(url);url=null;g?.clearRect(0,0,1080,1350);$('shareCaption').textContent='尚未產生預覽，沒有可下載的卡片。';}
  document.addEventListener('growth-clear',()=>{invalidate();profile=null;summary=null;badges=[];});
  controls.addEventListener('change',()=>{invalidate();$('shareWeeklyOptions').hidden=$('shareKind').value!=='weekly';$('shareBadgeOptions').hidden=$('shareKind').value!=='achievement';});
  const image=source=>new Promise((resolve,reject)=>{const img=new Image();img.onload=()=>resolve(img);img.onerror=reject;img.src=source;});
  function ink(token){return getComputedStyle(document.documentElement).getPropertyValue(token).trim();}
  function text(value,x,y,size=44,color='--w-ink-dark'){g.fillStyle=ink(color);g.font=size+'px Cubic11, sans-serif';while(size>24&&g.measureText(String(value)).width>1016-x){size-=2;g.font=size+'px Cubic11, sans-serif';}g.fillText(String(value),x,y);}
  async function preview(){
    invalidate();if(!ctx?.user||!profile||!summary||!g)return;const own=version,scope=ctx;
    try{
      const kind=$('shareKind').value,visible=Object.fromEntries([...controls.querySelectorAll('[data-share-visible]')].map(i=>[i.dataset.shareVisible,i.checked]));
      const payload=core.card({kind,profile,summary,badge:badges.find(b=>b.key===$('shareBadge').value),visible}),layout=core.layout();
      await document.fonts.load('44px Cubic11');
      const [character,trophy]=await Promise.all([payload.character===null?null:image('assets/growth/characters/character_'+payload.character+'.png'),payload.badge?image('assets/growth/trophy-'+payload.badge.icon+'.png'):null]);
      if(!scope.alive()||own!==version)return;
      g.imageSmoothingEnabled=false;g.fillStyle=ink('--w-wood-deep');g.fillRect(0,0,1080,1350);g.fillStyle=ink('--w-frame');g.fillRect(32,32,1016,1286);g.fillStyle=ink('--w-parchment');g.fillRect(48,48,984,1254);
      text('NUDGE · 成長紀錄館',80,130,36,'--w-violet-deep');text(kind==='weekly'?'這一週的小小冒險':'值得記住的一座獎盃',80,210,52);text(payload.nickname,80,290,42);
      if(character){const a=layout.character;g.drawImage(character,a.x,a.y,a.w,a.h);}else text('角色圖尚未提供',690,450,28);
      if(kind==='weekly'){
        text(payload.days[0].date+' 至 '+payload.days[6].date,80,350,30);
        text('總專注',80,440,38);text(payload.totalFocus===null?'已隱藏':Math.round(payload.totalFocus)+' 分鐘',80,500,56);
        text('完成委託',80,590,38);text(payload.quests===null?'已隱藏':payload.quests+' 件',80,650,56);
        text('最棒的一天：'+(payload.bestDay||'留在自己心裡'),80,740,32);
        payload.days.forEach((d,i)=>{const x=layout.daySlots[i].x;text(d.date.slice(5),x,1020,27);if(d.quests>0)text("★",x+38,770,28,"--w-gold-deep");if(d.books===null)text('隱藏',x,970,26);else{for(let b=0;b<d.books;b++){g.fillStyle=ink(b%2?'--w-violet-deep':'--w-wood');g.fillRect(x+12,950-b*24,90,18);g.fillStyle=ink('--w-gold');g.fillRect(x+20,953-b*24,5,12);}text(Math.round(d.focus)+'分',x,1070,25);}});
        if(payload.companion)text(payload.companion,80,1160,30);
      }else {if(trophy)g.drawImage(trophy,120,410,256,256);text(payload.badge.name,80,850,52);text(payload.badge.date?'取得日期 '+payload.badge.date:'取得日期已隱藏',80,940,36);text('每一座獎盃，都有自己的步調。',80,1100,30);}
      text('只記下自己選擇分享的成長',80,1250,30,'--w-violet-deep');
      const blob=await new Promise(resolve=>canvas.toBlob(resolve,'image/png'));if(!scope.alive()||own!==version||!blob)return;
      url=URL.createObjectURL(blob);ready=payload;$('shareDownload').disabled=false;$('shareCaption').textContent='預覽已完成：1080 × 1350 PNG。請確認可見內容後下載。';say('卡片只包含暱稱、角色及已勾選欄位；未包含電子郵件、帳號或家庭團體資訊。');
    }catch(_){if(scope.alive()&&own===version){invalidate();say('尚未產生卡片：請確認已解鎖的徽章、連線與圖片載入後重試。');}}
  }
  $('sharePreview').addEventListener('click',preview);
  $('shareDownload').addEventListener('click',()=>{if(!ready||!url||!ctx?.alive())return;const a=el('a',null,{href:url,download:'nudge-'+ready.kind+'.png'});document.body.append(a);a.click();a.remove();});
  async function load(){
    invalidate();profile=null;summary=null;badges=[];$('shareBadge').replaceChildren();$('sharePreview').disabled=true;controls.querySelectorAll('select,input').forEach(n=>n.disabled=true);
    if(!ctx?.user){say('登入後讀取本人紀錄；沒有載入卡片資料。');return;}const scope=ctx,own=version;say('雲端確認中；尚未開放預覽。');
    try{const range=core.weekRange(new Date()),[snap,rows]=await Promise.all([scope.db.collection('users').doc(scope.user.uid).get({source:'server'}),sessions(scope,range.start,range.end)]);confirmed(snap);if(!scope.alive()||own!==version)return;if(!snap.exists)throw Error('Missing profile');profile=snap.data();summary=core.week(rows,new Date());badges=root.NudgeAchievementsCore.records(profile).filter(b=>b.unlocked);
      for(const b of badges)$('shareBadge').append(el('option',b.name,{value:b.key}));const selected=new URLSearchParams(location.search).get('badge');if(badges.some(b=>b.key===selected)){$('shareBadge').value=selected;$('shareKind').value='achievement';$('shareWeeklyOptions').hidden=true;$('shareBadgeOptions').hidden=false;}
      $('sharePreview').disabled=false;controls.querySelectorAll('select,input').forEach(n=>n.disabled=false);say('本人最近七個 05:00 邏輯日已由雲端確認；選擇顯示內容後產生預覽。');
    }catch(_){if(scope.alive()&&own===version)say('讀取未完成，請重新讀取。未用部分或範例資料製作卡片。');}
  }
  $('shareReload').addEventListener('click',load);connect(c=>{ctx=c;load();return()=>{invalidate();profile=null;summary=null;badges=[];};});
})(typeof globalThis!=='undefined'?globalThis:this);
