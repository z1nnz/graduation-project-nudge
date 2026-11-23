const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs');
const {parseMetadata}=require('../web_dashboard/assets/growth_capsules.js');
test('capsule metadata never contains the sealed message or another owner',()=>{
  const m={schemaVersion:1,capsuleId:'capsule_unit_001',ownerUid:'owner',title:'Title',status:'sealed',unlockAt:'2026-11-24T00:00:00.000Z'};
  assert.ok(parseMetadata(m.capsuleId,m,'owner'));
  assert.equal(parseMetadata(m.capsuleId,m,'other'),null);
  assert.equal(parseMetadata(m.capsuleId,{...m,message:'must not be public metadata'},'owner'),null);
});
test('Cloud entry point requires App Check and account operation lease',()=>{
  const code=fs.readFileSync('functions/index.js','utf8');
  assert.match(code,/manageGrowthCapsule = onCall\([\s\S]*?enforceAppCheck: true[\s\S]*?withAccountOperation\(request/);
});
