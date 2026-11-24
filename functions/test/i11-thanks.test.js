import assert from "node:assert/strict";
import test from "node:test";
import { randomUUID } from "node:crypto";
import { deleteApp, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { initializeTestEnvironment, assertFails, assertSucceeds } from "@firebase/rules-unit-testing";
import { doc, getDoc, setDoc } from "firebase/firestore";
import { createThanksCardHandler, cardContent } from "../src/thanks-card-service.js";

test("thank-you signatures validate the design and 60-character limit", () => {
  assert.equal(cardContent({text:"★".repeat(60),pattern:"stars"}).text.length,60);
  assert.throws(()=>cardContent({text:"★".repeat(61),pattern:"stars"}),{code:"invalid-argument"});
  assert.throws(()=>cardContent({text:"謝謝",pattern:"constructor"}),{code:"invalid-argument"});
});

test("i11-thanks emulator checks access, transactions and stored results", {
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
    const a=actor("sender");
    const people=Array.from({length:12},(_,index)=>actor("peer"+index));
    await Promise.all(people.map(peer=>friends(a,peer)));
    const handler=createThanksCardHandler(db,()=>new Date("2026-11-24T00:00:00Z"));
    const invoke=(uid,action,data={})=>handler({auth:{uid},data:{action,...data}});
    const send=to=>invoke(a,"send",{recipientId:to,pattern:"heart",text:"謝謝你"});
    await db.collection("social_safety").doc(a).set({blockedBy:[people[11]]});
    await assert.rejects(send(people[11]),{code:"permission-denied"});
    const tries=await Promise.allSettled([send(people[0]),send(people[0])]);
    const first=tries.find(attempt=>attempt.status==="fulfilled").value;
    assert.equal(tries.find(attempt=>attempt.status==="rejected").reason.code,"already-exists");
    await assertFails(getDoc(doc(client(a),"thanks_cards/"+first.id)));
    await assertFails(setDoc(doc(client(people[0]),"thanks_cards/forged"),{text:"forged"}));
    assert.equal((await invoke(people[0],"list")).cards.length,1);
    assert.equal((await invoke(a,"list")).cards.length,0);
    await assert.rejects(invoke(a,"save",{cardId:first.id}),{code:"permission-denied"});
    await invoke(people[0],"save",{cardId:first.id});
    assert.equal((await invoke(people[0],"list")).cards[0].saved,true);
    await invoke(people[0],"delete",{cardId:first.id});
    assert.equal((await db.collection("user_notifications").doc("thanks-"+first.id).get()).exists,false);
    await assert.rejects(send(people[0]),{code:"already-exists"});
    for(const peer of people.slice(1,10)) await send(peer);
    await assert.rejects(send(people[10]),{code:"resource-exhausted"});
  } finally {
    await env.cleanup();
    await deleteApp(server);
  }
});
