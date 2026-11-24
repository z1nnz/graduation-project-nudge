(function(root) {
  'use strict';
  const core = root.NudgeGrowthMuseumCore;
  if (!core || !document.querySelector('[data-growth-museum]')) return;
  const host = document.getElementById('museumView');
  const status = document.getElementById('museumStatus');
  const isDemo = document.body.dataset.museumDemo === 'true';
  let generation = 0, cleanup = () => {}, authOff = null, started = false;
  function node(tag,text,attributes) {
    const element = document.createElement(tag);
    if (text !== undefined && text !== null) element.textContent = String(text);
    for (const [k,v] of Object.entries(attributes || {})) element.setAttribute(k,String(v));
    return element;
  }
  function button(text,fn) {
    const b = node('button',text,{type:'button'});b.addEventListener('click',fn);return b;
  }
  function download(name,text) {
    const url = URL.createObjectURL(new Blob([text],{type:'text/plain;charset=utf-8'}));
    const link = node('a','',{href:url,download:name});document.body.append(link);link.click();link.remove();
    setTimeout(() => URL.revokeObjectURL(url),0);
  }
  function message(text) { status.textContent = text; }
  const ui = {node,button,download,message};
  const route = isDemo ? {...core.routes[1]} : core.routeFor(location.pathname.split('/').pop());
  document.getElementById('museumTitle').textContent = route.label;
  document.getElementById('museumDescription').textContent = route.description;
  const nav = document.getElementById('museumNav');
  for (const entry of core.routes) {
    const a = node('a',entry.label,{href:entry.file});
    if (entry.id === route.id) a.setAttribute('aria-current','page');
    nav.append(a);
  }
  const world = document.getElementById('museumWorld');
  // town_return.js owns the fixed return route and building arrival.

  function loadFeature(feature) {
    const globals = {review:'NudgeGrowthReview',tools:'NudgeGrowthTools',capsules:'NudgeGrowthCapsules',identity:'NudgeGrowthIdentity'};
    const key = globals[feature];
    if (root[key]) return Promise.resolve(root[key]);
    return new Promise((resolve,reject) => {
      const script=node('script',null,{src:'assets/growth_'+feature+'.js?v=1'});
      script.onload=() => root[key] ? resolve(root[key]) : reject(new Error('module'));
      script.onerror=() => reject(new Error('module'));
      document.head.append(script);
    });
  }
  function shelves() {
    const shelf=node('section',null,{class:'museum-books','aria-label':'可翻閱的成長書籍'});
    for (const r of core.routes.slice(1)) {
      const a=node('a',null,{href:r.file,class:'museum-book'});
      a.append(node('strong',r.label),node('span',r.description));shelf.append(a);
    }
    host.append(shelf,node('p','正式數字只來自本人雲端已確認的活動。家庭、團體成果不換算成個人 XP 或自律幣。'));
  }
  async function show(user) {
    const epoch=++generation;
    cleanup();cleanup=() => {};host.replaceChildren();
    // Never use demo IDs, caches or another viewer's route parameter as identity.
    const uid = !user?.isAnonymous && user?.uid ? user.uid : null;
    const alive=() => epoch===generation && (isDemo || (root.firebase.auth().currentUser?.uid===uid && !root.firebase.auth().currentUser?.isAnonymous));
    if (route.id==='home') {shelves();message(uid?'已登入；點選一本書開始回顧。':'登入後讀取本人成長紀錄。');return;}
    if (!uid && !isDemo) {
      host.append(node('h2','這一頁只屬於你'),node('p','登入後，才會讀取你自己的紀錄。沒有資料時不會以範例補滿。'),node('a','登入帳號',{href:'login.html'}));
      message('尚未登入。');return;
    }
    message(isDemo?'展示模式：全部是虛構範例，不能寫入正式資料。':'正在讀取；尚未顯示任何個人成果。');
    const context={
      uid:isDemo?'museum-demo':uid,demo:isDemo,alive,
      db:isDemo?null:root.firebase.firestore(),
      functions:isDemo?null:root.firebase.app().functions('asia-east1'),
      host,ui,route,
    };
    try {
      const feature=await loadFeature(route.feature);
      if (!alive()) return;
      const stop=await feature.mount(context);
      if (alive()) cleanup=typeof stop==='function'?stop:() => {};
      else if (typeof stop==='function') stop();
    } catch (_) {
      if (!alive()) return;
      host.replaceChildren(node('h2','這個篇章尚未就緒'),node('p','請稍後重試；不會用固定數字代替你的資料。'),button('重新讀取',() => show(user)));
      message('功能載入失敗或整合尚未完成。');
    }
  }
  function start() {
    if (started || isDemo || !root.firebase?.apps?.length) return;
    started=true;
    authOff=root.firebase.auth().onAuthStateChanged(show);
  }
  root.addEventListener('pagehide',() => {++generation;cleanup();authOff?.();authOff=null;started=false;host.replaceChildren();});
  root.addEventListener('pageshow',()=>{if(isDemo)show({uid:'museum-demo'});else start();});
  document.addEventListener('firebase-ready',start);
  if (isDemo) show({uid:'museum-demo'});
  else {
    const script=node('script',null,{src:'assets/app.js?v=28&surface=growth-museum-2'});
    script.onerror=() => {message('無法連線。請重試；沒有載入個人資料。');};
    document.head.append(script);
    start();
  }
})(typeof globalThis !== 'undefined' ? globalThis : this);
