(function (root) {
  'use strict';
  // Web collection case (J10): the 24 keepsakes in a glass display case.
  // Reads your own day summaries (users/{uid}.dailySummaries) and nothing
  // else; which keepsakes you have already seen arrive is kept on this device.
  // Opens as a room over the page (button #collectionOpen or #collection).
  const doc = root.document;
  const core = root.NudgeCollectionCore;
  if (!doc || !core) return;
  const host = doc.createElement('div');
  host.className = 'cc-overlay';
  host.hidden = true;
  host.setAttribute('role', 'dialog');
  host.setAttribute('aria-modal', 'true');
  host.setAttribute('aria-labelledby', 'collectionTitle');
  host.innerHTML = `<div class="cc-bar"><button type="button" class="w-btn" id="collectionClose">← 回小屋</button><h2 id="collectionTitle">收藏圖鑑</h2></div>
    <div class="cc-room">
      <p id="collectionStatus" class="cc-status" role="status" aria-live="polite">正在讀取你的收藏…</p>
      <div id="collectionCase" class="cc-case" role="group" aria-label="玻璃收藏盒：24 件收藏"></div>
      <p id="collectionLabel" class="w-parchment cc-label" role="status" aria-live="polite" hidden></p>
      <p class="w-muted cc-status">專注 25 分鐘的日子會撿到一件收藏，專注 2 小時有機會撿到稀有收藏。收藏只來自你的每日紀錄，不會發放金幣或經驗值。</p>
    </div>`;
  doc.body.append(host);
  const grid = host.querySelector('#collectionCase');
  let open = false;
  function show() { host.hidden = false; open = true; doc.body.classList.add('ph-open'); render(); host.querySelector('#collectionClose').focus(); }
  function hide() {
    host.hidden = true; open = false; doc.body.classList.remove('ph-open');
    if (root.location.hash === '#collection') root.history.replaceState(null, '', root.location.pathname);
    doc.getElementById('collectionOpen')?.focus();
  }
  host.querySelector('#collectionClose').addEventListener('click', hide);
  doc.getElementById('collectionOpen')?.addEventListener('click', show);
  doc.addEventListener('keydown', e => { if (e.key === 'Escape' && open) hide(); });
  const SEEN = 'nudge.collection.seen.v1';
  const reduced = () => root.matchMedia('(prefers-reduced-motion: reduce)').matches;
  const status = host.querySelector('#collectionStatus');
  const label = host.querySelector('#collectionLabel');

  function seen() { try { return new Set(JSON.parse(root.localStorage.getItem(SEEN) || '[]')); } catch { return new Set(); } }
  function remember(set) { try { root.localStorage.setItem(SEEN, JSON.stringify([...set])); } catch { /* private */ } }

  const slots = core.CATALOG.map((k, i) => {
    const b = doc.createElement('button');
    b.type = 'button';
    b.className = 'cc-slot';
    b.dataset.keepsake = k.id;
    b.style.setProperty('--cc-x', String(i % 6));
    b.style.setProperty('--cc-y', String(Math.floor(i / 6)));
    b.append(Object.assign(doc.createElement('i'), { className: 'cc-item' }), Object.assign(doc.createElement('i'), { className: 'cc-glass' }));
    if (k.rare) b.classList.add('is-rare');
    grid.append(b);
    return b;
  });

  let book = [];
  function render() {
    const owned = new Map();
    for (const d of book) owned.set(d.item.id, [...(owned.get(d.item.id) || []), d.date]);
    core.CATALOG.forEach((k, i) => {
      const found = owned.has(k.id);
      const b = slots[i];
      b.classList.toggle('is-found', found);
      b.setAttribute('aria-label', found ? `${k.name}，收藏 ${owned.get(k.id).length} 次` : '還沒找到的收藏');
      b.onclick = () => {
        const dates = owned.get(k.id) || [];
        label.hidden = false;
        label.textContent = found
          ? `${k.name}：第一次撿到 ${dates[dates.length - 1]}，共 ${dates.length} 次${k.rare ? '・稀有' : ''}`
          : `？？？：專注 ${k.rare ? core.RARE_MINUTES : core.COMMON_MINUTES} 分鐘的日子可能撿到。`;
      };
    });
    status.textContent = `已收藏 ${owned.size}／${core.CATALOG.length}`;
    const s = seen();
    const fresh = core.CATALOG.filter(k => owned.has(k.id) && !s.has(k.id));
    if (fresh.length && open) arrive(fresh, s);
  }

  function arrive(list, s) {
    const k = list[0];
    const slot = slots[core.CATALOG.indexOf(k)];
    slot.classList.remove('is-found');
    const box = doc.createElement('div');
    box.className = 'cc-arrive';
    box.setAttribute('role', 'status');
    box.innerHTML = '<span class="cc-box"><i class="cc-lid"></i></span><span class="cc-fly"></span><p></p>';
    box.querySelector('p').textContent = `新收藏：${k.name}！`;
    const fly = box.querySelector('.cc-fly');
    fly.style.setProperty('--cc-x', String(core.CATALOG.indexOf(k) % 6));
    fly.style.setProperty('--cc-y', String(Math.floor(core.CATALOG.indexOf(k) / 6)));
    doc.body.append(box);
    root.NudgeSfx?.play('open');
    const done = () => {
      box.remove();
      slot.classList.add('is-found', 'is-new');
      s.add(k.id);
      remember(s);
      if (list.length > 1) arrive(list.slice(1), s);
    };
    if (reduced()) { root.setTimeout(done, 900); return; }
    root.setTimeout(() => {
      const r = slot.getBoundingClientRect();
      fly.style.left = `${r.left + r.width / 2}px`;
      fly.style.top = `${r.top + r.height / 2}px`;
      box.classList.add('is-flying');
      root.NudgeSfx?.play('sparkle');
    }, 1100);
    root.setTimeout(done, 1900);
  }

  function start() {
    if (!root.firebase?.apps?.length) return;
    root.firebase.auth().onAuthStateChanged(user => {
      if (!user) { status.textContent = '請先登入，收藏盒只顯示你自己的收藏。'; return; }
      root.firebase.firestore().collection('users').doc(user.uid).onSnapshot(snap => {
        const days = snap.exists ? (snap.data().dailySummaries || []) : [];
        book = core.drops(days);
        render();
      }, () => { status.textContent = '暫時無法讀取收藏，請確認網路後重新整理。'; });
    });
  }
  let started = false;
  const go = () => { if (!started && root.firebase?.apps?.length) { started = true; start(); } };
  doc.addEventListener('firebase-ready', go);
  render();
  go();
  if (root.location.hash === '#collection') show();
  root.NudgeCollection = Object.freeze({ show, hide });
})(typeof globalThis !== 'undefined' ? globalThis : this);
