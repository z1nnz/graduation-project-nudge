(function (root) {
  'use strict';
  // 委託冊 page: reads the player's own tasks and Cloud-confirmed activity
  // receipts, keeps chosen chains and certificates on this device (per
  // account), and never writes rewards anywhere.
  const doc = root.document;
  const core = root.NudgeQuestChainCore;
  if (!doc || !core || doc.body?.dataset.page !== 'quests') return;

  const byId = id => doc.getElementById(id);
  const STORE_PREFIX = 'nudge_quest_book_v1:';
  const STAMP_ART = ['assets/quests/stamp_violet.png', 'assets/quests/stamp_gold.png', 'assets/quests/stamp_green.png'];
  const STATUS_TEXT = {
    active: ['進行中', 'is-wait'],
    completed: ['委託完成', 'is-ok'],
    expired: ['已過期限', 'is-alert'],
    unreachable: ['這次來不及了', 'is-alert'],
  };
  const reducedMotion = root.matchMedia ? root.matchMedia('(prefers-reduced-motion: reduce)') : { matches: false };

  let user = null;
  let connected = false;
  let generation = 0;
  let receipts = [];
  let cloudReady = false;
  let store = core.normalizeStore(null);
  let dialogReturn = null;
  const armed = new Set(); // chains whose "放下" was pressed once

  // ---------- helpers ----------

  function el(tag, className, text) {
    const node = doc.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined) node.textContent = text;
    return node;
  }
  function setStatus(text, kind) {
    const chip = byId('qbStatus');
    chip.textContent = text;
    chip.className = `w-chip ${kind || ''}`;
  }
  let toastTimer = 0;
  function toast(text) {
    const node = byId('qbToast');
    node.textContent = text;
    node.hidden = false;
    root.clearTimeout(toastTimer);
    toastTimer = root.setTimeout(() => { node.hidden = true; }, 2600);
  }
  function shortDay(day) { return day ? `${Number(day.slice(5, 7))}/${Number(day.slice(8, 10))}` : ''; }
  function stampArt(templateId) {
    const index = Math.max(0, core.TEMPLATES.findIndex(t => t.id === templateId));
    return STAMP_ART[index % STAMP_ART.length];
  }

  // ---------- local store ----------

  function loadStore(uid) {
    try { return core.normalizeStore(JSON.parse(root.localStorage.getItem(STORE_PREFIX + uid) || 'null')); }
    catch (_) { return core.normalizeStore(null); }
  }
  function saveStore() {
    if (!user) return;
    try { root.localStorage.setItem(STORE_PREFIX + user.uid, JSON.stringify(store)); }
    catch (_) { toast('這台裝置無法儲存委託冊，重新整理後可能會不見。'); }
  }

  // ---------- render ----------

  function progressMap(now) {
    const map = {};
    for (const chain of store.chains) map[chain.id] = core.chainProgress(chain, receipts, now);
    return map;
  }

  function render() {
    const now = new Date();
    const progress = cloudReady ? progressMap(now) : {};
    if (cloudReady) {
      const result = core.collectCertificates(store, progress);
      store = result.store;
      if (result.earned.length) {
        saveStore();
        // Show the newest certificate after the stamp lands.
        root.setTimeout(() => openCertificate(result.earned[result.earned.length - 1], true), reducedMotion.matches ? 0 : 320);
      }
    }
    renderChains(progress);
    renderTemplates();
    renderCertificates();
    if (cloudReady) {
      let changed = false;
      for (const chain of store.chains) {
        const p = progress[chain.id];
        if (p && store.seenStamps[chain.id] !== p.stamps) { store.seenStamps[chain.id] = p.stamps; changed = true; }
      }
      if (changed) saveStore();
    }
  }

  function renderChains(progress) {
    const box = byId('qbChains');
    box.replaceChildren();
    const open = store.chains.filter(c => !c.closed);
    if (!user) { box.append(el('p', 'w-empty', '登入後就能接委託。')); return; }
    if (!open.length) { box.append(el('p', 'w-empty', '還沒有進行中的委託。從下面的範本挑一條吧。')); return; }
    for (const chain of open) {
      const template = core.templateById(chain.templateId);
      const p = progress[chain.id];
      const card = el('article', 'w-parchment qb-chain');
      card.dataset.status = p ? p.status : 'loading';
      const head = el('div', 'qb-chain-head');
      head.append(el('h3', null, template.title));
      const [label, kind] = p ? STATUS_TEXT[p.status] : ['雲端確認中', 'is-wait'];
      head.append(el('span', `w-chip ${kind}`, label));
      card.append(head, el('p', 'w-muted', template.rule));

      const row = el('ol', 'qb-stamps');
      row.setAttribute('aria-label', p ? `印章 ${p.stamps} / ${p.target}` : '印章讀取中');
      const seen = store.seenStamps[chain.id] ?? 0;
      for (let i = 0; i < template.target; i += 1) {
        const slot = el('li', 'qb-slot');
        if (p && i < p.stamps) {
          slot.classList.add('is-stamped');
          if (i >= seen && !reducedMotion.matches) slot.classList.add('is-new');
          const img = el('img');
          img.src = stampArt(template.id);
          img.width = 48; img.height = 46; img.alt = '';
          slot.append(img);
          const day = p.stampDays[i];
          if (day) slot.title = `${shortDay(day)} 雲端確認`;
        } else {
          slot.append(el('span', 'qb-slot-num', String(i + 1)));
        }
        row.append(slot);
      }
      card.append(row);

      const info = el('p', 'qb-chain-info');
      if (!p) info.textContent = '雲端確認中…';
      else if (p.status === 'completed') info.textContent = `${shortDay(p.completedDay)} 蓋滿最後一格。證書已收進證書冊。`;
      else if (p.status === 'expired') info.textContent = `期限 ${shortDay(p.deadline)} 已過，蓋了 ${p.stamps} / ${p.target} 格。可以從今天重新開始。`;
      else if (p.status === 'unreachable') info.textContent = `剩下的天數不夠蓋滿 ${p.target} 格了。休息一下，想再挑戰時從今天重新開始。`;
      else {
        const parts = [`${shortDay(chain.startDay)} 開始，期限 ${shortDay(p.deadline)}（還有 ${p.daysLeft} 天）`];
        if (p.brokenOn) parts.push(`${shortDay(p.brokenOn)} 沒有蓋章，連續天數重新數起`);
        info.textContent = parts.join('。') + '。';
      }
      card.append(info);

      const actions = el('div', 'qb-actions');
      if (p && (p.status === 'expired' || p.status === 'unreachable')) {
        const again = el('button', 'w-btn is-gold', '從今天重新開始');
        again.type = 'button';
        again.addEventListener('click', () => restart(chain.id));
        actions.append(again);
      }
      if (p && p.status === 'completed') {
        const done = el('button', 'w-btn is-gold', '收好，騰出位置');
        done.type = 'button';
        done.addEventListener('click', () => closeChain(chain.id, '委託收好了，證書在下面。'));
        actions.append(done);
      } else {
        const drop = el('button', 'w-btn', armed.has(chain.id) ? '確定放下？再按一次' : '放下這條委託');
        drop.type = 'button';
        drop.addEventListener('click', () => {
          if (!armed.has(chain.id)) { armed.add(chain.id); render(); focusAction(chain.id); return; }
          armed.delete(chain.id);
          closeChain(chain.id, '已放下這條委託。');
        });
        drop.dataset.chain = chain.id;
        actions.append(drop);
      }
      card.append(actions);
      box.append(card);
    }
  }

  function focusAction(chainId) {
    const button = byId('qbChains').querySelector(`button[data-chain="${CSS.escape(chainId)}"]`);
    if (button) button.focus();
  }

  function renderTemplates() {
    const box = byId('qbTemplates');
    box.replaceChildren();
    const open = store.chains.filter(c => !c.closed);
    for (const template of core.TEMPLATES) {
      const card = el('article', 'w-panel qb-template');
      const art = el('img', 'qb-template-stamp');
      art.src = stampArt(template.id); art.width = 48; art.height = 46; art.alt = '';
      card.append(art, el('h3', null, template.title), el('p', null, template.rule));
      const meta = template.kind === 'streak' ? `連續 ${template.target} 天` : `${template.target} 格印章`;
      card.append(el('p', 'qb-template-meta', `${meta} · ${template.windowDays} 天內完成`));
      const button = el('button', 'w-btn is-violet', '接下委託');
      button.type = 'button';
      let reason = '';
      if (!user) reason = '登入後可以接';
      else if (!cloudReady) reason = '雲端確認中';
      else if (open.some(c => c.templateId === template.id)) reason = '進行中';
      else if (open.length >= core.MAX_ACTIVE) reason = '已有 3 條進行中';
      if (reason) { button.disabled = true; button.textContent = reason; }
      button.addEventListener('click', () => create(template.id));
      card.append(button);
      box.append(card);
    }
  }

  function renderCertificates() {
    const box = byId('qbCerts');
    box.replaceChildren();
    if (!store.certificates.length) {
      box.append(el('p', 'w-empty', '完成第一條委託鏈，就會在這裡放一張證書。'));
      return;
    }
    for (const cert of store.certificates.slice().reverse()) {
      const button = el('button', 'qb-cert-card');
      button.type = 'button';
      const img = el('img'); img.src = stampArt(cert.templateId); img.width = 48; img.height = 46; img.alt = '';
      button.append(img, el('strong', null, cert.title), el('span', null, `${shortDay(cert.completedDay)} 完成`));
      button.setAttribute('aria-label', `查看「${cert.title}」證書，${shortDay(cert.completedDay)} 完成`);
      button.addEventListener('click', () => openCertificate(cert, false));
      box.append(button);
    }
  }

  // ---------- certificate dialog ----------

  function openCertificate(cert, celebrate) {
    const dialog = byId('qbCertDialog');
    if (dialog.open) return;
    dialogReturn = doc.activeElement;
    byId('qbCertTitle').textContent = cert.title;
    byId('qbCertStamp').src = stampArt(cert.templateId);
    byId('qbCertText').textContent =
      `從 ${shortDay(cert.startDay)} 開始，在 ${shortDay(cert.completedDay)} 蓋滿 ${cert.stamps} 格印章。`;
    dialog.classList.toggle('is-celebrate', Boolean(celebrate) && !reducedMotion.matches);
    if (typeof dialog.showModal === 'function') dialog.showModal();
    else dialog.setAttribute('open', '');
    byId('qbCertClose').focus();
  }
  function closeCertificate() {
    const dialog = byId('qbCertDialog');
    if (typeof dialog.close === 'function') dialog.close();
    else dialog.removeAttribute('open');
  }
  byId('qbCertClose').addEventListener('click', closeCertificate);
  byId('qbCertDialog').addEventListener('close', () => {
    // An automatic (celebration) open has no opener: land on the new certificate.
    const opener = dialogReturn && dialogReturn !== doc.body && doc.contains(dialogReturn) ? dialogReturn : null;
    dialogReturn = null;
    const target = opener || byId('qbCerts').querySelector('.qb-cert-card') || byId('qbCertsTitle');
    if (!target.matches('button, a')) target.setAttribute('tabindex', '-1');
    target.focus();
  });

  // ---------- actions ----------

  function create(templateId) {
    if (!user || !cloudReady) return;
    try {
      const chain = core.createChain(templateId, new Date(), store.chains);
      store = { ...store, chains: [...store.chains, chain] };
      saveStore();
      render();
      toast(`接下「${core.templateById(templateId).title}」。今天就能蓋第一格。`);
    } catch (error) { toast(error.message); }
  }

  function restart(chainId) {
    const now = new Date();
    const chain = store.chains.find(c => c.id === chainId);
    if (!chain) return;
    const next = core.restartChain(chain, core.chainProgress(chain, receipts, now), now);
    if (next === chain) return;
    store = { ...store, chains: store.chains.map(c => (c.id === chainId ? { ...c, closed: true } : c)).concat(next) };
    saveStore();
    render();
    toast('從今天重新開始。慢慢來也沒關係。');
  }

  function closeChain(chainId, message) {
    store = { ...store, chains: store.chains.map(c => (c.id === chainId ? { ...c, closed: true } : c)) };
    saveStore();
    render();
    toast(message);
    byId('qbActiveTitle').setAttribute('tabindex', '-1');
    byId('qbActiveTitle').focus();
  }

  // ---------- townsfolk request ----------

  function renderRequest(request, state) {
    const line = byId('qbRequestLine');
    const chip = byId('qbRequestState');
    byId('qbRequestDay').textContent = `· ${shortDay(core.taskDayKey(new Date()))}`;
    if (state) { line.textContent = state; chip.hidden = true; return; }
    if (!request) {
      byId('qbNpcName').textContent = '歐莉';
      byId('qbNpcRole').textContent = '告示板管理員';
      setPortrait('assets/town/guide.png', 96, 124);
      line.textContent = '今天的告示板還是空的。到任務清單安排一件小事，明天起鎮民就會來拜託你。';
      chip.hidden = true;
      return;
    }
    byId('qbNpcName').textContent = request.npc.name;
    byId('qbNpcRole').textContent = request.npc.role;
    if (request.npc.portrait.includes('/characters/')) setPortrait(request.npc.portrait, 128, 192);
    else setPortrait(request.npc.portrait, 96, 124);
    line.textContent = request.done ? `「${request.taskTitle}」已經在清單上打勾了，謝謝你！` : request.line;
    chip.hidden = false;
    chip.className = `w-chip ${request.done ? 'is-ok' : 'is-wait'}`;
    chip.textContent = request.done ? '✓ 已在清單打勾' : '今天的請託';
  }
  function setPortrait(src, width, height) {
    const img = byId('qbNpcImg');
    img.src = src; img.width = width; img.height = height;
    // Characters are 512x768: shown at 1/4 and framed from the head down.
    img.closest('figure').classList.toggle('is-character', src.includes('/characters/'));
  }

  // ---------- Cloud reads ----------

  async function readReceipts(uid, request) {
    const db = root.firebase.firestore();
    const start = core.receiptWindowStart(store.chains, new Date());
    const base = db.collection('activity_receipts')
      .where('actorUserId', '==', uid)
      .where('verifiedAt', '>=', start)
      .orderBy('verifiedAt', 'desc');
    const out = [];
    let cursor = null;
    for (let page = 0; page < 20; page += 1) {
      let query = base.limit(100);
      if (cursor) query = query.startAfter(cursor);
      const snap = await query.get({ source: 'server' });
      if (request !== generation) return null;
      for (const item of snap.docs) out.push({ ...item.data(), receiptId: item.id });
      if (snap.size < 100) return out;
      cursor = snap.docs[snap.docs.length - 1];
    }
    throw new Error('這段期間的紀錄太多，暫時無法完整計算印章。');
  }

  async function refresh() {
    const request = ++generation;
    cloudReady = false;
    receipts = [];
    if (!user || user.isAnonymous) {
      store = core.normalizeStore(null);
      setStatus('登入自己的帳號後才能接委託', 'is-alert');
      renderRequest(null, '登入後，鎮民會從你今天的任務裡挑一件來拜託你。');
      render();
      return;
    }
    store = loadStore(user.uid);
    setStatus('雲端確認中…', 'is-wait');
    renderRequest(null, '鎮民正在看告示板…');
    render();
    const uid = user.uid;
    const db = root.firebase.firestore();
    const tasksRead = db.collection('users').doc(uid).get({ source: 'server' })
      .then(snap => {
        if (request !== generation) return;
        const data = snap.exists ? snap.data() : {};
        renderRequest(core.townsfolkRequest(data.tasks, uid, new Date()));
      })
      .catch(() => { if (request === generation) renderRequest(null, '暫時讀不到今天的任務，請稍後再看告示板。'); });
    try {
      const raw = await readReceipts(uid, request);
      if (raw === null || request !== generation) return;
      receipts = core.confirmedReceipts(raw, uid, new Date());
      cloudReady = true;
      setStatus('✓ 已讀取雲端確認紀錄', 'is-ok');
      render();
    } catch (error) {
      if (request !== generation) return;
      setStatus(error.message && /[一-鿿]/.test(error.message) ? error.message : '讀取雲端紀錄失敗，請稍後重試', 'is-alert');
      render();
    }
    await tasksRead;
  }

  byId('qbRefresh').addEventListener('click', () => { refresh(); });
  doc.addEventListener('visibilitychange', () => {
    if (doc.visibilityState === 'visible' && user && cloudReady) refresh();
  });

  function connect() {
    if (connected || !root.firebase?.apps?.length) return;
    connected = true;
    root.firebase.auth().onAuthStateChanged(next => { user = next; armed.clear(); refresh(); });
  }

  if (/[?&]view=request\b/.test(root.location.search || '')) {
    const focusRequest = () => byId('request').focus();
    if (doc.readyState === 'loading') doc.addEventListener('DOMContentLoaded', focusRequest); else focusRequest();
  }
  doc.addEventListener('firebase-ready', connect);
  connect();
  render();
})(typeof globalThis !== 'undefined' ? globalThis : this);
