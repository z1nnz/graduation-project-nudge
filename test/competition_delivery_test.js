const test=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {spawnSync}=require('node:child_process');
const base=path.resolve(__dirname,'..'),tool=path.join(base,'scripts/prepare_competition_delivery.py');
const archive=path.join(base,'output/delivery/Nudge-Competition-Demo-preparation-2026-11-19.zip');
const py=(args)=>spawnSync('python3',[tool,...args],{encoding:'utf8'});
function temp(t){const p=fs.mkdtempSync(path.join(os.tmpdir(),'nudge-p13-'));t.after(()=>fs.rmSync(p,{recursive:true,force:true}));return p;}
test('delivery archive has exact v1 work packages, four candidates and explicit non-acceptance',()=>{
  const a=py(['verify',archive]);assert.equal(a.status,0,a.stderr);const r=JSON.parse(a.stdout);
  assert.equal(r.work_packages,14);assert.equal(r.candidate_images,4);assert.equal(r.physical_verified,false);assert.equal(r.video_playback_verified,false);
});
test('archive source verifier is the same file as the reviewed working source',()=>{
  const a=spawnSync('python3',['-c',`import sys,zipfile
from pathlib import Path
with zipfile.ZipFile(sys.argv[1]) as z:assert z.read('Nudge-Competition-Demo/scripts/prepare_competition_delivery.py')==Path(sys.argv[2]).read_bytes()
`,archive,tool],{encoding:'utf8'});assert.equal(a.status,0,a.stderr);
});
test('verified extraction works offline and preserves all structure',t=>{
  const out=path.join(temp(t),'fresh');const a=py(['extract',archive,'--out',out]);assert.equal(a.status,0,a.stderr);
  const root=path.join(out,'Nudge-Competition-Demo');
  for(const f of ['README.md','VERSION.txt','evidence/orbit/HANDOFF.md','evidence/station/HANDOFF.md','scripts/runbook.md'])assert.equal(fs.existsSync(path.join(root,f)),true,f);
  const r=py(['evidence',path.join(root,'evidence/delivery-record.pending.json'),'--root',root]);assert.equal(r.status,2,r.stderr);
  assert.equal(JSON.parse(r.stdout).minimum_device_records_complete,false);
});
test('extract refuses an existing output and does not overwrite operator files',t=>{
  const out=temp(t);fs.writeFileSync(path.join(out,'keep.txt'),'operator content');const a=py(['extract',archive,'--out',out]);
  assert.equal(a.status,1);assert.equal(fs.readFileSync(path.join(out,'keep.txt'),'utf8'),'operator content');
});
const modes=['hash','extra','traversal','symlink','duplicate','old32','legacyFolder','mixedBinary','fakeVerified','wrongDemo','splitDemo','fakeVideo','wrongSource','badVersion','fakePR'];
for(const mode of modes)test('archive rejects '+mode+' mutation',t=>{
  const out=path.join(temp(t),'mutated.zip');
  const code=`import sys,zipfile,json,hashlib,stat
R='Nudge-Competition-Demo/'
with zipfile.ZipFile(sys.argv[1]) as z:data={i.filename[len(R):]:z.read(i.filename) for i in z.infolist()}
m=json.loads(data['MANIFEST.json']);mode=sys.argv[3];repair=False
if mode=='hash':data['README.md']+=b'corrupt'
if mode=='extra':data['evidence/unlisted.txt']=b'UNIT FIXTURE'
if mode=='traversal':data['../escape.txt']=b'UNIT FIXTURE'
if mode=='old32':data['work-packages/31-old.md']=b'UNIT LEGACY FIXTURE';repair=True
if mode=='legacyFolder':data['legacy-32/README.md']=b'UNIT LEGACY FIXTURE';repair=True
if mode=='mixedBinary':data['binaries/orbit_demo/station_mixed.bin']=b'UNIT FIXTURE';repair=True
if mode=='fakeVerified':m['physical_verified']=True
if mode=='wrongDemo':
 d=json.loads(data['evidence/demo-data.json']);d['data']['disciplineScore']=81;data['evidence/demo-data.json']=json.dumps(d).encode();repair=True
if mode=='splitDemo':
 d=json.loads(data['evidence/delivery-record.pending.json']);d['devices']['station']['demo_data_reference']='other.json';data['evidence/delivery-record.pending.json']=json.dumps(d).encode();repair=True
if mode=='fakeVideo':data['evidence/orbit/fake.mp4']=b'NOT PHYSICAL FOOTAGE';repair=True
if mode=='wrongSource':
 d=json.loads(data['SOURCE_LOCK.json']);d['firmware_commit']='b'*40;data['SOURCE_LOCK.json']=json.dumps(d).encode();repair=True
if mode=='badVersion':data['VERSION.txt']=data['VERSION.txt'].replace(b'Orbit device verified: false',b'Orbit device verified: true');repair=True
if mode=='fakePR':m['delivery_pr']='https://github.com/z1nnz/graduation-project-nudge/pull/999999'
if repair:
 old={f['file']:f for f in m['files']}
 m['files']=[dict(file=n,bytes=len(b),sha256=hashlib.sha256(b).hexdigest(),**({'origin':old[n]['origin']} if n in old and 'origin' in old[n] else {})) for n,b in sorted(data.items()) if n!='MANIFEST.json']
data['MANIFEST.json']=json.dumps(m).encode()
with zipfile.ZipFile(sys.argv[2],'w') as z:
 for n,b in data.items():
  i=zipfile.ZipInfo(R+n)
  if mode=='symlink' and n=='README.md':i.external_attr=(stat.S_IFLNK|0o777)<<16
  z.writestr(i,b)
 if mode=='duplicate':z.writestr(R+'README.md',data['README.md'])
`;
  const changed=spawnSync('python3',['-c',code,archive,out,mode],{encoding:'utf8'});assert.equal(changed.status,0,changed.stderr);
  const a=py(['verify',out]);assert.equal(a.status,1,a.stdout+a.stderr);
});
test('physical record minimum checks boot, scene order, real-file hashes, interaction and distinct boards',t=>{
  const dir=temp(t),code=`import sys,zipfile,json,hashlib,importlib.util
from pathlib import Path
spec=importlib.util.spec_from_file_location('delivery',sys.argv[1]);d=importlib.util.module_from_spec(spec);spec.loader.exec_module(d)
root=Path(sys.argv[3]);d.extract(Path(sys.argv[2]),root/'extract');root=root/'extract'/'Nudge-Competition-Demo'
r=json.loads((root/'evidence/delivery-record.pending.json').read_text());a=d.evidence(r,root);assert not a['minimum_device_records_complete']
for name,device in r['devices'].items():
 device['hardware'].update(board_id=name+'-UNIT',display_configured=True)
 device.update(physical_verified=True,operator='UNIT FIXTURE',recorded_at='2026-11-19')
 b=('UNIT BINARY '+device['build_id']).encode();file='binaries/'+name+'_fixture.bin';(root/file).write_bytes(b)
 device['binary']={'file':file,'sha256':hashlib.sha256(b).hexdigest(),'configuration':'accepted-profile'}
 device['verification'].update(physical_upload=True,cold_boot_successes=3,complete_demo_flow=True,offline_fallback=True)
 file='evidence/'+name+'/UNIT.mp4';b=b'UNIT FIXTURE - NOT PHYSICAL FOOTAGE';(root/file).write_bytes(b)
 device['media']=[dict(file=file,sha256=hashlib.sha256(b).hexdigest(),kind='physical_video',continuous=True,duration_ms=32000,
  roles=['full','closeup'],physical_xiao_visible=True,physical_screen_visible=True,boot_visible=True,complete_visible=True,scenes=['boot','home','focus','complete'])]
a=d.evidence(r,root);assert a['minimum_device_records_complete'] and not a['hardware_certified'] and not a['full_delivery_records_complete']
r['devices']['orbit']['claims']['p1']=True
assert not d.evidence(r,root)['devices']['orbit']['records_complete']
r['devices']['orbit']['claims']['p1']=False
r['devices']['orbit']['media'][0]['scenes']=['boot','complete','focus','home']
assert not d.evidence(r,root)['devices']['orbit']['records_complete']
r['devices']['orbit']['media'][0]['scenes']=['boot','home','focus','complete']
r['devices']['station']['hardware']['board_id']=r['devices']['orbit']['hardware']['board_id']
assert not d.evidence(r,root)['minimum_device_records_complete']
print('PASS: record completeness is not a hardware certificate')
`;
  const a=spawnSync('python3',['-c',code,tool,archive,dir],{encoding:'utf8'});assert.equal(a.status,0,a.stdout+a.stderr);
});
test('renaming a known unconfigured Station binary cannot turn it into accepted-profile evidence',t=>{
  const code=`import sys,zipfile,json,hashlib,importlib.util
from pathlib import Path
sp=importlib.util.spec_from_file_location('d',sys.argv[1]);d=importlib.util.module_from_spec(sp);sp.loader.exec_module(d)
root=Path(sys.argv[3]);d.extract(Path(sys.argv[2]),root/'out');root=root/'out'/'Nudge-Competition-Demo'
r=json.loads((root/'evidence/delivery-record.pending.json').read_text());s=r['devices']['station'];s['hardware'].update(board_id='UNIT',display_configured=True)
s.update(physical_verified=True,operator='UNIT',recorded_at='2026-11-19');s['verification'].update(physical_upload=True,cold_boot_successes=3,complete_demo_flow=True,offline_fallback=True)
s['binary']['configuration']='accepted-profile';data=(root/s['binary']['file']).read_bytes();(root/'binaries/station_renamed.bin').write_bytes(data);s['binary']['file']='binaries/station_renamed.bin'
b=b'UNIT FIXTURE';f='evidence/station/UNIT.mp4';(root/f).write_bytes(b);s['media']=[dict(file=f,sha256=hashlib.sha256(b).hexdigest(),kind='physical_video',continuous=True,duration_ms=32000,roles=['full','closeup'],physical_xiao_visible=True,physical_screen_visible=True,boot_visible=True,complete_visible=True,scenes=['boot','home','focus','complete'])]
assert not d.evidence(r,root)['devices']['station']['records_complete']
`;
  const a=spawnSync('python3',['-c',code,tool,archive,temp(t)],{encoding:'utf8'});assert.equal(a.status,0,a.stdout+a.stderr);
});
