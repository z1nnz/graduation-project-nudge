const test=require('node:test'),assert=require('node:assert/strict'),{spawnSync}=require('node:child_process');
test('growth text privacy and Rules integration on loopback emulator',{skip:!process.env.FIRESTORE_EMULATOR_HOST,timeout:150000},()=>{
  const run=spawnSync(process.execPath,['--test','functions/test/growth_documents_emulator.test.js'],{encoding:'utf8',timeout:140000});
  assert.equal(run.status,0,run.stdout+'\n'+run.stderr);assert.doesNotMatch(run.stdout,/# skipped [1-9]/);
});
