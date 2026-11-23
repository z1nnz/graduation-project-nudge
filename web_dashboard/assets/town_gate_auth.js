(function(root){
  'use strict';
  const target='town.html';
  function initialProfile(user,stamp){
    return {id:user.uid,email:user.email||'',nickname:'自律使用者',myNudgeId:'NDG_'+user.uid.substring(0,6).toUpperCase(),
      username:'NDG_'+user.uid.substring(0,6).toUpperCase(),planetCount:0,weeklyPlanetEarned:false,tasks:[],dailySummaries:[],createdAt:stamp,updatedAt:stamp};
  }
  async function ensureProfile({db,user,stamp,alive}){
    if(!user?.uid||user.isAnonymous)throw Error('請使用本人帳號登入。');
    const ref=db.collection('users').doc(user.uid);
    await db.runTransaction(async tx=>{
      const existing=await tx.get(ref);
      if(!alive())throw Error('帳號已切換，請重新操作。');
      if(!existing.exists)tx.set(ref,initialProfile(user,stamp()));
    });
    if(!alive())throw Error('帳號已切換，舊回應已忽略。');
  }
  const api={target,initialProfile,ensureProfile};
  if(typeof module==='object'&&module.exports){module.exports=api;return;}
  if(!document.querySelector('[data-town-gate="login"]'))return;
  const $=id=>document.getElementById(id),form=$('loginForm'),submit=$('submitBtn'),error=$('errorMsg'),note=$('gateAuthStatus');
  let auth=null,db=null,authOff=null,register=false,busy=false,started=false,epoch=0;
  const buttons=[...document.querySelectorAll('button')];
  function sayError(text){error.textContent=text;error.hidden=!text;}
  function lock(value){busy=value;buttons.forEach(b=>b.disabled=value||!auth);for(const i of form.querySelectorAll('input'))i.disabled=value;}
  function clearPreview(){
    for(const key of ['nudgePreviewMode','nudgePreviewRole','nudgeActiveDemoUserId','nudgePostLoginRedirect'])localStorage.removeItem(key);
  }
  function mode(value){
    if(busy)return;register=value;$('tabLogin').setAttribute('aria-pressed',String(!value));$('tabRegister').setAttribute('aria-pressed',String(value));
    $('groupConfirm').hidden=!value;$('inputConfirmPassword').required=value;$('inputPassword').autocomplete=value?'new-password':'current-password';
    submit.textContent=value?'建立帳號並進入小鎮':'登入並進入小鎮';sayError('');
  }
  $('tabLogin').addEventListener('click',()=>mode(false));$('tabRegister').addEventListener('click',()=>mode(true));
  document.querySelectorAll('[data-password-toggle]').forEach(b=>b.addEventListener('click',()=>{
    const input=$(b.dataset.passwordToggle),visible=input.type==='password';input.type=visible?'text':'password';b.setAttribute('aria-pressed',String(visible));b.textContent=visible?'隱藏密碼':'顯示密碼';
  }));
  async function finish(user,ownEpoch){
    await ensureProfile({db,user,stamp:()=>root.firebase.firestore.FieldValue.serverTimestamp(),alive:()=>epoch===ownEpoch&&auth.currentUser?.uid===user.uid});
    clearPreview();localStorage.setItem('nudgeWebLoggedIn','true');localStorage.setItem('nudgeActiveDemoUserId',user.uid);
    root.location.assign(target);
  }
  async function perform(signIn,verification=false){
    if(busy||!auth)return;const ownEpoch=epoch;lock(true);sayError('');note.textContent='正在登入並確認帳號資料…';
    try{
      const result=await signIn();
      if(epoch!==ownEpoch)throw Error('登入畫面已離開，請重新操作。');
      if(verification)result.user.sendEmailVerification().catch(()=>{});
      await finish(result.user,ownEpoch);
    }catch(e){
      if(epoch===ownEpoch){sayError('尚未完成：'+(e.message||'登入失敗，請重試。'));note.textContent='尚未進入小鎮。若已登入但同步失敗，可按「以目前帳號進入小鎮」重試。';}
    }finally{if(epoch===ownEpoch)lock(false);}
  }
  form.addEventListener('submit',e=>{
    e.preventDefault();if(!form.reportValidity()||!auth||busy)return;
    const email=$('inputEmail').value.trim(),password=$('inputPassword').value;
    if(register&&password!==$('inputConfirmPassword').value){sayError('兩次輸入的密碼不一致。');return;}
    perform(()=>register?auth.createUserWithEmailAndPassword(email,password):auth.signInWithEmailAndPassword(email,password),register);
  });
  $('btnGoogle').addEventListener('click',()=>perform(()=>auth.signInWithPopup(new root.firebase.auth.GoogleAuthProvider())));
  $('btnFacebook').addEventListener('click',()=>perform(()=>auth.signInWithPopup(new root.firebase.auth.FacebookAuthProvider())));
  $('gateContinue').addEventListener('click',()=>perform(async()=>({user:auth.currentUser})));
  $('gateSignOut').addEventListener('click',async()=>{if(busy)return;lock(true);try{await auth.signOut();clearPreview();note.textContent='登入服務已就緒，請選擇登入或建立帳號。';}catch(e){sayError(e.message);}finally{lock(false);}});
  $('gateGuest').addEventListener('click',clearPreview);
  async function boot(){
    if(started||!root.firebase?.apps?.length)return;started=true;auth=root.firebase.auth();db=root.firebase.firestore();
    try{await auth.setPersistence(root.firebase.auth.Auth.Persistence.LOCAL);}catch(_){note.textContent='瀏覽器無法保存登入狀態；本次登入仍可嘗試。';}
    if(!started)return;
    authOff=auth.onAuthStateChanged(user=>{
      $('gateCurrentAccount').hidden=!user||user.isAnonymous;
      if(!busy)note.textContent=user&&!user.isAnonymous?'目前已有登入帳號，可直接進入小鎮或登出換帳號。':'登入服務已就緒，請選擇登入或建立帳號。';
      if(!user){$('inputPassword').value='';$('inputConfirmPassword').value='';}
    });lock(false);
  }
  document.addEventListener('firebase-ready',boot);document.addEventListener('DOMContentLoaded',boot);
  root.addEventListener('pagehide',()=>{++epoch;authOff?.();authOff=null;started=false;$('inputPassword').value='';$('inputConfirmPassword').value='';lock(true);});
  root.addEventListener('pageshow',()=>{busy=false;boot();});boot();
})(typeof globalThis!=='undefined'?globalThis:this);
