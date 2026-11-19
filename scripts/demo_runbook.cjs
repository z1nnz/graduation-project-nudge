#!/usr/bin/env node
'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const hex=v=>typeof v==='string'&&/^[a-f0-9]{64}$/.test(v);
const text=v=>typeof v==='string'&&v.trim().length>0&&v.length<2000;
const date=v=>typeof v==='string'&&/^\d{4}-\d{2}-\d{2}$/.test(v)&&Number.isFinite(Date.parse(v))&&new Date(v+'T00:00:00Z').toISOString().slice(0,10)===v;
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
function fileOK(ref,root,kind){
  if(!ref||ref.kind!==kind||!text(ref.file)||!hex(ref.sha256)||path.isAbsolute(ref.file)||ref.file.includes('\\')||ref.file.split('/').includes('..'))return false;
  try{const base=fs.realpathSync(root),file=fs.realpathSync(path.resolve(base,ref.file));
    if(!file.startsWith(base+path.sep)||!fs.statSync(file).isFile()||!fs.statSync(file).size)return false;
    if(kind==='physical_video'&&(!/\.(mp4|mov|m4v)$/i.test(ref.file)||ref.continuous!==true))return false;
    const h=crypto.createHash('sha256'),b=Buffer.alloc(1024*1024),fd=fs.openSync(file,'r');
    try{let n;while((n=fs.readSync(fd,b,0,b.length,null))>0)h.update(b.subarray(0,n));}finally{fs.closeSync(fd);}
    return h.digest('hex')===ref.sha256;
  }catch{return false;}
}
function template(){
  const device=()=>({board_id:null,source_commit:null,build_id:null,environment:null,profile_sha256:null,
    binary:null,physical_video:null,wiring_photo:null,display_configured:false,physical_accepted:false,
    frozen:false,cold_boot_successes:0,demo_successes:0,restart_verified:false,home_observed:false,
    arrival_auto_run:false,arrival_build_id:null,adopted_inputs:[],adopted_modules:[],options_rehearsed:false,ble_adopted:false,ble_rehearsed:false});
  return {schema_version:1,scope:'competition-readiness-record',competition_date:null,venue:null,
    physical_acceptance_deferred:true,devices:{orbit:device(),station:device()},
    inventory:{usb_cables:[{id:null,data_capable:false,verified:false},{id:null,data_capable:false,verified:false}],
      two_independent_controllers:false,laptop_ready:false,laptop_charger_ready:false,phone_ready:false,
      phone_cable_ready:false,source_saved:false,platformio_environment_saved:false,configured_upload_tested:false,
      existing_power_accessory_confirmed:false,existing_adopted_modules_and_cables_packed:false,offline_script_opened:false},
    backups:{one_take_physical_video:null,offline_copy:null,phone_copy_confirmed:false,same_hardware_versions_confirmed:false},
    roles:{presenter:null,operator:null,reset_protocol_rehearsed:false},
    arrival_steps_completed:[],stage:{story_opening_rehearsed:false,one_action_only:false,no_login_or_pairing_for_judges:false,
      complete_growth_summary_observed:false,prototype_boundary_explained:false},
    onsite_result:{date_and_venue:null,orbit_pre_stage_result:null,station_pre_stage_result:null,interaction:null,
      ble_used:null,fallback:null,outcome:null},
    notes:'Preparation only. No hardware upload, adopted input, physical backup video or on-site result has been verified.'};
}
const arrival=['position_devices','usb_separately','verify_build_ids','orbit_auto_run','station_auto_run','restart',
  'optional_ble_or_skip','observe_home'];
