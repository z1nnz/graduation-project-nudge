(function(root,factory){
  const api=factory(typeof module==='object'&&module.exports?require('./library_scene_core.js'):root.NudgeLibrarySceneCore,typeof module==='object'&&module.exports?require('./planet_core.js'):root.NudgePlanetCore);
  if(typeof module==='object'&&module.exports)module.exports=api;else root.NudgeObservatorySceneCore=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(library,planet){
  'use strict';
  function model(rows,profile,now){
    const week=library.shelf(rows,now,1).books[0],activeDays=week.days.filter(d=>d.recorded).length;
    return {week,activeDays,base:Array.isArray(profile?.unlockedPlanets)&&profile.unlockedPlanets.includes(planet.BASE),planets:planet.planets(profile)};
  }
  return Object.freeze({model});
});
