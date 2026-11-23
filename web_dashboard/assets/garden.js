(function (root) {
  'use strict';
  // Starlight garden scene. Login is enforced by app.js (this page is not
  // public); the level gate is re-checked here from the user's own document
  // so the town is never the only gate. Read-only: nothing here writes.
  const core = root.NudgeGardenCore;
  const doc = root.document;
  if (!core || !doc || doc.body?.dataset.page !== 'garden') return;
  const els = id => doc.getElementById(id);

  let started = false;
  let unsubscribeUser = null;
  let generation = 0;

  function show(view) {
    els('gardenLocked').hidden = view !== 'locked';
    els('gardenScene').hidden = view !== 'scene';
  }

  function renderBeds() {
    const stage = els('gardenBeds');
    const list = els('gardenBedList');
    stage.textContent = '';
    list.textContent = '';
    for (const bed of core.BEDS) {
      const plot = doc.createElement('li');
      plot.className = 'garden-bed is-stage-0';
      plot.dataset.bed = bed.id;
      stage.appendChild(plot);
      const item = doc.createElement('li');
      item.textContent = `${bed.name}：${bed.plant}還在土裡，等待雲端確認的行動。`;
      list.appendChild(item);
    }
    els('gardenSceneSummary').textContent =
      '花圃會隨你自己雲端確認的行動長大；花園不會發放經驗值或自律幣。';
  }

  function applyUser(data) {
    const gate = core.access(data?.avatarLevel);
    els('gardenLevel').textContent = `Lv ${gate.level}`;
    if (!gate.unlocked) {
      els('gardenLockedText').textContent = gate.reason;
      els('gardenStatus').textContent = '花園尚未開放';
      show('locked');
      return;
    }
    els('gardenStatus').textContent = '歡迎來到星光花園';
    renderBeds();
    show('scene');
  }

  function start() {
    if (started || !root.firebase?.apps?.length) return;
    started = true;
    root.firebase.auth().onAuthStateChanged(user => {
      const own = ++generation;
      unsubscribeUser?.();
      unsubscribeUser = null;
      show(null);
      if (!user) {
        els('gardenStatus').textContent = '請先登入，花園只顯示你自己的行動。';
        return;
      }
      els('gardenStatus').textContent = '正在確認你的角色等級…';
      unsubscribeUser = root.firebase.firestore().collection('users').doc(user.uid)
        .onSnapshot(snap => {
          if (own !== generation) return;
          applyUser(snap.exists ? snap.data() : null);
        }, () => {
          if (own !== generation) return;
          show(null);
          els('gardenStatus').textContent = '暫時無法讀取角色等級，請確認網路後重新整理。';
        });
    });
  }

  doc.addEventListener('firebase-ready', start);
  root.addEventListener('pagehide', () => { ++generation; unsubscribeUser?.(); unsubscribeUser = null; });
  start();
})(typeof globalThis !== 'undefined' ? globalThis : this);
