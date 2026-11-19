#!/usr/bin/env node
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const repo = 'z1nnz/graduation-project-nudge';
const sha = b => crypto.createHash('sha256').update(b).digest('hex');
const ids = ['DEMO-00','DEMO-01','DEMO-02','DEMO-03','DEMO-10','DEMO-11','DEMO-12','DEMO-13',
  ...Array.from({length:8},(_,i)=>'ORB-'+String(i+1).padStart(2,'0')),
  ...Array.from({length:9},(_,i)=>'STA-'+String(i+1).padStart(2,'0')),
  ...Array.from({length:6},(_,i)=>'DEMO-'+(30+i)),'BLE-01','BLE-02','BLE-03'];
const p0a = ['DEMO-00','DEMO-01','DEMO-02','ORB-01','ORB-02','ORB-03','STA-01','STA-02','STA-03','DEMO-32'];
function validateCatalog(c) {
  if (c?.schema_version!==1 || c.edition!=='CompetitionDemoV1' || c.items?.length!==34 ||
      c.requirements_commit!=='9ace911bf892dfb3a451acce7e2ecbeb41904f7d') throw Error('Wrong catalog edition/count');
  const map = new Map(c.items.map(i=>[i.id,i]));
  if (map.size!==34 || ids.some(id=>!map.has(id))) throw Error('Missing/duplicate canonical ID');
  for (const i of c.items) {
    const expected=p0a.includes(i.id)?'P0-A':i.id.startsWith('BLE')?'P2':
      ['ORB-07','ORB-08','STA-07','STA-08','STA-09'].includes(i.id)?'P1':'P0-B';
    const owner=i.id.startsWith('ORB')||['DEMO-01','DEMO-10','DEMO-11','DEMO-12','DEMO-13'].includes(i.id)?'johnsnow':
      i.id.startsWith('STA')||i.id==='DEMO-02'?'roy':i.id.startsWith('BLE')?'有餘力者':
      ['DEMO-03','DEMO-30','DEMO-34'].includes(i.id)?'專題負責人':'全員';
    const device=i.id.startsWith('ORB')||i.id==='DEMO-01'?'orbit':i.id.startsWith('STA')||i.id==='DEMO-02'?'station':'both';
    if (i.priority!==expected || i.device!==device ||
        i.default_role!==owner || i.source_status!=='reference_only' ||
        !Array.isArray(i.source_prs)||!i.source_prs.length||i.source_prs.some(n=>!Number.isInteger(n)||n<1)||
        !Array.isArray(i.depends_on) || i.depends_on.some(id=>!map.has(id)) ||
        new Set(i.depends_on).size!==i.depends_on.length || i.physical_status!=='pending' ||
        i.claim_status!=='unassigned' || !i.title || !i.acceptance ||
        !Array.isArray(i.focused_minutes) || i.focused_minutes.length!==2 ||
        !i.focused_minutes.every(Number.isInteger) || i.focused_minutes[0]<=0 || i.focused_minutes[1]<i.focused_minutes[0]) throw Error('Invalid catalog item: '+i.id);
  }
  const active=new Set(),done=new Set();
  function visit(id){if(active.has(id))throw Error('Dependency cycle');if(done.has(id))return;
    active.add(id);map.get(id).depends_on.forEach(visit);active.delete(id);done.add(id);}
  ids.forEach(visit);return c;
}
function marker(id){if(!ids.includes(id))throw Error('Unknown ID');return '<!-- nudge-demo:CompetitionDemoV1:'+id+' -->';}
function issueTitle(i){return '['+i.id+']['+i.priority+'] '+i.title;}
function existingIssue(i, issues){
  const found=issues.filter(x=>!x.pull_request && ((x.body||'').includes(marker(i.id)) ||
    new RegExp('^\\['+i.id+'\\]').test(x.title||'')));
  if(found.length>1)throw Error('Duplicate remote issues: '+i.id);
  return found[0]||null;
}
function eligibility(c, completed=[]){
  validateCatalog(c);const known=new Set(ids);
  if(!Array.isArray(completed)||completed.some(id=>!known.has(id)))throw Error('Unknown verified ID');
  const done=new Set(completed),allA=p0a.every(id=>done.has(id));
  return c.items.map(i=>({id:i.id,priority:i.priority,default_role:i.default_role,assigned_to:null,
    eligible_for_claim_review:!done.has(i.id) && i.depends_on.every(id=>done.has(id)) && (i.priority==='P0-A'||allA),
    blocked_by:[...i.depends_on.filter(id=>!done.has(id)),...(i.priority!=='P0-A'&&!allA?['all-P0-A-physical-acceptance']:[])],
    physical_acceptance_certified:false}));
}
function issueBody(i, registry=[]){
  const byId=new Map(registry.map(r=>[r.id,r]));
  const dep=i.depends_on.map(id=>byId.has(id)?'['+id+']('+byId.get(id).url+')':id).join('、')||'無其他細項依賴；仍需核對範圍與零件';
  const hardware=i.device==='orbit'?'Orbit：XIAO ESP32-S3＋Seeed 圓屏，實物方向／USB 仍需持板者驗。':i.device==='station'?
    'Station：Waveshare 17344 ST7789V／VW 240×320；獨立第二塊 XIAO 與 pinmap 未確認，不猜 GPIO。':'兩台各自驗證；兩塊獨立主控／版本／影片必須分開記錄。';
  return `${marker(i.id)}
## 目標
${i.title}。驗收重點：${i.acceptance}。
來源：新版 package 11，固定需求 9ace911bf892dfb3a451acce7e2ecbeb41904f7d。

## 裝置與零件
${hardware}
預設責任角色：${i.default_role}（不是已認領／GitHub assignee）。估計專注工作 ${i.focused_minutes.join('-')} 分鐘，非承諾；阻塞半天回報。

## Scope
- In：只完成 ${i.id}，每個 Issue 一分支一個可驗收 PR，base main。
- Out：不加購、不改正式帳號／Cloud／Ledger／OTA，不為消警告猜 pin，不順便認領其他 Issue。
- 前置：${dep}。
${i.priority==='P0-A'?'- P0-A 裝置工作可平行，未知零件先核對，不等動畫／感測器。':'- 目前不可認領：全體 P0-A 實機門檻未通過；本 Issue 只建待辦，不因先前軟體準備而跳過前置。'}

## 既有來源參考
${i.source_prs.map(n=>'- https://github.com/'+repo+'/pull/'+n).join('\n')}
以上只是已有軟體／文件參考，尚未合併與未驗項目按原 PR 揭露；不是本 Issue 已 source-complete 或 device-verified。

## 實作步驟
1. 確認認領與前置；從最新 main 建自己的分支，只改此成果。
2. 核對零件／型號，先最小 compile，再一個畫面或輸入一輪。
3. 實機由持板者稍後 upload／錄影；目前使用者已明確暫緩，不代填成功。
4. 存 source commit、env、build id、profile／binary hash、影片與失敗紀錄；六 CI 全綠後請 z1nnz 審查，不自行 merge。

## 驗收
- [ ] compile／文件驗證：貼命令、版本與完整結果；不適用須說明，CI 不省略
- [ ] physical upload：實際裝置／USB／版本，SUCCESS 不是畫面驗收
- [ ] physical display/input：${i.acceptance}
- [ ] fallback：無 App／網路／P1 仍可最低 P0-A；未採項目明示
- [ ] video：連續實物畫面、相同硬體版本、hash、時間碼；不是電腦預覽

## 交付
- Branch：待認領（單 Issue）
- Commit／Environment／Build id：待補
- Video／SHA-256：未拍
- Binary／Profile hash：待補
- Known limitations：實機稍後驗收、團隊認領未確認；P1／BLE OFF、Station pinmap 未配置

## 狀態與關閉
維持 open、無 assignee。沒有影片與版本不得關閉；沒有實機證據至多標 source-complete，不能標 device-verified。本 Issue 建立不等於認領、啟用周邊或驗收通過。
`;}
function validateRegistry(registry){
  if(registry.schema_version!==1||registry.repository!==repo||registry.issues?.length!==34)throw Error('Incomplete registry');
  const seen=new Set(),numbers=new Set();
  for(const i of registry.issues){if(!ids.includes(i.id)||seen.has(i.id)||!Number.isInteger(i.number)||i.number<1||numbers.has(i.number)||
    i.url!=='https://github.com/'+repo+'/issues/'+i.number||i.state!=='open'||i.assignees?.length!==0||!/^[a-f0-9]{64}$/.test(i.body_sha256))throw Error('Invalid/claimed/closed issue registry');seen.add(i.id);numbers.add(i.number);}
  return true;
}
function closeReadiness(record,root){
  const version=typeof record?.source_commit==='string'&&/^[a-f0-9]{40}$/.test(record.source_commit);
  const video=require('./demo_runbook.cjs').fileOK(record?.video,root,'physical_video');
  return {eligible_for_close_review:Boolean(version&&video&&record.physical_verified===true&&record.human_reviewed===true),
    will_close_issue:false,physical_acceptance_certified:false,
    note:'Checks submitted record completeness only. A maintainer must review footage and close the real issue.'};
}
function render(c,registry={issues:[]}){
  validateCatalog(c);const map=new Map(registry.issues.map(i=>[i.id,i]));
  const status=registry.issues.length===34?'34 項已發布，全部 open、無 assignee。':'以下 34 項仍是草稿，尚未發布，不代表 Issue 已存在或已認領。';
  return '# 34 個新版 Demo Issue\n\n預設責任不是認領。'+status+'P0-A 實機未通過前，P0-B／P1／P2 不可認領。\n\n'+
    '| ID／Issue | 優先 | 預設角色 | 依賴 | 既有參考 |\n| --- | --- | --- | --- | --- |\n'+c.items.map(i=>
    '| '+(map.has(i.id)?'['+i.id+' #'+map.get(i.id).number+']('+map.get(i.id).url+')':i.id+'（尚未發布）')+' | '+i.priority+' | '+i.default_role+' | '+(i.depends_on.join('、')||'無')+' | '+i.source_prs.map(n=>'#'+n).join('、')+' |').join('\n')+
    '\n\n估時、Scope、步驟與五項驗收在每個 Issue。現有 PR 不是裝置通過，沒有影片與版本不關閉。\n';
}
if(require.main===module){try{const args=process.argv.slice(2),[command,file]=args,raw=JSON.parse(fs.readFileSync(file,'utf8'));
  if(command==='close-check'){
    const i=args.indexOf('--evidence-root');if(i<0||!args[i+1])throw Error('close-check requires --evidence-root');
    const a=closeReadiness(raw,args[i+1]);console.log(JSON.stringify(a,null,2));process.exitCode=a.eligible_for_close_review?0:2;
  }else{const c=validateCatalog(raw);
  if(command==='validate')console.log('PASS: 34 IDs, priorities, DAG, unassigned/pending status');
  else if(command==='plan')console.log(JSON.stringify(eligibility(c),null,2));
  else throw Error('Usage: demo_backlog.cjs validate|plan backlog.json');
  }
}catch(e){console.error(e.message);process.exitCode=1;}}
module.exports={validateCatalog,marker,issueTitle,issueBody,existingIssue,eligibility,validateRegistry,closeReadiness,render,sha,ids,p0a};
