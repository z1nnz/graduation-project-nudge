(function(root,factory){const api=factory();if(typeof module==='object'&&module.exports)module.exports=api;else root.NudgeOnboardingCore=api;})(typeof globalThis!=='undefined'?globalThis:this,function(){
  'use strict';
  const starters=Object.freeze([
    {index:0,name:'星辰學徒',line:'從一小步開始，我會陪你把日常記成星光。',free:true},
    {index:3,name:'星詠見習生',line:'今天想讀哪一頁？我們慢慢來。',free:true},
    {index:6,name:'焰心新星',line:'先做一件做得到的事，讓行動點亮今天！',free:true},
    {index:9,name:'玫瑰書生',line:'為自己留一段安靜的時間，一起成長。',free:true},
    {index:12,name:'月影見習忍',line:'安靜也有力量，專注在眼前的一步。',free:false},
    {index:15,name:'森芽靈童',line:'照顧自己的步調，每一天都能重新開始。',free:false},
  ].map(Object.freeze));
  function hasCharacter(data){return Number.isInteger(data?.avatarProfile?.faceShapeIndex)&&data.avatarProfile.faceShapeIndex>=0;}
  function canSelect(data,index){const s=starters.find(s=>s.index===index);return !!s&&(s.free||(Array.isArray(data?.unlockedAvatarItems)&&data.unlockedAvatarItems.includes('faceShape:'+index)));}
  function nickname(value){const s=typeof value==='string'?value.trim():'';if(!s||s.length>40||/[\u0000-\u001f\u007f]/.test(s))throw Error('請填寫40字內的暱稱。');return s;}
  function suggestion(habit,custom=''){const options={study:'讀書 10 分鐘',exercise:'輕鬆活動 10 分鐘',sleep:'睡前留 10 分鐘放鬆',custom:String(custom).trim()};if(!Object.hasOwn(options,habit))throw Error('請選擇習慣。');return options[habit];}
  function avatar(index){if(!starters.some(s=>s.index===index))throw Error('請選擇起始角色。');const keys=['skinToneIndex','faceShapeIndex','hairStyleIndex','hairColorIndex','eyeStyleIndex','eyebrowStyleIndex','mouthStyleIndex','outfitStyleIndex','outfitColorIndex','accessoryIndex','backgroundColorIndex','avatarIconIndex'];const profile=Object.fromEntries(keys.map(k=>[k,0]));return {...profile,faceShapeIndex:index,avatarIconIndex:index,useCustomImage:false,customImagePath:null};}
  function plan({index,name,taskTitle,createTask,requestId,taskId}){nickname(name);avatar(index);if(typeof taskTitle!=='string'||(createTask===true&&!taskTitle.trim())||taskTitle.trim().length>120)throw Error('請填寫120字內的任務草稿。');if(!/^[A-Za-z0-9_-]{8,128}$/.test(requestId)||!/^[A-Za-z0-9_-]{8,128}$/.test(taskId))throw Error('請重新建立安全的請求識別。');return {index,name:nickname(name),taskTitle:taskTitle.trim(),createTask:createTask===true,requestId,taskId};}
  return Object.freeze({starters,hasCharacter,canSelect,nickname,suggestion,avatar,plan});
});
