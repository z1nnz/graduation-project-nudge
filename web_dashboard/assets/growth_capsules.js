(function(root) {
  'use strict';
  const validId=id=>typeof id==='string'&&/^[A-Za-z0-9_-]{8,128}$/.test(id);
  const knownCodes={
    'functions/failed-precondition':'尚未到開封時間、已取消，或帳號目前無法操作。',
    'functions/unauthenticated':'請重新登入並完成網站驗證。',
    'functions/permission-denied':'目前沒有這封信的讀取權限。',
    'functions/already-exists':'此請求已保存不同內容；請重新讀取或另寫一封。',
    'functions/invalid-argument':'請確認標題、內容，以及未來的開封日期。',
    'functions/resource-exhausted':'保存數量已達上限，請先整理既有膠囊。',
  };
  function parseMetadata(id,data,uid) {
    if(!validId(id)||data?.capsuleId!==id||data?.ownerUid!==uid||data.schemaVersion!==1||
      !['sealed','opened','cancelled'].includes(data.status)||typeof data.title!=='string'||
      typeof data.unlockAt!=='string'||!Number.isFinite(Date.parse(data.unlockAt))||'message' in data)return null;
    return {id,...data};
  }
  function mount(ctx) {
    const {host,ui,uid,db,functions,alive}=ctx,{node,button,message,download}=ui;
    let stopped=false,off=null,busy=false,sealId=null;
    const live=()=>!stopped&&alive();
    const form=node('form',null,{class:'museum-panel'});
    const title=node('input',null,{required:true,maxlength:120,autocomplete:'off'});
    const date=node('input',null,{type:'date',required:true});
    const body=node('textarea',null,{required:true,maxlength:8000,rows:8,autocomplete:'off'});
    for(const [label,input] of [['膠囊標題',title],['開封日（Asia/Taipei 當日 00:00）',date],['想封存的文字',body]]){
      const l=node('label',label);l.append(input);form.append(l);
    }
    const note=node('p','封存後不能提前讀取或修改正文。取消會擦除正文；刪除會移除膠囊。開封以伺服器時間為準。');
    const result=node('section',null,{class:'museum-panel','aria-label':'開封結果',hidden:true});
    const output=node('pre');result.append(node('h2','開封的信'),output);
    const list=node('section',null,{'aria-label':'我的時間膠囊'});
    const error=node('p','尚未封存。',{role:'status'});
    async function call(action,id,payload) {
      if(!live()||ctx.demo)throw Error('read-only');
      const response=await functions.httpsCallable('manageGrowthCapsule')({action,capsuleId:id,...payload});
      if(!live())return null;
      const data=response?.data;
      if(!data||typeof data.serverNow!=='string'||
        (action==='delete'?data.status!=='deleted':data.capsule?.ownerUid!==uid||data.capsule?.capsuleId!==id))throw Error('invalid-result');
      return data;
    }
    async function act(fn) {
      if(busy||!live())return;
      busy=true;const buttons=host.querySelectorAll('button');for(const b of buttons)b.disabled=true;
      try{await fn();}
      catch(e){if(live()){error.textContent=knownCodes[e.code]||'這次沒有完成。請確認網路後重試；不會以本機時間解鎖。';message('操作尚未確認，請重試或重新讀取。');}}
      finally{busy=false;if(live())for(const b of host.querySelectorAll('button'))b.disabled=false;}
    }
    const seal=button('確認封存',()=>act(async()=>{
      if(!title.value.trim()||!body.value.trim()||!date.value){error.textContent='請填寫標題、日期與內容。';return;}
      if(!root.confirm('封存後到指定日期才可讀，不能提前修改。確認封存？'))return;
      if(!sealId){
        if(!root.crypto?.randomUUID)throw Error('no-secure-id');
        sealId='capsule_'+root.crypto.randomUUID().replaceAll('-','_');
      }
      const saved=await call('seal',sealId,{title:title.value,message:body.value,unlockDate:date.value});
      if(!saved||!live())return;
      if(!['sealed','opened'].includes(saved.capsule.status))throw Error('not-sealed');
      title.value='';body.value='';date.value='';sealId=null;
      error.textContent='已封存。伺服器現在時間：'+saved.serverNow+'。';
      message('正文不會保存在 localStorage，也不會在膠囊清單中傳回。');
    }));
    form.addEventListener('submit',e=>e.preventDefault());
    const fresh=button('寫新的一封',()=>{
      if((title.value||body.value||date.value)&&!root.confirm('清空這份尚未封存的草稿？已封存的信不受影響。'))return;
      title.value='';body.value='';date.value='';sealId=null;error.textContent='新的草稿，尚未封存。';title.focus();
    });
    form.append(note,seal,fresh,error);host.append(form,result,list);
    if(ctx.demo){seal.disabled=true;message('此為展示，沒有建立真實膠囊。');return()=>{stopped=true;};}
    off=db.collection('users').doc(uid).collection('growth_capsules').onSnapshot({includeMetadataChanges:true},snapshot=>{
      if(!live())return;
      list.replaceChildren(node('h2','我的膠囊櫃'));
      const cached=snapshot.metadata?.fromCache||snapshot.metadata?.hasPendingWrites;
      message(cached?'清單正在等待雲端確認；開封仍須向伺服器驗證。':'已同步本人私有清單。開封是否到期以伺服器回應為準。');
      let count=0;
      for(const doc of snapshot.docs){
        const capsule=parseMetadata(doc.id,doc.data(),uid);if(!capsule)continue;count++;
        const card=node('article',null,{class:'museum-panel','data-capsule-state':capsule.status});
        const controls=node('div',null,{class:'museum-row'});
        if(capsule.status!=='cancelled'){
          // Always ask the server; changing Date.now() never unlocks content.
          const open=action=>act(async()=>{
            result.hidden=true;output.textContent='';
            const response=await call(action,capsule.id);
            if(!response||!live())return;
            if(typeof response.capsule.message!=='string')throw Error('missing-body');
            if(action==='export')download('nudge-capsule.txt',response.capsule.title+'\n\n'+response.capsule.message);
            else{result.dataset.openedId=capsule.id;result.hidden=false;output.textContent=response.capsule.title+'\n\n'+response.capsule.message;result.tabIndex=-1;result.focus();}
            error.textContent='伺服器已確認到期，只向本人提供正文。';
          });
          controls.append(button('向伺服器申請開封',()=>open('open')),button('到期後匯出',()=>open('export')),
            button('取消並擦除正文',()=>act(async()=>{
              if(!root.confirm('取消封存並永久擦除正文？'))return;
              await call('cancel',capsule.id);
              if(live()){output.textContent='';result.hidden=true;error.textContent='已取消，正文已擦除。';}
            })));
        }
        controls.append(button('刪除膠囊',()=>act(async()=>{
          if(!root.confirm('永久刪除膠囊與正文，並同步到其他裝置？'))return;
          await call('delete',capsule.id);
          if(live()){output.textContent='';result.hidden=true;error.textContent='已刪除膠囊。重送舊請求也不會恢復正文。';}
        })));
        card.append(node('h3',capsule.title),node('p','開封時刻：'+capsule.unlockAt),node('strong',{sealed:'封存中',opened:'已開封',cancelled:'已取消（正文已擦除）'}[capsule.status]),controls);
        list.append(card);
      }
      if(snapshot.docs.length>count)list.append(node('p','部分膠囊資料無法核對，未顯示其內容。請稍後重試。'));
      if(!count&&!snapshot.docs.length)list.append(node('p','尚未保存任何膠囊。',{class:'museum-empty'}));
      if(!snapshot.docs.some(d=>d.id===result.dataset.openedId&&d.data().status==='opened')){output.textContent='';result.hidden=true;}
    },()=>{if(live()){output.textContent='';result.hidden=true;list.replaceChildren(node('p','清單讀取失敗，請重新整理或重新登入。'));message('無法同步；沒有從本機補入膠囊內容。');}});
    return()=>{stopped=true;off?.();body.value='';title.value='';output.textContent='';result.hidden=true;};
  }
  const api={validId,parseMetadata,mount};
  if(typeof module==='object'&&module.exports)module.exports=api;else root.NudgeGrowthCapsules=api;
})(typeof globalThis!=='undefined'?globalThis:this);
