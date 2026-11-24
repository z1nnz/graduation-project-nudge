(function (root) {
  'use strict';
  // In-town scenes for the personal loop (#82 slice 2):
  //   quest board -> focus desk -> Cloud confirmation -> companion feedback.
  // Tasks go through window.queueWebTaskLedgerEvent and focus through
  // window.queueWebStandaloneFocusLedgerEvent (both defined in app.js and
  // backed by the Activity Ledger outbox). Celebration only follows a
  // Cloud-written activity receipt for the same session; this file never
  // writes Firestore and never computes coins or XP.
  const routes = root.NudgeTownRoutes;
  const core = root.NudgeTownDeskCore;
  const doc = root.document;
  if (!routes || !core || !doc || doc.body?.dataset.page !== 'town') return;

  const reducedMotion = root.matchMedia?.('(prefers-reduced-motion: reduce)').matches;
  const store = {
    get(key) { try { return root.localStorage.getItem(key); } catch { return null; } },
    set(key, value) { try { root.localStorage.setItem(key, value); } catch { /* private mode */ } },
    remove(key) { try { root.localStorage.removeItem(key); } catch { /* private mode */ } },
  };
  const storage = { getItem: key => store.get(key) };
  const h = (tag, props = {}, ...children) => {
    const el = doc.createElement(tag);
    for (const [key, value] of Object.entries(props)) {
      if (key === 'class') el.className = value;
      else if (key === 'text') el.textContent = value;
      else if (key.startsWith('on')) el.addEventListener(key.slice(2), value);
      else el.setAttribute(key, value);
    }
    for (const child of children) if (child != null) el.append(child);
    return el;
  };

  const state = {
    uid: null,
    user: null,
    userError: false,
    fromCache: false,
    latestReceipt: null,
    session: null,
    sessionReceipt: null,
    taskWatch: new Map(), // taskId -> { status, correlationId, since, unsubscribe }
    busy: false,
    open: null, // 'board' | 'desk' | 'cabin'
    returnFocus: null,
    generation: 0,
  };
  let unsubscribeUser = null;
  let unsubscribeLatest = null;
  let unsubscribeSessionReceipt = null;
  let ticker = null;

  // ---------- shell ----------
  const shell = h('section', {
    id: 'townScene', class: 'town-scene', role: 'dialog', 'aria-modal': 'true', 'aria-labelledby': 'townSceneTitle',
  });
  shell.hidden = true;
  doc.addEventListener('nudge-town-open-scene', event => {
    if (['board', 'desk', 'cabin'].includes(event.detail?.kind)) open(event.detail.kind);
  });
  const title = h('h2', { id: 'townSceneTitle' });
  const closeButton = h('button', { type: 'button', class: 'town-ghost', 'aria-label': '關閉，回到小鎮', onclick: () => close() }, '✕ ', h('kbd', { text: 'Esc' }));
  const body = h('div', { class: 'town-scene-body' });
  const live = h('p', { class: 'town-scene-live', role: 'status', 'aria-live': 'polite' });
  shell.append(h('div', { class: 'town-panel-head' }, title, closeButton), live, body);
  const chip = h('button', { id: 'townDeskChip', type: 'button', class: 'town-hud town-desk-chip', onclick: () => open('desk') });
  chip.hidden = true;
  (doc.querySelector('main.town') || doc.body).append(shell, chip);

  doc.addEventListener('keydown', event => {
    if (shell.hidden) return;
    if (event.key === 'Escape') { event.preventDefault(); close(); }
  });

  function open(kind, options = {}) {
    if (shell.hidden) state.returnFocus = options.returnFocus || doc.activeElement;
    state.open = kind;
    shell.hidden = false;
    doc.dispatchEvent(new CustomEvent('nudge-town-scene', { detail: { open: true, scene: kind } }));
    render();
    (body.querySelector('button:not([disabled]), a') || closeButton).focus({ preventScroll: true });
  }

  function close() {
    if (shell.hidden) return;
    shell.hidden = true;
    state.open = null;
    if (state.session?.status === 'awaiting' && state.sessionReceipt) clearSession();
    doc.dispatchEvent(new CustomEvent('nudge-town-scene', { detail: { open: false } }));
    const back = state.returnFocus;
    state.returnFocus = null;
    if (back && doc.contains(back) && typeof back.focus === 'function') back.focus({ preventScroll: true });
    renderChip();
  }

  function say(text) { live.textContent = text; }

  function render() {
    if (shell.hidden) return;
    // Keep keyboard focus on the same control when live data re-renders the scene.
    // A button that becomes disabled drops focus to <body>; pull it back into the scene.
    const focusables = () => [...body.querySelectorAll('button:not(:disabled), a')];
    const active = doc.activeElement;
    const focusedIndex = focusables().indexOf(active);
    const focusWasHere = focusedIndex >= 0 || !active || active === doc.body || shell.contains(active);
    paint();
    if (focusWasHere && !shell.contains(doc.activeElement)) {
      const list = focusables();
      (list[Math.max(0, focusedIndex)] || list[0] || closeButton).focus({ preventScroll: true });
    }
  }

  function paint() {
    body.textContent = '';
    if (!state.uid) {
      title.textContent = { board: '委託告示板', desk: '書桌', cabin: '你的小屋' }[state.open] || '小鎮';
      body.append(h('p', { text: '登入後才能看到你自己的任務與專注紀錄。' }),
        h('a', { class: 'town-gold', href: 'login.html', onclick: () => store.set('nudgePostLoginRedirect', 'town.html') }, '登入'));
      return;
    }
    if (state.open === 'board') renderBoard();
    else if (state.open === 'desk') renderDesk();
    else if (state.open === 'cabin') renderCabin();
  }

  // ---------- quest board ----------
  function renderBoard() {
    title.textContent = '委託告示板';
    if (state.userError) {
      body.append(h('p', { text: '暫時無法讀取你的任務清單。不會顯示其他帳號的資料，請確認網路後重新整理。' }));
      return;
    }
    if (!state.user) { body.append(h('p', { text: '正在讀取你的任務清單…' })); return; }
    const tasks = state.user.tasks;
    const next = root.NudgeDailyNextAction?.resolve(tasks);
    if (next) {
      body.append(h('div', { class: 'town-quest-next' },
        h('small', { text: '今天的一步' }), h('strong', { text: next.title }), h('p', { text: next.detail })));
    }
    if (state.fromCache) body.append(h('p', { class: 'town-scene-note', text: '目前是快取清單，等待網路確認。' }));
    const rows = core.boardTasks(tasks, root.isDeadlineTaskReadyForWeb);
    if (!rows.length) {
      body.append(h('p', { text: '告示板還是空的。可以到任務清單安排一件做得到的小事。' }),
        h('a', { class: 'town-ghost', href: 'planet.html' }, '安排我的任務'));
    }
    const list = h('ul', { class: 'town-quest-list' });
    for (const row of rows) list.append(questRow(row));
    body.append(list,
      h('div', { class: 'town-scene-actions' },
        h('button', { type: 'button', class: 'town-gold', onclick: () => open('desk') }, '去書桌專注'),
        h('a', { class: 'town-ghost', href: 'planet.html' }, '完整任務清單')));
  }

  function questRow(row) {
    const watch = state.taskWatch.get(row.id);
    const li = h('li', { class: `town-quest-row${row.done ? ' is-done' : ''}` }, h('span', { text: row.title }));
    if (watch?.status === 'confirming') {
      li.append(h('span', { class: 'town-quest-state', text: '確定要送出完成嗎？' }),
        h('button', { type: 'button', class: 'town-gold', onclick: () => submitTask(row) }, '送出'),
        h('button', { type: 'button', class: 'town-ghost', onclick: () => { state.taskWatch.delete(row.id); render(); } }, '取消'));
      return li;
    }
    if (watch?.status === 'sending') li.append(h('span', { class: 'town-quest-state', text: '保存中…' }));
    else if (watch?.status === 'queued') li.append(h('span', { class: 'town-quest-state', text: taskConfirmationText(watch) }));
    else if (watch?.status === 'confirmed') li.append(h('span', { class: 'town-quest-state is-ok', text: '雲端已確認' }));
    else if (watch?.status === 'failed') {
      li.append(h('span', { class: 'town-quest-state is-bad', text: watch.message }),
        h('button', { type: 'button', class: 'town-ghost', onclick: () => askTask(row) }, '再試一次'));
    } else if (row.canComplete) {
      li.append(h('button', { type: 'button', class: 'town-ghost', onclick: () => askTask(row) }, '完成'));
    } else {
      li.append(h('span', { class: 'town-quest-state', text: row.reason }));
    }
    return li;
  }

  function askTask(row) {
    state.taskWatch.set(row.id, { status: 'confirming' });
    render();
    body.querySelector('.town-quest-row .town-gold')?.focus({ preventScroll: true });
  }

  function taskConfirmationText(watch) {
    const c = core.confirmation({ uid: state.uid, sessionId: watch.correlationId, receipt: null, storage });
    if (c.state === 'pending') return '已離線保存，連線後自動重送';
    return '已送出，等待雲端確認';
  }

  async function submitTask(row) {
    if (state.taskWatch.get(row.id)?.status === 'sending') return;
    const uid = state.uid;
    const occurredAt = new Date();
    state.taskWatch.set(row.id, { status: 'sending' });
    render();
    try {
      if (typeof root.queueWebTaskLedgerEvent !== 'function') throw new Error('Activity Ledger 尚未載入，請稍後再試。');
      await root.queueWebTaskLedgerEvent({ userId: uid, taskId: row.id, completed: true, occurredAt });
      if (uid !== state.uid) return;
      const ledger = root.NudgeActivityLedgerClient;
      const correlationId = ledger && typeof root.webActivityDateKey === 'function'
        ? ledger.buildTaskCompletionEvidence({ userId: uid, taskId: row.id, activityDateKey: root.webActivityDateKey(occurredAt), completed: true, occurredAt }).activityCorrelationId
        : null;
      const watch = { status: 'queued', correlationId, since: occurredAt.toISOString(), unsubscribe: null };
      state.taskWatch.set(row.id, watch);
      if (correlationId) {
        watch.unsubscribe = watchReceipt(correlationId, receipt => {
          if (receipt.verifiedAt < watch.since) return;
          watch.status = 'confirmed';
          watch.unsubscribe?.();
          say(`「${row.title}」已由雲端確認。`);
          celebrate(`「${row.title}」完成，雲端已確認！`);
          render();
        });
      }
      say(`「${row.title}」已保存，等待雲端確認。`);
    } catch (error) {
      state.taskWatch.set(row.id, { status: 'failed', message: error?.message || '沒有保存成功，任務狀態沒有變更。' });
      say('任務沒有保存成功。');
    }
    render();
  }

  // ---------- focus desk ----------
  function sessionKey() { return core.storageKey(state.uid); }
  function saveSession() { if (state.uid && state.session) store.set(sessionKey(), JSON.stringify(state.session)); }
  function clearSession() {
    unsubscribeSessionReceipt?.();
    unsubscribeSessionReceipt = null;
    if (state.uid) store.remove(sessionKey());
    state.session = null;
    state.sessionReceipt = null;
    renderChip();
  }

  async function queueFocus(eventType, session) {
    if (typeof root.queueWebStandaloneFocusLedgerEvent !== 'function') throw new Error('Activity Ledger 尚未載入，請稍後再試。');
    await root.queueWebStandaloneFocusLedgerEvent({
      sessionId: session.sessionId,
      eventType,
      elapsedSeconds: core.elapsedSeconds(session, Date.now()),
      occurredAt: new Date(),
    });
  }

  async function deskAction(action, minutes) {
    if (state.busy) return;
    state.busy = true;
    render();
    const now = Date.now();
    try {
      if (action === 'start') {
        const session = core.createSession(now, minutes);
        await queueFocus('started', session);
        state.session = session;
        say(`開始專注 ${session.targetSeconds / 60} 分鐘。`);
      } else if (action === 'pause') {
        await queueFocus('paused', state.session);
        state.session = core.pause(state.session, now);
        say('已暫停。');
      } else if (action === 'resume') {
        const next = core.resume(state.session, now);
        await queueFocus('resumed', state.session);
        state.session = next;
        say('繼續專注。');
      } else if (action === 'complete') {
        await queueFocus('completed', state.session);
        state.session = core.awaitConfirmation(state.session, now);
        watchSession();
        say('專注完成，等待雲端確認。');
      } else if (action === 'discard') {
        await queueFocus('discarded', state.session);
        clearSession();
        say('這一輪已放棄，不會送出完成紀錄。');
      }
      saveSession();
    } catch (error) {
      say(error?.message || '沒有保存成功，計時狀態沒有變更。');
    } finally {
      state.busy = false;
      render();
      renderChip();
    }
  }

  function renderDesk() {
    title.textContent = '書桌專注';
    const s = state.session;
    const pose = !s ? 'idle' : s.status !== 'awaiting' ? 'study' : state.sessionReceipt ? 'celebrate' : 'idle';
    const companion = companionImage(pose);
    body.append(companion);
    if (!s) {
      body.append(h('p', { text: '選一個長度，坐下來專注。完成後由雲端確認，夥伴才會慶祝。' }));
      const row = h('div', { class: 'town-scene-actions' });
      for (const m of core.DURATIONS) {
        row.append(h('button', { type: 'button', class: m === 25 ? 'town-gold' : 'town-ghost', onclick: () => deskAction('start', m) }, `${m} 分鐘`));
      }
      if (state.busy) row.querySelectorAll('button').forEach(b => { b.disabled = true; });
      body.append(row);
      return;
    }
    if (s.status === 'awaiting') { renderAwaiting(); return; }
    const remaining = core.remainingSeconds(s, Date.now());
    body.append(h('p', { class: 'town-desk-clock', 'aria-hidden': 'true', text: core.clock(remaining) }),
      h('p', { class: 'town-scene-note', text: s.status === 'paused' ? '已暫停。重新整理或換頁也會保留這一輪。' : '專注中。重新整理或換頁也會從這裡接續。' }));
    const actions = h('div', { class: 'town-scene-actions' });
    if (remaining <= 0) {
      actions.append(h('button', { type: 'button', class: 'town-gold', onclick: () => deskAction('complete') }, '時間到了，送出完成'));
    } else if (s.status === 'active') {
      actions.append(h('button', { type: 'button', class: 'town-ghost', onclick: () => deskAction('pause') }, '暫停'));
    } else {
      actions.append(h('button', { type: 'button', class: 'town-gold', onclick: () => deskAction('resume') }, '繼續'));
    }
    actions.append(h('button', { type: 'button', class: 'town-ghost', onclick: () => deskAction('discard') }, '放棄這一輪'));
    if (state.busy) actions.querySelectorAll('button').forEach(b => { b.disabled = true; });
    body.append(actions, h('p', { class: 'town-sr-only', text: `剩餘 ${Math.ceil(remaining / 60)} 分鐘` }));
  }

  function renderAwaiting() {
    const s = state.session;
    const minutes = Math.round(s.completedSeconds / 60);
    if (state.sessionReceipt) {
      body.append(h('p', { class: 'town-result is-ok', text: `專注完成！雲端已確認 ${minutes} 分鐘。` }),
        h('p', { class: 'town-scene-note', text: '自律幣與經驗值以獎勵帳本為準；達到每日上限時可能不會增加。' }),
        h('div', { class: 'town-scene-actions' },
          h('button', { type: 'button', class: 'town-gold', onclick: () => { clearSession(); open('cabin'); } }, '回小屋看夥伴'),
          h('button', { type: 'button', class: 'town-ghost', onclick: () => { clearSession(); render(); } }, '再專注一輪')));
      return;
    }
    const c = core.confirmation({ uid: state.uid, sessionId: s.sessionId, receipt: null, storage });
    const text = {
      sending: `正在送出 ${minutes} 分鐘…`,
      pending: `已保存 ${minutes} 分鐘，目前無法連上雲端（已試 ${c.attempts} 次），連線後會自動重送。`,
      sent: `已送出 ${minutes} 分鐘，等待雲端確認…`,
      rejected: '雲端沒有接受這一輪，所以不會發放獎勵。',
    }[c.state];
    body.append(h('p', { class: `town-result${c.state === 'rejected' ? ' is-bad' : ''}`, text }));
    if (c.state === 'rejected' && live.textContent !== text) say(text);
    const actions = h('div', { class: 'town-scene-actions' });
    if (c.state === 'pending') {
      actions.append(h('button', { type: 'button', class: 'town-gold', onclick: retryOutbox }, '立即重試'));
    }
    if (c.state === 'rejected') {
      actions.append(h('button', { type: 'button', class: 'town-ghost', onclick: () => { clearSession(); render(); } }, '知道了'));
    }
    body.append(actions);
  }

  async function retryOutbox() {
    try {
      const outbox = await root.ensureWebActivityLedgerOutbox?.();
      const report = await outbox?.flush();
      say(report?.retryBlocked ? '仍無法連線，稍後會再試。' : '已重新送出。');
    } catch (error) {
      say(error?.message || '重試失敗，稍後會自動再試。');
    }
    render();
  }

  function watchSession() {
    unsubscribeSessionReceipt?.();
    const s = state.session;
    if (!s || s.status !== 'awaiting') return;
    unsubscribeSessionReceipt = watchReceipt(s.sessionId, () => {
      state.sessionReceipt = true;
      unsubscribeSessionReceipt?.();
      unsubscribeSessionReceipt = null;
      say('雲端已確認這一輪專注。');
      celebrate('專注完成，雲端已確認！夥伴在小屋等你。');
      render();
      renderChip();
    });
  }

  function renderChip() {
    const s = state.session;
    chip.hidden = !state.uid || !s || !shell.hidden;
    if (chip.hidden) return;
    if (s.status === 'awaiting') chip.textContent = state.sessionReceipt ? '✓ 專注已確認' : '⏳ 等待雲端確認';
    else if (s.status === 'paused') chip.textContent = `⏸ 書桌 ${core.clock(core.remainingSeconds(s, Date.now()))}`;
    else chip.textContent = `📖 書桌 ${core.clock(core.remainingSeconds(s, Date.now()))}`;
    chip.setAttribute('aria-label', `${chip.textContent}，打開書桌`);
  }

  // ---------- cabin feedback ----------
  function renderCabin() {
    title.textContent = '你的小屋';
    const receipt = state.latestReceipt;
    const fresh = receipt && Date.now() - Date.parse(receipt.verifiedAt) < 30 * 60 * 1000;
    body.append(companionImage(fresh ? 'celebrate' : 'idle'));
    if (state.session && state.session.status !== 'awaiting') {
      body.append(h('p', { text: '夥伴坐在書桌旁陪你專注。' }));
    } else if (state.session?.status === 'awaiting' && !state.sessionReceipt) {
      body.append(h('p', { text: '夥伴在等雲端確認你剛完成的專注。' }));
    } else if (receipt) {
      body.append(h('p', { class: fresh ? 'town-result is-ok' : '', text: fresh ? `夥伴在跳舞：${receipt.label}。` : `上一次：${receipt.label}。` }));
    } else {
      body.append(h('p', { text: '還沒有雲端確認的行動。到告示板選一件小事，夥伴會陪你。' }));
    }
    body.append(h('p', { class: 'town-scene-note', text: '夥伴只會因為雲端確認的行動而慶祝，不會自己發放獎勵。' }),
      h('div', { class: 'town-scene-actions' },
        h('button', { type: 'button', class: 'town-gold', onclick: () => open('desk') }, '坐到書桌前'),
        h('a', { class: 'town-ghost', href: 'profile.html' }, '我的名片與角色')));
  }

  function companionImage(pose) {
    const face = Number(state.user?.avatarProfile?.faceShapeIndex);
    const src = `assets/avatar/characters/character_${Number.isInteger(face) && face >= 0 ? face : 0}.png`;
    const img = h('img', { class: `town-companion is-${pose}${reducedMotion ? ' is-still' : ''}`, src, alt: '' });
    img.addEventListener('error', () => { img.hidden = true; }, { once: true });
    return img;
  }

  function celebrate(message) {
    doc.dispatchEvent(new CustomEvent('nudge-town-celebrate', { detail: { message } }));
  }

  // ---------- Cloud reads ----------
  function watchReceipt(activitySessionId, onReceipt) {
    const fb = root.firebase;
    if (!fb?.apps?.length || !state.uid) return null;
    const uid = state.uid;
    const own = state.generation;
    return fb.firestore().collection('activity_receipts')
      .where('actorUserId', '==', uid)
      .where('activitySessionId', '==', activitySessionId)
      .limit(5)
      .onSnapshot({ includeMetadataChanges: true }, snapshot => {
        if (own !== state.generation || snapshot.metadata.hasPendingWrites) return;
        for (const d of snapshot.docs) {
          const data = d.data();
          if (root.NudgeConfirmedActivityFeedback?.parse(d.id, data, uid)) { onReceipt(data); return; }
        }
      }, () => { if (own === state.generation) say('暫時無法讀取雲端確認，連線恢復後會再檢查。'); });
  }

  function resetAccount() {
    state.generation += 1;
    unsubscribeUser?.();
    unsubscribeLatest?.();
    unsubscribeSessionReceipt?.();
    unsubscribeUser = unsubscribeLatest = unsubscribeSessionReceipt = null;
    for (const watch of state.taskWatch.values()) watch.unsubscribe?.();
    state.taskWatch.clear();
    Object.assign(state, { user: null, userError: false, fromCache: false, latestReceipt: null, session: null, sessionReceipt: null });
  }

  function connect() {
    const fb = root.firebase;
    if (!fb?.apps?.length || connect.done) return;
    connect.done = true;
    fb.auth().onAuthStateChanged(user => {
      resetAccount();
      state.uid = user?.uid || null;
      if (!user) { render(); renderChip(); return; }
      const own = state.generation;
      state.session = core.parseStored(store.get(sessionKey()));
      if (state.session?.status === 'awaiting') watchSession();
      unsubscribeUser = fb.firestore().collection('users').doc(user.uid)
        .onSnapshot({ includeMetadataChanges: true }, snap => {
          if (own !== state.generation) return;
          state.user = snap.exists ? snap.data() : {};
          state.userError = false;
          state.fromCache = snap.metadata.fromCache;
          render();
        }, () => {
          if (own !== state.generation) return;
          state.user = null;
          state.userError = true;
          render();
        });
      unsubscribeLatest = fb.firestore().collection('activity_receipts')
        .where('actorUserId', '==', user.uid).orderBy('verifiedAt', 'desc').limit(1)
        .onSnapshot(snap => {
          if (own !== state.generation) return;
          const d = snap.docs[0];
          const parsed = d ? root.NudgeConfirmedActivityFeedback?.parse(d.id, d.data(), user.uid) : null;
          state.latestReceipt = parsed ? { ...parsed, verifiedAt: d.data().verifiedAt } : null;
          if (state.open === 'cabin') render();
        }, () => {});
      render();
      renderChip();
    });
  }

  routes.registerScene('board', options => open('board', options));
  routes.registerScene('desk', options => open('desk', options));
  routes.registerScene('cabin', options => open('cabin', options));
  doc.addEventListener('firebase-ready', connect);
  root.addEventListener('storage', event => {
    if (state.open === 'desk' && event.key && event.key.startsWith('nudge_web_activity_ledger')) render();
  });
  // Once a second: update the clock text in place; re-render only when the
  // visible state changes, so keyboard focus is not thrown away every tick.
  let lastShape = '';
  ticker = root.setInterval(() => {
    const s = state.session;
    if (s?.status === 'active') {
      renderChip();
      const remaining = core.remainingSeconds(s, Date.now());
      const clockEl = body.querySelector('.town-desk-clock');
      if (state.open === 'desk' && clockEl) clockEl.textContent = core.clock(remaining);
      const shape = `${s.sessionId}:${remaining <= 0 ? 'done' : 'running'}`;
      if (shape !== lastShape) {
        if (remaining <= 0 && lastShape) say('時間到了，可以送出完成。');
        lastShape = shape;
        if (state.open === 'desk') render();
      }
    } else if (s?.status === 'awaiting' && !state.sessionReceipt) {
      const shape = `${s.sessionId}:${core.confirmation({ uid: state.uid, sessionId: s.sessionId, receipt: null, storage }).state}`;
      if (shape !== lastShape) {
        lastShape = shape;
        if (state.open === 'desk') render();
      }
    }
  }, 1000);
  root.addEventListener('pagehide', () => { resetAccount(); root.clearInterval(ticker); });
  connect();
})(typeof globalThis !== 'undefined' ? globalThis : this);