function assess(s,root){
  if(s?.schema_version!==1||s.scope!=='competition-readiness-record'||!s.devices?.orbit||!s.devices?.station)throw Error('Wrong readiness schema');
  const r={schema_version:1,scope:'records-for-human-review',physical_acceptance_certified:false,
    ready_for_human_review:false,night_before_complete:false,arrival_15min_complete:false,devices:{},blockers:[]};
  for(const name of ['orbit','station']){
    const d=s.devices[name];
    if(!Array.isArray(d.adopted_inputs)||!Array.isArray(d.adopted_modules)||typeof d.ble_adopted!=='boolean'||
      d.adopted_modules.some(m=>!['button','encoder','led','light','buzzer'].includes(m)))throw Error('Invalid adopted options');
    const identity=text(d.board_id)&&typeof d.source_commit==='string'&&/^[a-f0-9]{40}$/.test(d.source_commit)&&
      text(d.build_id)&&d.build_id.startsWith(d.source_commit.slice(0,12))&&text(d.environment)&&
      d.environment.startsWith(name+'_')&&hex(d.profile_sha256)&&d.display_configured===true;
    let binary=fileOK(d.binary,root,'application_image');
    if(binary){const b=fs.readFileSync(path.resolve(root,d.binary.file));binary=b.includes(Buffer.from(d.build_id||'INVALID'))&&
      path.basename(d.binary.file).startsWith(name+'_')&&d.binary.configuration==='accepted-profile';}
    const accepted=Boolean(identity&&binary&&d.physical_accepted===true&&d.frozen===true&&
      d.cold_boot_successes===3&&d.demo_successes===3&&d.restart_verified===true&&
      fileOK(d.physical_video,root,'physical_video')&&fileOK(d.wiring_photo,root,'physical_photo'));
    r.devices[name]={accepted_record_complete:accepted,arrival_complete:accepted&&d.arrival_auto_run===true&&
      d.arrival_build_id===d.build_id&&d.home_observed===true,ble_may_be_shown:d.ble_adopted&&d.ble_rehearsed&&accepted};
    if(!accepted)r.blockers.push(name+': missing accepted/frozen version, 3 cold boots, 3 replays, restart, photo or physical video');
    if(d.ble_adopted&&!d.ble_rehearsed)r.blockers.push(name+': unrehearsed BLE must be skipped');
  }
  const inv=s.inventory,b=s.backups;
  if(!inv||!b||!s.roles||!s.stage)throw Error('Incomplete readiness sections');
  const cables=Array.isArray(inv.usb_cables)&&inv.usb_cables.length===2&&
    new Set(inv.usb_cables.map(c=>c.id)).size===2&&inv.usb_cables.every(c=>text(c.id)&&c.data_capable===true&&c.verified===true);
  const kit=['two_independent_controllers','laptop_ready','laptop_charger_ready','phone_ready','phone_cable_ready',
    'source_saved','platformio_environment_saved','configured_upload_tested','offline_script_opened'].every(k=>inv[k]===true);
  const independent=text(s.devices.orbit.board_id)&&s.devices.orbit.board_id!==s.devices.station.board_id;
  const backups=fileOK(b.one_take_physical_video,root,'physical_video')&&fileOK(b.offline_copy,root,'physical_video')&&
    b.one_take_physical_video.sha256===b.offline_copy.sha256&&b.phone_copy_confirmed===true&&b.same_hardware_versions_confirmed===true;
  const people=text(s.roles.presenter)&&text(s.roles.operator)&&s.roles.reset_protocol_rehearsed===true;
  const adopted=Object.values(s.devices).some(d=>d.adopted_inputs.length||d.adopted_modules.length||d.ble_adopted);
  const optionsReady=Object.values(s.devices).every(d=>(!d.adopted_inputs.length&&!d.adopted_modules.length||d.options_rehearsed===true)&&
    (!d.ble_adopted||d.ble_rehearsed===true));
  r.night_before_complete=Boolean(date(s.competition_date)&&text(s.venue)&&s.physical_acceptance_deferred===false&&
    Object.values(r.devices).every(d=>d.accepted_record_complete)&&independent&&cables&&kit&&backups&&people&&
    optionsReady&&(!adopted||inv.existing_adopted_modules_and_cables_packed===true));
  if(!cables||!kit||!people)r.blockers.push('Inventory, two verified data cables or presenter/operator/reset rehearsal incomplete');
  if(!backups)r.blockers.push('Real one-take video, matching offline copy, phone copy or same-version statement missing');
  if(!date(s.competition_date)||!text(s.venue))r.blockers.push('Competition date/venue not confirmed');
  const steps=s.arrival_steps_completed;
  if(!Array.isArray(steps)||new Set(steps).size!==steps.length||steps.some(v=>!arrival.includes(v)))throw Error('Invalid/duplicate arrival step');
  r.arrival_15min_complete=r.night_before_complete&&arrival.every(v=>steps.includes(v))&&Object.values(r.devices).every(d=>d.arrival_complete);
  r.ready_for_human_review=r.arrival_15min_complete&&['story_opening_rehearsed','one_action_only','no_login_or_pairing_for_judges',
    'complete_growth_summary_observed','prototype_boundary_explained'].every(k=>s.stage[k]===true)&&
    Object.values(r.devices).every((d,i)=>!s.devices[['orbit','station'][i]].ble_adopted||d.ble_may_be_shown);
  r.fallback={one_device:'Use the working device; use the failed device physical video only if available.',
    both_devices:backups?'Physical video records present; operator must verify playback.':'No verified physical backup video: explain the non-live prototype honestly; do not label software preview as hardware footage.',
    app_ble:'Stop phone control; use verified local input or autoplay.',
    reset:'USB off for 5 seconds, then reconnect. Long-press only after that exact gesture is physically verified.'};
  return r;
}
function main(args){const [command,file]=args;
  if(command==='init'&&file){fs.writeFileSync(file,JSON.stringify(template(),null,2)+'\n',{flag:'wx'});console.log('Created pending readiness record');return 0;}
  const i=args.indexOf('--evidence-root');if(command!=='assess'||!file||i<0||!args[i+1])throw Error('Usage: demo_runbook.cjs init record.json | assess record.json --evidence-root DIR');
  const r=assess(JSON.parse(fs.readFileSync(file,'utf8')),args[i+1]);console.log(JSON.stringify(r,null,2));return r.ready_for_human_review?0:2;
}
if(require.main===module){try{process.exitCode=main(process.argv.slice(2));}catch(e){console.error(e.message);process.exitCode=1;}}
module.exports={template,assess,fileOK,sha,arrival};
