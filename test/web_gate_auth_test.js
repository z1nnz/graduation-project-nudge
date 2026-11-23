const test=require('node:test'),assert=require('node:assert/strict');
const {target,initialProfile,ensureProfile}=require('../web_dashboard/assets/town_gate_auth.js');
test('gate returns only to the town and initializes no reward balance or authority',()=>{
 assert.equal(target,'town.html');const p=initialProfile({uid:'user_a',email:'a@example.test'},'stamp');
 assert.deepEqual(p.tasks,[]);assert.deepEqual(p.dailySummaries,[]);
 for(const field of ['disciplineCoins','avatarExperienceLedger','developerAccess','staffRole'])assert.equal(field in p,false);
});
test('profile setup preserves existing account data and retries without duplication',async()=>{
 let saved=null,writes=0;
 const db={collection:()=>({doc:()=>({})}),runTransaction:async fn=>fn({get:async()=>({exists:!!saved}),set:(_r,v)=>{saved=v;writes++;}})};
 const args={db,user:{uid:'user_a',email:'a@example.test'},stamp:()=>1,alive:()=>true};
 await ensureProfile(args);saved.tasks=[{id:'keep',title:'Existing task'}];await ensureProfile(args);
 assert.equal(writes,1);assert.equal(saved.tasks[0].id,'keep');
 await assert.rejects(ensureProfile({...args,alive:()=>false}));assert.equal(writes,1);
 await assert.rejects(ensureProfile({...args,user:{uid:'anonymous',isAnonymous:true}}));
});
