const test=require('node:test'),assert=require('node:assert/strict');
const {validate,taskDraft,saveDocument,addTask}=require('../web_dashboard/assets/growth_tools.js');
test('tool text stays editable private prose, never an issued reward',()=>{
  assert.deepEqual(validate('letter',' hello ',' a note '),{kind:'letter',title:'hello',body:'a note'});
  for(const args of [['capsule','x','x'],['strategy','','x'],['letter','x','x'.repeat(8001)]])assert.throws(()=>validate(...args));
  const task=taskDraft({id:'museum_task_unit_01',uid:'owner',title:'A step',now:'2026-11-23T00:00:00.000Z'});
  assert.equal(task.isDone,false);assert.equal(task.sourceType,'manual');assert.equal(task.userId,'owner');
  assert.equal('xp' in task,false);assert.equal('reward' in task,false);
});
test('save only trusts a matching owner and confirmed Cloud result',async()=>{
  const args={uid:'owner',id:'growth_unit_01',revision:0,values:validate('letter','Title','Body')};
  let payload;
  const result=await saveDocument({...args,call:async p=>{payload=p;return {documentId:args.id,ownerUid:'owner',status:'saved',revision:1};}});
  assert.equal(result.revision,1);assert.equal(payload.ownerUid,undefined);assert.equal(payload.createdAt,undefined);
  for(const patch of [{ownerUid:'foreign'},{documentId:'different'},{status:'pending'},{revision:null}])
    await assert.rejects(saveDocument({...args,call:async()=>({documentId:args.id,ownerUid:'owner',status:'saved',revision:1,...patch})}));
  await assert.rejects(saveDocument(args));
});
test('task call sends editable title and id without client rewards, ownership or completion',async()=>{
  const draft=taskDraft({id:'museum_task_unit_01',uid:'owner',title:'A step',now:'2026-11-23T00:00:00.000Z'});
  let payload;
  assert.equal((await addTask({draft,call:async p=>{payload=p;return {taskId:draft.id,status:'created'};}})).status,'created');
  assert.deepEqual(payload,{action:'createTask',taskId:draft.id,title:'A step'});
  assert.equal((await addTask({draft,call:async()=>({taskId:draft.id,status:'existing'})})).status,'existing');
  await assert.rejects(addTask({draft,call:async()=>({taskId:draft.id,status:'completed'})}));
});
