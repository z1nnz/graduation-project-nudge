(function(root){
  'use strict';
  function mount(stage,getModel){
    const canvas=document.createElement('canvas');canvas.className='observatory-sky';canvas.setAttribute('aria-hidden','true');stage.prepend(canvas);
    const scope=document.createElement('img');scope.src='assets/scenes/observatory/telescope.webp';scope.alt='';scope.className='observatory-telescope';stage.append(scope);
    const g=canvas.getContext('2d'),media=root.matchMedia('(prefers-reduced-motion: reduce)');let raf=null,visible=true,last=null,elapsed=0,painted=-1;
    function draw(frame){
      const r=stage.getBoundingClientRect(),dpr=Math.min(root.devicePixelRatio||1,2);canvas.width=Math.round(r.width*dpr);canvas.height=Math.round(r.height*dpr);g.setTransform(dpr,0,0,dpr,0,0);g.imageSmoothingEnabled=false;
      const css=getComputedStyle(document.documentElement),color=k=>css.getPropertyValue('--w-'+k).trim(),m=getModel(),w=r.width,h=r.height;
      g.fillStyle=color('gold');for(let i=0;i<28;i++){g.globalAlpha=.5+((frame+i)%3)*.1;g.fillRect(Math.floor((i*.173%1)*w),Math.floor(h*(.17+(i*.113%1)*.25)),2,2);}g.globalAlpha=1;
      if(frame%240<9){g.fillRect(Math.floor(w*.2+frame%240*8),Math.floor(h*.19+frame%240*3),18,2);}
      if(m){
        const positions=[[12,25],[26,19],[40,14],[61,14],[76,20],[88,27],[51,42]];let previous=null;g.strokeStyle=color('gold');g.lineWidth=2;for(let i=0;i<7;i++){if(!m.week.days[i].recorded)continue;const point=[w*positions[i][0]/100,h*positions[i][1]/100];if(previous){g.beginPath();g.moveTo(...previous);g.lineTo(...point);g.stroke();}previous=point;}
        const x=w*.5,y=h*.31,rad=Math.min(w*.16,94);g.save();g.beginPath();g.arc(x,y,rad,0,Math.PI*2);g.clip();g.fillStyle=color(m.base?'violet-deep':'wood-deep');g.fillRect(x-rad,y-rad,rad*2,rad*2);
        if(m.base){g.fillStyle=color('green');for(let i=0;i<18;i++){const a=i*2.399+frame*.003;g.fillRect(Math.floor(x+Math.sin(a)*rad*.8),Math.floor(y+Math.cos(i*1.7)*rad*.65),12,8);}}g.restore();g.strokeStyle=color('frame');g.lineWidth=3;g.beginPath();g.arc(x,y,rad,0,Math.PI*2);g.stroke();
        if(m.base){g.fillStyle=color('green');for(let i=0;i<m.activeDays;i++){const px=x-rad+8+i*(rad*2-16)/6;g.fillRect(px,y+rad+7,3,8);g.fillRect(px-3,y+rad+4,9,5);}}
        m.planets.nodes.slice(0,6).forEach((p,i)=>{const a=i*Math.PI/3+frame*.002;g.fillStyle=color('gold');g.fillRect(Math.floor(x+Math.cos(a)*(rad+20)),Math.floor(y+Math.sin(a)*(rad+20)),8,8);});}
      scope.style.transform=media.matches?'none':'rotate('+Math.sin(frame/50)*1.5+'deg)';
    }
    function tick(now){raf=null;if(document.hidden||!visible)return;if(last!==null)elapsed+=Math.min(now-last,100);last=now;const frame=media.matches?0:Math.floor(elapsed/100);if(frame!==painted){draw(frame);painted=frame;}if(!media.matches)raf=requestAnimationFrame(tick);}
    function pause(){if(raf!==null)cancelAnimationFrame(raf);raf=null;last=null;}
    function resume(){pause();painted=-1;if(!document.hidden&&visible)raf=requestAnimationFrame(tick);}
    const observer=new IntersectionObserver(entries=>{visible=entries[0].isIntersecting;resume();});observer.observe(stage);document.addEventListener('visibilitychange',resume);media.addEventListener('change',resume);root.addEventListener('resize',resume);root.addEventListener('pagehide',pause);root.addEventListener('pageshow',resume);resume();
    return {redraw:resume,destroy(){pause();observer.disconnect();document.removeEventListener('visibilitychange',resume);media.removeEventListener('change',resume);root.removeEventListener('resize',resume);root.removeEventListener('pagehide',pause);root.removeEventListener('pageshow',resume);canvas.remove();scope.remove();}};
  }
  root.NudgeObservatoryLife=Object.freeze({mount});
})(typeof globalThis!=='undefined'?globalThis:this);
