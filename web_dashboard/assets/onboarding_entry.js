(function(root,factory){const api=factory();if(typeof module==='object'&&module.exports)module.exports=api;else root.NudgeOnboardingEntry=api;})(typeof globalThis!=='undefined'?globalThis:this,function(){
  'use strict';
  // A restored town session needs the same first-role flow as the login gate.
  // The listener's cached hint never decides: recheck the owner on the server.
  function create({auth,db,open,isInTown=()=>true,isShowing=()=>false}){
    const attempted=new Set(),inFlight=new Set();
    return Object.freeze({async consider(uid){
      const current=()=>isInTown()&&auth.currentUser?.uid===uid&&!auth.currentUser?.isAnonymous;
      if(!uid||!current()||attempted.has(uid)||inFlight.has(uid))return false;
      inFlight.add(uid);
      try{
        const snap=await db.collection('users').doc(uid).get({source:'server'});
        if(!current()||!snap.exists||snap.metadata?.fromCache||snap.metadata?.hasPendingWrites)return false;
        const face=snap.data()?.avatarProfile?.faceShapeIndex;
        if(Number.isInteger(face)&&face>=0)return false;
        attempted.add(uid);
        if(isShowing())return false;
        open('onboarding.html');return true;
      }catch(_){return false;}finally{inFlight.delete(uid);}
    }});
  }
  return Object.freeze({create});
});
