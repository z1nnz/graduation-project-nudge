import assert from "node:assert/strict";
import test from "node:test";
import { randomUUID } from "node:crypto";
import { deleteApp, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { initializeTestEnvironment, assertFails, assertSucceeds } from "@firebase/rules-unit-testing";
import { doc, getDoc, setDoc } from "firebase/firestore";
import { createJournalHandler, createJournalCleanup, journalEntry } from "../src/exchange-journal-service.js";

test("journal entries validate the character and sticker limits", () => {
  assert.equal(journalEntry("星".repeat(500), "heart").text.length, 500);
  assert.throws(() => journalEntry("星".repeat(501)), { code: "invalid-argument" });
  assert.throws(() => journalEntry("一行", ["heart","fire"]), { code: "invalid-argument" });
});

test("i9-journal emulator checks access, transactions and stored results", {
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
    const [a,b,c] = ["author","partner","stranger"].map(actor);
    let now = new Date("2026-11-24T00:00:00Z");
    const handler = createJournalHandler(db, () => now);
    const invoke = (uid, action, data={}) => handler({auth:{uid},data:{ action,...data }});
    await friends(a,b);
    await assert.rejects(invoke(a,"open",{peerId:c}), {code:"permission-denied"});
    const {id:journalId}=await invoke(a,"open",{peerId:b});
    assert.equal((await invoke(b,"open",{peerId:a})).id,journalId);
    await assertFails(getDoc(doc(client(a),"exchange_journals/"+journalId)));
    await assertFails(setDoc(doc(client(b),"exchange_journals/"+journalId+"/entries/fake"),{text:"forged"}));
    await assert.rejects(invoke(c,"read",{journalId}),{code:"permission-denied"});
    await assert.rejects(invoke(a,"accept",{journalId}),{code:"failed-precondition"});
    await invoke(b,"accept",{journalId});
    assert.ok((await invoke(a,"read",{journalId})).prompt);
    await assert.rejects(invoke(b,"write",{ journalId,text:"先等等" }),{code:"failed-precondition"});
    const simultaneous=await Promise.allSettled(["第一頁","再送一次"].map(text=>invoke(a,"write",{journalId,text,sticker:"heart"})));
    assert.equal(simultaneous.filter(item=>item.status==="fulfilled").length,1);
    await invoke(b,"write",{journalId,text:"第二頁"});
    assert.equal((await invoke(a,"read",{journalId})).entries[0].number,2);
    await invoke(a,"end",{journalId});
    assert.equal((await invoke(b,"read",{journalId})).expiresAt,"2026-12-24T00:00:00.000Z");
    now=new Date("2026-12-24T00:00:00Z");
    await assert.rejects(invoke(b,"read",{journalId}),{code:"permission-denied"});
    await createJournalCleanup(db,()=>now)();
    const first=db.collection("exchange_journals").doc(journalId);
    assert.equal((await first.get()).exists,false);
    assert.equal((await first.collection("entries").get()).size,0);
    const next=(await invoke(b,"open",{peerId:a})).id;
    await invoke(a,"delete",{journalId:next});
    assert.equal((await db.collection("exchange_journals").doc(next).get()).exists,false);
  } finally {
    await env.cleanup();
    await deleteApp(server);
  }
});
