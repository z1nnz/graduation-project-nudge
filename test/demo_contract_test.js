const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const {generate}=require('../scripts/generate_demo_contract.cjs');
const root=path.resolve(__dirname,'..');
const source=JSON.parse(fs.readFileSync(path.join(root,'shared/demo_contract.json'),'utf8'));
test('firmware and Flutter consume the exact same generated demo protocol and visuals',()=>{
  const output=generate(source);
  assert.equal(fs.readFileSync(path.join(root,'firmware/nudge_competition_demo/include/demo/generated_contract.h'),'utf8'),output.header);
  assert.equal(fs.readFileSync(path.join(root,'lib/demo/generated_demo_contract.dart'),'utf8'),output.dart);
  assert.equal(fs.readFileSync(path.join(root,'android/app/src/main/kotlin/com/example/nudge/DemoBleSpec.kt'),'utf8'),output.kotlin);
});
test('visual contract rejects duplicate poses, invalid geometry and incompatible scenes',()=>{
  for(const mutate of [c=>c.poses.focus=c.poses.idle,c=>c.poses.idle[0][3]=80,c=>c.scenes.push('extra'),c=>c.animation.stepMs=10]){
    const c=structuredClone(source);mutate(c);assert.throws(()=>generate(c));
  }
});
