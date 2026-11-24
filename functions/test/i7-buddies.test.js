import assert from "node:assert/strict";
import test from "node:test";
import { randomUUID } from "node:crypto";
import { deleteApp, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { initializeTestEnvironment, assertFails, assertSucceeds } from "@firebase/rules-unit-testing";
import { doc, getDoc, setDoc } from "firebase/firestore";
import { createBuddyHandler, createBuddyReminder, nextBuddyReminder, buddyCheckIn } from "../src/buddy-service.js";

test("buddy time and check-in use Taiwan dates and confirmed positive receipts", () => {
  const now = new Date("2026-11-24T12:00:00Z");
  assert.equal(nextBuddyReminder(now,"20:00"),"2026-11-25T12:00:00.000Z");
  const entry={verifiedAt:now.toISOString(),acceptedMetric:1};
  assert.deepEqual(buddyCheckIn([entry],[entry],now),{mine:true,theirs:true,streak:1,interrupted:false});
  assert.equal(buddyCheckIn([entry],[{...entry,correctionOfReceiptId:"old"}],now).theirs,false);
});

test("i7-buddies emulator checks access, transactions and stored results", {
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
    const a=actor("a"), b=actor("b"), outsider=actor("outsider");
    let now=new Date("2026-11-24T11:50:00Z");
    const handler=createBuddyHandler(db,()=>now);
    const invoke=(uid,action,data={})=>handler({auth:{uid},data:{action,...data}});
    await friends(a,b);
    await assert.rejects(invoke(a,"invite",{peerId:outsider,time:"20:00"}),{code:"permission-denied"});
    const {id:pairId}=await invoke(a,"invite",{peerId:b,time:"20:00"});
    await assertFails(getDoc(doc(client(outsider),"buddy_pairs/"+pairId)));
    await assertFails(setDoc(doc(client(a),"buddy_pairs/forged"),{participantIds:[a,b]}));
    await assert.rejects(invoke(a,"accept",{pairId}),{code:"failed-precondition"});
    await invoke(b,"accept",{pairId});
    await invoke(a,"propose",{pairId,time:"20:05"});
    await assert.rejects(invoke(a,"confirm",{pairId}),{code:"failed-precondition"});
    await invoke(b,"confirm",{pairId});
    await invoke(b,"limit",{limit:0});
    await assert.rejects(invoke(a,"nudge",{pairId}),{code:"failed-precondition"});
    await invoke(b,"limit",{limit:1});
    await invoke(a,"nudge",{pairId});
    await assert.rejects(invoke(a,"nudge",{pairId}),{code:"failed-precondition"});
    await invoke(b,"pause",{pairId,paused:true});
    await assert.rejects(invoke(b,"nudge",{pairId}),{code:"failed-precondition"});
    await invoke(b,"pause",{pairId,paused:false});
    now=new Date("2026-11-24T12:05:00Z");
    const send = createBuddyReminder(db,()=>now);
    await send(); await send();
    const notices = db.collection("user_notifications").where("sourceId","==",pairId);
    assert.equal((await notices.get()).docs.filter(doc=>doc.data().kind==="buddy_reminder").length,2);
    for(const uid of [a,b]) await db.collection("activity_receipts").doc(uid).set({actorUserId:uid,verifiedAt:now.toISOString(),acceptedMetric:1});
    const check=(await invoke(a,"list")).pairs[0].checkIn;
    assert.deepEqual(check,{mine:true,theirs:true,streak:1,interrupted:false});
    await invoke(b,"remove",{pairId});
    assert.equal((await notices.get()).size,0);
    assert.equal((await invoke(a,"list")).pairs.length,0);
    const extra=Array.from({length:4},(_,index)=>actor("extra-"+index));
    for (const peer of extra) await friends(a,peer);
    for (const peer of extra.slice(0,3)) {
      const invite=await invoke(a,"invite",{peerId:peer,time:"19:00"});
      await invoke(peer,"accept",{pairId:invite.id});
    }
    await assert.rejects(invoke(a,"invite",{peerId:extra[3],time:"19:00"}),{code:"resource-exhausted"});
  } finally {
    await env.cleanup();
    await deleteApp(server);
  }
});
