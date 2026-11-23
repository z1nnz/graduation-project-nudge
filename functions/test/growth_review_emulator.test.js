import test from "node:test";
import assert from "node:assert/strict";
import {createHash} from "node:crypto";
import {readFileSync} from "node:fs";
import {initializeApp,deleteApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";
import {initializeTestEnvironment,assertFails,assertSucceeds} from "@firebase/rules-unit-testing";
import {collection,query,where,orderBy,limit,getDocsFromServer,doc,setDoc} from "firebase/firestore";
import review from "../../web_dashboard/assets/growth_review.js";
test("museum reads the real canonical completed-session query and refuses foreign or client-created facts",{
  skip:!process.env.FIRESTORE_EMULATOR_HOST,timeout:120000,
},async()=>{
  assert.match(process.env.FIRESTORE_EMULATOR_HOST,/^(127\.0\.0\.1|localhost):\d+$/);
  const projectId="demo-growth-review-"+process.pid;
  const [host,port]=process.env.FIRESTORE_EMULATOR_HOST.split(":");
  const env=await initializeTestEnvironment({projectId,firestore:{host,port:Number(port),rules:readFileSync(new URL("../../firestore.rules",import.meta.url),"utf8")}});
  const app=initializeApp({projectId},"growth-review-"+process.pid),db=getFirestore(app);
  const owner=env.authenticatedContext("owner").firestore(),other=env.authenticatedContext("other").firestore();
  const now="2026-11-23T10:00:00.000Z",p=review.period("week",now);
  try{
    const fixture={activitySessionId:"source-session",activityFingerprint:"source-fingerprint",actorUserId:"owner",status:"completed",activityType:"focus",metricValue:25,metricUnit:"minutes",source:"web",startedAt:"2026-11-23T08:00:00.000Z",endedAt:"2026-11-23T08:25:00.000Z"};
    const id=createHash("sha256").update(fixture.activityFingerprint).digest("hex");
    await db.doc("activity_sessions/"+id).set(fixture);
    const q=query(collection(owner,"activity_sessions"),where("actorUserId","==","owner"),where("status","==","completed"),
      where("endedAt",">=",p.previousStart),where("endedAt","<=",p.end),orderBy("endedAt","desc"),limit(501));
    const result=await assertSucceeds(getDocsFromServer(q));assert.equal(result.size,1);
    const row=await review.parseSession(result.docs[0].id,result.docs[0].data(),"owner",now);
    assert.ok(row);assert.equal(review.summarize([row],p).current.focusMinutes,25);
    await assertFails(getDocsFromServer(query(collection(other,"activity_sessions"),where("actorUserId","==","owner"))));
    await assertFails(setDoc(doc(owner,"activity_sessions","forged"),fixture));
    await db.doc("account_deletion_fences/owner").set({active:true});await assertFails(getDocsFromServer(q));
  }finally{await env.cleanup();await deleteApp(app);}
});
