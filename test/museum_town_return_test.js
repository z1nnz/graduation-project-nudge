const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs');
const routes=require('../web_dashboard/assets/town_routes.js');
test('all personal player pages use the shared town return contract',()=>{
 const pages=fs.readdirSync('web_dashboard').filter(p=>/^personal.*\.html$/.test(p));
 assert.ok(pages.includes('personal-share.html'));
 assert.equal(pages.length,11);
 for(const page of pages){
  const html=fs.readFileSync('web_dashboard/'+page,'utf8');
  assert.match(html,/<a[^>]*data-town-return[^>]*href="town\.html"[^>]*>← 回小鎮<\/a>/,page);
  assert.match(html,/assets\/town_routes\.js/,page);assert.match(html,/assets\/town_return\.js/,page);
  const href=routes.returnHrefForPage(page);
  assert.equal(href,page==='personal-focus.html'?'town.html?at=cabin':'town.html?at=library');
 }
});
