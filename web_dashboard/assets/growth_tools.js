(function(root) {
  'use strict';
  const text=(value,max)=>typeof value==='string'&&value.trim().length>0&&value.trim().length<=max?value.trim():null;
  function validate(kind,title,body) {
    const t=text(title,120),b=text(body,8000);
    if(!['strategy','letter'].includes(kind)||!t||!b)throw Error('請填寫標題（120 字內）與內容（8000 字內）。');
    return {kind,title:t,body:b};
  }
  function taskDraft({id,uid,title,now}) {
    if(!/^[A-Za-z0-9_-]{8,128}$/.test(id)||!uid||!text(title,120))throw Error('任務草稿不完整。');
    return {id,userId:uid,title:title.trim(),category:'自定義',taskType:'fixed',priority:'medium',isDone:false,
      isSystemTask:false,isAutoTracked:false,sourceType:'manual',createdAt:now,updatedAt:now};
  }
  async function saveDocument({call,uid,id,revision,values}) {
    if(!call)throw Error('請先登入並完成網站驗證。');
    const data=await call({action:'save',documentId:id,revision,...values});
    if(data?.documentId!==id||data?.ownerUid!==uid||data?.status!=='saved'||!Number.isInteger(data.revision))throw Error('保存結果無法確認，請重試。');
    return data;
  }
  async function addTask({call,draft}) {
    if(!call)throw Error('請先登入並完成網站驗證。');
    const data=await call({action:'createTask',taskId:draft.id,title:draft.title});
    if(data?.taskId!==draft.id||!['created','existing'].includes(data?.status))throw Error('任務結果無法確認。');
    return data;
  }
  function mount(ctx) {
    const {host,ui,uid,db,alive,route}=ctx,{node,button,message,download}=ui;
    const kind=route.id==='letter'?'letter':'strategy';
    const call=async payload=>{if(!alive()||ctx.demo)throw Error('此模式不能寫入。');const response=await ctx.functions.httpsCallable('manageGrowthDocument')(payload);if(!alive())return null;return response.data;};
    let selected=null,revision=0,off=null,stopped=false,busy=false,requestId=null,draftId=null;
    const live=()=>!stopped&&alive();
    const newId=prefix=>{
      if(!root.crypto?.randomUUID)throw Error('瀏覽器尚不支援安全的請求識別，請使用最新瀏覽器與 HTTPS。');
      return prefix+root.crypto.randomUUID().replaceAll('-','_');
    };
    const form=node('form',null,{class:'museum-panel'});
    const title=node('input',null,{maxlength:120,required:true,autocomplete:'off'});
    const body=node('textarea',null,{maxlength:8000,required:true,rows:8});
    const label1=node('label',kind==='letter'?'信件標題':'下一步標題');label1.append(title);
    const label2=node('label','內容（可自由修改）');label2.append(body);
    const state=node('p','尚未保存。',{role:'status'});
    form.append(node('h2',kind==='letter'?'寫給未來的自己':'把建議變成你自己的下一步'),label1,label2,state);
    const actions=node('div',null,{class:'museum-row'}),list=node('section',null,{'aria-label':'已保存文件'});
    async function action(fn) {
      if(busy||!live())return;
      if(ctx.demo){message('展示模式不能保存、刪除或建立正式任務。');return;}
      busy=true;for(const b of actions.querySelectorAll('button'))b.disabled=true;
      try{await fn();}catch(error){if(live())state.textContent=error.message||'未完成，請確認網路後重試。';}
      finally{busy=false;if(live())for(const b of actions.querySelectorAll('button'))b.disabled=false;}
    }
    const save=button('保存到我的紀錄',()=>action(async()=>{
      const values=validate(kind,title.value,body.value);
      requestId ||= selected||newId('growth_');
      const result=await saveDocument({call,uid,id:requestId,revision,values});
      if(!live())return;
      selected=result.documentId;revision=result.revision;state.textContent='已由雲端確認保存。';message('文件已同步，可在另一個裝置讀取。');
    }));
    const reset=()=>{selected=null;revision=0;requestId=null;draftId=null;title.value='';body.value='';state.textContent='新的文件，尚未保存。';title.focus();};
    const fresh=button('寫一份新的',reset);
    const exportText=button('下載目前文字',()=>{try{const v=validate(kind,title.value,body.value);download(kind==='letter'?'nudge-letter.txt':'nudge-strategy.txt',v.title+'\n\n'+v.body);}catch(e){state.textContent=e.message;}});
    actions.append(save,fresh,exportText);
    if(kind==='strategy') {
      const task=button('確認後加入我的任務',()=>action(async()=>{
        const values=validate(kind,title.value,body.value);
        if(!root.confirm('將「'+values.title+'」加入未完成的手動任務？不會開始活動或發放獎勵。'))return;
        draftId ||= newId('museum_task_');
        const created=await addTask({call,draft:taskDraft({id:draftId,uid,title:values.title,now:new Date().toISOString()})});
        if(live()){state.textContent=created.status==='created'?'已加入未完成任務。可到任務頁調整與開始。':'這份任務已存在，請到任務頁查看目前狀態。';message('已完成任務建立；沒有完成任務或核發獎勵。');}
      }));
      actions.append(task,node('a','開啟既有任務流程',{href:'planet.html'}));
      if(new URLSearchParams(root.location?.search||'').get('idea')==='gentle-focus'){
        title.value='先做一個小段落';body.value='選一件現在做得到的小事，調整時間與內容；要不要開始，由我自己決定。';
        state.textContent='這是可編輯的建議草稿，尚未保存或加入任務。';
      }
    }
    form.addEventListener('submit',e=>e.preventDefault());form.append(actions);host.append(form,list);
    if(ctx.demo){save.disabled=true;list.append(node('p','虛構展示不載入任何人的文件。'));return()=>{stopped=true;};}
    off=db.collection('users').doc(uid).collection('growth_documents').where('kind','==',kind)
      .onSnapshot({includeMetadataChanges:true},snap=>{
        if(!live())return;
        list.replaceChildren(node('h2','我的'+(kind==='letter'?'信件':'策略')));
        if(snap.metadata?.fromCache||snap.metadata?.hasPendingWrites)message('文件來自快取或正在同步，尚不能視為另一裝置已確認。');
        else message('已讀取本人私有文件；可跨裝置保存。');
        const docs=snap.docs.filter(d=>d.data().ownerUid===uid&&d.data().kind===kind).sort((a,b)=>(b.data().updatedAt?.toMillis?.()||0)-(a.data().updatedAt?.toMillis?.()||0));
        if(!docs.length)list.append(node('p','尚未保存任何文件。',{class:'museum-empty'}));
        for(const doc of docs){
          const d=doc.data(),card=node('article',null,{class:'museum-panel'}),controls=node('div',null,{class:'museum-row'});
          controls.append(button('修改',()=>{selected=doc.id;requestId=doc.id;revision=d.revision;title.value=d.title;body.value=d.body;draftId=null;state.textContent='編輯版本 '+revision+'；保存前不會改變雲端。';title.focus();}),
            button('下載',()=>download(kind==='letter'?'nudge-letter.txt':'nudge-strategy.txt',d.title+'\n\n'+d.body)),
            button('刪除',()=>action(async()=>{
              if(!root.confirm('刪除這份文字？這會同步到其他裝置。'))return;
              await call({action:'delete',documentId:doc.id,revision:d.revision});
              if(live()){if(selected===doc.id)reset();message('已刪除這份文件。');}
            })));
          card.append(node('h3',d.title),node('pre',d.body),controls);list.append(card);
        }
      },()=>{if(live()){list.replaceChildren(node('p','文件讀取失敗。請確認網路或權限後重新整理。'));message('無法讀取文件；沒有使用 Demo localStorage 代替。');}});
    return()=>{stopped=true;off?.();title.value='';body.value='';};
  }
  const api={validate,taskDraft,saveDocument,addTask,mount};
  if(typeof module==='object'&&module.exports)module.exports=api;else root.NudgeGrowthTools=api;
})(typeof globalThis!=='undefined'?globalThis:this);
