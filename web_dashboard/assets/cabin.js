(function (root) {
  'use strict';
  // Web companion cabin (#82 slice 3). Login is enforced by app.js (this page
  // is not public). The account's own users/{uid} document is the only read;
  // the only write is the existing arrangeHomeDecor callable, which re-checks
  // ownership in Cloud. Nothing here grants coins, XP or items.
  const core = root.NudgeCabinCore;
  const doc = root.document;
  if (!core || !doc || doc.body?.dataset.page !== 'cabin') return;
  const els = id => doc.getElementById(id);

  const state = {
    catalog: null,
    layout: null,
    uid: null,
    owned: new Map(),
    saved: null,      // what Cloud has (normalized, owned-only)
    draft: null,      // what the player is arranging
    data: null,
    saving: false,
    pending: null,    // { id, key } reused when a save's outcome was unknown
    generation: 0,
  };
  let unsubscribeUser = null;
  let started = false;

  function setStatus(text) { els('cabinStatus').textContent = text; }
  function setSaveStatus(text, tone = '') {
    const el = els('cabinSaveStatus');
    el.textContent = text;
    el.dataset.tone = tone;
  }

  // ---------- assets ----------
  async function loadJson(path) {
    const response = await root.fetch(path, { cache: 'no-cache' });
    if (!response.ok) throw new Error(`${path} ${response.status}`);
    return response.json();
  }
  const assetsReady = Promise.all([
    loadJson('assets/home/home_decor_catalog.json'),
    loadJson('assets/home/cabin_layout.json'),
  ]).then(([catalog, layout]) => { state.catalog = catalog; state.layout = layout; })
    .catch(() => {
      setStatus('家具目錄載入失敗，請確認網路後重新整理。你的擺設仍保存在雲端。');
      return Promise.reject(new Error('assets'));
    });

  // ---------- stage ----------
  const stage = els('cabinStage');
  els('cabinBase').addEventListener('error', () => {
    // Art missing: keep the text summary and the controls usable.
    stage.hidden = true;
    els('cabinSummary').dataset.fallback = 'true';
  });

  function place(img, rect) {
    const [x, y, w, h] = rect;
    img.style.left = `${x * 100}%`;
    img.style.top = `${y * 100}%`;
    img.style.width = `${w * 100}%`;
    img.style.height = `${h * 100}%`;
  }

  function variantName(slot, index) {
    return slot.variants.find(v => v.index === index)?.name || '';
  }

  function renderStage() {
    const { layout, catalog, draft } = state;
    if (!stage.style.aspectRatio && layout?.aspect) stage.style.aspectRatio = `${layout.aspect} / 1`;
    if (els('cabinBase').getAttribute('src') !== layout.baseImage) els('cabinBase').setAttribute('src', layout.baseImage);
    const holder = els('cabinLayers');
    holder.textContent = '';
    for (const layer of core.decorLayers(layout, draft)) {
      const img = doc.createElement('img');
      img.className = 'cabin-layer';
      img.alt = '';
      img.src = layer.src;
      img.style.zIndex = String(layer.z);
      place(img, layer.rect);
      img.addEventListener('error', () => { img.hidden = true; });
      holder.appendChild(img);
    }
    const character = els('cabinCharacter');
    const sprite = core.characterSprite(state.data);
    if (character.getAttribute('src') !== sprite) character.setAttribute('src', sprite);
    if (layout.character?.rect) place(character, layout.character.rect);
    const parts = core.slots(catalog).map(slot => `${slot.label}：${variantName(slot, draft[slot.slot])}`);
    els('cabinSummary').textContent = `夥伴在小屋裡。${parts.join('、')}。`;
  }

  // ---------- controls ----------
  function renderSlots() {
    const holder = els('cabinSlots');
    holder.textContent = '';
    core.slots(state.catalog).forEach((slot, order) => {
      const set = doc.createElement('fieldset');
      set.className = 'cabin-slot';
      const legend = doc.createElement('legend');
      legend.textContent = slot.label;
      set.appendChild(legend);
      for (const variant of slot.variants) {
        const owned = core.canPlace(state.owned, slot.slot, variant.index);
        const label = doc.createElement('label');
        label.className = `cabin-choice${owned ? '' : ' is-locked'}`;
        const input = doc.createElement('input');
        input.type = 'radio';
        input.name = `decor-${slot.slot}`;
        input.value = String(variant.index);
        input.checked = state.draft[slot.slot] === variant.index;
        input.disabled = !owned || state.saving;
        input.addEventListener('change', () => {
          state.draft = core.choose(state.draft, state.owned, slot.slot, variant.index);
          setSaveStatus('');
          render();
        });
        const name = doc.createElement('span');
        name.textContent = variant.name;
        const note = doc.createElement('small');
        note.textContent = owned
          ? (variant.index === 0 ? '免費' : '已擁有')
          : `未擁有・${variant.price} 自律幣`;
        label.append(input, name, note);
        label.dataset.itemKey = core.itemKey(order, variant.index);
        set.appendChild(label);
      }
      holder.appendChild(set);
    });
  }

  function render() {
    if (!state.catalog || !state.layout || !state.draft) return;
    renderStage();
    renderSlots();
    const dirty = core.isDirty(state.draft, state.saved);
    els('cabinSave').disabled = !dirty || state.saving;
    els('cabinRevert').disabled = !dirty || state.saving;
    els('cabinSave').textContent = state.saving ? '保存中…' : '保存擺設';
    els('cabinScene').hidden = false;
  }

  // ---------- save / revert ----------
  els('cabinRevert').addEventListener('click', () => {
    if (state.saving || !state.saved) return;
    state.draft = { ...state.saved };
    setSaveStatus('已復原成雲端目前的擺設。');
    render();
  });

  els('cabinForm').addEventListener('submit', async event => {
    event.preventDefault();
    if (state.saving || !state.uid || !core.isDirty(state.draft, state.saved)) return;
    const fb = root.firebase;
    if (!fb?.apps?.length || typeof fb.app().functions !== 'function') {
      setSaveStatus('雲端服務尚未載入，請稍後再試。沒有保存任何變更。', 'bad');
      return;
    }
    const sent = core.normalizeArrangement(state.draft, state.catalog);
    const key = JSON.stringify(sent);
    // Same arrangement after an unknown outcome: reuse the id so Cloud replays it.
    const id = state.pending?.key === key ? state.pending.id : core.newRequestId(Date.now());
    state.pending = { id, key };
    state.saving = true;
    const own = state.generation;
    setSaveStatus('保存中…');
    render();
    try {
      const call = fb.app().functions('asia-east1').httpsCallable('arrangeHomeDecor');
      const response = await call(core.arrangeCommand(sent, state.catalog, id));
      if (own !== state.generation) return;
      if (!core.validArrangeResult(response?.data, sent)) throw Object.assign(new Error('mismatch'), { code: 'unknown' });
      state.pending = null;
      state.saved = { ...sent };
      setSaveStatus(response.data.replayed ? '這個擺設已經保存過了。' : '已保存到雲端，其他裝置也會看到。', 'ok');
    } catch (error) {
      if (own !== state.generation) return;
      const failure = core.arrangeError(error);
      if (failure.saved === 'no') state.pending = null;
      setSaveStatus(failure.message, 'bad');
    } finally {
      if (own === state.generation) {
        state.saving = false;
        render();
      }
    }
  });

  // ---------- account ----------
  function applyUser(data) {
    state.data = data || {};
    state.owned = core.ownedVariants(state.catalog, state.data.unlockedAvatarItems);
    const remote = core.visibleArrangement(state.data.homeDecor, state.catalog, state.owned);
    const hadDraft = state.draft && state.saved && core.isDirty(state.draft, state.saved);
    const remoteChanged = state.saved && core.isDirty(remote, state.saved);
    state.saved = remote;
    if (!hadDraft) state.draft = { ...remote };
    else if (remoteChanged && !state.saving) {
      setSaveStatus('另一台裝置更新了擺設。按「復原成雲端版本」可以改看雲端的擺設。');
    }
    // A variant can stop being owned (e.g. a refund); never keep it in the draft.
    state.draft = core.visibleArrangement(state.draft, state.catalog, state.owned);
    const coins = Number(state.data.disciplineCoins);
    els('cabinCoins').textContent = Number.isSafeInteger(coins) ? `自律幣 ${coins}` : '自律幣 —';
    setStatus('這是你的小屋。家具和擺設都來自雲端帳本。');
    render();
  }

  function start() {
    if (started || !root.firebase?.apps?.length) return;
    started = true;
    assetsReady.then(() => {
      root.firebase.auth().onAuthStateChanged(user => {
        const own = ++state.generation;
        unsubscribeUser?.();
        unsubscribeUser = null;
        Object.assign(state, { uid: user?.uid || null, saved: null, draft: null, data: null, saving: false, pending: null });
        els('cabinScene').hidden = true;
        if (!user) {
          setStatus('請先登入，小屋只顯示你自己的夥伴和家具。');
          return;
        }
        setStatus('正在讀取你的小屋…');
        unsubscribeUser = root.firebase.firestore().collection('users').doc(user.uid)
          .onSnapshot(snap => {
            if (own !== state.generation) return;
            applyUser(snap.exists ? snap.data() : null);
          }, () => {
            if (own !== state.generation) return;
            setStatus('暫時無法讀取你的小屋，請確認網路後重新整理。');
          });
      });
    }, () => { /* message already shown */ });
  }

  doc.addEventListener('firebase-ready', start);
  root.addEventListener('pagehide', () => { ++state.generation; unsubscribeUser?.(); unsubscribeUser = null; });
  start();
})(typeof globalThis !== 'undefined' ? globalThis : this);
