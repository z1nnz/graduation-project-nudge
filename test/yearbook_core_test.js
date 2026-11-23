const test=require('node:test');const assert=require('node:assert/strict');
const core=require('../web_dashboard/assets/yearbook_core.js');
test('yearbook uses Taipei 05:00 including month and year rollover',()=>{
  assert.equal(core.logicalDay('2026-11-30T20:59:59.999Z'),'2026-11-30');assert.equal(core.logicalDay('2026-11-30T21:00:00.000Z'),'2026-12-01');
  assert.equal(core.logicalDay('2026-12-31T21:00:00.000Z'),'2027-01-01');assert.throws(()=>core.logicalDay('bad'));
});
test('leap-year chapter splits Monday weeks without duplicating boundary days',()=>{
  const c=core.chapter([],2024,2);assert.equal(c.days.length,29);assert.equal(c.weeks.length,5);assert.equal(c.weeks[0].start,'2024-02-01');assert.equal(c.weeks[0].end,'2024-02-04');
  assert.equal(new Set(c.weeks.flatMap(w=>w.days.map(d=>d.key))).size,29);assert.ok(c.weeks.every(w=>w.empty));assert.throws(()=>core.monthRange(2026,13));
});
test('sessions deduplicate, sum units and stay in their chapter',()=>{
  const row=(id,type,value,endedAt)=>({id,type,value,endedAt}),rows=[row('a','focus',25,'2026-10-31T21:00:00.000Z'),row('a','focus',25,'2026-10-31T21:00:00.000Z'),row('b','study',10,'2026-11-01T00:00:00.000Z'),row('c','sleep',7.5,'2026-11-01T00:00:00.000Z'),row('d','exercise',20,'2026-11-01T00:00:00.000Z'),row('e','task',1,'2026-11-01T00:00:00.000Z'),row('old','focus',99,'2026-10-31T20:59:59.999Z'),row('new','focus',99,'2026-11-30T21:00:00.000Z')];
  const c=core.chapter(rows,2026,11);assert.deepEqual(c.days[0].totals,{focus:35,exercise:20,sleep:7.5,tasks:1});assert.equal(c.days[0].rows.length,5);assert.equal(c.weeks[0].empty,false);assert.ok(c.weeks.slice(1).every(w=>w.empty));
});
test('paging clamps at chapter ends',()=>{assert.equal(core.pageIndex(-1,5),0);assert.equal(core.pageIndex(8,5),4);assert.equal(core.pageIndex(NaN,0),0);});
