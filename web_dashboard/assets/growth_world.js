(function(root){
  'use strict';
  const doc=root.document;
  function el(tag,text,attrs={}){const n=doc.createElement(tag);if(text!==undefined&&text!==null)n.textContent=String(text);for(const [k,v]of Object.entries(attrs))n.setAttribute(k,String(v));return n;}
  function button(text,fn){const n=el('button',text,{type:'button',class:'w-btn'});n.addEventListener('click',fn);return n;}
  function say(text){const status=doc.getElementById('growthStatus');if(status)status.textContent=text;}
  function confirmed(snap){if(snap.metadata?.fromCache||snap.metadata?.hasPendingWrites)throw Error('Awaiting Cloud confirmation');return snap;}
  function connect(render){
    let version=0,off=null,stop=()=>{},active=false;
    function boot(){
      if(active||!root.firebase?.apps?.length)return;active=true;
      off=root.firebase.auth().onAuthStateChanged(async user=>{
        const own=++version;stop();stop=()=>{};
        const alive=()=>active&&own===version&&root.firebase.auth().currentUser?.uid===user?.uid;
        const ctx={user:user&&!user.isAnonymous?user:null,db:root.firebase.firestore(),alive,functions:root.firebase.app().functions('asia-east1')};
        try{const cleanup=await render(ctx);if(alive())stop=typeof cleanup==='function'?cleanup:()=>{};else if(typeof cleanup==='function')cleanup();}
        catch(_){if(alive())say('這次無法讀取。請檢查連線後重試；未用範例代替本人資料。');}
      });
    }
    doc.addEventListener('firebase-ready',boot);
    root.addEventListener('pagehide',()=>{++version;active=false;off?.();off=null;stop();stop=()=>{};doc.dispatchEvent(new Event('growth-clear'));});
    root.addEventListener('pageshow',boot);
    if(!root.firebase?.apps?.length){const s=el('script',null,{src:'assets/app.js?v=30&surface=growth-world-1'});s.onerror=()=>say('連線未就緒，請重新整理。');doc.head.append(s);}boot();
  }
  async function sessions(ctx,start,end){
    const now=new Date().toISOString();
    const snap=confirmed(await ctx.db.collection('activity_sessions').where('actorUserId','==',ctx.user.uid).where('status','==','completed').where('endedAt','>=',start).where('endedAt','<',end).orderBy('endedAt','desc').limit(501).get({source:'server'}));
    if(!ctx.alive())throw Error('Account changed');if(snap.docs.length>500)throw Error('Month exceeds safe query limit');
    const rows=[];for(const d of snap.docs){const row=await root.NudgeGrowthReview.parseSession(d.id,d.data(),ctx.user.uid,now);if(!row)throw Error('Invalid receipt');if(!row.withdrawn)rows.push(row);}
    if(!ctx.alive())throw Error('Account changed');return rows;
  }
  function signedOut(host){host.replaceChildren(el('h2','這一頁只屬於你'),el('p','登入後讀取本人的雲端紀錄。'),el('a','登入帳號',{href:'login.html',class:'w-btn'}));say('尚未登入；沒有載入個人資料。');}
  root.NudgeGrowthWorld=Object.freeze({el,button,say,confirmed,connect,sessions,signedOut});
})(typeof globalThis!=='undefined'?globalThis:this);
