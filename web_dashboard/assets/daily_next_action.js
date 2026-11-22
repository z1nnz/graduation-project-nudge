(function (root) {
  'use strict';
  function resolve(tasks) {
    const fixed = (Array.isArray(tasks) ? tasks : []).filter(t => t && typeof t === 'object' && t.taskType !== 'deadline');
    const pending = fixed.filter(t => t.done !== true && t.isDone !== true);
    const sources = ['sleepHours', 'steps', 'exerciseMinutes', 'focusMinutes', 'studyRoom'];
    const manual = pending.filter(t => t.isAutoTracked !== true && !sources.includes(t.sourceType) && typeof t.title === 'string' && t.title.trim());
    const rank = p => ['高', 'high'].includes(p) ? 0 : ['低', 'low'].includes(p) ? 2 : 1;
    let next = null;
    for (const task of manual) if (!next || rank(task.priority) < rank(next.priority)) next = task;
    if (next) return { kind: 'task', title: next.title.trim(), detail: '先從這一件開始；可以到任務頁調整或拆小。', button: '查看我的任務' };
    if (pending.length) return { kind: 'tracking', title: '讓紀錄跟上你的行動', detail: '目前有自動追蹤或待整理的項目，請到任務頁確認來源與目標。', button: '查看追蹤項目' };
    if (fixed.length) return { kind: 'rest', title: '今天的清單完成了', detail: '可以休息一下；不需要為了累積獎勵再塞滿任務。', button: '回顧今日任務' };
    return { kind: 'plan', title: '從一件做得到的小事開始', detail: '先安排一個日常任務，今天不必一次改變所有習慣。', button: '安排我的任務' };
  }
  if (typeof module === 'object' && module.exports) { module.exports = { resolve }; return; }
  root.NudgeDailyNextAction = { resolve };

  let started = false;
  let unsubscribeUser = null;
  let unsubscribeAuth = null;
  let generation = 0;
  const element = id => document.getElementById(id);
  function render(title, detail, button, href, status) {
    element('dailyActionTitle').textContent = title;
    element('dailyActionDetail').textContent = detail;
    element('dailyActionLink').textContent = button;
    element('dailyActionLink').href = href;
    element('dailyActionStatus').textContent = status;
  }
  function start() {
    if (started || !element('dailyActionTitle') || !root.firebase?.apps?.length) return;
    started = true;
    unsubscribeAuth = root.firebase.auth().onAuthStateChanged(user => {
      const ownGeneration = ++generation;
      if (unsubscribeUser) unsubscribeUser();
      unsubscribeUser = null;
      if (!user) {
        render('先登入，讓夥伴認識今天的你', '登入後只讀取你自己的日常任務。', '登入帳號', 'login.html', '尚未登入');
        return;
      }
      render('正在整理你的下一步', '讀取個人清單中，不會自動完成或開始任何活動。', '開啟個人工作台', 'planet.html', '讀取中');
      unsubscribeUser = root.firebase.firestore().collection('users').doc(user.uid).onSnapshot({ includeMetadataChanges: true }, snapshot => {
        if (ownGeneration !== generation) return;
        if (!snapshot.exists) {
          render('個人資料尚未就緒', '請先完成帳號設定，再重新開啟總覽。', '開啟個人工作台', 'planet.html', '沒有帳號資料');
          return;
        }
        const action = resolve(snapshot.data().tasks);
        render(action.title, action.detail, action.button, 'planet.html',
          snapshot.metadata.hasPendingWrites ? '本機清單變更，等待同步確認' :
          snapshot.metadata.fromCache ? '快取清單，等待網路確認' : '已讀取雲端清單；獎勵另由 Cloud 驗證');
      }, () => {
        if (ownGeneration !== generation) return;
        render('暫時無法讀取清單', '目前不顯示上一個帳號的任務；請確認網路或重新登入。', '重新登入', 'login.html', '讀取失敗');
      });
    });
  }
  document.addEventListener('firebase-ready', start);
  document.addEventListener('DOMContentLoaded', start);
  root.addEventListener('pagehide', () => {
    ++generation;
    if (unsubscribeUser) unsubscribeUser();
    if (unsubscribeAuth) unsubscribeAuth();
    unsubscribeUser = unsubscribeAuth = null;
    started = false;
  });
  root.addEventListener('pageshow', start);
  start();
})(typeof globalThis !== 'undefined' ? globalThis : this);
