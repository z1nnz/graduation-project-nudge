(function(root,factory){const api=factory();if(typeof module==='object'&&module.exports)module.exports=api;else root.NudgeVirtualOrbitCore=api;})(typeof globalThis!=='undefined'?globalThis:this,function(){
  'use strict';
  const DURATION=20000,HOLD=1000;
  function initial(){return {phase:'idle',minutes:25,startedAt:null,pressedAt:null,remaining:20};}
  function reduce(state,event){
    const s={...state},now=Number(event.now);if(!Number.isFinite(now))return s;
    if(event.type==='reset')return initial();
    if(event.type==='rotate'&&s.phase==='idle'&&Number.isFinite(event.delta)&&event.delta!==0)s.minutes=event.delta>0?50:25;
    if(event.type==='press'&&s.pressedAt===null)s.pressedAt=now;
    if(event.type==='cancel')s.pressedAt=null;
    if(event.type==='release'&&s.pressedAt!==null){const duration=Math.max(0,now-s.pressedAt);s.pressedAt=null;
      if(duration>=HOLD&&s.phase==='focus'){s.phase='complete';s.remaining=0;}
      else if(duration<HOLD&&s.phase==='idle'){s.phase='focus';s.startedAt=now;s.remaining=20;}
    }
    if(event.type==='start'&&s.phase==='idle'){s.phase='focus';s.startedAt=now;s.remaining=20;s.pressedAt=null;}
    if(event.type==='complete'&&s.phase==='focus'){s.phase='complete';s.remaining=0;s.pressedAt=null;}
    if(event.type==='tick'&&s.phase==='focus'){s.remaining=Math.max(0,Math.min(20,Math.ceil((DURATION-Math.max(0,now-s.startedAt))/1000)));if(s.remaining===0)s.phase='complete';}
    return s;
  }
  function dragSteps(delta){return Number.isFinite(delta)?Math.trunc(delta/24):0;}
  function frame(state,device='orbit'){const which=device==='station'?'station':'orbit';return 'assets/virtual-device/'+which+'-'+(state.phase==='focus'?'focus-'+state.remaining:state.phase==='complete'?'complete-'+state.minutes:'idle-'+state.minutes)+'.png';}
  return Object.freeze({DURATION,HOLD,initial,reduce,dragSteps,frame});
});
