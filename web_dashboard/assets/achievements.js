(function(root){
  'use strict';
  const {el,button,say,confirmed,connect,signedOut}=root.NudgeGrowthWorld,core=root.NudgeAchievementsCore;
  const host=document.getElementById('achievementContent'),dialog=document.getElementById('achievementDialog');let ctx=null,off=()=>{},current=null,returnId=null,command=0;
  function close(){dialog.close();if(returnId)document.getElementById(returnId)?.focus();returnId=null;}
  dialog.addEventListener('cancel',e=>{e.preventDefault();close();});
  function clear(){++command;current=null;off();off=()=>{};if(dialog.open)close();host.replaceChildren();}
  document.addEventListener('growth-clear',clear);
  function detail(badge){
    returnId='badge-'+badge.key;dialog.replaceChildren();
    dialog.append(el('h2',badge.name,{id:'achievementDialogTitle'}),el('img',null,{src:`assets/growth/trophy-${badge.icon}.png`,alt:'',width:128,height:128,class:'achievement-large'+(badge.unlocked?'':' achievement-locked')}),el('p',badge.condition),el('p',badge.unlocked?'取得日期：'+badge.unlockedAt:'尚未解鎖；不根據本機數字推算。'));
    const equip=button('設為稱號',()=>equipTitle(badge,equip));equip.disabled=!badge.unlocked||current?.profileTitleBadgeKey===badge.key;
    if(badge.unlocked&&current?.profileTitleBadgeKey===badge.key)equip.textContent='目前使用的稱號';dialog.append(equip,button('關閉',close));dialog.showModal();dialog.querySelector('button:not([disabled])')?.focus();
  }
  async function equipTitle(badge,btn){
    if(!ctx?.user||!core.canEquip(current,badge.key))return;const own=++command,scope=ctx;btn.disabled=true;say('稱號雲端確認中。');
    try{const ref=scope.db.collection('users').doc(scope.user.uid),pub=scope.db.collection('public_profiles').doc(scope.user.uid);
      await scope.db.runTransaction(async tx=>{const [u,p]=await Promise.all([tx.get(ref),tx.get(pub)]);if(!scope.alive()||!u.exists||!core.canEquip(u.data(),badge.key))throw Error('Badge unavailable');const update={profileTitleBadgeKey:badge.key,updatedAt:new Date().toISOString()};tx.update(ref,update);if(p.exists)tx.update(pub,update);});
      if(!scope.alive()||own!==command)return;say('稱號已由雲端確認，沿用 App 的稱號欄位。');if(dialog.open)close();
    }catch(_){if(!scope.alive()||own!==command)return;say('稱號尚未更新；請檢查連線或徽章狀態後重試。');btn.disabled=false;}
  }
  function paint(data){
    current=data;if(dialog.open)close();host.replaceChildren();const cases=el('div',null,{class:'achievement-cases'});
    for(const [tier,label]of Object.entries(core.tiers)){const cabinet=el('section',null,{class:'achievement-case'}),list=el('div',null,{class:'achievement-grid'});cabinet.append(el('h2',label));
      for(const badge of core.records(data).filter(b=>b.rarity===tier)){const b=button('',()=>detail(badge));b.className='achievement-trophy'+(badge.unlocked?'':' is-locked');b.id='badge-'+badge.key;b.dataset.rarity=tier;b.append(el('img',null,{src:`assets/growth/trophy-${badge.icon}.png`,alt:'',width:64,height:64}),el('strong',badge.name),el('span',badge.unlocked?'已取得 '+badge.unlockedAt:'未解鎖',{class:'achievement-date'}),el('span',badge.condition,{class:'achievement-condition'}));list.append(b);}cabinet.append(list);cases.append(cabinet);
    }host.append(cases);
  }
  function load(){
    clear();if(!ctx?.user){signedOut(host);return;}const scope=ctx;
    say('雲端確認中；尚未顯示解鎖結果。');
    off=scope.db.collection('users').doc(scope.user.uid).onSnapshot({includeMetadataChanges:true},snap=>{
      if(!scope.alive())return;
      try{confirmed(snap);if(!snap.exists)throw Error('Missing profile');paint(snap.data());say('已讀取本人雲端徽章紀錄。分櫃是展示分類，不新增解鎖或獎勵。');}
      catch(_){++command;current=null;host.replaceChildren();if(dialog.open)close();say('雲端確認中；已清除未確認的解鎖結果。');}
    },()=>{if(!scope.alive())return;current=null;host.replaceChildren(button('重試讀取',load));if(dialog.open)close();say('無法讀取本人徽章，請重試。');});
  }
  document.getElementById('achievementReload').addEventListener('click',load);
  connect(c=>{ctx=c;load();return clear;});
})(typeof globalThis!=='undefined'?globalThis:this);
