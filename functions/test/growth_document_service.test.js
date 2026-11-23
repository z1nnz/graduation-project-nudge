import test from "node:test";
import assert from "node:assert/strict";
import {normalizeGrowthDocument,createManageGrowthDocumentHandler} from "../src/growth-document-service.js";
const input={action:"save",documentId:"growth_unit_001",revision:0,kind:"letter",title:" Title ",body:" Body "};
test("document mutations reject injected owners, timestamps, rewards and invalid revisions",()=>{
  assert.equal(normalizeGrowthDocument(input).title,"Title");
  for(const patch of [{ownerUid:"victim"},{updatedAt:"2099"},{xp:100},{revision:-1},{revision:0.5},{documentId:12345678},{body:""},{kind:"capsule"}])
    assert.throws(()=>normalizeGrowthDocument({...input,...patch}));
  assert.throws(()=>normalizeGrowthDocument({action:"createTask",taskId:"task_unit_001",title:"Step",isDone:true}));
});
test("document auth and attestation fail before database use",async()=>{
  const handle=createManageGrowthDocumentHandler({firestore:null});
  for(const request of [{},{auth:{uid:"owner"}},{auth:{uid:"owner",token:{firebase:{sign_in_provider:"anonymous"}}},app:{appId:"test"}}])
    await assert.rejects(handle({...request,data:input}),e=>e.code==="unauthenticated");
});
