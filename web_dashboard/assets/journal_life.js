(function(root){
 'use strict';
 function mount(stage){
  const canvas=document.createElement('canvas');canvas.className='journal-life';canvas.setAttribute('aria-hidden','true');stage.append(canvas);
  const media=root.matchMedia('(prefers-reduced-motion: reduce)'),desks=new Set();let raf=null,visible=true,last=null,elapsed=0,painted=-1,writing=false,ready=false,readyAt=0,stampAt=null,suspended=false;
  function props(g,w,h,frame,desk=false){const css=getComputedStyle(document.documentElement),color=k=>css.getPropertyValue('--w-'+k).trim();g.clearRect(0,0,w,h);g.imageSmoothingEnabled=false;
   const x=desk?w*.38:w*.44,y=desk?h*.65:h*.35,dx=writing&&!media.matches?Math.round(Math.sin(frame/3)*4):0;g.fillStyle=color('parchment-hi');for(let i=0;i<8;i++)g.fillRect(Math.floor(x+dx+i*2),Math.floor(y-i*4),Math.max(2,14-i),4);g.fillStyle=color('wood-deep');g.fillRect(x+dx,y,3,15);
   if(stampAt!==null){const progress=media.matches?1:Math.min(1,(elapsed-stampAt)/800);g.fillStyle=color('red');g.fillRect(w*(desk ? .66 : .54),h*(desk ? .54 : .39)-Math.round((1-progress)*12),18,14);g.fillStyle=color('gold');g.fillRect(w*(desk ? .66 : .54)+6,h*(desk ? .54 : .39)+4,6,6);}
   if(!desk){g.fillStyle=color('gold');for(let i=0;i<8;i++){g.globalAlpha=.4+(frame+i)%3*.1;g.fillRect(Math.floor(w*(.68+(i*.073)%.27)),Math.floor(h*(.2+(i*.13)%.43)),3,3);}g.globalAlpha=1;
    if(ready){const rise=media.matches?12:Math.min(12,Math.floor((elapsed-readyAt)/100));g.fillStyle=color('wood-deep');g.fillRect(w*.80-2,h*.48-rise-2,40,24);g.fillStyle=color('gold');g.fillRect(w*.80,h*.48-rise,36,20);g.fillStyle=color('wood');g.fillRect(w*.80,h*.48-rise+7,36,3);}}
  }
  function draw(frame){const r=stage.getBoundingClientRect(),dpr=Math.min(root.devicePixelRatio||1,2);canvas.width=Math.round(r.width*dpr);canvas.height=Math.round(r.height*dpr);const g=canvas.getContext('2d');g.setTransform(dpr,0,0,dpr,0,0);props(g,r.width,r.height,frame);for(const desk of desks){if(!desk.isConnected){desks.delete(desk);continue;}props(desk.getContext('2d'),desk.width,desk.height,frame,true);}}
  function tick(now){raf=null;if(document.hidden||!visible)return;if(last!==null)elapsed+=Math.min(now-last,100);last=now;const frame=media.matches?0:Math.floor(elapsed/100);if(frame!==painted){draw(frame);painted=frame;}if(!media.matches)raf=requestAnimationFrame(tick);}
  function pause(){if(raf!==null)cancelAnimationFrame(raf);raf=null;last=null;}
  function resume(){pause();painted=-1;if(!suspended&&!document.hidden&&visible)raf=requestAnimationFrame(tick);}
  const observer=new IntersectionObserver(entries=>{visible=entries[0].isIntersecting;resume();});observer.observe(stage);document.addEventListener('visibilitychange',resume);media.addEventListener('change',resume);root.addEventListener('resize',resume);const hide=()=>{suspended=true;pause();},show=()=>{suspended=false;resume();};root.addEventListener('pagehide',hide);root.addEventListener('pageshow',show);resume();
  return {setWriting(value){if(writing===value)return;writing=value;resume();},setReady(value){if(ready===value)return;ready=value;readyAt=elapsed;resume();},stamp(){stampAt=elapsed;resume();},reset(){writing=false;ready=false;stampAt=null;resume();},addDesk(desk){desks.add(desk);resume();},destroy(){pause();observer.disconnect();document.removeEventListener('visibilitychange',resume);media.removeEventListener('change',resume);root.removeEventListener('resize',resume);root.removeEventListener('pagehide',hide);root.removeEventListener('pageshow',show);}};
 }
 root.NudgeJournalLife=Object.freeze({mount});
})(typeof globalThis!=='undefined'?globalThis:this);
