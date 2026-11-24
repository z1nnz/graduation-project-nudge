const test=require('node:test'),assert=require('node:assert/strict'),vm=require('node:vm'),fs=require('node:fs');
const core=require('../web_dashboard/assets/observatory_scene_core.js');
test('weekly sky uses only actual confirmed input, deduplicates activity and never invents a starter planet',()=>{
 const rows=[{id:'f1',type:'focus',value:25,endedAt:'2026-11-23T23:00:00.000Z'},{id:'f1',type:'focus',value:25,endedAt:'2026-11-23T23:00:00.000Z'},{id:'future',type:'task',value:1,endedAt:'2026-11-29T23:00:00.000Z'}];
 const m=core.model(rows,{unlockedPlanets:['新手星球','綠洲星球']},'2026-11-24T17:00:00.000Z');assert.equal(m.week.days.length,7);assert.equal(m.activeDays,1);assert.equal(m.week.focus,25);assert.equal(m.base,true);assert.equal(m.planets.count,1);
 const empty=core.model([],{},'2026-11-24T17:00:00.000Z');assert.equal(empty.base,false);assert.equal(empty.activeDays,0);assert.equal(empty.planets.count,0);assert.equal(empty.week.empty,true);
 const legacy=core.model([],{planetCount:2},'2026-11-24T17:00:00.000Z');assert.equal(legacy.base,false);assert.equal(legacy.planets.nodes[0].name,'星球（類型未記錄）');
});
test('multiple growth surfaces share one bootstrap; a failed injected script can retry',()=>{
 const scripts=[],doc={head:{append(n){scripts.push(n);}},createElement(){return {setAttribute(k,v){this[k]=v;},remove(){scripts.splice(scripts.indexOf(this),1);}};},querySelector(){return scripts.find(s=>s.src.startsWith('assets/app.js'))||null;},addEventListener(){},getElementById(){return null;}};
 const root={document:doc,addEventListener(){}};vm.runInNewContext(fs.readFileSync('web_dashboard/assets/growth_world.js','utf8'),root);root.NudgeGrowthWorld.connect(()=>{});root.NudgeGrowthWorld.connect(()=>{});assert.equal(scripts.length,1);scripts[0].onerror();root.NudgeGrowthWorld.connect(()=>{});assert.equal(scripts.length,1);
});
test('sky animation uses a complete reduced first frame and cancels hidden/offscreen frames',()=>{
 const frames=new Map(),events={},media={matches:true,addEventListener(k,fn){events.media=fn;},removeEventListener(){}},context=new Proxy({},{get:()=>()=>{}});let next=0,intersection;
 const stage={children:[],prepend(n){this.children.unshift(n);},append(n){this.children.push(n);},getBoundingClientRect(){return {width:360,height:680};}},doc={hidden:false,documentElement:{},createElement(tag){return {style:{},setAttribute(){},getContext(){return context;},remove(){}};},addEventListener(k,fn){events[k]=fn;},removeEventListener(){}};
 const root={document:doc,matchMedia:()=>media,devicePixelRatio:1,getComputedStyle:()=>({getPropertyValue:()=>''}),requestAnimationFrame(fn){frames.set(++next,fn);return next;},cancelAnimationFrame(id){frames.delete(id);},addEventListener(k,fn){events[k]=fn;},removeEventListener(){},IntersectionObserver:class{constructor(fn){intersection=fn;}observe(){}disconnect(){}}};
 vm.runInNewContext(fs.readFileSync('web_dashboard/assets/observatory_life.js','utf8'),root);const life=root.NudgeObservatoryLife.mount(stage,()=>null);
 function step(t){for(const [id,fn]of [...frames]){frames.delete(id);fn(t);}}
 step(0);assert.equal(frames.size,0);assert.equal(stage.children[1].style.transform,'none');media.matches=false;events.media();step(10);assert.equal(frames.size,1);doc.hidden=true;events.visibilitychange();assert.equal(frames.size,0);doc.hidden=false;events.visibilitychange();assert.equal(frames.size,1);intersection([{isIntersecting:false}]);assert.equal(frames.size,0);life.destroy();
});
