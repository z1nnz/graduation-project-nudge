import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { initializeApp, deleteApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { initializeTestEnvironment, assertFails, assertSucceeds } from "@firebase/rules-unit-testing";
import { doc, getDoc, getDocs, collection, setDoc, updateDoc, deleteDoc } from "firebase/firestore";
import { createManageGrowthCapsuleHandler, createNotifyDueGrowthCapsulesHandler } from "../src/growth-capsule-service.js";
import { collectPrivacyExportData } from "../src/privacy-data-request-service.js";
import { FirestoreAccountDeletionRepository } from "../src/firestore-account-deletion-repository.js";

const enabled=!!process.env.FIRESTORE_EMULATOR_HOST;
test("capsule emulator: owner-only rules, server unlock, retries, cancellation, due notices, exports and erasure",
  {skip:!enabled,timeout:120000},async()=>{
    assert.match(process.env.FIRESTORE_EMULATOR_HOST,/^(127\.0\.0\.1|localhost):\d+$/,"loopback emulator only");
    const projectId="demo-growth-capsules-"+process.pid;
    const [host,port]=process.env.FIRESTORE_EMULATOR_HOST.split(":");
    const env=await initializeTestEnvironment({projectId,firestore:{host,port:Number(port),rules:readFileSync(new URL("../../firestore.rules",import.meta.url),"utf8")}});
    const admin=initializeApp({projectId},"growth-capsules-"+process.pid);
    const db=getFirestore(admin);
    const alice="growth-alice",bob="growth-bob";
    const owner=env.authenticatedContext(alice).firestore(),other=env.authenticatedContext(bob).firestore();
    const guest=env.unauthenticatedContext().firestore();
    let clock="2026-11-23T10:00:00.000Z";
    const handle=createManageGrowthCapsuleHandler({firestore:db,clock:()=>new Date(clock)});
    const notify=createNotifyDueGrowthCapsulesHandler({firestore:db,clock:()=>new Date(clock)});
    const request=(action,capsuleId,extra={},uid=alice)=>({auth:{uid},app:{appId:"emulator-attested-handler-fixture"},data:{action,capsuleId,...extra}});
    const id="capsule_private_001",payload={title:"Private title",message:"SEALED PRIVATE CONTENT",unlockDate:"2026-11-24"};
    const path="users/"+alice+"/growth_capsules/"+id;
    try {
      await db.doc("users/"+alice).set({nickname:"Alice",tasks:[]});
      await db.doc("users/"+bob).set({nickname:"Bob",tasks:[]});
      const sealed=await Promise.all([handle(request("seal",id,payload)),handle(request("seal",id,payload))]);
      assert.equal(sealed.filter(r=>r.wasDuplicate).length,1);
      assert.ok(sealed.every(r=>!JSON.stringify(r).includes(payload.message)));
      await assertSucceeds(getDoc(doc(owner,path)));
      await assertSucceeds(getDocs(collection(owner,"users/"+alice+"/growth_capsules")));
      await assertFails(getDoc(doc(other,path)));
      await assertFails(getDoc(doc(guest,path)));
      for(const area of ["growth_capsule_secrets","growth_capsule_operations"]){
        await assertFails(getDoc(doc(owner,"users/"+alice+"/"+area+"/"+id)));
        await assertFails(getDocs(collection(owner,"users/"+alice+"/"+area)));
        await assertFails(setDoc(doc(owner,"users/"+alice+"/"+area+"/forged"),{message:"forged"}));
      }
      await assertFails(updateDoc(doc(owner,path),{unlockAt:"2000-01-01T00:00:00.000Z"}));
      await assertFails(deleteDoc(doc(owner,path)));
      await assert.rejects(handle(request("open",id)),e=>e.code==="failed-precondition");
      await assert.rejects(handle(request("open",id,{now:"2099-01-01"})),e=>e.code==="invalid-argument");
      await assert.rejects(handle(request("open",id,{},bob)),e=>e.code==="not-found");
      const early=await collectPrivacyExportData({firestore:db,userId:alice,now:new Date(clock)});
      assert.equal(early.collections.growth_capsules.length,1);
      assert.ok(!JSON.stringify(early).includes(payload.message),"formal export must not bypass the seal");

      const second="capsule_notice_001";
      await handle(request("seal",second,{...payload,title:"Notice title",message:"SECOND PRIVATE CONTENT"}));
      clock="2026-11-23T16:00:00.000Z";
      const opened=await handle(request("open",id));
      assert.equal(opened.capsule.message,payload.message);
      assert.equal((await handle(request("export",id))).capsule.message,payload.message);
      const exported=await collectPrivacyExportData({firestore:db,userId:alice,now:new Date(clock)});
      assert.equal(exported.collections.growth_capsules.find(x=>x.id===id).data.message,payload.message);
      assert.equal((await notify()).notified,1);
      assert.equal((await notify()).notified,0);
      const notification=db.doc("user_notifications/growth-capsule--"+alice+"--"+second);
      assert.ok((await notification.get()).exists);
      assert.ok(!JSON.stringify((await notification.get()).data()).includes("PRIVATE CONTENT"));

      await handle(request("cancel",second));
      assert.equal((await db.doc("users/"+alice+"/growth_capsule_secrets/"+second).get()).exists,false);
      assert.equal((await notification.get()).exists,false);
      await assert.rejects(handle(request("open",second)),e=>e.code==="failed-precondition");
      await assert.rejects(handle(request("seal",second,{...payload,title:"Notice title",message:"SECOND PRIVATE CONTENT"})),e=>e.code==="failed-precondition");
      await handle(request("delete",id));
      assert.equal((await handle(request("delete",id))).status,"deleted");
      await assert.rejects(handle(request("seal",id,payload)),e=>e.code==="failed-precondition");
      assert.equal((await db.doc(path).get()).exists,false);

      clock="2026-11-23T10:00:00.000Z";
      const fenced="capsule_fence_001";await handle(request("seal",fenced,payload));
      await db.doc("account_deletion_fences/"+alice).set({active:true});
      await assert.rejects(handle(request("open",fenced)),e=>e.code==="failed-precondition");
      await assertFails(getDoc(doc(owner,"users/"+alice+"/growth_capsules/"+fenced)));
      clock="2026-11-23T16:00:00.000Z";
      assert.equal((await notify()).notified,0);
      const repo=new FirestoreAccountDeletionRepository({firestore:db,auth:null,bucket:null});
      await repo.eraseAccountData({userId:alice,request:{requestId:"capsule-erasure-unit"},plan:{operations:{
        leaveGroupIds:[],deleteOwnedRoomIds:[],deleteFamilyLinkIds:[],redactEndedFamilyLinkIds:[],deleteOwnedGroupIds:[],
      }},now:clock});
      for(const name of ["growth_capsules","growth_capsule_secrets","growth_capsule_operations"]){
        assert.equal((await db.collection("users/"+alice+"/"+name).get()).size,0,name);
      }
      assert.equal((await notify()).notified,0);
      assert.equal((await db.doc("users/"+bob).get()).exists,true);
    } finally {await db.recursiveDelete(db.collection("users").doc(alice));await db.recursiveDelete(db.collection("users").doc(bob));await env.cleanup();await deleteApp(admin);}
  });
