(function (root) {
  'use strict';
  // Web shop for characters and cabin decor (operations.html, #82 slice 3).
  // Reads published shop_items and the account's own users/{uid} (balance and
  // owned items); buys only through the existing purchaseRewardItem callable.
  const core = root.NudgeRewardShopCore;
  const doc = root.document;
  if (!core || !doc || doc.body?.dataset.page !== 'operations') return;
  const els = id => doc.getElementById(id);
  const container = els('shop-items-container');
  if (!container) return;

  const TABS = ['permanent', 'limited', 'event_character', 'decor'];
  const EMPTY = {
    permanent: '目前沒有上架的常駐角色。',
    limited: '目前沒有限時角色。',
    event_character: '目前沒有活動角色。',
    decor: '家具目錄暫時無法讀取，請重新整理。',
  };
  const state = {
    tab: TABS.includes((root.location?.hash || '').slice(1)) ? root.location.hash.slice(1) : 'permanent',
    items: null,          // shop_items docs, null until loaded
    itemsError: false,
    catalog: null,
    uid: null,
    data: null,           // users/{uid}
    inFlight: core.createInFlight(),
    notes: new Map(),     // itemKey -> { text, tone }
  };

  function status(text) {
    const el = els('shopStatus');
    if (el) el.textContent = text;
  }

  function balance() {
    const coins = Number(state.data?.disciplineCoins);
    return Number.isSafeInteger(coins) ? coins : null;
  }

  function renderBalance() {
    const el = doc.querySelector('.hero-card strong');
    if (!el) return;
    const coins = balance();
    el.textContent = state.uid ? (coins == null ? '—' : String(coins)) : '登入後顯示';
    el.dataset.count = coins == null ? '0' : String(coins);
    doc.querySelectorAll('[data-store-coins]').forEach(n => { n.textContent = el.textContent; });
  }

  function listings() {
    const unlocked = state.data?.unlockedAvatarItems;
    if (state.tab === 'decor') return state.catalog ? core.decorListings(state.catalog, unlocked) : null;
    if (!state.items) return null;
    return core.characterListings(state.items, Math.floor(Date.now() / 1000), unlocked)
      .filter(item => item.tab === state.tab);
  }

  function message(text) {
    const box = doc.createElement('div');
    box.className = 'shop-empty';
    box.textContent = text;
    return box;
  }

  function render() {
    doc.querySelectorAll('.shop-tab-btn').forEach(btn => {
      const active = btn.dataset.tab === state.tab;
      btn.classList.toggle('active', active);
      btn.setAttribute('aria-selected', String(active));
    });
    renderBalance();
    container.textContent = '';
    const list = listings();
    if (list == null) {
      container.appendChild(message(state.tab !== 'decor' && state.itemsError ? '目前無法讀取正式商城資料，請確認網路後重新整理。' : '載入中…'));
      return;
    }
    if (!list.length) { container.appendChild(message(EMPTY[state.tab])); return; }
    for (const item of list) container.appendChild(card(item));
  }

  // One item on a shelf: tap it to lift it up and read it, then buy.
  function card(item) {
    const el = doc.createElement('article');
    el.className = 'shop-item-card store-slot';
    el.dataset.itemKey = item.itemKey;
    if (item.owned) el.dataset.owned = '1';
    const lift = doc.createElement('button');
    lift.type = 'button';
    lift.className = 'store-lift';
    lift.setAttribute('aria-expanded', 'false');
    lift.setAttribute('aria-label', `拿起來看：${item.name}`);
    const image = doc.createElement('img');
    image.src = item.image;
    image.alt = '';
    image.loading = 'lazy';
    image.addEventListener('error', () => { image.hidden = true; });
    lift.append(image);
    lift.addEventListener('click', () => {
      const lifted = !el.classList.contains('is-lifted');
      container.querySelectorAll('.store-slot.is-lifted').forEach(n => {
        n.classList.remove('is-lifted');
        n.querySelector('.store-lift')?.setAttribute('aria-expanded', 'false');
      });
      el.classList.toggle('is-lifted', lifted);
      lift.setAttribute('aria-expanded', String(lifted));
      if (lifted) root.dispatchEvent(new root.CustomEvent('nudge-shop-lift', { detail: { item } }));
    });
    if (item.endTime) {
      const badge = doc.createElement('span');
      badge.className = 'expires-badge';
      badge.textContent = `限時到 ${new Date(item.endTime * 1000).toLocaleDateString('zh-TW')}`;
      el.appendChild(badge);
    }
    const name = doc.createElement('strong');
    name.textContent = item.name;
    const tag = doc.createElement('span');
    tag.className = 'store-price';
    tag.textContent = item.owned ? '已擁有' : `${item.price} 幣`;
    const description = doc.createElement('p');
    description.className = 'store-desc';
    description.textContent = item.description;
    const button = doc.createElement('button');
    button.className = 'shop-btn w-btn';
    button.type = 'button';
    const look = core.buttonState(item, { signedIn: Boolean(state.uid), balance: balance(), busy: state.inFlight.has(item.itemKey) });
    button.textContent = look.label;
    // Short of coins: stay pressable so the shopkeeper can say how many are missing.
    button.disabled = look.disabled && look.reason !== 'balance';
    if (look.reason === 'balance') button.dataset.short = '1';
    button.addEventListener('click', () => {
      if (look.reason === 'balance') {
        root.dispatchEvent(new root.CustomEvent('nudge-shop-short', { detail: { item, missing: item.price - balance() } }));
        return;
      }
      if (look.login) goLogin(); else buy(item, button);
    });
    const note = doc.createElement('p');
    note.className = 'shop-note';
    note.setAttribute('role', 'status');
    const saved = state.notes.get(item.itemKey);
    if (saved) { note.textContent = saved.text; note.dataset.tone = saved.tone; }
    el.append(lift, name, tag, description, button, note);
    return el;
  }

  function goLogin() {
    try { root.localStorage.setItem('nudgePostLoginRedirect', `operations.html#${state.tab}`); } catch { /* private mode */ }
    root.location.href = 'login.html';
  }

  async function buy(item, from) {
    if (!state.uid) { goLogin(); return; }
    if (!state.inFlight.start(item.itemKey)) return; // second press while sending
    state.notes.set(item.itemKey, { text: '正在向雲端帳本兌換…', tone: '' });
    render();
    try {
      const fb = root.firebase;
      if (!fb?.apps?.length || typeof fb.app().functions !== 'function') throw Object.assign(new Error('sdk'), { code: 'unavailable' });
      const call = fb.app().functions('asia-east1').httpsCallable('purchaseRewardItem');
      const response = await call(core.purchaseCommand(item));
      const result = response?.data;
      if (!core.validPurchaseResult(result, item)) throw Object.assign(new Error('mismatch'), { code: 'unknown' });
      // Show Cloud's answer right away; the users/{uid} listener confirms it.
      state.data = { ...state.data, disciplineCoins: result.disciplineCoins, unlockedAvatarItems: result.unlockedAvatarItems };
      const text = result.alreadyUnlocked
        ? '你已經擁有這個商品，沒有再次扣款。'
        : `兌換完成，雲端帳本扣除 ${item.price} 自律幣。`;
      state.notes.set(item.itemKey, {
        text: item.kind === 'decor' ? `${text}可以到小屋擺放。` : text,
        tone: 'ok',
      });
      root.dispatchEvent(new root.CustomEvent('nudge-shop-purchase', { detail: { item, from, alreadyUnlocked: Boolean(result.alreadyUnlocked) } }));
    } catch (error) {
      const failure = core.purchaseError(error);
      state.notes.set(item.itemKey, { text: failure.message, tone: 'bad' });
      root.dispatchEvent(new root.CustomEvent('nudge-shop-failed', { detail: { item, failure } }));
    } finally {
      state.inFlight.finish(item.itemKey);
      render();
    }
  }

  function selectTab(tab) {
    if (!TABS.includes(tab)) return;
    state.tab = tab;
    try { root.history?.replaceState?.(null, '', `#${tab}`); } catch { /* file:// */ }
    render();
  }
  doc.querySelectorAll('.shop-tab-btn').forEach(btn => btn.addEventListener('click', () => selectTab(btn.dataset.tab)));
  root.NudgeRewardShop = Object.freeze({ selectTab, tab: () => state.tab, balance });

  // ---------- data ----------
  root.fetch('assets/home/home_decor_catalog.json', { cache: 'no-cache' })
    .then(r => (r.ok ? r.json() : Promise.reject(new Error(String(r.status)))))
    .then(catalog => { state.catalog = catalog; render(); })
    .catch(() => { state.catalog = { slots: [] }; render(); });

  let started = false;
  let unsubscribeUser = null;
  let generation = 0;
  function start() {
    const fb = root.firebase;
    if (started || !fb?.apps?.length) return;
    started = true;
    fb.firestore().collection('shop_items').where('status', '==', 'published').get()
      .then(snapshot => { state.items = snapshot.docs.map(d => ({ id: d.id, ...d.data() })); state.itemsError = false; })
      .catch(() => { state.items = null; state.itemsError = true; })
      .finally(render);
    fb.auth().onAuthStateChanged(user => {
      const own = ++generation;
      unsubscribeUser?.();
      unsubscribeUser = null;
      state.uid = user?.uid || null;
      state.data = null;
      state.notes.clear();
      status(user ? '餘額與已擁有的商品來自雲端帳本。' : '登入後才能兌換；商品一律由雲端帳本扣款與解鎖。');
      render();
      if (!user) return;
      unsubscribeUser = fb.firestore().collection('users').doc(user.uid).onSnapshot(snap => {
        if (own !== generation) return;
        state.data = snap.exists ? snap.data() : {};
        render();
      }, () => {
        if (own !== generation) return;
        status('暫時無法讀取你的餘額，請確認網路後重新整理。兌換結果仍以雲端帳本為準。');
      });
    });
  }
  doc.addEventListener('firebase-ready', start);
  root.addEventListener('pagehide', () => { ++generation; unsubscribeUser?.(); unsubscribeUser = null; });
  render();
  start();
})(typeof globalThis !== 'undefined' ? globalThis : this);
