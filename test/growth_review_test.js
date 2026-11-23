const test=require('node:test'),assert=require('node:assert/strict');
const {period,dayKey,parseSession,summarize,bookmarks}=require('../web_dashboard/assets/growth_review.js');
const now='2026-11-23T10:00:00.000Z';
const {createHash}=require('node:crypto');
const id=createHash('sha256').update('canonical-fingerprint').digest('hex');
const data={activityFingerprint:'canonical-fingerprint',activitySessionId:'s1',actorUserId:'owner',status:'completed',activityType:'focus',metricValue:25,metricUnit:'minutes',source:'web',startedAt:'2026-11-23T09:00:00.000Z',endedAt:'2026-11-23T09:25:00.000Z',roomIds:['one','two']};
test('05:00 Taipei logical day, Monday and month windows are explicit',()=>{
  assert.equal(dayKey(Date.parse('2026-11-22T20:59:59.000Z')),'2026-11-22');
  assert.equal(dayKey(Date.parse('2026-11-22T21:00:00.000Z')),'2026-11-23');
  const p=period('week',now);assert.equal(p.start,'2026-11-22T21:00:00.000Z');assert.equal(p.previousStart,'2026-11-15T21:00:00.000Z');
  assert.equal(period('month','2026-03-31T12:00:00.000Z').previousEnd,'2026-02-28T21:00:00.000Z');
});
for(const [name,patch] of Object.entries({otherOwner:{actorUserId:'other'},fingerprintMismatch:{activityFingerprint:'other'},active:{status:'active'},nan:{metricValue:NaN},wrongUnit:{metricUnit:'hours'},future:{endedAt:'2026-12-01T00:00:00.000Z'},impossibleDate:{endedAt:'2026-02-30T00:00:00.000Z'},negative:{metricValue:-1}})){
 test('review rejects '+name,async()=>assert.equal(await parseSession(id,{...data,...patch},'owner',now),null));
}
test('one session in two rooms is still one personal activity, not relationship XP',async()=>{
  const row=await parseSession(id,data,'owner',now);assert.ok(row);assert.equal(summarize([row],period('week',now)).current.sessions,1);
  assert.equal(summarize([row],period('week',now)).current.focusMinutes,25);assert.equal('xp' in row,false);
  assert.equal(bookmarks([row])[1].met,true);assert.equal(bookmarks([row])[2].met,false);
});
test('task withdrawal and missing data cannot become a reward or fake level',async()=>{
  assert.deepEqual(await parseSession(id,{...data,activityType:'task',metricUnit:'completion',metricValue:0},'owner',now),{withdrawn:true});
  assert.equal(bookmarks([]).some(b=>b.met),false);
});

test("previous-period boundary cannot count a current-month activity twice",()=>{
 const p=period("month","2026-03-31T12:00:00.000Z");
 const row={endedAt:p.start,type:"focus",value:25,day:"2026-03-01"};
 const s=summarize([row],p);assert.equal(s.current.sessions,1);assert.equal(s.previous.sessions,0);
});

test("canonical document id is fingerprint SHA-256, not the source session id",async()=>{
 assert.notEqual(id,data.activitySessionId);assert.ok(await parseSession(id,data,"owner",now));
 assert.equal(await parseSession(data.activitySessionId,data,"owner",now),null);
});
