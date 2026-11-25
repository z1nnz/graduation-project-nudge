(function(root){
  'use strict';
  const {el,mount}=root.NudgeFacilityScene,world=root.NudgeGrowthWorld,role=document.body.dataset.observatoryScene;
  const label={observatory:'開啟虛擬裝置工作台',planet:'委託清單與星球詳情',builder:'翻開建築規劃稿',yearbook:'翻開成長年鑑',achievements:'翻開成就紀錄簿'}[role];
  const main=document.querySelector('main'),scene=mount({title:'天文台・'+label,npc:'stella',line:'星圖只會照亮已確認的紀錄。留白的日子，也可以慢慢往前走。',background:'assets/scenes/observatory/observatory_room.webp',content:main,objects:[{label,symbol:'▤',x:44,y:72,onSelect:()=>{scene.open();if(role==='yearbook')document.querySelector('.yearbook-shelf button')?.click();}}]});
  const nav=el('nav',null,{class:'observatory-links','aria-label':'天文台房間'});for(const [href,text]of [['observatory.html','每週星圖'],['achievements.html','成就星圖室'],['personal-trends.html','成長年鑑'],['planet.html','星球成果']])nav.append(el('a',text,{href}));scene.stage.append(nav);
  if(role==='planet'){
    const legacy=main.querySelector('.planet-stage'),button=document.getElementById('missionOrbBtn'),book=document.getElementById('missionLogPanel');
    // Keep the original task callbacks, outside the clipped demonstration model.
    main.prepend(button,book);button.setAttribute('aria-controls','missionLogPanel');
    const sync=()=>button.setAttribute('aria-expanded',String(book.classList.contains('active')));sync();new MutationObserver(sync).observe(book,{attributes:true,attributeFilter:['class']});
  }
  const status=el('p','等待本人的雲端紀錄，不顯示示範星球。',{class:'facility-status',role:'status','aria-live':'polite'});scene.stage.append(status);
  let model=null,ctx=null,version=0;const life=root.NudgeObservatoryLife.mount(scene.stage,()=>model);
  const stars=el('div',null,{class:'observatory-stars','aria-label':role==='achievements'?'成就星圖':'七天成果星座'});scene.stage.append(stars);
  function clear(){++version;model=null;stars.replaceChildren();scene.close();status.textContent='等待本人的雲端紀錄，不顯示示範星球。';scene.setGuideLine('星圖還在等待雲端確認；不根據本機進度點亮。');life.redraw();}
  document.addEventListener('growth-clear',clear);
  function daily(d){const page=el('section',null,{class:'observatory-day'});page.append(el('h3',d.date+' 的冒險日誌'),el('p',d.recorded?'本日已確認的活動如下。':'本日尚無已確認活動；留白不代表沒有努力。'));const list=el('dl');for(const [k,title,unit]of [['focus','專注／學習','分鐘'],['exercise','運動','分鐘'],['sleep','已記錄睡眠','小時'],['steps','步數','步'],['tasks','完成委託','件']])list.append(el('dt',title),el('dd',String(d[k])+' '+unit));page.append(list);return page;}
  async function load(){clear();const own=version,scope=ctx;if(!scope?.user){status.textContent='登入後才會照亮自己的星圖。';return;}status.textContent='本人紀錄雲端確認中。';try{
      const range=root.NudgeLibrarySceneCore.range(new Date(),1),now=new Date(range.end),[rows,snap]=await Promise.all([world.sessions(scope,range.start,range.end),scope.db.collection('users').doc(scope.user.uid).get({source:'server'})]);world.confirmed(snap);if(!scope.alive()||version!==own)return;if(!snap.exists)throw Error('No owner profile');model=root.NudgeObservatorySceneCore.model(rows,snap.data(),now);
      const positions=[[12,25],[26,19],[40,14],[61,14],[76,20],[88,27],[51,42]];
      model.week.days.forEach((d,i)=>{const b=el('button',null,{class:'observatory-star'+(d.recorded?' is-lit':''),type:'button','aria-label':d.date+(d.recorded?'，已確認活動，查看日誌':'，尚無已確認活動，查看日誌')});b.style.left=positions[i][0]+'%';b.style.top=positions[i][1]+'%';b.append(el('span',d.recorded?'★':'☆',{'aria-hidden':'true'}),el('time',d.date.slice(5),{datetime:d.date}));b.addEventListener('click',()=>scene.open({title:d.date+' 的星光',content:daily(d)}));stars.append(b);});
      status.textContent='本週 '+model.activeDays+' 天有確認活動・'+(model.base?'新手星球已確認':'尚無確認的新手星球')+'・其他星球 '+model.planets.count+' 顆。植栽數代表本週活動天數，不是新增獎勵。';scene.setGuideLine('本週有 '+model.activeDays+' 天留下已確認活動。'+model.week.focus+' 分鐘專注／學習，'+model.week.tasks+' 件委託。點一顆日期星星，看看那一天。');life.redraw();
    }catch(_){if(!scope.alive()||version!==own)return;clear();status.textContent='尚未確認完整本人資料，請檢查連線後重試。';const retry=el('button','重試讀取',{type:'button',class:'w-btn'});retry.addEventListener('click',load);stars.append(retry);}}
  if(['observatory','planet'].includes(role)){world.connect(c=>{ctx=c;load();return clear;});}
  else if(role==='achievements'){
    status.textContent='本人徽章雲端確認中；未確認的星不會亮起。';const host=document.getElementById('achievementContent'),dialog=document.getElementById('achievementDialog');let selected=null;
    const paintStars=()=>{stars.replaceChildren();const buttons=[...host.querySelectorAll('.achievement-trophy')];status.textContent=buttons.length?'星圖已讀取本人雲端徽章；點星星看原有條件與稱號。':'本人徽章尚未確認。';buttons.forEach((original,i)=>{const name=original.querySelector('strong').textContent,lit=!original.classList.contains('is-locked'),b=el('button',lit?'★':'☆',{type:'button',class:'observatory-badge-star'+(lit?' is-lit':''),'aria-label':name+(lit?'，已點亮':'，尚未解鎖')});b.style.left=(12+(i%4)*25)+'%';b.style.top=(18+Math.floor(i/4)*8)+'%';b.title=name;b.addEventListener('click',()=>{selected=b;original.click();});stars.append(b);});scene.setGuideLine(buttons.length?'這些星光來自已確認的徽章取得日期，不根據本機進度補發。':'我們先等本人雲端紀錄，確認前不點亮。');};const observer=new MutationObserver(paintStars);const observe=()=>{observer.observe(host,{childList:true,subtree:true});paintStars();};observe();root.addEventListener('pageshow',observe);dialog.addEventListener('close',()=>selected?.isConnected&&selected.focus({preventScroll:true}));root.addEventListener('pagehide',()=>{observer.disconnect();selected=null;stars.replaceChildren();});
  }else{status.textContent=role==='builder'?'這是規劃工作台；預覽不是已取得的建築。':'成長年鑑沿用本人已確認紀錄。點書開始翻閱。';}
})(typeof globalThis!=='undefined'?globalThis:this);
