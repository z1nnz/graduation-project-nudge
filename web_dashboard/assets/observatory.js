(function(root){
  'use strict';
  const {el,button,say,confirmed,connect,signedOut}=root.NudgeGrowthWorld,core=root.NudgeVirtualOrbitCore;
  const $=id=>document.getElementById(id),knob=$('orbitKnob'),binding=$('deviceBinding');let state=core.initial(),painted='',drag=null,holdTimer=null,ctx=null,off=()=>{},bindingRequest=0;
  function dispatch(type,extra={}){const before=state.phase;state=core.reduce(state,{type,now:performance.now(),...extra});paint();if(state.phase!==before)$('virtualStatus').textContent=state.phase==='focus'?'示範專注中：20 秒縮短倒數，不寫入活動。':state.phase==='complete'?'示範完成回饋，不發放任何獎勵。':'示範待命；可選擇25或50分鐘。';}
  function paint(){
    const key=state.phase+state.remaining+state.minutes;if(key===painted)return;painted=key;
    for(const device of ['orbit','station']){const img=$(device+'Screen');img.src=core.frame(state,device);img.alt=`${device==='orbit'?'Orbit':'Station'} 韌體示範：${state.phase==='idle'?'待命 '+state.minutes+' 分鐘':state.phase==='focus'?'倒數 '+state.remaining+' 秒':'完成回饋'}`;}
    $('virtualMinutes').textContent=state.minutes+' 分鐘';$('virtualCountdown').textContent=state.phase==='focus'?state.remaining+' 秒':state.phase==='complete'?'完成':'待命';
    document.querySelectorAll('.device-stage').forEach(n=>{n.classList.toggle('is-focusing',state.phase==='focus');n.classList.toggle('is-complete',state.phase==='complete');});
    $('virtual25').disabled=state.phase!=='idle';$('virtual50').disabled=state.phase!=='idle';$('virtualStart').disabled=state.phase!=='idle';$('virtualComplete').disabled=state.phase!=='focus';knob.setAttribute('aria-label','模擬旋鈕，目前 '+state.minutes+' 分鐘；短按開始，專注中按住一秒完成');
  }
  function cancel(){clearTimeout(holdTimer);holdTimer=null;drag=null;dispatch('cancel');}
  knob.addEventListener('wheel',e=>{e.preventDefault();dispatch('rotate',{delta:e.deltaY>0?1:-1});},{passive:false});
  knob.addEventListener('pointerdown',e=>{if(e.button!==0)return;e.preventDefault();knob.setPointerCapture(e.pointerId);knob.focus();drag={x:e.clientX,moved:false};dispatch('press');holdTimer=setTimeout(()=>{if(state.phase==='focus'&&state.pressedAt!==null)dispatch('complete');},1000);});
  knob.addEventListener('pointermove',e=>{if(!drag)return;const delta=core.dragSteps(e.clientX-drag.x);if(delta){drag.moved=true;drag.x=e.clientX;dispatch('cancel');dispatch('rotate',{delta});clearTimeout(holdTimer);}});
  knob.addEventListener('pointerup',e=>{if(!drag)return;clearTimeout(holdTimer);if(!drag.moved)dispatch('release');else dispatch('cancel');drag=null;if(knob.hasPointerCapture(e.pointerId))knob.releasePointerCapture(e.pointerId);});
  knob.addEventListener('pointercancel',cancel);knob.addEventListener('lostpointercapture',cancel);
  knob.addEventListener('keydown',e=>{if(e.key==='ArrowLeft'||e.key==='ArrowRight'){e.preventDefault();dispatch('rotate',{delta:e.key==='ArrowRight'?1:-1});}if([' ','Enter'].includes(e.key)){e.preventDefault();if(!e.repeat)dispatch('press');}});
  knob.addEventListener('keyup',e=>{if([' ','Enter'].includes(e.key)){e.preventDefault();dispatch('release');}});knob.addEventListener('blur',cancel);
  knob.addEventListener('click',e=>{if(e.detail===0&&state.pressedAt===null)dispatch('start');});
  $('virtual25').addEventListener('click',()=>dispatch('rotate',{delta:-1}));$('virtual50').addEventListener('click',()=>dispatch('rotate',{delta:1}));$('virtualStart').addEventListener('click',()=>dispatch('start'));$('virtualComplete').addEventListener('click',()=>dispatch('complete'));$('virtualReset').addEventListener('click',()=>{cancel();dispatch('reset');});
  // The demo uses elapsed time, but redraws only while its physical workbench is visible.
  let tick=null,lastTick=0;
  function stopTick(){if(tick!==null)root.cancelAnimationFrame(tick);tick=null;}
  function drawTick(now){tick=null;const panel=knob.closest('dialog');if(document.hidden||(panel&&!panel.open))return;if(now-lastTick>=100){lastTick=now;dispatch('tick');}tick=root.requestAnimationFrame(drawTick);}
  function resumeTick(){stopTick();if(!document.hidden)tick=root.requestAnimationFrame(drawTick);}
  document.addEventListener('visibilitychange',resumeTick);
  document.addEventListener('DOMContentLoaded',()=>{const panel=knob.closest('dialog');if(panel)new MutationObserver(resumeTick).observe(panel,{attributes:true,attributeFilter:['open']});resumeTick();});
  root.addEventListener('pageshow',resumeTick);root.addEventListener('pagehide',()=>{stopTick();cancel();off();++bindingRequest;binding.replaceChildren();});
  async function loadBindings(){
    off();off=()=>{};binding.replaceChildren();const own=++bindingRequest;
    if(!ctx?.user){signedOut(binding);return;}const scope=ctx;say('裝置綁定狀態雲端確認中；上方始終是唯讀示範。');
    off=scope.db.collection('device_assignments').where('assignedUserId','==',scope.user.uid).limit(51).onSnapshot({includeMetadataChanges:true},snap=>{
      if(!scope.alive()||own!==bindingRequest)return;
      try{confirmed(snap);binding.replaceChildren();if(snap.docs.length>50)throw Error('Too many bindings');const ownDocs=snap.docs.filter(d=>d.data().assignedUserId===scope.user.uid);if(!ownDocs.length)binding.append(el('p','目前沒有可確認的本人裝置綁定。'));
        for(const d of ownDocs){const data=d.data();binding.append(el('p',(String(data.deviceType||data.deviceModel||'裝置').slice(0,30))+' · '+(data.status==='active'?'已綁定':'綁定狀態：'+String(data.status||'尚待確認').slice(0,30))));}
        say('本人裝置綁定已由雲端確認。網頁不會連線、認領或轉移實體裝置。');
      }catch(_){binding.replaceChildren();say('裝置狀態雲端確認中，未確認資料已清空。');}
    },()=>{if(!scope.alive()||own!==bindingRequest)return;binding.replaceChildren(button('重試讀取裝置狀態',loadBindings));say('這次無法讀取裝置綁定，請重試。');});
  }
  connect(c=>{ctx=c;loadBindings();return()=>{off();++bindingRequest;binding.replaceChildren();};});paint();
})(typeof globalThis!=='undefined'?globalThis:this);
