(function (root) {
  'use strict';
  // Starlight garden scene. Login is enforced by app.js (this page is not
  // public); the level gate is re-checked here from the user's own document
  // so the town is never the only gate. Read-only: nothing here writes.
  //
  // Plants come from the signed-in user's own completed activity_sessions,
  // read once from the server. Cached or pending data is never drawn as a
  // grown plant: the page says "雲端確認中" until the server answers.
  const core = root.NudgeGardenCore;
  const doc = root.document;
  if (!core || !doc || doc.body?.dataset.page !== 'garden') return;
  const els = id => doc.getElementById(id);
  const reducedMotion = () => Boolean(root.matchMedia?.('(prefers-reduced-motion: reduce)').matches);
  const WEEKDAYS = ['日', '一', '二', '三', '四', '五', '六'];
  const SOURCES = { app: 'App', web: '網頁', device: '裝置', health: '健康資料' };

  let started = false;
  let unsubscribeUser = null;
  let generation = 0;
  let loadToken = 0;
  let currentUid = null;
  let unlocked = false;
  let beds = null;
  let focusIndex = 0;
  let lastFocus = null;
  let openPlot = null;
  let waterTimer = 0;

  function show(view) {
    els('gardenLocked').hidden = view !== 'locked';
    els('gardenScene').hidden = view !== 'scene';
  }

  function node(tag, text, attrs) {
    const el = doc.createElement(tag);
    if (text != null) el.textContent = text;
    for (const [k, v] of Object.entries(attrs || {})) el.setAttribute(k, v);
    return el;
  }

  function setSync(kind, text) {
    const chip = els('gardenSync');
    chip.className = `w-chip ${kind === 'ok' ? 'is-ok' : kind === 'alert' ? 'is-alert' : 'is-wait'}`;
    chip.textContent = text;
  }

  function spriteStyle(el, plantId, stage) {
    const kind = core.plantById(plantId);
    el.dataset.plant = plantId;
    el.dataset.stage = String(stage);
    // Set inline so the path resolves against the page, not the stylesheet.
    el.style.backgroundImage = `url("assets/${kind.sprite}")`;
    el.style.setProperty('--g-frame', String(Math.max(0, stage - 1)));
  }

  function applySeason(nowMs) {
    const s = core.season(nowMs);
    els('gardenStage').dataset.season = s.id;
    els('gardenSeason').textContent = `${s.name}・${s.note}`;
  }

  function weekHeading(week, index, count) {
    if (index === count - 1) return '本週';
    if (index === count - 2) return '上週';
    return core.weekRange(week).split('–')[0];
  }

  function renderLegend() {
    const list = els('gardenLegend');
    list.textContent = '';
    for (const kind of core.PLANTS) {
      const steps = kind.thresholds.map(n => core.formatNumber(n)).join('／');
      const item = node('li');
      const sprite = node('span', null, { class: 'g-sprite g-sprite-icon', 'aria-hidden': 'true' });
      spriteStyle(sprite, kind.id, 5);
      item.append(sprite, node('span', `${kind.name}：${kind.verb}長出來。一週累積 ${steps} ${kind.unitLabel}，分別長到第 1–5 階段。`));
      list.appendChild(item);
    }
  }

  /** Draw the grid. `beds` null means waiting for the Cloud: only bare soil. */
  function renderGrid(nowMs) {
    const grid = els('gardenGrid');
    const { weeks } = core.weekWindow(nowMs);
    grid.textContent = '';
    grid.style.setProperty('--g-weeks', String(weeks.length));
    grid.appendChild(node('span', null, { class: 'g-corner', 'aria-hidden': 'true' }));
    weeks.forEach((week, i) => {
      grid.appendChild(node('span', weekHeading(week, i, weeks.length), { class: 'g-week', 'aria-hidden': 'true' }));
    });
    const rows = beds || core.grow([], weeks);
    let index = 0;
    for (const bed of rows) {
      const kind = core.plantById(bed.plant);
      grid.appendChild(node('span', kind.short, { class: 'g-row-label', title: kind.name, 'aria-hidden': 'true' }));
      for (const plot of bed.plots) {
        const cell = node('button', null, { type: 'button', class: 'g-plot', 'data-index': String(index) });
        const week = core.weekNumber(plot.week).week;
        const label = beds
          ? `${kind.name}，第 ${week} 週（${core.weekRange(plot.week)}），${plot.stage ? `第 ${plot.stage} 階段${core.stageName(kind, plot.stage)}` : '空土'}`
          : `${kind.name}，第 ${week} 週，雲端確認中`;
        cell.setAttribute('aria-label', label);
        cell.tabIndex = index === focusIndex ? 0 : -1;
        if (!beds) cell.disabled = true;
        const sprite = node('span', null, { class: 'g-sprite', 'aria-hidden': 'true' });
        spriteStyle(sprite, kind.id, plot.stage);
        cell.appendChild(sprite);
        cell.addEventListener('click', () => openDialog(plot, cell));
        grid.appendChild(cell);
        index += 1;
      }
    }
  }

  function plotButtons() {
    return Array.from(els('gardenGrid').querySelectorAll('.g-plot'));
  }

  function onGridKey(event) {
    const buttons = plotButtons();
    const at = buttons.indexOf(doc.activeElement);
    if (at < 0) return;
    const cols = core.WEEKS_SHOWN;
    const moves = { ArrowRight: 1, ArrowLeft: -1, ArrowDown: cols, ArrowUp: -cols, Home: -(at % cols), End: cols - 1 - (at % cols) };
    if (!(event.key in moves)) return;
    const next = at + moves[event.key];
    if (next < 0 || next >= buttons.length) return;
    event.preventDefault();
    buttons[at].tabIndex = -1;
    buttons[next].tabIndex = 0;
    focusIndex = next;
    buttons[next].focus();
  }

  function formatSession(row) {
    const kind = core.plantById(row.plant);
    const ended = new Date(Date.parse(row.endedAt) + 8 * 3600000);
    const time = `${String(ended.getUTCHours()).padStart(2, '0')}:${String(ended.getUTCMinutes()).padStart(2, '0')}`;
    const date = `${ended.getUTCMonth() + 1}/${ended.getUTCDate()}（${WEEKDAYS[ended.getUTCDay()]}）${time}`;
    return `${date} ${SOURCES[row.source] || row.source}・${core.formatNumber(row.value)} ${kind.unitLabel}`;
  }

  function openDialog(plot, opener) {
    const kind = core.plantById(plot.plant);
    openPlot = plot;
    lastFocus = opener || doc.activeElement;
    focusIndex = Number(opener?.dataset.index || 0);
    els('gardenDialogTitle').textContent = kind.name;
    els('gardenDialogStage').textContent = plot.stage
      ? `第 ${plot.stage} / ${core.STAGES} 階段・${core.stageName(kind, plot.stage)}`
      : '空土';
    els('gardenDialogStory').textContent = core.describe(plot);
    const next = core.nextStage(kind, plot.total);
    const isCurrent = plot.week === core.weekStart(Date.now());
    els('gardenDialogNext').textContent = !next
      ? '這週已經長到最大了。'
      : isCurrent
        ? `本週再累積 ${core.formatNumber(next.need)} ${kind.unitLabel}${kind.verb}，就會長到第 ${next.stage} 階段。`
        : '這一週已經過去，植物會保持那週長成的樣子。';
    const list = els('gardenDialogSessions');
    list.textContent = '';
    const shown = plot.sessions.slice(-8);
    for (const row of shown) list.appendChild(node('li', formatSession(row)));
    if (plot.sessions.length > shown.length) list.appendChild(node('li', `…以及更早的 ${plot.sessions.length - shown.length} 筆`));
    list.hidden = !plot.sessions.length;
    const sprite = els('gardenDialogSprite');
    spriteStyle(sprite, kind.id, plot.stage);
    els('gardenWaterNote').textContent = '';
    els('gardenWater').disabled = !plot.stage;
    els('gardenDialog').hidden = false;
    doc.body.classList.add('g-dialog-open');
    els('gardenDialogClose').focus();
  }

  function closeDialog() {
    if (els('gardenDialog').hidden) return;
    els('gardenDialog').hidden = true;
    doc.body.classList.remove('g-dialog-open');
    stopWater();
    openPlot = null;
    const target = plotButtons()[focusIndex] || lastFocus;
    if (target && target.isConnected) target.focus();
    else lastFocus?.focus?.();
  }

  function stopWater() {
    root.clearTimeout(waterTimer);
    els('gardenDialog').classList.remove('is-watering');
  }

  function water() {
    if (!openPlot || !openPlot.stage) return;
    stopWater();
    // Restart the CSS animation; reduced motion shows still drops instead.
    void els('gardenDrops').offsetWidth;
    els('gardenDialog').classList.add('is-watering');
    els('gardenWaterNote').textContent = `你幫${core.plantById(openPlot.plant).name}澆了水。澆水只是互動，不會改變任何紀錄。`;
    waterTimer = root.setTimeout(stopWater, reducedMotion() ? 1200 : 900);
  }

  function trapFocus(event) {
    if (els('gardenDialog').hidden) return;
    if (event.key === 'Escape') { event.preventDefault(); closeDialog(); return; }
    if (event.key !== 'Tab') return;
    const items = Array.from(els('gardenDialog').querySelectorAll('button:not([disabled]), summary, a[href]'));
    if (!items.length) return;
    const first = items[0];
    const last = items[items.length - 1];
    if (event.shiftKey && doc.activeElement === first) { event.preventDefault(); last.focus(); }
    else if (!event.shiftKey && doc.activeElement === last) { event.preventDefault(); first.focus(); }
  }

  async function fingerprintMatches(id, fingerprint) {
    const subtle = root.crypto?.subtle;
    if (!subtle) return false;
    const bytes = await subtle.digest('SHA-256', new TextEncoder().encode(fingerprint));
    return Array.from(new Uint8Array(bytes), b => b.toString(16).padStart(2, '0')).join('') === id;
  }

  async function loadSessions(uid) {
    const token = ++loadToken;
    const nowMs = Date.now();
    const span = core.weekWindow(nowMs);
    beds = null;
    applySeason(nowMs);
    renderGrid(nowMs);
    setSync('wait', '雲端確認中…');
    els('gardenReload').disabled = true;
    els('gardenSource').textContent = '雲端確認中…';
    els('gardenStatus').textContent = '雲端確認中：正在讀取你本人已完成的活動…';
    try {
      const result = await root.firebase.firestore().collection('activity_sessions')
        .where('actorUserId', '==', uid)
        .where('status', '==', 'completed')
        .where('endedAt', '>=', span.start)
        .where('endedAt', '<=', span.end)
        .orderBy('endedAt', 'desc')
        .limit(core.QUERY_LIMIT + 1)
        .get({ source: 'server' });
      if (token !== loadToken || uid !== currentUid) return;
      if (result.metadata?.fromCache || result.metadata?.hasPendingWrites) throw new Error('cache');
      const docs = result.docs.slice(0, core.QUERY_LIMIT);
      const rows = [];
      let invalid = 0;
      let ignored = 0;
      for (const item of docs) {
        const data = item.data();
        const parsed = core.parseSession(item.id, data, uid, nowMs);
        if (!parsed) { invalid += 1; continue; }
        if (parsed.ignored) { ignored += 1; continue; }
        if (!(await fingerprintMatches(item.id, data.activityFingerprint))) { invalid += 1; continue; }
        rows.push(parsed.row);
      }
      if (token !== loadToken || uid !== currentUid) return;
      beds = core.grow(rows, span.weeks);
      renderGrid(nowMs);
      const grown = beds.flatMap(b => b.plots).filter(p => p.stage > 0).length;
      const truncated = result.docs.length > core.QUERY_LIMIT;
      setSync('ok', '✓ 雲端已確認');
      els('gardenStatus').textContent = grown
        ? `花園裡有 ${grown} 株植物，全部來自你雲端確認的行動。`
        : '最近 6 週還沒有雲端確認的專注、運動、睡眠或步數紀錄，花圃還是空土。完成一次行動後再回來看看。';
      els('gardenSource').textContent = `來源：你本人 status=completed 的活動紀錄，${core.weekRange(span.weeks[0]).split('–')[0]} 起共 ${docs.length} 筆。`
        + `任務與自訂活動不長植物（${ignored} 筆）；格式不符未計入 ${invalid} 筆。`
        + (truncated ? '紀錄超過 500 筆，只計最新 500 筆，最早幾週可能比實際矮。' : '')
        + '一週從週一清晨 5:00（台北）開始。';
    } catch (_) {
      if (token !== loadToken || uid !== currentUid) return;
      beds = null;
      renderGrid(nowMs);
      setSync('alert', '尚未確認');
      els('gardenStatus').textContent = '暫時無法從雲端確認你的活動，花園先不長植物。請確認網路後按「重新讀取」。';
      els('gardenSource').textContent = '尚未取得雲端資料。';
    } finally {
      if (token === loadToken) els('gardenReload').disabled = false;
    }
  }

  function applyUser(uid, data) {
    const gate = core.access(data?.avatarLevel);
    els('gardenLevel').textContent = `Lv ${gate.level}`;
    if (!gate.unlocked) {
      unlocked = false;
      ++loadToken;
      closeDialog();
      els('gardenLockedText').textContent = gate.reason;
      els('gardenStatus').textContent = '花園尚未開放';
      show('locked');
      return;
    }
    show('scene');
    if (unlocked) return;
    unlocked = true;
    loadSessions(uid);
  }

  function start() {
    if (started || !root.firebase?.apps?.length) return;
    started = true;
    root.firebase.auth().onAuthStateChanged(user => {
      const own = ++generation;
      ++loadToken;
      unsubscribeUser?.();
      unsubscribeUser = null;
      unlocked = false;
      beds = null;
      currentUid = user ? user.uid : null;
      closeDialog();
      show(null);
      if (!user) {
        els('gardenStatus').textContent = '請先登入，花園只顯示你自己的行動。';
        return;
      }
      els('gardenStatus').textContent = '正在確認你的角色等級…';
      unsubscribeUser = root.firebase.firestore().collection('users').doc(user.uid)
        .onSnapshot(snap => {
          if (own !== generation) return;
          applyUser(user.uid, snap.exists ? snap.data() : null);
        }, () => {
          if (own !== generation) return;
          show(null);
          els('gardenStatus').textContent = '暫時無法讀取角色等級，請確認網路後重新整理。';
        });
    });
  }

  renderLegend();
  els('gardenGrid').addEventListener('keydown', onGridKey);
  els('gardenReload').addEventListener('click', () => { if (currentUid && unlocked) loadSessions(currentUid); });
  els('gardenDialogClose').addEventListener('click', closeDialog);
  els('gardenWater').addEventListener('click', water);
  els('gardenDialog').addEventListener('click', event => { if (event.target === els('gardenDialog')) closeDialog(); });
  doc.addEventListener('keydown', trapFocus);
  doc.addEventListener('firebase-ready', start);
  root.addEventListener('pagehide', () => { ++generation; ++loadToken; unsubscribeUser?.(); unsubscribeUser = null; });
  start();
})(typeof globalThis !== 'undefined' ? globalThis : this);
