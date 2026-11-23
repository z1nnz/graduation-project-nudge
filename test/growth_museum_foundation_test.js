const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs');
const core=require('../web_dashboard/assets/growth_museum_core.js');
test('museum routes are fixed local destinations and the world fallback exists',()=>{
  assert.equal(core.routes.length,9);
  for(const r of core.routes){assert.match(r.file,/^personal(?:-[a-z-]+)?\.html$/);assert.ok(fs.existsSync('web_dashboard/'+r.file));}
  assert.equal(core.returnRoute(false),'town.html');assert.equal(core.returnRoute(true),'town.html');
  assert.equal(core.routeFor('https://other.test').id,'home');
});
test('real personal pages no longer contain the old fabricated figures or unsealed capsule UI',()=>{
  for(const r of core.routes){
    const html=fs.readFileSync('web_dashboard/'+r.file,'utf8');
    assert.doesNotMatch(html,/82 分|310 枚|截止日 78%|睡眠 54%|2026-06-15|data-capsule-message|data-toast/);
    assert.match(html,/data-museum-demo="false"/);assert.match(html,/role="status"/);assert.match(html,/id="museumWorld" data-town-return href="town.html"/);
    assert.match(html,/growth_museum\.js/);
  }
});
test('sample data has an explicit separate read-only page',()=>{
  const html=fs.readFileSync('web_dashboard/museum-demo.html','utf8');
  assert.match(html,/data-museum-demo="true"/);
  assert.doesNotMatch(html,/<script[^>]+src="assets\/app\.js/);
  assert.ok(core.sources.rewards.includes('separate'));
});
