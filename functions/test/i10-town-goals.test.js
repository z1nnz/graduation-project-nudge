import assert from "node:assert/strict";
import test from "node:test";
import { randomUUID } from "node:crypto";
import { deleteApp, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { initializeTestEnvironment, assertFails, assertSucceeds } from "@firebase/rules-unit-testing";
import { doc, getDoc, setDoc } from "firebase/firestore";
import { aggregateTownEvent, townEventWeek, createTownEventPreferences, createTownEventSchedule } from "../src/town-event-service.js";

test("weekly rotation and aggregate ignore duplicates, unconfirmed records and opted-out actors", () => {
  const beginning = new Date("2026-11-23T00:00:00+08:00");
  const weeks = Array.from({length:12},(_,index)=>townEventWeek(new Date(beginning.getTime()+index*604800000)));
  assert.equal(new Set(weeks.map(week=>week.key)).size,12);
  const goal = {...weeks[0],mode:"sum",minimum:0,activity:"focus"};
  const original={id:"receipt",activityFingerprint:"confirmed",actorUserId:"a",activityType:"focus",acceptedMetric:15,verifiedAt:goal.startsAt};
  assert.equal(aggregateTownEvent(goal,[original,{...original,id:"duplicate"},
    {...original,id:"opted-out",activityFingerprint:"else",actorUserId:"b"},
    {...original,id:"expired",activityFingerprint:"old",verifiedAt:goal.endsAt},
    {actorUserId:"a",activityType:"focus",acceptedMetric:100},{...original,correctionOfReceiptId:"existing"}],new Set(["b"])),15);
});

test("i10-town-goals emulator checks access, transactions and stored results", {
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
    const a=actor("a"), b=actor("b");
    const dates=Array.from({length:12},(_,index)=>new Date(Date.parse("2026-11-23T00:00:00+08:00")+index*604800000));
    const now=dates.find(date=>townEventWeek(date).key==="focus-minutes");
    const goal=townEventWeek(now);
    await Promise.all([rootUser(a).set({}),rootUser(b).set({})]);
    await createTownEventPreferences(db)({auth:{uid:b},data:{excluded:true}});
    await assertFails(getDoc(doc(client(a),"town_event_preferences/"+b)));
    await assertSucceeds(getDoc(doc(client(b),"town_event_preferences/"+b)));
    await assertFails(setDoc(doc(client(a),"town_events/current"),{total:1000000}));
    await assertFails(setDoc(doc(client(a),"town_event_preferences/"+a),{excluded:true}));
    const rows=db.collection("activity_receipts");
    await rows.doc(a).set({actorUserId:a,activityType:"focus",acceptedMetric:10000,verifiedAt:goal.startsAt});
    await rows.doc(b).set({actorUserId:b,activityType:"focus",acceptedMetric:300,verifiedAt:goal.startsAt});
    const execute=createTownEventSchedule(db,()=>now);
    await execute(); await execute();
    const current=await assertSucceeds(getDoc(doc(client(a),"town_events/current")));
    assert.equal(current.data().total,10000);
    assert.equal(current.data().celebrated,true);
    assert.equal(Object.hasOwn(current.data(),"participants"),false);
    for(const uid of [a,b]) {
      const notice=await db.collection("user_notifications").where("recipientUserId","==",uid).get();
      assert.equal(notice.docs.filter(doc=>doc.data().kind==="town_goal_celebration").length,1);
    }
  } finally {
    await env.cleanup();
    await deleteApp(server);
  }
});
