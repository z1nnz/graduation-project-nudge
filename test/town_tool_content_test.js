const test=require('node:test'),assert=require('node:assert/strict');
const {scenarioDraft,catalogRows,steps}=require('../web_dashboard/assets/town_tools.js');
test('scenario exports actual user text with an explicit non-research label',()=>{
 const output=scenarioDraft(' My title ',' <script>plain text</script> ');
 assert.match(output,/本人輸入，非正式研究結果/);assert.match(output,/<script>plain text<\/script>/);
 for(const args of [['','body'],['t',''],['t','x'.repeat(8001)]])assert.throws(()=>scenarioDraft(...args));
});
test('catalog presentation ignores drafts and never presents ownership or reward claims',()=>{
 const rows=catalogRows([{id:'draft',data:{status:'draft',name:'Hidden'}},{id:'real',data:{status:'published',name:'Real',type:'avatar_series',secret:'not exposed'}}]);
 assert.deepEqual(rows,[{id:'real',name:'Real',type:'avatar_series'}]);
 assert.ok(steps.every(s=>s.title&&s.text));
});
test('operational admin inline handlers remain valid JavaScript after the frame conversion',()=>{
 const fs=require('node:fs'),vm=require('node:vm');
 const html=fs.readFileSync('web_dashboard/admin_dashboard.html','utf8');
 const scripts=[...html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/g)].map(m=>m[1]).filter(s=>s.trim());
 assert.ok(scripts.length>0);for(const source of scripts)assert.doesNotThrow(()=>new vm.Script(source));
});
