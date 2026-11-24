import assert from "node:assert/strict";
import test from "node:test";
import { randomUUID } from "node:crypto";
import { deleteApp, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { initializeTestEnvironment, assertFails, assertSucceeds } from "@firebase/rules-unit-testing";
import { doc, getDoc, setDoc, writeBatch } from "firebase/firestore";
import { createClubHandler, clubPostTimes } from "../src/club-service.js";
import { createSocialSafetyHandler } from "../src/social-safety-service.js";

test("club publication throttle is a rolling hour", () => {
  const now=3600000;
  assert.equal(clubPostTimes(Array(10).fill(0),now).length,1);
  assert.throws(()=>clubPostTimes(Array(10).fill(1),now),{code:"resource-exhausted"});
});

test("i8-clubs emulator checks access, transactions and stored results", {
  skip: !process.env.FIRESTORE_EMULATOR_HOST,
}, async () => {
  const suffix = randomUUID();
  const projectId = process.env.NUDGE_RULES_TEST_PROJECT || "nudge-discipline-app";
  const [host, port] = process.env.FIRESTORE_EMULATOR_HOST.split(":");
  const server = initializeApp({ projectId }, suffix);
  const env = await initializeTestEnvironment({ projectId, firestore: { host, port: Number(port) } });
  const db = getFirestore(server);
  const actor = label => label + "-" + suffix;
  const client = uid => env.authenticatedContext(uid).firestore();
  const rootUser = id => db.collection("users").doc(id);
  const friends = async (left, right) => {
    await Promise.all([rootUser(left).set({}), rootUser(right).set({}),
      rootUser(left).collection("friends").doc(right).set({id:right}),
      rootUser(right).collection("friends").doc(left).set({id:left})]);
  };
  try {
    const [owner,member,operator,outsider]=["owner","member","operator","outsider"].map(actor);
    await rootUser(operator).set({staffRole:"operator"});
    const handler=createClubHandler(db,()=>new Date("2026-11-24T00:00:00Z"));
    const invoke=(uid,action,data={})=>handler({auth:{uid},data:{action,...data}});
    const {id:clubId}=await invoke(owner,"apply",{name:"森林讀書會",introduction:"一起讀書",emblem:"book"});
    await assert.rejects(invoke(owner,"review",{clubId,status:"approved"}),{code:"permission-denied"});
    await assert.rejects(invoke(member,"join",{clubId}),{code:"permission-denied"});
    await invoke(operator,"review",{clubId,status:"approved"});
    await assertSucceeds(getDoc(doc(client(outsider),"club_public/"+clubId)));
    await assertFails(getDoc(doc(client(outsider),"clubs/"+clubId)));
    assert.deepEqual(await invoke(outsider,"view",{clubId}),{joined:false});
    await assert.rejects(invoke(outsider,"post",{clubId,body:"未加入"}),{code:"permission-denied"});
    await invoke(member,"join",{clubId});
    await invoke(member,"visibility",{clubId,enabled:true});
    await invoke(member,"challenge",{clubId});
    assert.equal((await invoke(member,"view",{clubId})).challenge.participants,1);
    for(let i=0;i<10;i++) await invoke(member,"post",{clubId,body:"貼文 "+i,sticker:"study"});
    await assert.rejects(invoke(member,"post",{clubId,body:"太多"}),{code:"resource-exhausted"});
    const post=(await invoke(member,"view",{clubId})).posts[0];
    await assertFails(getDoc(doc(client(outsider),"club_posts/"+post.id)));
    await assertFails(setDoc(doc(client(member),"club_posts/forged"),{body:"forged"}));
    const report=createSocialSafetyHandler(db);
    const input={action:"report", type:"clubPost", targetId:post.id, reason:"spam"};
    await assert.rejects(report({auth:{uid:outsider},data:input}),{code:"permission-denied"});
    await report({auth:{uid:owner},data:input});
    assert.equal((await db.collection("safety_reports").where("userId","==",owner).get()).size,1);
    await invoke(owner,"react",{clubId,postId:post.id,emoji:"👍"});
    assert.equal((await invoke(member,"view",{clubId})).posts.find(item=>item.id===post.id).totals["👍"],1);
    const {roomId}=await invoke(owner,"room",{clubId,voiceEnabled:true});
    await invoke(member,"room",{clubId});
    const metadata=(await db.collection("rooms").doc(roomId).get()).data();
    const rogue=client(outsider);
    const attempt=writeBatch(rogue);
    attempt.set(doc(rogue,"rooms/"+roomId),{...metadata,memberIds:[...metadata.memberIds,outsider]});
    attempt.set(doc(rogue,"rooms/"+roomId+"/members/"+outsider),{schemaVersion:1,roomId,memberId:outsider,
      displayName:"Outside",role:"member",approvalStatus:"pending",presenceStatus:"offline",sessionSeconds:0,
      metricValue:0,metricUnit:"minutes",activeSessionId:null,updatedAt:metadata.updatedAt});
    await assertFails(attempt.commit());
    assert.equal((await db.collection("rooms").doc(roomId).get()).data().voiceEnabled,true);
    await invoke(owner,"moderate",{clubId,operation:"mute",targetId:member,minutes:10,reason:"連續貼文"});
    await assert.rejects(invoke(member,"react",{clubId,postId:post.id,emoji:"🔥"}),{code:"permission-denied"});
    await invoke(owner,"moderate",{clubId,operation:"remove",targetId:member,reason:"不當貼文"});
    assert.equal((await db.collection("rooms").doc(roomId).get()).data().memberIds.includes(member),false);
    await assert.rejects(invoke(member,"join",{clubId}),{code:"permission-denied"});
    assert.equal((await db.collection("audit_events").where("safetyTargetId","==",member).get()).size,2);
  } finally {
    await env.cleanup();
    await deleteApp(server);
  }
});
