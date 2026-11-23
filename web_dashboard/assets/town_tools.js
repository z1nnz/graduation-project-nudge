(function(root){
  'use strict';
  const steps=[
    {title:'問題與定位',text:'從一件做得到的小事開始。Nudge 把日常行動、陪伴與回顧放在同一個循環，使用者保留自己的步調。'},
    {title:'日常行動',text:'由本人選任務與開始活動，成果以 Cloud Activity Ledger 接受的紀錄為準。畫面動畫不會代替使用者完成行動。'},
    {title:'關係與同意',text:'家庭與團體只看本人同意分享的摘要。管理者能提出共同目標，不能控制另一個人的活動。'},
    {title:'成長回顧',text:'紀錄館顯示有來源的本人活動與可修改的下一步；沒有資料就說明空狀態，提示不是健康或性格診斷。'},
    {title:'驗收與限制',text:'展示時應指出使用的提交版本、資料來源、CI 與實際驗收結果；未部署、實機或正式網站驗證未完成的項目要保留待驗。'}
  ];
  function scenarioDraft(title,body){
    if(typeof title!=='string'||!title.trim()||title.trim().length>120||typeof body!=='string'||!body.trim()||body.trim().length>8000)throw Error('請填寫120字內標題與8000字內內容。');
    return '展示敘事草稿（本人輸入，非正式研究結果）\n\n'+title.trim()+'\n\n'+body.trim()+'\n';
  }
  function catalogRows(docs){
    return docs.filter(d=>d.data?.status==='published').map(d=>({id:d.id,name:String(d.data.name||'未命名商品'),type:String(d.data.type||'未提供')}));
  }
  const api={steps,scenarioDraft,catalogRows};
  if(typeof module==='object'&&module.exports){module.exports=api;return;}
  const $=id=>document.getElementById(id);
  function node(tag,text){const e=document.createElement(tag);if(text!=null)e.textContent=String(text);return e;}
  function download(name,text){const url=URL.createObjectURL(new Blob([text],{type:'text/plain;charset=utf-8'})),a=node('a');a.href=url;a.download=name;document.body.append(a);a.click();a.remove();setTimeout(()=>URL.revokeObjectURL(url),0);}
  if($('scenarioForm')){
    let draft=null;
    $('scenarioForm').addEventListener('submit',e=>{e.preventDefault();try{draft=scenarioDraft($('scenarioTitle').value,$('scenarioBody').value);$('scenarioOutput').textContent=draft;$('scenarioDownload').disabled=false;$('scenarioStatus').textContent='草稿已產生；只在此頁，尚未保存到雲端。';}catch(e){$('scenarioStatus').textContent=e.message;}});
    for(const input of $('scenarioForm').querySelectorAll('input,textarea'))input.addEventListener('input',()=>{$('scenarioDownload').disabled=true;draft=null;$('scenarioStatus').textContent='內容已修改，請重新產生草稿後下載。';});
    $('scenarioDownload').addEventListener('click',()=>{if(draft)download('nudge-presentation-draft.txt',draft);});
  }
  if($('presentationSteps')){
    let current=0,revision=0;
    const paint=()=>{$('presentationTitle').textContent=steps[current].title;$('presentationText').textContent=steps[current].text;for(const [i,b]of [...$('presentationSteps').children].entries())b.setAttribute('aria-pressed',String(i===current));};
    for(const [i,step]of steps.entries()){const b=node('button',step.title);b.type='button';b.addEventListener('click',()=>{current=i;revision++;paint();});$('presentationSteps').append(b);}
    $('presentationNext').addEventListener('click',()=>{current=(current+1)%steps.length;revision++;paint();$('presentationTitle').tabIndex=-1;$('presentationTitle').focus();});
    $('presentationCopy').addEventListener('click',async()=>{const own=revision;try{if(!navigator.clipboard?.writeText)throw Error('Clipboard unavailable');await navigator.clipboard.writeText(steps[current].title+'\n'+steps[current].text);if(own===revision)$('presentationStatus').textContent='目前講稿已複製。';}catch(_){$('presentationStatus').textContent='瀏覽器未允許複製；可選取文字，或下載完整講稿。';}});
    $('presentationDownload').addEventListener('click',()=>download('nudge-presentation.txt',steps.map(s=>s.title+'\n'+s.text).join('\n\n')));paint();
  }
  // Keep labels and horizontal scrolling usable on the inherited admin forms.
  for(const group of document.querySelectorAll('.admin-form-group')){
    const label=group.querySelector('label'),fields=[...group.querySelectorAll('input,select,textarea')];
    fields.forEach((field,i)=>{if(!field.id)field.id='adminField_'+Math.random().toString(36).slice(2);if(label&&fields.length===1)label.htmlFor=field.id;else if(label&&!field.getAttribute('aria-label'))field.setAttribute('aria-label',label.textContent.trim()+(i?' '+(i+1):''));});
  }
  let started=false,authOff=null,docOff=null,dataOff=null,epoch=0;
  const isAdmin=document.body.dataset.townTool==='admin';
  const stopData=()=>{++epoch;docOff?.();docOff=null;dataOff?.();dataOff=null;if(isAdmin)root.clearAdminWorkbench?.('帳號或權限已改變；舊資料已清除。');if($('toolCatalogList'))$('toolCatalogList').replaceChildren();};
  function boot(){
    if(started||!root.firebase?.apps?.length||(!isAdmin&&!$('toolCatalogList')))return;started=true;
    authOff=root.firebase.auth().onAuthStateChanged(user=>{
      stopData();const own=epoch;
      if(isAdmin)for(const form of document.querySelectorAll('#adminWorkbench form'))form.reset();
      if(!user||user.isAnonymous){if($('toolCatalogStatus'))$('toolCatalogStatus').textContent='請先登入，再讀取正式已發布目錄。';return;}
      if(isAdmin){
        docOff=root.firebase.firestore().collection('users').doc(user.uid).onSnapshot({includeMetadataChanges:true},snap=>{
          if(own!==epoch)return;
          if(!snap.exists||snap.metadata.fromCache||snap.metadata.hasPendingWrites){root.clearAdminWorkbench('權限尚待 Cloud 確認。');return;}
          const data=snap.data();
          if(data.developerAccess!==true&&!['developer','operator','admin'].includes(data.staffRole)){root.clearAdminWorkbench('這個帳號沒有後台權限。');return;}
          root.enforceAdminAccess();
        },()=>{if(own===epoch)root.clearAdminWorkbench('無法讀取權限；舊資料已清除。');});
      }else{
        dataOff=root.firebase.firestore().collection('shop_items').where('status','==','published').onSnapshot({includeMetadataChanges:true},snap=>{
          if(own!==epoch)return;$('toolCatalogList').replaceChildren();
          if(snap.metadata.fromCache||snap.metadata.hasPendingWrites){$('toolCatalogStatus').textContent='目錄尚待 Cloud 確認；不顯示快取商品。';return;}
          const rows=catalogRows(snap.docs.map(d=>({id:d.id,data:d.data()})));
          $('toolCatalogStatus').textContent=rows.length?'已讀取正式已發布目錄；包含排程或已過期項目，不表示目前可購買。':'目前沒有正式已發布商品。';
          for(const row of rows){const card=node('article');card.append(node('h3',row.name),node('p','商品 ID：'+row.id+'；類型：'+row.type));$('toolCatalogList').append(card);}
        },()=>{if(own===epoch){$('toolCatalogList').replaceChildren();$('toolCatalogStatus').textContent='無法讀取正式目錄，請確認網路與權限。';}});
      }
    });
  }
  document.addEventListener('firebase-ready',boot);document.addEventListener('DOMContentLoaded',boot);
  root.addEventListener('pagehide',()=>{stopData();authOff?.();authOff=null;started=false;});
  root.addEventListener('pageshow',boot);boot();
})(typeof globalThis!=='undefined'?globalThis:this);
