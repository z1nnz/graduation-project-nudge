(function(root){
  'use strict';
  // This page belongs in the existing town window, including direct bookmarks.
  if(root.parent===root){root.location.replace('town.html#open=onboarding.html');return;}
  const {el,button,say,confirmed,connect,signedOut}=root.NudgeGrowthWorld,core=root.NudgeOnboardingCore;
  const $=id=>document.getElementById(id),host=$('onboardingContent');let ctx=null,profile=null,index=0,step=0,busy=false,pending=null,previousUid=null,version=0;
  const key=uid=>'nudge_onboarding_plan:'+uid;
  const live=()=>ctx?.user&&ctx.alive();
  function clear(){++version;profile=null;busy=false;host.replaceChildren();}
  document.addEventListener('growth-clear',clear);
  function setStep(value){step=value;for(const s of document.querySelectorAll('[data-onboarding-step]'))s.hidden=Number(s.dataset.onboardingStep)!==step;for(const s of document.querySelectorAll('[data-step-marker]')){if(Number(s.dataset.stepMarker)===step)s.setAttribute('aria-current','step');else s.removeAttribute('aria-current');}document.querySelector('[data-onboarding-step="'+step+'"] h2')?.focus();if(!pending)say(['請選擇夥伴；尚未寫入任何選擇。','夥伴尚未保存，請取一個暱稱。','目前只有草稿；勾選並確認後才會建立任務。'][step]);}
  function choose(value){if(busy||pending)return;index=value;const s=core.starters.find(s=>s.index===index);document.querySelectorAll('[data-character-index]').forEach(b=>{const chosen=Number(b.dataset.characterIndex)===index;b.setAttribute('aria-pressed',String(chosen));b.querySelector('.onboarding-pedestal').classList.toggle('is-chosen',chosen);});$('onboardingIntro').textContent=s.line;$('onboardingChoose').disabled=!core.canSelect(profile,index);$('onboardingOwnership').textContent=core.canSelect(profile,index)?'此角色可沿用既有權限選用。':'此角色需要先在既有商城持有；這裡只提供預覽，不會免費解鎖。';}
  function draft(){if(pending)return;const habit=document.querySelector('[name="habit"]:checked')?.value;$('onboardingCustom').hidden=habit!=='custom';$('onboardingCustomField').hidden=habit!=='custom';$('onboardingTask').value=core.suggestion(habit,$('onboardingCustom').value);}
  function storedPlan(uid){try{const value=JSON.parse(sessionStorage.getItem(key(uid))||'null');return value?core.plan(value):null;}catch(_){return null;}}
  function savePlan(){try{sessionStorage.setItem(key(ctx.user.uid),JSON.stringify(pending));}catch(_){/* Cloud request ids stay stable for this open page. */}}
  function lock(value){busy=value;for(const input of host.querySelectorAll('button,input,textarea'))input.disabled=value||!!pending;const confirm=$('onboardingConfirm');if(confirm)confirm.disabled=value;}
  async function finish(){
    if(!live()||busy)return;const scope=ctx,own=version;
    try{
      if(!pending){const requestId='onboard_'+root.crypto.randomUUID().replaceAll('-','_');pending=core.plan({index,name:$('onboardingName').value,taskTitle:$('onboardingTask').value,createTask:$('onboardingCreateTask').checked,requestId,taskId:requestId+'_task'});savePlan();}
      lock(true);say('角色雲端確認中。任務只有在你勾選確認後才會建立。');
      const ref=scope.db.collection('users').doc(scope.user.uid),before=confirmed(await ref.get({source:'server'}));if(!scope.alive()||own!==version)return;
      if(!before.exists||!core.canSelect(before.data(),pending.index))throw Error('角色尚未持有，請重新讀取。');
      if(core.hasCharacter(before.data())&&before.data().avatarProfile.faceShapeIndex!==pending.index)throw Error('另一裝置已選擇角色，請重新開啟頁面確認。');
      const equipment=(await scope.functions.httpsCallable('equipRewardAvatar')({avatarProfile:core.avatar(pending.index),backgroundTheme:'softGlow',faceCatalogItemId:null,iconCatalogItemId:null,clientRequestId:pending.requestId,sourceSurface:'web'})).data;
      if(!scope.alive()||own!==version)return;
      if(!equipment?.rewardEntryId||equipment.avatarProfile?.faceShapeIndex!==pending.index||equipment.avatarProfile?.avatarIconIndex!==pending.index||equipment.backgroundTheme!=='softGlow')throw Error('角色回應無法確認。');
      const pub=scope.db.collection('public_profiles').doc(scope.user.uid);await scope.db.runTransaction(async tx=>{const [u,p]=await Promise.all([tx.get(ref),tx.get(pub)]);if(!scope.alive()||!u.exists||u.data().avatarProfile?.faceShapeIndex!==pending.index)throw Error('角色已改變，請重新確認。');const update={nickname:pending.name,updatedAt:new Date().toISOString()};tx.update(ref,update);if(p.exists)tx.update(pub,update);});
      if(!scope.alive()||own!==version)return;
      if(pending.createTask){say('角色與暱稱已保存，任務雲端確認中。');const task=(await scope.functions.httpsCallable('manageGrowthDocument')({action:'createTask',taskId:pending.taskId,title:pending.taskTitle})).data;if(!scope.alive()||own!==version)return;if(task?.taskId!==pending.taskId||!['created','existing'].includes(task.status))throw Error('任務尚未確認，可使用相同識別重試。');}
      const final=confirmed(await ref.get({source:'server'}));if(!scope.alive()||own!==version)return;const data=final.data();if(data?.nickname!==pending.name||data.avatarProfile?.faceShapeIndex!==pending.index||(pending.createTask&&!data.tasks?.some(t=>t.id===pending.taskId&&t.title===pending.taskTitle)))throw Error('尚未完整同步，請重試確認。');
      try{sessionStorage.removeItem(key(scope.user.uid));}catch(_){}say('角色與暱稱已由雲端確認；'+(pending.createTask?'任務已建立。':'未建立任何任務。'));
      host.replaceChildren(el('h2','準備好進入小鎮了'),el('img',null,{src:'assets/growth/characters/character_'+pending.index+'.png',alt:pending.name+'的夥伴走進小鎮',class:'onboarding-walk',width:128,height:192}));
      const enter=()=>{
        if(!scope.alive()||own!==version)return;
        const town=root.parent,box=town.document.getElementById('townWindow'),uid=scope.user.uid;
        // The shared window restores background focus after its close animation.
        // Start the tour only after that restoration, including reduced motion.
        const guide=()=>{if(town.firebase?.auth().currentUser?.uid===uid)town.document.getElementById('townHelp')?.click();};
        if(!box){guide();return;}
        let expiry;const observer=new town.MutationObserver(()=>{if(box.hidden){observer.disconnect();town.clearTimeout(expiry);guide();}});
        observer.observe(box,{attributes:true,attributeFilter:['hidden']});expiry=town.setTimeout(()=>observer.disconnect(),3000);
        town.NudgeTownWindow?.close();
      };
      if(root.matchMedia('(prefers-reduced-motion: reduce)').matches)enter();else setTimeout(enter,240);
    }catch(error){if(!scope.alive()||own!==version)return;lock(false);say('尚未全部完成：'+(error.code?'連線或網站驗證尚未就緒，請重試。':error.message||'請重試。')+' 已送出的確認不會重複建立任務；按確認可接續。');}
  }
  function paint(){
    host.innerHTML='<section data-onboarding-step="0"><h2 tabindex="-1">選一位一起出發的夥伴</h2><p>六個角色都可預覽，選用仍依既有的雲端持有條件。</p><div id="onboardingCharacters" class="onboarding-grid"></div><p id="onboardingIntro" class="onboarding-line" role="status"></p><p id="onboardingOwnership"></p><button id="onboardingChoose" class="w-btn is-gold" type="button">選好角色，下一步</button></section><section data-onboarding-step="1" hidden><h2 tabindex="-1">在小鎮上怎麼稱呼你？</h2><label class="onboarding-field">暱稱<input id="onboardingName" class="w-input" maxlength="40" required autocomplete="nickname"></label><div class="growth-controls"><button id="onboardingNameBack" class="w-btn" type="button">回到角色</button><button id="onboardingNameNext" class="w-btn is-gold" type="button">取好暱稱，下一步</button></div></section><section data-onboarding-step="2" hidden><h2 tabindex="-1">想先養成哪個習慣？</h2><fieldset class="onboarding-habits"><legend>習慣方向</legend><label><input type="radio" name="habit" value="study" checked>讀書</label><label><input type="radio" name="habit" value="exercise">運動</label><label><input type="radio" name="habit" value="sleep">早睡</label><label><input type="radio" name="habit" value="custom">自訂</label></fieldset><label class="onboarding-field" id="onboardingCustomField" hidden>自訂方向<input id="onboardingCustom" class="w-input" maxlength="100" hidden></label><label class="onboarding-field">建議的第一個任務草稿（可修改）<textarea id="onboardingTask" class="w-textarea" maxlength="120" rows="3" required></textarea></label><label class="onboarding-confirm"><input id="onboardingCreateTask" type="checkbox">我確認要建立這個任務</label><p>不勾選就只保存角色與暱稱；選習慣或編輯草稿都不會自動建立任務，也不發放獎勵。</p><div class="growth-controls"><button id="onboardingHabitBack" class="w-btn" type="button">修改暱稱</button><button id="onboardingConfirm" class="w-btn is-gold" type="button">確認選擇，走進小鎮</button></div></section>';
    for(const s of core.starters){const b=button('',()=>choose(s.index));b.dataset.characterIndex=s.index;b.className='onboarding-character';b.setAttribute('aria-pressed','false');const stage=el('span',null,{class:'onboarding-pedestal'});stage.append(el('img',null,{src:'assets/growth/characters/character_'+s.index+'.png',alt:'',width:128,height:192}));b.append(stage,el('strong',s.name),el('small',core.canSelect(profile,s.index)?'可選用':'僅預覽 · 需先持有'));$('onboardingCharacters').append(b);}
    $('onboardingName').value=profile.nickname||'';$('onboardingChoose').addEventListener('click',()=>setStep(1));$('onboardingNameBack').addEventListener('click',()=>setStep(0));$('onboardingNameNext').addEventListener('click',()=>{try{core.nickname($('onboardingName').value);setStep(2);}catch(e){say(e.message);$('onboardingName').focus();}});$('onboardingHabitBack').addEventListener('click',()=>setStep(1));$('onboardingConfirm').addEventListener('click',finish);for(const radio of host.querySelectorAll('[name="habit"]'))radio.addEventListener('change',draft);$('onboardingCustom').addEventListener('input',draft);draft();choose(index);
    if(pending){index=pending.index;$('onboardingName').value=pending.name;$('onboardingTask').value=pending.taskTitle;$('onboardingCreateTask').checked=pending.createTask;setStep(2);lock(false);say('上次的確認尚未收尾，可使用相同請求接續；不會重複建立任務。');}else setStep(0);
  }
  connect(async c=>{
    clear();ctx=c;if(previousUid&&previousUid!==c.user?.uid){try{sessionStorage.removeItem(key(previousUid));}catch(_){}}previousUid=c.user?.uid||null;
    if(!c.user){pending=null;signedOut(host);return clear;}say('正在確認本人角色與持有權限。');
    try{const snap=confirmed(await c.db.collection('users').doc(c.user.uid).get({source:'server'}));if(!c.alive())return;if(!snap.exists)throw Error('請從登入頁確認帳號後再進入。');profile=snap.data();pending=storedPlan(c.user.uid);if(core.hasCharacter(profile)&&!pending){host.append(el('h2','你已經有夥伴了'),el('p','保留現有角色；可回小鎮或到名片調整暱稱。'),el('a','我的名片',{href:'profile.html',class:'w-btn'}));say('既有角色已確認，不會重新建立。');return clear;}
      paint();if(!pending)say('請選擇角色。尚未寫入任何選擇或任務。');return clear;
    }catch(e){if(c.alive()){host.replaceChildren(el('p',e.message||'無法確認本人資料。'),button('重新讀取',()=>root.location.reload()));say('雲端尚未確認，未開放建立角色。');}return clear;}
  });
})(typeof globalThis!=='undefined'?globalThis:this);
