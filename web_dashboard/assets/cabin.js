(function (root) {
  'use strict';
  // Web companion cabin 2.0: the same pixel room as the App, a companion that
  // follows the App's cabin behaviour, and a decorate mode.
  //
  // Login is enforced by app.js (this page is not public). The account's own
  // users/{uid} document is the only read; the only write is the existing
  // arrangeHomeDecor callable, called once when the player presses 「儲存」.
  // The callable re-checks ownership in Cloud. Nothing here grants coins, XP
  // or items.
  const core = root.NudgeCabinCore;
  const layoutCore = root.NudgeCabinLayoutCore;
  const pal = root.NudgeCabinCompanionCore;
  const doc = root.document;
  if (!core || !layoutCore || !pal || !doc || doc.body?.dataset.page !== 'cabin') return;
  const els = id => doc.getElementById(id);

  const DESK_KEY = 'nudge_town_desk_session_v1_';
  const DRAG_START_PX = 6;

  const state = {
    catalog: null,
    layout: null,
    spots: [],
    grid: null,
    uid: null,
    data: null,
    owned: new Map(),
    saved: null,        // what Cloud has (normalized, owned-only)
    history: null,      // undo / redo stack; history.present is the draft
    decorating: false,
    saving: false,
    pending: null,      // { id, key } reused when a save's outcome was unknown
    generation: 0,
    remoteChangedWhileEditing: false,
  };
  let unsubscribeUser = null;
  let started = false;

  const draft = () => state.history?.present || state.saved;
  const dirty = () => Boolean(state.saved && state.history && core.isDirty(state.history.present, state.saved));

  function setStatus(text) { els('cabinStatus').textContent = text; }
  function setSaveStatus(text, tone = '') {
    const el = els('cabinSaveStatus');
    el.textContent = text;
    el.dataset.tone = tone;
  }

  function reducedMotion() {
    try { return Boolean(root.matchMedia?.('(prefers-reduced-motion: reduce)').matches); } catch { return false; }
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
  ]).then(([catalog, layout]) => {
    state.catalog = catalog;
    state.tallLayout = layout;
    state.layout = isWide() ? wideLayout(layout) : layout;
    state.spots = layoutCore.spots(state.layout, catalog);
    state.grid = layoutCore.grid(state.layout.aspect);
  }).catch(() => {
    setStatus('家具目錄載入失敗，請確認網路後重新整理。你的擺設仍保存在雲端。');
    return Promise.reject(new Error('assets'));
  });

  // ---------- desktop layout ----------
  // Desktop shows the landscape cabin; every decor layer, the notice board
  // and the doors move to their spot on that art. The companion still thinks
  // in the portrait room's coordinates and is mapped onto the wide floor.
  const WIDE = Object.freeze({
    baseImage: 'assets/scenes/workbench/cabin_wide.webp',
    aspect: 1.5,
    rects: {
      rug: [0.3, 0.76, 0.4, 0.13],
      curtain: [0.385, 0.09, 0.24, 0.27],
      books: [0.245, 0.4, 0.115, 0.17],
      badges: [0.635, 0.42, 0.11, 0.05],
      globe: [0.45, 0.47, 0.05, 0.08],
      lamp: [0.61, 0.45, 0.05, 0.1],
      plant: [0.08, 0.6, 0.09, 0.14],
    },
    books: [[0.245, 0.4, 0.115, 0.045], [0.245, 0.4, 0.115, 0.1], [0.245, 0.4, 0.115, 0.17]],
    character: [0.43, 0.55, 0.16, 0.3],
    questBoard: [0.42, 0.39, 0.17, 0.13],
    doors: { family: [0.05, 0.29, 0.14, 0.41], group: [0.81, 0.29, 0.14, 0.41] },
  });
  function isWide() {
    const w = Number(root.innerWidth) || 0, h = Number(root.innerHeight) || 1;
    return w >= 860 && w / h >= 1.05;
  }
  function wideLayout(tall) {
    const layers = {};
    for (const [slot, layer] of Object.entries(tall.layers || {})) {
      const rect = WIDE.rects[slot] || layer.rect;
      layers[slot] = { ...layer, rect, ...(layer.rects ? { rects: slot === 'books' ? WIDE.books : layer.rects.map(() => rect) } : {}) };
    }
    return {
      ...tall, baseImage: WIDE.baseImage, aspect: WIDE.aspect, layers, wide: true,
      character: { rect: WIDE.character }, questBoard: { rect: WIDE.questBoard },
      doors: { family: { rect: WIDE.doors.family }, group: { rect: WIDE.doors.group } },
    };
  }
  // portrait floor (x .12-.88, y .6-.86) -> wide floor (x .2-.8, y .7-.95)
  const toView = p => (state.layout?.wide ? { x: 0.2 + ((p.x - 0.12) / 0.76) * 0.6, y: 0.7 + ((p.y - 0.6) / 0.26) * 0.25 } : p);
  const toBrain = p => (state.layout?.wide ? { x: 0.12 + ((p.x - 0.2) / 0.6) * 0.76, y: 0.6 + ((p.y - 0.7) / 0.25) * 0.26 } : p);

  // ---------- stage ----------
  const stage = els('cabinStage');
  els('cabinBase').addEventListener('error', () => {
    // Art missing: keep the text summary and the controls usable.
    stage.hidden = true;
    els('cabinSummary').dataset.fallback = 'true';
  });

  function place(node, rect) {
    const [x, y, w, h] = rect;
    node.style.left = `${x * 100}%`;
    node.style.top = `${y * 100}%`;
    node.style.width = `${w * 100}%`;
    node.style.height = `${h * 100}%`;
  }

  function slotDef(slot) { return core.slots(state.catalog).find(s => s.slot === slot); }
  function variantName(slot, index) { return slotDef(slot)?.variants.find(v => v.index === index)?.name || ''; }
  function imageFor(slot, index) { return state.layout?.layers?.[slot]?.images?.[index] || ''; }

  function renderStage() {
    const { layout, catalog } = state;
    root.setTimeout?.(() => renderTouches?.(), 0);
    const arrangement = draft();
    if (layout?.aspect) stage.style.aspectRatio = `${layout.aspect} / 1`;
    if (stage.dataset) stage.dataset.layout = layout?.wide ? 'wide' : 'tall';
    if (els('cabinBase').getAttribute('src') !== layout.baseImage) els('cabinBase').setAttribute('src', layout.baseImage);
    const holder = els('cabinLayers');
    holder.textContent = '';
    for (const layer of core.decorLayers(layout, arrangement)) {
      const img = doc.createElement('img');
      img.className = 'cabin-layer';
      img.alt = '';
      img.draggable = false;
      img.src = layer.src;
      img.dataset.slot = layer.slot;
      img.style.zIndex = String(layer.z);
      place(img, layer.rect);
      img.addEventListener('error', () => { img.hidden = true; });
      holder.appendChild(img);
    }
    const parts = core.slots(catalog).map(slot => `${slot.label}：${variantName(slot.slot, arrangement[slot.slot])}`);
    els('cabinSummary').textContent = `夥伴在小屋裡。${parts.join('、')}。`;
    renderSpots();
  }

  // Decorate-mode hit areas, one per slot, on the slot's allowed spot.
  function renderSpots() {
    const holder = els('cabinSpots');
    holder.hidden = !state.decorating;
    els('cabinGrid').hidden = !state.decorating;
    holder.textContent = '';
    if (!state.decorating) return;
    const arrangement = draft();
    for (const spot of state.spots) {
      const button = doc.createElement('button');
      button.type = 'button';
      button.className = 'cabin-spot';
      button.dataset.slot = spot.slot;
      button.disabled = state.saving;
      const count = [...(state.owned.get(spot.slot) || [])].length;
      button.setAttribute('aria-label', `${spot.label}：${variantName(spot.slot, arrangement[spot.slot])}。` +
        (count > 1 ? '點一下或按 ← → 換款式' : '目前只有這一款'));
      place(button, spot.rect);
      const tag = doc.createElement('span');
      tag.className = 'cabin-spot-tag';
      tag.textContent = spot.label;
      button.appendChild(tag);
      button.addEventListener('click', () => {
        if (consumeClick()) return;
        cycle(spot.slot, 1);
      });
      button.addEventListener('keydown', event => {
        if (event.key === 'ArrowRight' || event.key === 'ArrowDown') { event.preventDefault(); cycle(spot.slot, 1); }
        if (event.key === 'ArrowLeft' || event.key === 'ArrowUp') { event.preventDefault(); cycle(spot.slot, -1); }
      });
      button.addEventListener('pointerdown', event => beginPress(event, spot.slot, arrangement[spot.slot], button));
      holder.appendChild(button);
    }
  }

  function spotButtons() { return [...(els('cabinSpots').children || [])]; }

  // ---------- tray ----------
  function renderTray() {
    els('cabinTray').hidden = !state.decorating;
    const holder = els('cabinSlots');
    holder.textContent = '';
    if (!state.decorating) return;
    const arrangement = draft();
    core.slots(state.catalog).forEach((slot, order) => {
      const set = doc.createElement('fieldset');
      set.className = 'cabin-slot';
      const legend = doc.createElement('legend');
      legend.textContent = slot.label;
      set.appendChild(legend);
      const row = doc.createElement('div');
      row.className = 'cabin-tiles';
      for (const variant of slot.variants) {
        const owned = core.canPlace(state.owned, slot.slot, variant.index);
        const current = arrangement[slot.slot] === variant.index;
        const tile = doc.createElement('button');
        tile.type = 'button';
        tile.className = `cabin-tile${owned ? '' : ' is-locked'}${current ? ' is-current' : ''}`;
        tile.name = `decor-${slot.slot}`;
        tile.value = String(variant.index);
        tile.disabled = !owned || state.saving;
        tile.setAttribute('aria-pressed', current ? 'true' : 'false');
        tile.dataset.itemKey = core.itemKey(order, variant.index);
        const pic = doc.createElement('img');
        pic.alt = '';
        pic.draggable = false;
        pic.src = imageFor(slot.slot, variant.index);
        const name = doc.createElement('span');
        name.className = 'cabin-tile-name';
        name.textContent = variant.name;
        const note = doc.createElement('small');
        note.textContent = owned ? (current ? '擺放中' : (variant.index === 0 ? '免費' : '已擁有')) : `未擁有・${variant.price} 自律幣`;
        tile.append(pic, name, note);
        if (owned) {
          tile.addEventListener('click', () => {
            if (consumeClick()) return;
            apply(slot.slot, variant.index, `${slot.label}換成「${variant.name}」。`);
          });
          tile.addEventListener('pointerdown', event => beginPress(event, slot.slot, variant.index, tile));
        }
        row.appendChild(tile);
      }
      set.appendChild(row);
      holder.appendChild(set);
    });
  }

  function renderTools() {
    const editing = state.decorating;
    els('cabinViewTools').hidden = editing;
    els('cabinEditTools').hidden = !editing;
    els('cabinDecorate').disabled = state.saving || !state.saved;
    const h = state.history;
    els('cabinUndo').disabled = !h || !layoutCore.canUndo(h) || state.saving;
    els('cabinRedo').disabled = !h || !layoutCore.canRedo(h) || state.saving;
    els('cabinReset').disabled = state.saving || !h ||
      layoutCore.same(h.present, layoutCore.defaultArrangement(state.catalog));
    els('cabinCancel').disabled = state.saving;
    els('cabinSave').disabled = !dirty() || state.saving;
    els('cabinSave').textContent = state.saving ? '雲端確認中…' : '儲存';
    stage.classList.toggle('is-decorating', editing);
    if (state.grid) {
      stage.style.setProperty('--cabin-cell-w', `${state.grid.cellW * 100}%`);
      stage.style.setProperty('--cabin-cell-h', `${state.grid.cellH * 100}%`);
    }
  }

  function setLocked(locked) {
    els('cabinLock').hidden = !locked;
    const main = els('cabinMain');
    main.inert = locked;
    main.setAttribute('aria-busy', locked ? 'true' : 'false');
  }

  function render() {
    if (!state.catalog || !state.layout || !state.saved) return;
    // Spots and tiles are rebuilt; keep keyboard focus on the same control.
    const active = doc.activeElement;
    const keep = active?.dataset?.itemKey ? { tile: active.dataset.itemKey }
      : active?.classList?.contains?.('cabin-spot') ? { spot: active.dataset.slot } : null;
    renderStage();
    renderTray();
    renderTools();
    renderCompanion();
    els('cabinScene').hidden = false;
    if (keep?.spot) spotButtons().find(c => c.dataset.slot === keep.spot)?.focus?.({ preventScroll: true });
    if (keep?.tile) {
      const tiles = [...(els('cabinSlots').querySelectorAll?.('.cabin-tile') || [])];
      tiles.find(c => c.dataset.itemKey === keep.tile)?.focus?.({ preventScroll: true });
    }
  }

  // ---------- editing ----------
  function apply(slot, index, message) {
    if (!state.decorating || state.saving) return;
    const next = core.choose(state.history.present, state.owned, slot, index);
    const before = state.history;
    state.history = layoutCore.record(state.history, next);
    if (state.history !== before) setSaveStatus(`${message || ''}按「儲存」才會寫到雲端。`.trim());
    render();
  }

  function cycle(slot, dir) {
    const current = state.history.present[slot];
    const next = layoutCore.cycleVariant(state.catalog, state.owned, slot, current, dir);
    if (next === current) {
      setSaveStatus(`${slotDef(slot)?.label || ''}目前只有這一款，可以到雜貨店買更多款式。`);
      return;
    }
    apply(slot, next, `${slotDef(slot)?.label}換成「${variantName(slot, next)}」。`);
  }

  function enterDecorate() {
    if (state.saving || !state.saved) return;
    state.decorating = true;
    state.history = layoutCore.createHistory(state.saved);
    state.remoteChangedWhileEditing = false;
    setSaveStatus('布置模式：拖曳或點選家具，完成後按「儲存」。');
    render();
    els('cabinUndo').focus?.({ preventScroll: true });
  }

  function leaveDecorate(message = '') {
    state.decorating = false;
    state.history = layoutCore.createHistory(state.saved);
    setSaveStatus(message);
    render();
    els('cabinDecorate').focus?.({ preventScroll: true });
  }

  function undoStep() {
    if (state.saving || !layoutCore.canUndo(state.history)) return;
    state.history = layoutCore.undo(state.history);
    setSaveStatus('已復原上一步。');
    render();
  }
  function redoStep() {
    if (state.saving || !layoutCore.canRedo(state.history)) return;
    state.history = layoutCore.redo(state.history);
    setSaveStatus('已重做。');
    render();
  }
  function resetToDefault() {
    if (state.saving) return;
    state.history = layoutCore.record(state.history, layoutCore.defaultArrangement(state.catalog));
    setSaveStatus('已換回預設家具。按「儲存」才會寫到雲端，按「復原」可以拿回剛才的布置。');
    render();
  }
  function cancelDecorate() {
    if (state.saving) return;
    if (dirty()) openDialog(els('cabinCancel'));
    else leaveDecorate();
  }

  els('cabinDecorate').addEventListener('click', enterDecorate);
  els('cabinUndo').addEventListener('click', undoStep);
  els('cabinRedo').addEventListener('click', redoStep);
  els('cabinReset').addEventListener('click', resetToDefault);
  els('cabinCancel').addEventListener('click', cancelDecorate);
  els('cabinSave').addEventListener('click', save);

  doc.addEventListener('keydown', event => {
    if (!state.decorating || state.saving || !els('cabinDialog').hidden) return;
    const mod = event.ctrlKey || event.metaKey;
    const key = String(event.key || '').toLowerCase();
    if (mod && key === 'z' && !event.shiftKey) { event.preventDefault(); undoStep(); }
    else if (mod && (key === 'y' || (key === 'z' && event.shiftKey))) { event.preventDefault(); redoStep(); }
    else if (key === 'escape' && !drag) { event.preventDefault(); cancelDecorate(); }
  });

  // ---------- dialog ----------
  let dialogReturn = null;
  function openDialog(opener) {
    dialogReturn = opener || doc.activeElement;
    els('cabinDialog').hidden = false;
    els('cabinDialogStay').focus?.();
  }
  function closeDialog() {
    els('cabinDialog').hidden = true;
    const back = dialogReturn;
    dialogReturn = null;
    if (back && !back.hidden && !back.disabled && doc.contains?.(back) !== false) back.focus?.();
    else els('cabinDecorate').focus?.();
  }
  els('cabinDialogStay').addEventListener('click', closeDialog);
  els('cabinDialogLeave').addEventListener('click', () => {
    els('cabinDialog').hidden = true;
    dialogReturn = null;
    leaveDecorate('已放棄變更，小屋維持雲端的擺設。');
  });
  els('cabinDialog').addEventListener('keydown', event => {
    if (event.key === 'Escape') { event.preventDefault(); closeDialog(); }
    if (event.key === 'Tab') {
      // Keep focus inside the two dialog buttons.
      const stay = els('cabinDialogStay');
      const leave = els('cabinDialogLeave');
      if (event.shiftKey && doc.activeElement === stay) { event.preventDefault(); leave.focus(); }
      else if (!event.shiftKey && doc.activeElement === leave) { event.preventDefault(); stay.focus(); }
    }
  });

  // ---------- drag ----------
  let press = null;   // pointer down, not yet a drag
  let drag = null;    // { slot, index, size, pointerId }
  let swallowClick = false;
  function consumeClick() {
    if (!swallowClick) return false;
    swallowClick = false;
    return true;
  }

  function stagePoint(event) {
    const box = stage.getBoundingClientRect();
    return { x: (event.clientX - box.left) / box.width, y: (event.clientY - box.top) / box.height, box };
  }

  function beginPress(event, slot, index, node) {
    if (!state.decorating || state.saving || (event.button !== undefined && event.button !== 0)) return;
    press = { slot, index, x: event.clientX, y: event.clientY, pointerId: event.pointerId, node };
  }

  function startDrag(event) {
    const spot = state.spots.find(s => s.slot === press.slot);
    if (!spot) { press = null; return; }
    drag = { slot: press.slot, index: press.index, size: [spot.rect[2], spot.rect[3]], pointerId: press.pointerId, target: null };
    try { press.node?.setPointerCapture?.(press.pointerId); } catch { /* ignore */ }
    press = null;
    const ghost = els('cabinGhost');
    const img = ghost.querySelector?.('img') || ghost.children?.[0];
    if (img) img.src = imageFor(drag.slot, drag.index);
    ghost.hidden = false;
    stage.classList.add('is-dragging');
    spotButtons().forEach(b => {
      b.classList.toggle('is-goal', b.dataset.slot === drag.slot);
    });
    moveDrag(event);
  }

  function moveDrag(event) {
    const point = stagePoint(event);
    const rect = layoutCore.rectAt(point, drag.size, state.grid);
    drag.target = layoutCore.dropTarget(state.spots, drag.slot, rect);
    const ghost = els('cabinGhost');
    place(ghost, rect);
    ghost.dataset.ok = drag.target.ok ? 'true' : 'false';
  }

  function endDrag(cancelled) {
    const done = drag;
    drag = null;
    els('cabinGhost').hidden = true;
    stage.classList.remove('is-dragging');
    spotButtons().forEach(b => b.classList.remove('is-goal'));
    if (!done || cancelled) return;
    const label = slotDef(done.slot)?.label || '';
    const name = variantName(done.slot, done.index);
    const t = done.target;
    if (t?.ok) apply(done.slot, done.index, `${label}換成「${name}」。`);
    else if (t?.reason === 'occupied') setSaveStatus(`那裡是${t.byLabel}的位置，放不下${label}。${label}只能放在發光的格子。`, 'bad');
    else setSaveStatus(`${label}只能放在房間裡發光的位置，已放回原處。`, 'bad');
  }

  root.addEventListener('pointermove', event => {
    if (press && event.pointerId === press.pointerId &&
      Math.hypot(event.clientX - press.x, event.clientY - press.y) >= DRAG_START_PX) startDrag(event);
    else if (drag && event.pointerId === drag.pointerId) moveDrag(event);
  });
  root.addEventListener('pointerup', event => {
    if (press && event.pointerId === press.pointerId) press = null;
    if (drag && event.pointerId === drag.pointerId) {
      // The click that follows this pointerup belongs to the drag, not a pick.
      swallowClick = true;
      root.setTimeout?.(() => { swallowClick = false; }, 0);
      endDrag(false);
    }
  });
  root.addEventListener('pointercancel', () => { press = null; if (drag) endDrag(true); });

  // ---------- save ----------
  async function save() {
    if (state.saving || !state.uid || !dirty()) return;
    const fb = root.firebase;
    if (!fb?.apps?.length || typeof fb.app().functions !== 'function') {
      setSaveStatus('雲端服務尚未載入，請稍後再試。沒有儲存任何變更。', 'bad');
      return;
    }
    const sent = core.normalizeArrangement(state.history.present, state.catalog);
    const key = JSON.stringify(sent);
    // Same arrangement after an unknown outcome: reuse the id so Cloud replays it.
    const id = state.pending?.key === key ? state.pending.id : core.newRequestId(Date.now());
    state.pending = { id, key };
    state.saving = true;
    const own = state.generation;
    setSaveStatus('雲端確認中…');
    setLocked(true);
    render();
    try {
      const call = fb.app().functions('asia-east1').httpsCallable('arrangeHomeDecor');
      const response = await call(core.arrangeCommand(sent, state.catalog, id));
      if (own !== state.generation) return;
      if (!core.validArrangeResult(response?.data, sent)) throw Object.assign(new Error('mismatch'), { code: 'unknown' });
      state.pending = null;
      state.saved = { ...sent };
      state.saving = false;
      setLocked(false);
      leaveDecorate(response.data.replayed ? '這個擺設已經儲存過了。' : '已儲存到雲端，其他裝置也會看到一樣的擺設。');
      els('cabinSaveStatus').dataset.tone = 'ok';
    } catch (error) {
      if (own !== state.generation) return;
      const failure = core.arrangeError(error);
      if (failure.saved === 'no') state.pending = null;
      state.saving = false;
      setLocked(false);
      // Show what Cloud has; the attempt stays one 「復原」 away for a retry.
      state.history = layoutCore.record(state.history, state.saved);
      setSaveStatus(`${failure.message} 小屋已還原成雲端的擺設，按「復原」可以拿回剛才的布置。`, 'bad');
      render();
    }
  }

  // ---------- companion ----------
  const brain = pal.createBrain();
  let lastFrame = 0;
  let frameHandle = 0;
  let bubbleTimer = 0;
  let night = false;

  function face() {
    const f = Number(state.data?.avatarProfile?.faceShapeIndex);
    return Number.isInteger(f) && f >= 0 ? f : 0;
  }

  function focusing() {
    if (!state.uid) return false;
    try { return pal.deskFocusing(root.localStorage?.getItem(`${DESK_KEY}${state.uid}`)); } catch { return false; }
  }

  function updateActivity() {
    const hour = new Date().getHours();
    const wanted = pal.wantedActivity({ focusing: focusing(), hour });
    night = wanted === 'rest' || hour >= 22 || hour < 6;
    brain.setActivity(wanted);
    if (reducedMotion()) brain.settle();
    els('cabinNight').hidden = !night;
  }

  function renderCompanion() {
    if (!state.layout) return;
    const button = els('cabinCompanion');
    const img = els('cabinCharacter');
    const p = toView(brain.position);
    const height = state.layout.character?.rect?.[3] || 0.245;
    const pose = brain.pose;
    const sprite = pal.spriteFor(face(), pose, brain.stepPhase);
    if (img.getAttribute('src') !== sprite.src) img.setAttribute('src', sprite.src);
    button.style.left = `${p.x * 100}%`;
    button.style.top = `${p.y * 100}%`;
    button.style.height = `${height * 100}%`;
    button.dataset.pose = pose;
    button.dataset.flip = brain.facingLeft && sprite.kind === 'walk' ? 'true' : 'false';
    button.style.zIndex = String(p.y > 0.7 ? 7 : 6);
    button.tabIndex = state.decorating ? -1 : 0;
    els('cabinGlyph').textContent = pose === 'sleep' ? 'Z z' : pose === 'read' ? '✦' : pose === 'cheer' ? '★ ★' : '';
    const bubble = els('cabinBubble');
    if (!bubble.hidden) {
      bubble.style.left = `${Math.min(0.78, Math.max(0.22, p.x)) * 100}%`;
      bubble.style.top = `${Math.max(0.05, p.y - height - 0.02) * 100}%`;
    }
  }

  function loop(now) {
    frameHandle = 0;
    const dt = lastFrame ? (now - lastFrame) / 1000 : 0;
    lastFrame = now;
    brain.tick(dt);
    renderCompanion();
    schedule();
  }

  function schedule() {
    if (frameHandle || reducedMotion() || doc.hidden || typeof root.requestAnimationFrame !== 'function') return;
    frameHandle = root.requestAnimationFrame(loop);
  }

  function stopLoop() {
    if (frameHandle && typeof root.cancelAnimationFrame === 'function') root.cancelAnimationFrame(frameHandle);
    frameHandle = 0;
    lastFrame = 0;
  }

  function say(text) {
    const bubble = els('cabinBubble');
    bubble.textContent = text;
    bubble.hidden = false;
    renderCompanion();
    if (bubbleTimer) root.clearTimeout?.(bubbleTimer);
    bubbleTimer = root.setTimeout?.(() => { bubble.hidden = true; bubbleTimer = 0; }, 2600) || 0;
  }

  els('cabinCompanion').addEventListener('click', event => {
    event.stopPropagation?.();
    if (state.decorating) return;
    brain.poke();
    const button = els('cabinCompanion');
    if (!reducedMotion()) {
      button.classList.remove('is-jump');
      void button.offsetWidth; // restart the hop
      button.classList.add('is-jump');
    }
    say(pal.lineFor(brain.activity));
    renderCompanion();
    schedule();
  });
  els('cabinCompanion').addEventListener('animationend', () => els('cabinCompanion').classList.remove('is-jump'));

  stage.addEventListener('click', event => {
    if (state.decorating || event.target !== stage && !String(event.target?.className || '').includes('cabin-layer')) return;
    const point = stagePoint(event);
    if (reducedMotion()) return;
    if (brain.walkTo(toBrain(point))) schedule();
  });

  // Switch between the portrait and landscape room when the window changes.
  root.addEventListener?.('resize', () => {
    if (!state.tallLayout || state.decorating) return;
    const wide = isWide();
    if (wide === Boolean(state.layout?.wide)) return;
    state.layout = wide ? wideLayout(state.tallLayout) : state.tallLayout;
    state.spots = layoutCore.spots(state.layout, state.catalog);
    state.grid = layoutCore.grid(state.layout.aspect);
    renderStage();
    renderCompanion();
    root.dispatchEvent?.(new root.CustomEvent('nudge-cabin-layout'));
  });

  // ---------- cabin 2.0: things to touch ----------
  // Lamp, plant, bookshelf and window answer a tap; none of them writes data.
  const touches = doc.createElement('div');
  touches.className = 'cabin-touches';
  stage.appendChild(touches);
  let lampOff = false, waterings = 0;
  function sparkle(rect, glyph, count = 5) {
    if (reducedMotion()) return;
    for (let i = 0; i < count; i++) {
      const s = doc.createElement('span');
      s.className = 'cabin-sparkle';
      s.textContent = glyph;
      s.style.left = `${(rect[0] + rect[2] * (0.2 + 0.6 * Math.random())) * 100}%`;
      s.style.top = `${(rect[1] + rect[3] * 0.3) * 100}%`;
      s.style.animationDelay = `${i * 80}ms`;
      s.addEventListener('animationend', () => s.remove());
      touches.appendChild(s);
    }
  }
  const TOUCHES = [
    { slot: 'lamp', label: '檯燈：開關燈', act: rect => {
      lampOff = !lampOff;
      stage.classList.toggle('is-lamp-off', lampOff);
      sparkle(rect, '✦', 3);
      say(lampOff ? '關燈了，房間暗下來了。' : '開燈！亮亮的比較好讀書。');
    } },
    { slot: 'plant', label: '盆栽：澆水', act: rect => {
      waterings += 1;
      brain.walkTo(toBrain({ x: rect[0] + rect[2] / 2 + 0.06, y: Math.max(0.7, rect[1] + rect[3]) })) && schedule();
      sparkle(rect, '💧', 4);
      root.setTimeout?.(() => sparkle(rect, '✿', 3), 500);
      say(waterings > 2 ? '盆栽今天喝得很飽了～' : '幫盆栽澆點水，它看起來很開心。');
    } },
    { slot: 'books', label: '書架：翻翻紀錄', act: () => {
      say('書架上收著你的紀錄，帶你去紀錄館看看！');
      root.setTimeout?.(() => { root.location.href = 'personal.html'; }, 900);
    } },
    { slot: 'curtain', label: '窗戶：看看外面', act: rect => {
      brain.walkTo(toBrain({ x: rect[0] + rect[2] / 2, y: 0.72 })) && schedule();
      sparkle(rect, '★', 4);
      say(new Date().getHours() >= 18 || new Date().getHours() < 6 ? '今晚的星星好亮。' : '外面天氣不錯，等等出去走走吧。');
    } },
  ];
  function renderTouches() {
    touches.textContent = '';
    if (!state.layout || state.decorating) return;
    for (const t of TOUCHES) {
      const rect = state.layout.layers?.[t.slot]?.rect;
      if (!rect) continue;
      const b = doc.createElement('button');
      b.type = 'button';
      b.className = 'cabin-touch';
      b.setAttribute('aria-label', t.label);
      b.title = t.label;
      b.style.left = `${rect[0] * 100}%`;
      b.style.top = `${rect[1] * 100}%`;
      b.style.width = `${rect[2] * 100}%`;
      b.style.height = `${rect[3] * 100}%`;
      b.addEventListener('click', event => { event.stopPropagation?.(); t.act(rect); });
      touches.appendChild(b);
    }
  }
  root.addEventListener?.('nudge-cabin-layout', renderTouches);

  doc.addEventListener('visibilitychange', () => {
    if (doc.hidden) stopLoop();
    else { updateActivity(); schedule(); }
  });
  root.addEventListener('storage', event => {
    if (state.uid && event.key === `${DESK_KEY}${state.uid}`) { updateActivity(); renderCompanion(); schedule(); }
  });
  try {
    root.matchMedia?.('(prefers-reduced-motion: reduce)').addEventListener?.('change', () => {
      if (reducedMotion()) { stopLoop(); brain.settle(); renderCompanion(); } else schedule();
    });
  } catch { /* old browsers */ }
  root.setInterval?.(() => { updateActivity(); renderCompanion(); schedule(); }, 60 * 1000);

  // ---------- account ----------
  function applyUser(data) {
    state.data = data || {};
    state.owned = core.ownedVariants(state.catalog, state.data.unlockedAvatarItems);
    const remote = core.visibleArrangement(state.data.homeDecor, state.catalog, state.owned);
    const remoteChanged = state.saved && core.isDirty(remote, state.saved);
    state.saved = remote;
    if (!state.decorating || !state.history) {
      state.history = layoutCore.createHistory(remote);
    } else {
      // Never keep a variant that stopped being owned (e.g. a refund).
      const kept = core.visibleArrangement(state.history.present, state.catalog, state.owned);
      if (!layoutCore.same(kept, state.history.present)) state.history = layoutCore.record(state.history, kept);
      if (remoteChanged && !state.saving) {
        setSaveStatus('另一台裝置更新了擺設。按「離開布置」放棄變更，就會看到雲端的擺設。');
      }
    }
    const coins = Number(state.data.disciplineCoins);
    const chip = els('cabinCoins');
    chip.textContent = Number.isSafeInteger(coins) ? `自律幣 ${coins}` : '自律幣 —';
    chip.className = 'w-chip is-ok';
    setStatus('這是你的小屋。家具和擺設都來自雲端帳本。');
    updateActivity();
    render();
    schedule();
  }

  function start() {
    if (started || !root.firebase?.apps?.length) return;
    started = true;
    assetsReady.then(() => {
      root.firebase.auth().onAuthStateChanged(user => {
        const own = ++state.generation;
        unsubscribeUser?.();
        unsubscribeUser = null;
        Object.assign(state, {
          uid: user?.uid || null, saved: null, history: null, data: null,
          saving: false, pending: null, decorating: false,
        });
        setLocked(false);
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
  root.addEventListener('pagehide', () => { ++state.generation; stopLoop(); unsubscribeUser?.(); unsubscribeUser = null; });
  start();
})(typeof globalThis !== 'undefined' ? globalThis : this);
