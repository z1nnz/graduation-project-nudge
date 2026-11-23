(function(root) {
  'use strict';
  const types={focus:['專注','minutes',1440],study:['學習','minutes',1440],exercise:['運動','minutes',1440],steps:['步數','steps',200000],sleep:['睡眠','hours',24],task:['任務','completion',1]};
  const day=86400000;
  const iso=value => typeof value==='string' && /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/.test(value) && Number.isFinite(Date.parse(value)) && new Date(value).toISOString()===value;
  function dayKey(ms){return new Date(ms+3*3600000).toISOString().slice(0,10);}
  function period(kind,now) {
    const n=new Date(now);if(!Number.isFinite(n.getTime())||!['day','week','month'].includes(kind))throw Error('period');
    const logical=new Date(n.getTime()+3*3600000);
    const midnight=Date.UTC(logical.getUTCFullYear(),logical.getUTCMonth(),logical.getUTCDate())-3*3600000;
    let start=midnight,previous=midnight-day;
    if(kind==='week'){start=midnight-((logical.getUTCDay()+6)%7)*day;previous=start-7*day;}
    if(kind==='month'){start=Date.UTC(logical.getUTCFullYear(),logical.getUTCMonth(),1)-3*3600000;previous=Date.UTC(logical.getUTCFullYear(),logical.getUTCMonth()-1,1)-3*3600000;}
    return {kind,start:new Date(start).toISOString(),end:n.toISOString(),previousStart:new Date(previous).toISOString(),
      previousEnd:new Date(Math.min(previous+(n.getTime()-start),start)).toISOString()};
  }
  async function hashFingerprint(value) {
    const bytes=await root.crypto.subtle.digest("SHA-256",new TextEncoder().encode(value));
    return Array.from(new Uint8Array(bytes),b=>b.toString(16).padStart(2,"0")).join("");
  }
  async function parseSession(id,data,uid,now) {
    const type=data&&types[data.activityType];
    if(!type||typeof data.activitySessionId!=='string'||!data.activitySessionId||typeof data.activityFingerprint!=='string'||
      !/^[a-f0-9]{64}$/.test(id)||data.actorUserId!==uid||data.status!=='completed'||
      !iso(data.startedAt)||!iso(data.endedAt)||Date.parse(data.startedAt)>Date.parse(data.endedAt)||Date.parse(data.endedAt)>new Date(now).getTime()||
      data.metricUnit!==type[1]||typeof data.metricValue!=='number'||!Number.isFinite(data.metricValue)||data.metricValue<0||data.metricValue>type[2]||
      !['app','web','device','health'].includes(data.source))return null;
    if(await hashFingerprint(data.activityFingerprint)!==id)return null;
    // A Cloud-confirmed undo of a task is not a completed task.
    if(data.activityType==='task'&&data.metricValue!==1)return {withdrawn:true};
    return {id,type:data.activityType,label:type[0],value:data.metricValue,unit:data.metricUnit,endedAt:data.endedAt,
      source:data.source,reference:'activity_sessions/'+id,day:dayKey(Date.parse(data.endedAt))};
  }
  function summarize(rows,p) {
    const select=(start,end,exclusive=false)=>rows.filter(r=>r.endedAt>=start&&(exclusive?r.endedAt<end:r.endedAt<=end));
    const total=items=>({sessions:items.length,activeDays:new Set(items.map(r=>r.day)).size,
      focusMinutes:items.filter(r=>['focus','study'].includes(r.type)).reduce((v,r)=>v+r.value,0),
      exerciseMinutes:items.filter(r=>r.type==='exercise').reduce((v,r)=>v+r.value,0)});
    return {current:total(select(p.start,p.end)),previous:total(select(p.previousStart,p.previousEnd,true))};
  }
  function bookmarks(rows) {
    return [
      {name:'第一頁行動',condition:'此檢視期間至少 1 筆本人已完成活動',met:rows.length>=1},
      {name:'專注的一頁',condition:'此檢視期間專注／學習合計至少 25 分鐘',met:rows.filter(r=>['focus','study'].includes(r.type)).reduce((n,r)=>n+r.value,0)>=25},
      {name:'再次回來',condition:'此檢視期間至少 2 個不同的 05:00 邏輯日有已完成活動',met:new Set(rows.map(r=>r.day)).size>=2},
    ];
  }
  async function mount(ctx) {
    const {host,ui,uid,db,alive,route}=ctx,{node,button,message,download}=ui;
    const controls=node('div',null,{class:'museum-row'});
    const range=node('select',null,{'aria-label':'回顧期間'});
    for(const [value,label] of [['day','今日'],['week','本週'],['month','本月']])range.append(node('option',label,{value}));
    range.value='week';
    const content=node('div');let request=0,stopped=false;
    const current=()=>!stopped&&alive();
    controls.append(range,button('重新讀取',load));host.append(controls,content);
    range.addEventListener('change',load);
    async function load() {
      const token=++request,now=new Date(),p=period(range.value,now);
      content.replaceChildren(node('p','正在翻閱活動帳本……'));message(ctx.demo?'展示模式：虛構活動，不能當正式成果。':'正在從雲端讀取本人已完成活動。');
      let docs,metadata={};
      try {
        if(ctx.demo){
          const values=[25,15,30];
          docs=await Promise.all(values.map(async(value,i)=>({id:await hashFingerprint('demo-'+i),data:()=>({activitySessionId:'demo-'+i,activityFingerprint:'demo-'+i,actorUserId:uid,status:'completed',activityType:'focus',metricValue:value,metricUnit:'minutes',source:'web',
            startedAt:new Date(now.getTime()-(i+1)*day-value*60000).toISOString(),endedAt:new Date(now.getTime()-(i+1)*day).toISOString()})})));
        } else {
          const result=await db.collection('activity_sessions').where('actorUserId','==',uid).where('status','==','completed')
            .where('endedAt','>=',p.previousStart).where('endedAt','<=',p.end).orderBy('endedAt','desc').limit(501).get({source:'server'});
          docs=result.docs;metadata=result.metadata||{};
        }
        if(!current()||token!==request)return;
        if(metadata.fromCache||metadata.hasPendingWrites)throw Error('cache');
        const unique=new Set(),rows=[];let invalid=0,withdrawn=0;
        for(const doc of docs){
          const row=await parseSession(doc.id,doc.data(),uid,now);
          if(!row||unique.has(doc.id)){invalid++;continue;}
          unique.add(doc.id);if(row.withdrawn){withdrawn++;continue;}rows.push(row);
        }
        if(!current()||token!==request)return;
        const complete=docs.length<=500&&invalid===0;
        const summary=complete?summarize(rows,p):null;
        content.replaceChildren();
        message((ctx.demo?'虛構展示。':'已讀取雲端已完成活動。')+(complete?'此視窗資料完整。':'資料超出 500 筆或格式不符；不提供完整總計，請縮小期間或重試。'));
        content.append(node('p','回顧依 Asia/Taipei 05:00 換日。本人活動只計一次；不加總家庭、團體 XP 或自律幣。'));
        const sources=node('details'),explain=node('summary','期間與資料來源');
        sources.append(explain,node('p','本期：'+p.start+' — '+p.end),node('p','比較期（上期相同經過時間）：'+p.previousStart+' — '+p.previousEnd),
          node('p','來源：activity_sessions，actorUserId=本人，status=completed。一次完整查詢；超出上限不假裝完整。'),
          node('p','未納入格式不符 '+invalid+' 筆；已撤回任務 '+withdrawn+' 筆。'));
        content.append(sources);
        if(!complete)content.append(node('a','需要完整資料？使用正式隱私匯出',{href:'privacy.html'}));
        if(summary) {
          const totals=node('section',null,{class:'museum-grid','aria-label':'已確認活動回顧'});
          for(const [key,label] of [['sessions','已完成活動（筆）'],['activeDays','有活動的邏輯日'],['focusMinutes','專注／學習分鐘'],['exerciseMinutes','運動分鐘']]){
            const card=node('article',null,{class:'museum-panel'});
            card.append(node('h2',label),node('strong',summary.current[key]),node('p','上期同期：'+summary.previous[key]+'；差值 '+(summary.current[key]-summary.previous[key])));
            totals.append(card);
          }
          content.append(totals);
        }
        const selected=rows.filter(r=>r.endedAt>=p.start&&r.endedAt<=p.end);
        if(!selected.length)content.append(node('p','這個期間尚無可顯示的已完成活動；不等於沒有努力，也不補入範例。',{class:'museum-empty'}));
        if(route.id==='skills'){
          content.append(node('h2','閱讀書籤'),node('p','以下只是可檢查的回顧條件，不發放等級、物品或獎勵。正式技能 Lv／解鎖規則：尚未提供。'));
          for(const mark of bookmarks(complete?selected:[])){
            const card=node('article',null,{class:'museum-panel','data-bookmark':complete&&mark.met?'met':'pending'});
            card.append(node('h3',mark.name),node('p',mark.condition),node('strong',!complete?'資料未完整，尚不能判斷':mark.met?'已符合回顧條件':'尚未符合回顧條件'));content.append(card);
          }
        }
        if(['weather','pressure'].includes(route.id)){
          content.append(node('h2',route.id==='weather'?'回顧生活天氣':'為下一步留一點空間'),
            node('p',complete&&selected.length?'這段期間有可追溯的活動。你可以維持步調，也可以調整成更小的一步。':'資料不足以形成活動回顧。你仍可自己選擇下一步。'),
            node('p','這不是預測或壓力／睡眠／健康診斷，活動量不能說明你的心情。'),
            node('a','編輯一個溫和的下一步',{href:'personal-template.html?idea=gentle-focus'}));
        }
        const exportButton=button('匯出這份回顧',()=>download('nudge-growth-review.json',JSON.stringify({mode:ctx.demo?'fictional-demo':'Cloud-confirmed sessions',period:p,summary,rows},null,2)));
        exportButton.disabled=!complete;content.append(exportButton);
        const list=node('ol',null,{class:'museum-timeline','aria-label':'行動時間線'}),paging=node('div',null,{class:'museum-row'});let page=0;
        const paint=()=>{
          list.replaceChildren();
          for(const row of selected.slice(page*20,(page+1)*20)){
            const li=node('li');const details=node('details');
            details.append(node('summary','查看來源'),node('code',row.reference),node('p','紀錄來源：'+row.source+'；不表示獎勵已核發。'));
            li.append(node('time',row.endedAt,{datetime:row.endedAt}),node('h3',row.label+' · '+row.value+' '+row.unit),details);list.append(li);
          }
          paging.replaceChildren();
          const prev=button('上一頁',()=>{page--;paint();list.focus();}),next=button('下一頁',()=>{page++;paint();list.focus();});
          prev.disabled=page===0;next.disabled=(page+1)*20>=selected.length;
          list.tabIndex=-1;paging.append(prev,node('span','第 '+(page+1)+' 頁，共 '+Math.max(1,Math.ceil(selected.length/20))+' 頁'),next);
        };
        paint();content.append(list,paging);
      } catch(_) {
        if(!current()||token!==request)return;
        content.replaceChildren(node('h2','這次還不能讀取紀錄'),node('p','可能是網路、權限或索引尚未就緒。沒有以本機資料或固定數字補上。'),button('重試',load));
        message('讀取失敗或尚待雲端確認。');
      }
    }
    load();return()=>{stopped=true;++request;};
  }
  const api={period,dayKey,hashFingerprint,parseSession,summarize,bookmarks,mount};
  if(typeof module==='object'&&module.exports)module.exports=api;else root.NudgeGrowthReview=api;
})(typeof globalThis!=='undefined'?globalThis:this);
