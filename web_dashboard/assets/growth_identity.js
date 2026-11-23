(function(root){
  'use strict';
  function mount(ctx){
    const {host,ui,uid,db,alive}=ctx,{node,button,message}=ui;
    const content=node('div'),controls=node('div',null,{class:'museum-row'});host.append(controls,content);
    let stopped=false,busy=false,off=null,version=0;const live=()=>!stopped&&alive();
    const empty=text=>{content.replaceChildren(node('h2','身分書尚未就緒'),node('p',text));};
    function render(raw){
      const snapshot=root.NudgeDisciplineIdentityContract.parseDisciplineIdentity(uid,raw);
      content.replaceChildren();
      const intro=node('section',null,{class:'museum-panel'});
      intro.append(node('h2',snapshot.persona.title),node('p',snapshot.persona.description),node('p','本人私有快照；不公開給好友、家庭或團體。'));
      content.append(intro);
      if(snapshot.metrics.completedSessions===0)content.append(node('p','此觀察窗尚無已完成活動；不補入範例。',{class:'museum-empty'}));
      const grid=node('section',null,{class:'museum-grid','aria-label':'Cloud 身分快照指標'});
      for(const [key,label]of [['activeDays','活躍的自律日'],['completedSessions','已完成活動'],['focusMinutes','專注分鐘'],['exerciseMinutes','運動分鐘']]){
        const card=node('article',null,{class:'museum-panel'});card.append(node('h3',label),node('strong',snapshot.metrics[key]));grid.append(card);
      }
      content.append(grid);
      const next=node('section',null,{class:'museum-panel'});next.append(node('h2','為下一步留一點空間'),node('p',snapshot.recovery.message),
        node('a','考慮一段 '+snapshot.recovery.recommendedFocusMinutes+' 分鐘的專注',{href:'personal-focus.html?focus='+snapshot.recovery.recommendedFocusMinutes}),
        node('p','只開啟書桌，不會替你開始活動；中斷不扣分，也不需要補做錯過的份量。'));content.append(next);
      const source=node('details');source.append(node('summary','資料來源與觀察窗'),node('code','discipline_identity_snapshots/'+uid),
        node('p',snapshot.window.startedAt+' — '+snapshot.window.endedAt),node('p','最後更新：'+snapshot.updatedAt),
        node('p','最近28個05:00自律日的 canonical Activity Ledger；身分會隨新行動更新，不是性格或健康診斷。'));content.append(source);
      message('已讀取本人 Cloud 私有快照；數字不是本機推算。');
    }
    const refresh=button('依最新 Ledger 更新',async()=>{
      if(busy||!live())return;busy=true;refresh.disabled=true;const ownVersion=version;
      try{
        const result=await ctx.functions.httpsCallable('refreshDisciplineIdentity')({});
        if(live()&&ownVersion===version)render(result?.data?.snapshot);
      }catch(_){if(live()){empty('更新未完成，請確認登入、網路與網站驗證後重試。');message('未收到有效 Cloud 快照；沒有以本機資料代替。');}}
      finally{busy=false;if(live())refresh.disabled=false;}
    });refresh.id='refreshDisciplineIdentityBtn';controls.append(refresh);
    empty('正在從雲端讀取本人身分書。');
    off=db.collection('discipline_identity_snapshots').doc(uid).onSnapshot({includeMetadataChanges:true},snap=>{
      if(!live())return;++version;
      if(snap.metadata?.fromCache||snap.metadata?.hasPendingWrites){empty('目前只有快取或尚待同步；請連線後重試。');message('尚待雲端確認。');return;}
      if(!snap.exists){empty('尚未建立快照。你可以按「依最新 Ledger 更新」提出建立要求。');message('沒有本人快照，不會自動補入資料。');return;}
      try{render(snap.data());}catch(_){empty('快照格式或帳號不符，請重新更新。');message('無法確認此快照。');}
    },()=>{if(live()){empty('無法讀取，請確認網路與本人權限。');message('快照讀取失敗。');}});
    return()=>{stopped=true;off?.();content.replaceChildren();};
  }
  root.NudgeGrowthIdentity={mount};
})(typeof globalThis!=='undefined'?globalThis:this);
