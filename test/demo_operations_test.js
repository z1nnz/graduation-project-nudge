const test=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),os=require('node:os');
const {spawnSync}=require('node:child_process');
const b=require('../scripts/demo_backlog.cjs'),r=require('../scripts/demo_runbook.cjs');
const base=path.resolve(__dirname,'../docs/competition-demo/package11-12');
const catalog=()=>JSON.parse(fs.readFileSync(path.join(base,'backlog.json')));
function fixture(t){
  const root=fs.mkdtempSync(path.join(os.tmpdir(),'nudge-ops-test-'));
  t.after(()=>fs.rmSync(root,{recursive:true,force:true}));
  const save=(file,body,kind)=>{fs.writeFileSync(path.join(root,file),body);return{file,sha256:r.sha(Buffer.from(body)),kind};};
  const state=r.template();state.competition_date='2026-12-01';state.venue='UNIT FIXTURE';state.physical_acceptance_deferred=false;
  for(const [name,d] of Object.entries(state.devices)){
    Object.assign(d,{board_id:name+'-unit',source_commit:'a'.repeat(40),build_id:'aaaaaaaaaaaa',environment:name+'_p0a',
      profile_sha256:'b'.repeat(64),display_configured:true,physical_accepted:true,frozen:true,cold_boot_successes:3,demo_successes:3,
      restart_verified:true,arrival_auto_run:true,arrival_build_id:'aaaaaaaaaaaa',home_observed:true});
    d.binary={...save(name+'_unit.bin','UNIT FIXTURE aaaaaaaaaaaa','application_image'),configuration:'accepted-profile'};
    d.physical_video={...save(name+'.mp4','UNIT FIXTURE - NOT REAL FOOTAGE '+name,'physical_video'),continuous:true};
    d.wiring_photo=save(name+'.png','UNIT FIXTURE - NOT REAL PHOTO '+name,'physical_photo');
  }
  Object.keys(state.inventory).filter(k=>typeof state.inventory[k]==='boolean').forEach(k=>{state.inventory[k]=true;});
  state.inventory.usb_cables=[{id:'cable-unit-1',data_capable:true,verified:true},{id:'cable-unit-2',data_capable:true,verified:true}];
  const body='UNIT FIXTURE - NOT A PHYSICAL BACKUP VIDEO';
  state.backups={one_take_physical_video:{...save('one-take.mp4',body,'physical_video'),continuous:true},
    offline_copy:{...save('offline.mp4',body,'physical_video'),continuous:true},phone_copy_confirmed:true,same_hardware_versions_confirmed:true};
  state.roles={presenter:'unit-presenter',operator:'unit-operator',reset_protocol_rehearsed:true};
  state.arrival_steps_completed=[...r.arrival];Object.keys(state.stage).forEach(k=>{state.stage[k]=true;});
  return{root,state,save,assess:()=>r.assess(state,root)};
}
test('canonical catalog has 34 IDs, roles, priorities and an acyclic graph',()=>{
  assert.equal(b.validateCatalog(catalog()).items.length,34);
  const c=catalog();c.items[1].id=c.items[0].id;assert.throws(()=>b.validateCatalog(c),/duplicate/);
});
test('wrong owner/device/priority cannot silently rewrite the default plan',()=>{
  for(const [key,value]of[['default_role','roy'],['device','station'],['priority','P2']]){
    const c=catalog();Object.assign(c.items.find(i=>i.id==='ORB-01'),{[key]:value});assert.throws(()=>b.validateCatalog(c),/Invalid/);
  }
});
test('unknown dependency and cycle reject before issue publication',()=>{
  let c=catalog();c.items[0].depends_on=['UNKNOWN'];assert.throws(()=>b.validateCatalog(c),/Invalid/);
  c=catalog();c.items[0].depends_on=['DEMO-01'];c.items[1].depends_on=['DEMO-00'];assert.throws(()=>b.validateCatalog(c),/cycle/);
});
test('P0-B/P1/P2 stay blocked until ALL P0-A acceptance, not just a source PR',()=>{
  const c=catalog();for(const i of b.eligibility(c))if(i.priority!=='P0-A')assert.equal(i.eligible_for_claim_review,false);
  const partial=b.eligibility(c,['ORB-01','ORB-02','ORB-03']);assert.equal(partial.find(i=>i.id==='ORB-07').eligible_for_claim_review,false);
  const complete=b.eligibility(c,[...b.p0a]);assert.equal(complete.find(i=>i.id==='ORB-07').eligible_for_claim_review,true);
  assert.equal(complete.find(i=>i.id==='STA-07').eligible_for_claim_review,true);
});
test('stable marker/title matching prevents duplicate issues including closed matches',()=>{
  const i=catalog().items[0],existing={number:9,title:b.issueTitle(i),body:b.issueBody(i),state:'closed'};
  assert.equal(b.existingIssue(i,[existing]).number,9);
  assert.throws(()=>b.existingIssue(i,[existing,{...existing,number:10}]),/Duplicate/);
  assert.equal(b.existingIssue(i,[{...existing,pull_request:{}}]),null);
});
test('registry requires 34 unique, open, unassigned real issue URLs',()=>{
  const reg={schema_version:1,repository:'z1nnz/graduation-project-nudge',issues:b.ids.map((id,j)=>({id,number:j+100,
    url:'https://github.com/z1nnz/graduation-project-nudge/issues/'+(j+100),state:'open',assignees:[],body_sha256:'a'.repeat(64)}))};
  assert.equal(b.validateRegistry(reg),true);reg.issues[0].assignees=['someone'];assert.throws(()=>b.validateRegistry(reg),/Invalid/);
});
test('source-complete alone cannot make an issue ready to close',t=>{
  const f=fixture(t);assert.equal(b.closeReadiness({source_complete:true},f.root).eligible_for_close_review,false);
  const record={source_commit:'a'.repeat(40),video:f.state.devices.orbit.physical_video,physical_verified:true,human_reviewed:true};
  const a=b.closeReadiness(record,f.root);assert.equal(a.eligible_for_close_review,true);assert.equal(a.will_close_issue,false);
  fs.writeFileSync(path.join(f.root,record.video.file),'changed');assert.equal(b.closeReadiness(record,f.root).eligible_for_close_review,false);
});
test('pending state never becomes on-site acceptance and gives honest missing-video fallback',t=>{
  const f=fixture(t),a=r.assess(r.template(),f.root);assert.equal(a.ready_for_human_review,false);
  assert.equal(a.physical_acceptance_certified,false);assert.match(a.fallback.both_devices,/No verified physical backup/);
});
test('complete parser fixture only becomes ready for HUMAN review, never certified',t=>{
  const f=fixture(t),a=f.assess();assert.equal(a.ready_for_human_review,true);assert.equal(a.physical_acceptance_certified,false);
});
test('two cold boots or unaccepted/frozen firmware cannot count as three',t=>{
  const f=fixture(t);f.state.devices.orbit.cold_boot_successes=2;assert.equal(f.assess().night_before_complete,false);
  f.state.devices.orbit.cold_boot_successes=3;f.state.devices.orbit.frozen=false;assert.equal(f.assess().ready_for_human_review,false);
});
test('wrong-device binary/env, repeated board IDs and missing build bytes reject',t=>{
  const f=fixture(t);f.state.devices.orbit.environment='station_p0a';assert.equal(f.assess().night_before_complete,false);
  f.state.devices.orbit.environment='orbit_p0a';f.state.devices.station.board_id=f.state.devices.orbit.board_id;
  assert.equal(f.assess().night_before_complete,false);
  f.state.devices.station.board_id='station-unit';fs.writeFileSync(path.join(f.root,'orbit_unit.bin'),'changed');
  assert.equal(f.assess().devices.orbit.accepted_record_complete,false);
});
test('two distinct verified USB data cables are required',t=>{
  const f=fixture(t);f.state.inventory.usb_cables[1].id=f.state.inventory.usb_cables[0].id;assert.equal(f.assess().night_before_complete,false);
});
test('mismatched physical backup copies or software preview cannot be counted',t=>{
  const f=fixture(t);f.state.backups.phone_copy_confirmed=false;assert.equal(f.assess().night_before_complete,false);
  f.state.backups.phone_copy_confirmed=true;f.state.devices.orbit.physical_video.kind='software_preview';
  assert.equal(f.assess().devices.orbit.accepted_record_complete,false);
});
test('unrehearsed BLE and unpacked adopted LEDs must be skipped',t=>{
  const f=fixture(t);f.state.devices.orbit.ble_adopted=true;assert.equal(f.assess().ready_for_human_review,false);
  f.state.devices.orbit.ble_adopted=false;f.state.devices.station.adopted_modules=['led'];
  f.state.inventory.existing_adopted_modules_and_cables_packed=false;assert.equal(f.assess().night_before_complete,false);
});
test('arrival requires all eight steps, matching build IDs and explicit stage fields',t=>{
  const f=fixture(t);f.state.arrival_steps_completed.pop();assert.equal(f.assess().arrival_15min_complete,false);
  f.state.arrival_steps_completed=[...r.arrival];delete f.state.stage.one_action_only;assert.equal(f.assess().ready_for_human_review,false);
});
test('evidence paths cannot escape via traversal/symlink',t=>{
  const f=fixture(t),v=f.state.devices.orbit.physical_video;assert.equal(r.fileOK({...v,file:'../escape.mp4'},f.root,'physical_video'),false);
  fs.symlinkSync(__filename,path.join(f.root,'outside.mp4'));
  assert.equal(r.fileOK({...v,file:'outside.mp4',sha256:r.sha(fs.readFileSync(__filename))},f.root,'physical_video'),false);
});
const kit=path.resolve(__dirname,'../output/demo/nudge-demo-preparation.zip');
const builder=path.resolve(__dirname,'../scripts/build_demo_kit.py');
test('real offline preparation kit verifies without network or source checkout',()=>{
  const a=spawnSync('python3',[builder,'verify',kit],{encoding:'utf8'});assert.equal(a.status,0,a.stderr);
  const j=JSON.parse(a.stdout);assert.equal(j.phase,'preparation-only');assert.equal(j.physical_verified,false);
});
for(const mode of ['corrupt','extra','traversal','phase','symlink'])test('offline verifier rejects '+mode+' archive',t=>{
  const root=fs.mkdtempSync(path.join(os.tmpdir(),'nudge-kit-test-'));t.after(()=>fs.rmSync(root,{recursive:true,force:true}));
  const out=path.join(root,'changed.zip');
  const script=`import sys,zipfile,json,stat
with zipfile.ZipFile(sys.argv[1]) as z:
 data={i.filename:z.read(i.filename) for i in z.infolist()}
 mode=sys.argv[3]
 if mode=='corrupt':data['README.txt']+=b'changed'
 if mode=='extra':data['operations/.env']=b'UNIT FIXTURE'
 if mode=='traversal':data['../escape.txt']=b'UNIT FIXTURE'
 if mode=='phase':
  m=json.loads(data['MANIFEST.json']);m['phase']='device-verified';data['MANIFEST.json']=json.dumps(m).encode()
 with zipfile.ZipFile(sys.argv[2],'w') as w:
  for n,b in data.items():
   i=zipfile.ZipInfo(n)
   if mode=='symlink' and n=='README.txt':i.external_attr=(stat.S_IFLNK|0o777)<<16
   w.writestr(i,b)
`;
  const changed=spawnSync('python3',['-c',script,kit,out,mode],{encoding:'utf8'});assert.equal(changed.status,0,changed.stderr);
  const a=spawnSync('python3',[builder,'verify',out],{encoding:'utf8'});assert.equal(a.status,1,a.stdout+a.stderr);
});
