(function (root) {
  'use strict';
  // Arcade hall: four cabinets, break tickets and the shared game frame.
  // Ticket and record rules live in arcade_core.js; each game registers
  // itself from arcade_games.js. Read-only towards the Cloud: receipts are
  // read to find tickets, nothing is written, and scores stay on this device.
  const core = root.NudgeArcadeCore;
  const doc = root.document;
  if (!core || !doc || doc.body?.dataset.page !== 'arcade') return;

  const els = id => doc.getElementById(id);
  const reducedMotion = Boolean(root.matchMedia?.('(prefers-reduced-motion: reduce)').matches);
  const store = {
    get(key) { try { return root.localStorage.getItem(key); } catch { return null; } },
    set(key, value) { try { root.localStorage.setItem(key, value); } catch { /* private mode */ } },
    remove(key) { try { root.localStorage.removeItem(key); } catch { /* private mode */ } },
  };

  const games = [];
  const state = {
    uid: null,
    faceIndex: 0,
    loaded: false,       // first receipts snapshot arrived
    failed: false,
    receipts: [],
    session: null,
    active: null,        // game object while in a game
    paused: false,
    busy: 0,             // game-owned dialogs (catch card…) hold the clock
    playing: false,      // the game reports real play (not a pick screen)
    lastFrame: 0,
    lastSave: 0,
    infoFor: null,
    returnFocus: null,
  };

  // ---------- storage ----------
  const usedKey = () => `nudge_arcade_used_tickets_${state.uid}`;
  const legacyUsedKey = () => `nudge_town_used_tickets_${state.uid}`;
  const sessionKey = () => `nudge_arcade_session_${state.uid}`;
  function usedIds() {
    if (!state.uid) return [];
    return [...core.readList(store.get(legacyUsedKey())), ...core.readList(store.get(usedKey()))];
  }
  function tickets() { return state.uid ? core.allTickets(state.failed ? [] : state.receipts, Date.now(), usedIds()) : []; }
  function saveSession() {
    if (!state.uid) return;
    if (core.validSession(state.session)) store.set(sessionKey(), JSON.stringify(state.session));
    else store.remove(sessionKey());
  }

  const records = {
    get(game) {
      const key = core.recordKey(state.uid, game);
      if (!key) return {};
      try { const v = JSON.parse(store.get(key) || '{}'); return v && typeof v === 'object' ? v : {}; } catch { return {}; }
    },
    /** Save value under variant if it beats the stored one; returns true if new best. */
    offer(game, variant, value, kind) {
      const key = core.recordKey(state.uid, game);
      if (!key) return false;
      const all = records.get(game);
      if (!core.isBetter(kind, value, all[variant])) return false;
      all[variant] = value;
      store.set(key, JSON.stringify(all));
      return true;
    },
  };

  // ---------- toast ----------
  let toastTimer = 0;
  function toast(text, ms = 3200) {
    const el = els('arcadeToast');
    el.textContent = text;
    el.hidden = false;
    root.clearTimeout(toastTimer);
    toastTimer = root.setTimeout(() => { el.hidden = true; }, ms);
  }

  // ---------- integer pixel scale ----------
  // Pixel art is only ever drawn at whole multiples of its native size.
  function fitScale(nativeW, nativeH, availW, availH) {
    return Math.max(1, Math.min(Math.floor(availW / nativeW), Math.floor(availH / nativeH)));
  }
  function applyHallScale() {
    const stage = els('arcadeStage');
    const avail = stage.parentElement.clientWidth || 320;
    const k = Math.max(1, Math.min(4, Math.floor(avail / 320)));
    stage.style.setProperty('--k', String(k));
    stage.classList.toggle('is-compact', avail < 640);
  }

  // ---------- ticket chip and hall ----------
  function ticketText() {
    if (!state.uid) return { cls: 'is-alert', text: '登入後就能玩' };
    if (!state.loaded && !state.failed) return { cls: 'is-wait', text: '雲端確認中…' };
    if (core.validSession(state.session)) return { cls: 'is-ok', text: `這局剩 ${core.formatClock(state.session.remainingMs)}` };
    const list = tickets();
    const free = list.filter(t => t.free).length, bonus = list.length - free;
    if (!list.length) return { cls: 'is-wait', text: '今天的次數用完了' };
    return { cls: 'is-ok', text: `今天還能玩 ${list.length} 次${bonus ? `（含專注獎勵 ${bonus}）` : ''}` };
  }
  function refreshTicket() {
    const chip = els('arcadeTicket');
    const t = ticketText();
    chip.className = `w-chip arcade-ticket ${t.cls}`;
    chip.textContent = t.text;
    const status = els('arcadeStatus');
    if (!state.uid) status.textContent = '請先登入。每天有 3 次免費遊玩，專注 25 分鐘以上還能多拿獎勵券。';
    else if (!state.loaded) status.textContent = '雲端確認中：正在讀取你最近的專注紀錄…';
    else if (state.failed) status.textContent = '暫時讀不到雲端紀錄，請確認網路後重新整理。';
    else if (!core.validSession(state.session) && !tickets().length) status.textContent = `${core.NO_TICKET_TEXT}：明天早上 5 點會補滿 3 次；現在完成一次 25 分鐘以上的專注，也能多拿一張獎勵券。`;
    else status.textContent = '點一台機台看看說明和你的最佳紀錄。';
    if (!els('arcadeInfo').hidden && state.infoFor) fillInfo(state.infoFor);
  }

  function renderCabinets() {
    const list = els('arcadeCabinets');
    list.textContent = '';
    games.forEach((game, i) => {
      const li = doc.createElement('li');
      li.className = 'arcade-cabinet-slot';
      li.style.setProperty('--slot', String(i));
      const btn = doc.createElement('button');
      btn.type = 'button';
      btn.className = 'arcade-cabinet';
      btn.dataset.game = game.id;
      btn.setAttribute('aria-haspopup', 'dialog');
      const img = doc.createElement('img');
      img.src = `assets/arcade/cabinet_${game.cabinet}.png`;
      img.alt = '';
      img.width = 96;
      img.height = 160;
      const label = doc.createElement('span');
      label.className = 'arcade-cabinet-label';
      label.textContent = game.title;
      btn.append(img, label);
      btn.addEventListener('click', () => openInfo(game, btn));
      li.appendChild(btn);
      list.appendChild(li);
    });
  }

  // ---------- dialogs ----------
  const FOCUSABLE = 'button:not([disabled]):not([hidden]), a[href]:not([hidden]), [tabindex="0"]';
  function openDialog(id, returnTo) {
    const dlg = els(id);
    dlg.dataset.returnFocus = '';
    dlg._returnFocus = returnTo || doc.activeElement;
    dlg.hidden = false;
    const first = dlg.querySelector('.is-gold:not([disabled]):not([hidden])') || dlg.querySelector(FOCUSABLE);
    first?.focus({ preventScroll: true });
  }
  function closeDialog(id, { restore = true } = {}) {
    const dlg = els(id);
    if (dlg.hidden) return;
    dlg.hidden = true;
    const back = dlg._returnFocus;
    dlg._returnFocus = null;
    if (restore && back && doc.contains(back)) back.focus({ preventScroll: true });
  }
  function trapTab(event) {
    const dlg = [...doc.querySelectorAll('.arcade-dialog')].find(d => !d.hidden);
    if (!dlg || event.key !== 'Tab') return false;
    const items = [...dlg.querySelectorAll(FOCUSABLE)].filter(x => x.offsetParent !== null || x === doc.activeElement);
    if (!items.length) return false;
    const first = items[0];
    const last = items[items.length - 1];
    if (event.shiftKey && doc.activeElement === first) { event.preventDefault(); last.focus(); return true; }
    if (!event.shiftKey && doc.activeElement === last) { event.preventDefault(); first.focus(); return true; }
    return false;
  }

  function fillInfo(game) {
    els('infoTitle').textContent = game.title;
    els('infoDesc').textContent = game.desc;
    els('infoControls').textContent = game.controls;
    const best = els('infoBest');
    best.textContent = '';
    const lines = state.uid ? game.bestLines(records.get(game.id), { uid: state.uid, store }) : ['登入後會記錄在這台裝置上。'];
    const ul = doc.createElement('ul');
    ul.className = 'arcade-best-list';
    for (const line of lines.length ? lines : ['還沒有紀錄，第一次玩就會留下。']) {
      const li = doc.createElement('li');
      li.textContent = line;
      ul.appendChild(li);
    }
    best.appendChild(ul);
    const start = els('infoStart');
    const desk = els('infoDesk');
    const note = els('infoTicket');
    desk.hidden = true;
    start.hidden = false;
    start.disabled = false;
    if (!state.uid) {
      note.textContent = '登入後每天可以免費玩 3 次。';
      start.hidden = true;
      desk.hidden = false;
      desk.textContent = '前往登入';
      desk.href = 'login.html';
    } else if (!state.loaded && !state.failed) {
      note.textContent = '雲端確認中：正在確認你今天的次數…';
      start.textContent = '雲端確認中…';
      start.disabled = true;
    } else if (core.validSession(state.session)) {
      note.textContent = `這一局還剩 ${core.formatClock(state.session.remainingMs)}，可以換任何一台繼續玩。`;
      start.textContent = '繼續遊玩';
    } else {
      const list = tickets();
      if (list.length) {
        const free = list.filter(t => t.free).length;
        note.textContent = `今天還能玩 ${list.length} 次${list.length > free ? `（含 ${list.length - free} 張專注獎勵券）` : ''}。每次 5 分鐘，暫停時不計時；每天早上 5 點補滿 3 次免費遊玩。`;
        start.textContent = '開始玩';
      } else {
        note.textContent = `${core.NO_TICKET_TEXT}，明天早上 5 點會補滿。現在去專注 25 分鐘以上，雲端確認後能多拿一張獎勵券。`;
        start.hidden = true;
        desk.hidden = false;
        desk.textContent = '去書桌專注換獎勵券';
        desk.href = 'personal-focus.html';
      }
    }
  }
  function openInfo(game, from) {
    state.infoFor = game;
    fillInfo(game);
    openDialog('arcadeInfo', from);
  }

  els('infoClose').addEventListener('click', () => { state.infoFor = null; closeDialog('arcadeInfo'); });
  els('infoStart').addEventListener('click', () => {
    const game = state.infoFor;
    if (!game || !state.uid || (!state.loaded && !state.failed)) return;
    if (!core.validSession(state.session)) {
      const spent = core.spendTicket(state.failed ? [] : state.receipts, Date.now(), usedIds(), { free: true });
      if (!spent) { fillInfo(game); toast(core.NO_TICKET_TEXT); return; }
      store.set(usedKey(), JSON.stringify(spent.used.filter(id => id.includes('#'))));
      state.session = spent.session;
      saveSession();
      toast(spent.ticket.free ? `用掉今天第 ${spent.ticket.slot} 次免費遊玩，盡情玩 5 分鐘吧！` : '用掉 1 張專注獎勵券，盡情玩 5 分鐘吧！');
    }
    closeDialog('arcadeInfo', { restore: false });
    state.infoFor = null;
    enterGame(game);
  });

  // ---------- game frame ----------
  function setPaused(paused) {
    if (!state.active) return;
    if (paused === state.paused) return;
    state.paused = paused;
    els('gamePaused').hidden = !paused;
    const btn = els('gamePause');
    btn.setAttribute('aria-pressed', String(paused));
    btn.innerHTML = paused ? '繼續 <kbd>Esc</kbd>' : '暫停 <kbd>Esc</kbd>';
    if (paused) { state.active.pause?.(); els('gameResume').focus({ preventScroll: true }); saveSession(); }
    else { state.active.resume?.(); state.lastFrame = performance.now(); state.active.focusTarget?.()?.focus({ preventScroll: true }); }
  }

  const ctx = {
    reducedMotion,
    store,
    records,
    toast,
    fitScale,
    uid: () => state.uid,
    faceIndex: () => state.faceIndex,
    setScore(text) { els('gameScore').textContent = text; },
    setHint(text) { els('gameHint').textContent = text; },
    setPlaying(flag) { state.playing = Boolean(flag); },
    hold(flag) { state.busy = Math.max(0, state.busy + (flag ? 1 : -1)); },
    openDialog,
    closeDialog,
    remainingMs: () => state.session?.remainingMs || 0,
    /** A game ended: show the result. lines: string[]; grade optional. */
    finish(result) {
      state.playing = false;
      saveSession();
      els('resultTitle').textContent = result.title || '結算';
      const grade = els('resultGrade');
      grade.hidden = !result.grade;
      grade.textContent = result.grade ? `評級 ${result.grade}` : '';
      const ul = els('resultLines');
      ul.textContent = '';
      for (const line of result.lines || []) {
        const li = doc.createElement('li');
        li.textContent = line;
        ul.appendChild(li);
      }
      els('resultBest').textContent = result.newBest ? '★ 新的個人最佳紀錄！' : (result.bestText || '');
      const again = els('resultAgain');
      again.textContent = core.validSession(state.session) ? '再玩一次' : '再開一局';
      again.disabled = !core.validSession(state.session) && !tickets().length;
      openDialog('arcadeResult', els('gameExit'));
    },
  };

  function enterGame(game) {
    state.active = game;
    state.paused = false;
    state.busy = 0;
    state.playing = false;
    els('arcadeHall').hidden = true;
    els('arcadeGame').hidden = false;
    els('gameTitle').textContent = game.title;
    els('gamePaused').hidden = true;
    els('gamePause').setAttribute('aria-pressed', 'false');
    els('gamePause').innerHTML = '暫停 <kbd>Esc</kbd>';
    els('gameScore').textContent = '';
    for (const v of doc.querySelectorAll('.arcade-view')) v.hidden = v.dataset.view !== game.id;
    doc.body.classList.add('is-playing');
    game.enter(ctx);
    updateClock();
    refreshTicket();
    state.lastFrame = performance.now();
    (game.focusTarget?.() || els('gamePause')).focus({ preventScroll: true });
  }

  function leaveGame() {
    if (!state.active) return;
    const game = state.active;
    state.active = null;
    state.paused = false;
    state.playing = false;
    state.busy = 0;
    game.leave?.();
    saveSession();
    closeDialog('arcadeResult', { restore: false });
    closeDialog('arcadeCard', { restore: false });
    els('arcadeGame').hidden = true;
    els('arcadeHall').hidden = false;
    doc.body.classList.remove('is-playing');
    refreshTicket();
    doc.querySelector(`.arcade-cabinet[data-game="${game.id}"]`)?.focus({ preventScroll: true });
  }

  els('gamePause').addEventListener('click', () => setPaused(!state.paused));
  els('gameResume').addEventListener('click', () => setPaused(false));
  els('gameExit').addEventListener('click', () => {
    if (state.active && state.playing) state.active.end?.('exit');
    leaveGame();
  });
  els('resultHall').addEventListener('click', leaveGame);
  els('resultAgain').addEventListener('click', () => {
    const game = state.active;
    closeDialog('arcadeResult', { restore: false });
    if (!game) return;
    if (core.validSession(state.session)) { game.leave?.(); enterGame(game); return; }
    leaveGame();
    openInfo(game, doc.querySelector(`.arcade-cabinet[data-game="${game.id}"]`));
  });

  function updateClock() {
    els('gameTime').textContent = core.formatClock(state.session?.remainingMs || 0);
  }

  function frame(now) {
    const dt = Math.max(0, Math.min(100, now - (state.lastFrame || now)));
    state.lastFrame = now;
    const game = state.active;
    if (game && !state.paused) {
      if (state.playing && !state.busy && core.validSession(state.session)) {
        const before = Math.ceil(state.session.remainingMs / 1000);
        state.session = core.drainSession(state.session, dt);
        if (Math.ceil(state.session.remainingMs / 1000) !== before) { updateClock(); refreshTicket(); }
        if (now - state.lastSave > 5000) { state.lastSave = now; saveSession(); }
        if (state.session.remainingMs <= 0) {
          state.session = null;
          saveSession();
          updateClock();
          refreshTicket();
          toast('休息券的時間到了，回到下一個委託吧！', 4500);
          game.end?.('time');
        }
      }
      game.tick?.(now, dt);
    }
    root.requestAnimationFrame(frame);
  }

  // ---------- input ----------
  doc.addEventListener('keydown', event => {
    if (trapTab(event)) return;
    const openDlg = [...doc.querySelectorAll('.arcade-dialog')].find(d => !d.hidden);
    if (openDlg) {
      if (event.key === 'Escape') {
        event.preventDefault();
        if (openDlg.id === 'arcadeInfo') { state.infoFor = null; closeDialog('arcadeInfo'); }
        else if (openDlg.id === 'arcadeCard') els('cardClose').click();
        else if (openDlg.id === 'arcadeResult') leaveGame();
      }
      return;
    }
    if (!state.active) return;
    const key = event.key.toLowerCase();
    if (key === 'escape' || key === 'p') { event.preventDefault(); setPaused(!state.paused); return; }
    if (state.paused) return;
    if (state.active.key?.('down', key, event)) event.preventDefault();
  });
  doc.addEventListener('keyup', event => {
    if (!state.active || state.paused) return;
    if (state.active.key?.('up', event.key.toLowerCase(), event)) event.preventDefault();
  });
  // Switching tabs or windows pauses the game (and its clock).
  doc.addEventListener('visibilitychange', () => { if (doc.hidden && state.active) setPaused(true); });
  root.addEventListener('blur', () => { if (state.active && state.playing) setPaused(true); });
  root.addEventListener('resize', () => { applyHallScale(); state.active?.resize?.(); });
  root.addEventListener('pagehide', saveSession);

  // ---------- account data (read-only) ----------
  let unsubUser = null;
  let unsubReceipts = null;
  let generation = 0;
  function applyUser(user) {
    state.uid = user?.uid || null;
    state.receipts = [];
    state.loaded = false;
    state.failed = false;
    state.session = state.uid ? core.readSession(store.get(sessionKey())) : null;
    refreshTicket();
  }
  function connect() {
    const fb = root.firebase;
    if (connect.done || !fb?.apps?.length) return;
    connect.done = true;
    fb.auth().onAuthStateChanged(user => {
      const own = ++generation;
      unsubUser?.();
      unsubReceipts?.();
      unsubUser = unsubReceipts = null;
      applyUser(user);
      if (!user) return;
      unsubUser = fb.firestore().collection('users').doc(user.uid).onSnapshot(snap => {
        if (own !== generation) return;
        const face = Number(snap.exists ? snap.data()?.avatarProfile?.faceShapeIndex : 0);
        state.faceIndex = Number.isInteger(face) && face >= 0 ? face : 0;
      }, () => {});
      unsubReceipts = fb.firestore().collection('activity_receipts')
        .where('actorUserId', '==', user.uid).orderBy('verifiedAt', 'desc').limit(10)
        .onSnapshot(snap => {
          if (own !== generation) return;
          state.receipts = snap.docs.map(d => ({ receiptId: d.id, ...d.data() }))
            .filter(d => root.NudgeConfirmedActivityFeedback?.parse(d.receiptId, d, user.uid));
          state.loaded = true;
          state.failed = false;
          refreshTicket();
        }, () => {
          if (own !== generation) return;
          state.failed = true;
          refreshTicket();
        });
    });
  }

  root.NudgeArcade = Object.freeze({
    register(game) {
      if (!game || typeof game.id !== 'string' || games.some(g => g.id === game.id)) throw new Error('bad game');
      games.push(game);
      renderCabinets();
    },
  });

  doc.addEventListener('firebase-ready', connect);
  applyHallScale();
  refreshTicket();
  root.setInterval(refreshTicket, 30000);
  root.requestAnimationFrame(frame);
  connect();
})(typeof globalThis !== 'undefined' ? globalThis : this);
