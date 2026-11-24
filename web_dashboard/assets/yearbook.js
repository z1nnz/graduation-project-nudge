(function(root){
  'use strict';
  const {el,button,say,connect,sessions,signedOut}=root.NudgeGrowthWorld,core=root.NudgeYearbookCore;
  const host=document.getElementById('yearbookContent'),year=document.getElementById('yearbookYear'),month=document.getElementById('yearbookMonth');
  const today=core.logicalDay(new Date());year.value=today.slice(0,4);month.value=String(Number(today.slice(5,7)));year.max=today.slice(0,4);
  let ctx=null,request=0,chapter=null,index=0,opened=false;
  function clear(){++request;chapter=null;host.replaceChildren();}
  document.addEventListener('growth-clear',clear);
  function turn(delta){if(!chapter)return;const previous=document.activeElement?.textContent;index=core.pageIndex(index+delta,chapter.weeks.length);paint(true);const target=[...host.querySelectorAll('button')].find(b=>b.textContent===previous&&!b.disabled);(target||document.getElementById('yearbookBook')).focus({preventScroll:true});}
  function paint(animate=false){
    if(!chapter)return;host.replaceChildren();
    if(!opened){const shelf=el('section',null,{class:'yearbook-shelf'});shelf.append(el('img',null,{src:'assets/growth/yearbook-cover.png',alt:'紫色金星皮革年鑑',class:'yearbook-cover',width:160}),button('翻開這本年鑑',()=>{opened=true;paint();document.getElementById('yearbookBook').focus();}));host.append(shelf);return;}
    const week=chapter.weeks[index],book=el('section',null,{id:'yearbookBook',class:'yearbook-book'+(animate?' yearbook-turn':''),tabindex:0,'aria-label':'可用左右方向鍵翻頁的年鑑'});
    const pages=el('div',null,{class:'yearbook-pages'}),left=el('section',null,{class:'yearbook-leaf'}),right=el('section',null,{class:'yearbook-leaf'});
    left.append(el('h2',`${chapter.year} 年 ${chapter.month} 月 · 第 ${index+1} 週`),el('p',`${week.start} 至 ${week.end}`));
    if(week.empty)left.append(el('p','這一週留白也沒關係，下一頁隨時可以開始。',{class:'yearbook-empty'}));
    else {const labels={focus:'▤ 專注／學習（分鐘）',exercise:'◆ 運動（分鐘）',sleep:'☾ 睡眠（小時）',tasks:'✓ 完成委託（件）'};for(const [k,label]of Object.entries(labels))left.append(el('p',label),el('strong',String(Math.round(week.totals[k]*100)/100),{class:'growth-number'}));}
    const list=el('ul',null,{class:'yearbook-days','aria-label':'此週每日活動'});
    for(const d of week.days){const li=el('li');li.append(el('time',d.key,{datetime:d.key}));if(!d.rows.length)li.append(el('p','留白的一天'));else{const metrics=el('div',null,{class:'yearbook-metrics'});for(const [key,label]of [['focus','▤ 專注'],['exercise','◆ 運動'],['sleep','☾ 睡眠'],['tasks','✓ 委託']])metrics.append(el('span',`${label} ${Math.round(d.totals[key]*100)/100}${key==='sleep'?' 小時':key==='tasks'?' 件':' 分'}`));li.append(metrics);}list.append(li);}right.append(list);pages.append(left,right);book.append(pages);
    book.addEventListener('keydown',e=>{if(e.key==='ArrowLeft'||e.key==='ArrowRight'){e.preventDefault();turn(e.key==='ArrowLeft'?-1:1);document.getElementById('yearbookBook').focus();}});
    let start=null;book.addEventListener('pointerdown',e=>{if(e.target.closest('a,button'))return;start={x:e.clientX,y:e.clientY};});book.addEventListener('pointercancel',()=>start=null);book.addEventListener('pointerup',e=>{if(!start)return;const dx=e.clientX-start.x,dy=e.clientY-start.y;start=null;if(Math.abs(dx)>50&&Math.abs(dx)>Math.abs(dy)*1.5)turn(dx<0?1:-1);});
    const pager=el('nav',null,{class:'growth-controls yearbook-pager','aria-label':'年鑑翻頁'}),prev=button('上一週',()=>turn(-1)),next=button('下一週',()=>turn(1));prev.disabled=index===0;next.disabled=index===chapter.weeks.length-1;
    pager.append(prev,el('span',`${index+1}／${chapter.weeks.length}`,{role:'status','aria-live':'polite'}),next,button('闔上年鑑',()=>{opened=false;paint();host.querySelector('button')?.focus();}));host.append(book,pager);
  }
  async function load(){
    clear();if(!ctx?.user){signedOut(host);return;}const own=request;
    const y=Number(year.value),m=Number(month.value);
    if(!year.reportValidity()||`${y}-${String(m).padStart(2,'0')}`>today.slice(0,7)){say('請選擇今天以前的月份。');return;}
    say('雲端確認中；尚未顯示本月數字。');
    try{const range=core.monthRange(y,m),rows=await sessions(ctx,range.start,range.end);if(!ctx.alive()||own!==request)return;chapter=core.chapter(rows,y,m);index=0;paint();say('本月雲端紀錄已確認。以臺北時間清晨 05:00 換日；跨月週分章呈現。');}
    catch(_){if(!ctx.alive()||own!==request)return;clear();host.append(el('p','本月讀取未完成，可能離線、格式不符或超過 500 筆。沒有用部分資料當完整總計。'),button('重新讀取',load),el('a','使用正式資料匯出',{href:'privacy.html'}));say('尚待雲端確認，本月內容已清空。');}
  }
  document.getElementById('yearbookLoad').addEventListener('click',()=>{opened=false;load();});
  connect(c=>{ctx=c;opened=false;load();return clear;});
})(typeof globalThis!=='undefined'?globalThis:this);
