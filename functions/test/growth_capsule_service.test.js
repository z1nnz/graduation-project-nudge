import test from "node:test";
import assert from "node:assert/strict";
import { normalizeCapsuleRequest, canOpenCapsule, createManageGrowthCapsuleHandler } from "../src/growth-capsule-service.js";
const input={action:"seal",capsuleId:"capsule_unit_001",title:"One day",message:"Private note",unlockDate:"2026-11-24"};
test("capsule dates use Taiwan midnight and reject calendar overflow and client clock injection",()=>{
  assert.equal(normalizeCapsuleRequest(input).unlockAt,"2026-11-23T16:00:00.000Z");
  for(const patch of [{unlockDate:"2026-02-30"},{now:"2099-01-01"},{ownerUid:"victim"},{message:""},{capsuleId:"../victim"},{capsuleId:12345678}])
    assert.throws(()=>normalizeCapsuleRequest({...input,...patch}));
});
test("server time, ownership and lifecycle all gate content, including cancelled due letters",()=>{
  const m={ownerUid:"owner",status:"sealed",unlockAt:"2026-11-23T16:00:00.000Z"};
  assert.equal(canOpenCapsule(m,"owner","2026-11-23T15:59:59.999Z"),false);
  assert.equal(canOpenCapsule(m,"owner","2026-11-23T16:00:00.000Z"),true);
  assert.equal(canOpenCapsule(m,"other","2099-01-01T00:00:00.000Z"),false);
  assert.equal(canOpenCapsule({...m,status:"cancelled"},"owner","2099-01-01T00:00:00.000Z"),false);
});
test("identity and attestation fail before any database operation",async()=>{
  const handle=createManageGrowthCapsuleHandler({firestore:null});
  await assert.rejects(handle({data:input}),e=>e.code==="unauthenticated");
  await assert.rejects(handle({auth:{uid:"owner"},data:input}),e=>e.code==="unauthenticated");
  await assert.rejects(handle({auth:{uid:"owner",token:{firebase:{sign_in_provider:"anonymous"}}},app:{appId:"test"},data:input}),e=>e.code==="unauthenticated");
});
