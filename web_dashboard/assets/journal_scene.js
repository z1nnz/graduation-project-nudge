(function(root){
 'use strict';
 const kind=document.body.dataset.journalScene,{el,mount}=root.NudgeFacilityScene;
 const config={weather:['健康小屋・生活天氣','health_cabin','sprout','翻開生活天氣札記','☾'],pressure:['冒險手札・溫柔整理','journal_room','inky','翻開心情手札','▤'],skills:['冒險手札・技能書籤','journal_room','inky','翻開技能書','✦'],template:['冒險手札・下一步','journal_room','inky','翻開委託草稿','▤'],letter:['時光寫信桌','letter_garden','letty','坐到寫信桌','✎'],capsules:['樹下的時間膠囊','letter_garden','letty','查看伺服器膠囊','✉'],identity:['冒險者證書','journal_room','inky','打開冒險者證書','▤'],share:['紀錄館・分享印刷桌','journal_room','inky','打開分享印刷桌','▤']}[kind];
 const [title,room,npc,label,symbol]=config,main=document.querySelector('main'),scene=mount({title,background:'assets/scenes/journal/'+room+'.webp',npc,line:kind==='capsules'?'樹下的信由伺服器保護。先確認封存，到期開封也要由伺服器核對。':'點開桌上的實物，原來的紀錄、選項與保存流程都在這裡。',content:main,objects:[{label,symbol,x:44,y:75}]});
 const header=document.querySelector('.museum-header');if(header){const back=document.getElementById('museumWorld');header.className='w-hud';header.replaceChildren(back,el('h1',title),el('a','紀錄館',{href:'personal.html'}));}
 const life=root.NudgeJournalLife.mount(scene.stage),source=document.getElementById('museumStatus')||document.getElementById('growthStatus'),status=el('p',source?.textContent||'等待本人的紀錄。',{class:'facility-status',role:'status','aria-live':'polite'});scene.stage.append(status);
 const host=document.getElementById('museumView')||main;let seenReply='',authOff=null,authStarted=false;
 function sync(){status.textContent=source?.textContent||'等待本人的紀錄。';
  if(['letter','capsules'].includes(kind)){
   const form=host.querySelector('form');if(form&&!form.querySelector('.journal-writing')){const desk=el('canvas',null,{class:'journal-writing',width:128,height:72,'aria-hidden':'true'});form.prepend(desk);life.addDesk(desk);}
   const reply=[...host.querySelectorAll('p[role=status]')].map(n=>n.textContent).find(s=>s.startsWith('已封存。伺服器現在時間'))||'';if(reply&&reply!==seenReply){seenReply=reply;life.stamp();}
   life.setReady(kind==='capsules'&&source?.textContent.startsWith('已同步本人私有清單')&&!!host.querySelector('[data-capsule-state=opened]'));
  }
 }
 const observer=new MutationObserver(sync),observe=()=>{observer.observe(main,{childList:true,subtree:true,characterData:true});sync();};observe();
 document.addEventListener('focusin',e=>{if(['letter','capsules'].includes(kind)&&main.contains(e.target)&&e.target.matches('input,textarea'))life.setWriting(true);});document.addEventListener('focusout',()=>life.setWriting(false));
 document.querySelector('a[href="#museumMain"]')?.addEventListener('click',e=>{e.preventDefault();scene.open();main.focus();});
 function auth(){if(authStarted||!root.firebase?.apps?.length)return;authStarted=true;authOff=root.firebase.auth().onAuthStateChanged(()=>{seenReply='';life.reset();scene.close();});}
 document.addEventListener('firebase-ready',auth);auth();root.addEventListener('pageshow',()=>{observe();auth();});root.addEventListener('pagehide',()=>{observer.disconnect();authOff?.();authOff=null;authStarted=false;life.reset();});
})(typeof globalThis!=='undefined'?globalThis:this);
