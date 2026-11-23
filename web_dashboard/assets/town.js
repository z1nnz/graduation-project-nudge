(function(root) {
  'use strict';
  // Nudge companion town: a walkable pixel map where each building opens an
  // existing Web feature. Rules live in town_core.js; this file draws and
  // handles input. Nothing here writes rewards: break-game scores stay local.
  const core = root.NudgeTownCore;
  const gameCore = root.NudgeTownGameCore;
  const doc = root.document;
  if (!core || !gameCore || !doc || doc.body?.dataset.page !== 'town') return;

  const MAP_W = 1672;
  const MAP_H = 941;
  const n = (x, y) => ({ x: Math.round(x * MAP_W), y: Math.round(y * MAP_H) });
  const r = (x, y, w, h) => ({ x: x * MAP_W, y: y * MAP_H, w: w * MAP_W, h: h * MAP_H });

  // Positions measured on assets/town/town_map.jpg (0-1 of width/height).
  // `login: true` marks pages whose own guard (app.js) asks guests to sign in;
  // the town only labels that honestly and never bypasses the guard.
  const BUILDINGS = [
    { id: 'cabin', name: '你的小屋', desc: '夥伴與家具', href: 'personal.html', login: true, rect: r(0.04, 0.37, 0.165, 0.18), door: n(0.165, 0.585), label: n(0.12, 0.35) },
    { id: 'board', name: '委託告示板', desc: '今天的小目標', href: 'dashboard.html', rect: r(0.29, 0.405, 0.075, 0.12), door: n(0.327, 0.555), label: n(0.327, 0.39) },
    { id: 'tower', name: '專注塔', desc: '自律房，一起專注', href: 'rooms.html', login: true, rect: r(0.42, 0.06, 0.055, 0.25), door: n(0.447, 0.345), label: n(0.447, 0.05) },
    { id: 'family', name: '家庭庭院', desc: '家庭連結與共同目標', href: 'guardian.html', login: true, rect: r(0.045, 0.14, 0.245, 0.17), door: n(0.18, 0.345), label: n(0.17, 0.12) },
    { id: 'guild', name: '團體會館', desc: '團體挑戰與成員', href: 'groups.html', login: true, rect: r(0.55, 0.11, 0.205, 0.22), door: n(0.648, 0.365), label: n(0.652, 0.09) },
    { id: 'library', name: '紀錄館', desc: '統計與每週回顧', href: 'personal-trends.html', login: true, rect: r(0.78, 0.34, 0.2, 0.2), door: n(0.875, 0.585), label: n(0.88, 0.31) },
    { id: 'store', name: '雜貨店', desc: '角色與家具商城', href: 'profile.html', login: true, rect: r(0.13, 0.63, 0.155, 0.16), door: n(0.205, 0.82), label: n(0.205, 0.6) },
    { id: 'park', name: '遊樂園', desc: '用休息券玩小遊戲', game: true, rect: r(0.6, 0.62, 0.2, 0.15), door: n(0.6, 0.79), label: n(0.7, 0.58) },
    { id: 'observatory', name: '天文台', desc: 'Orbit 與 Station 裝置', href: 'personal-focus.html', login: true, rect: r(0.845, 0.04, 0.14, 0.2), door: n(0.93, 0.28), label: n(0.915, 0.03) },
    { id: 'garden', name: '星光花園', desc: '更高等級開放', minLevel: 10, rect: r(0.745, 0.72, 0.255, 0.28), door: n(0.88, 0.92), label: n(0.86, 0.7) },
  ];
  const BOUNDS = { x: 10, y: 0.22 * MAP_H, w: MAP_W - 20, h: 0.76 * MAP_H };
  const START = n(0.475, 0.66);
  const SPEED = 150;
  const RADIUS = 10;
  const REACH = 46;

  const TOUR = [
    { at: null, text: '歡迎來到 Nudge 夥伴小鎮！我是館長歐莉。用 WASD 或方向鍵走路，也可以直接點地面；走到建築旁按 F，或直接點建築就能進去。' },
    { at: 'cabin', text: '這是你的小屋，夥伴住在這裡。你在 App 完成的真實行動，會讓書櫃、盆栽和徽章慢慢長出來。' },
    { at: 'board', text: '委託告示板寫著今天的小目標。只要做一件小事，就是很好的開始。' },
    { at: 'tower', text: '專注塔裡是自律房。大家各自開始自己的專注，坐在一起就不孤單。' },
    { at: 'family', text: '家庭庭院和團體會館是和家人、夥伴一起前進的地方。分享什麼，永遠由你自己決定。' },
    { at: 'park', text: '遊樂園要用休息券才能玩。每完成一次 25 分鐘以上、由雲端確認的專注，就能拿到一張。' },
    { at: 'garden', text: '星光花園還鎖著。角色升到 10 級就會開放，升級是有意義的！' },
    { at: null, text: '導覽結束！右上角的問號可以再看一次。祝你今天也穩穩前進。' },
  ];

  const els = id => doc.getElementById(id);
  const canvas = els('townCanvas');
  let ctx = null;
  try { ctx = canvas.getContext ? canvas.getContext('2d') : null; } catch { ctx = null; }
  const reducedMotion = root.matchMedia?.('(prefers-reduced-motion: reduce)').matches;
  const store = {
    get(key) { try { return root.localStorage.getItem(key); } catch { return null; } },
    set(key, value) { try { root.localStorage.setItem(key, value); } catch { /* private mode */ } },
  };

  const state = {
    player: { ...START },
    target: null,
    pendingBuilding: null,
    keys: new Set(),
    camera: { ...START },
    zoom: 1,
    level: 1,
    uid: null,
    receipts: [],
    tour: -1,
    near: null,
    face: 0,
    walking: 0,
    toastUntil: 0,
    static: false,
  };

  const mapImage = new Image();
  mapImage.addEventListener('error', () => enterStatic('小鎮地圖載入失敗'));
  mapImage.src = 'assets/town/town_map.jpg';
  const playerImage = new Image();
  playerImage.src = 'assets/avatar/characters/character_0.png';
  // Character art has wide transparent margins; draw only the visible box.
  let playerCrop = null;
  playerImage.addEventListener('load', () => {
    try {
      const c = doc.createElement('canvas');
      c.width = playerImage.naturalWidth;
      c.height = playerImage.naturalHeight;
      const g = c.getContext('2d');
      g.drawImage(playerImage, 0, 0);
      const { data, width, height } = g.getImageData(0, 0, c.width, c.height);
      let minX = width, minY = height, maxX = 0, maxY = 0;
      for (let y = 0; y < height; y += 2) {
        for (let x = 0; x < width; x += 2) {
          if (data[(y * width + x) * 4 + 3] > 20) {
            if (x < minX) minX = x; if (x > maxX) maxX = x;
            if (y < minY) minY = y; if (y > maxY) maxY = y;
          }
        }
      }
      playerCrop = maxX > minX ? { x: minX, y: minY, w: maxX - minX + 2, h: maxY - minY + 2 } : null;
    } catch { playerCrop = null; }
  });

  // ---------- labels and directory ----------
  const labels = new Map();
  const entries = new Map();
  for (const b of BUILDINGS) {
    const el = doc.createElement('div');
    el.className = 'town-label';
    const title = doc.createElement('strong');
    title.textContent = b.name;
    el.append(title, doc.createElement('span'));
    els('townLabels').appendChild(el);
    labels.set(b.id, el);
    const li = doc.createElement('li');
    const link = doc.createElement('a');
    link.href = b.href || '#';
    link.dataset.building = b.id;
    const name = doc.createElement('strong');
    name.textContent = b.name;
    const desc = doc.createElement('span');
    desc.textContent = b.desc;
    const note = doc.createElement('em');
    link.append(name, desc, note);
    link.addEventListener('click', event => { event.preventDefault(); enter(b); });
    li.appendChild(link);
    els('townDirectoryList').appendChild(li);
    entries.set(b.id, note);
  }
  /** Honest status for the list: lock level, sign-in need or ticket need. */
  function entryNote(b) {
    if (!core.isUnlocked(b, state.level)) return `Lv ${b.minLevel} 開放`;
    if (b.game) return state.uid ? '需要休息券' : '登入後可用休息券';
    if (b.login && !state.uid) return '進入時需要登入';
    return '';
  }
  function refreshLabels() {
    for (const b of BUILDINGS) {
      const unlocked = core.isUnlocked(b, state.level);
      const el = labels.get(b.id);
      el.classList.toggle('is-locked', !unlocked);
      el.querySelector('span').textContent = unlocked ? b.desc : `Lv ${b.minLevel} 解鎖`;
      const note = entries.get(b.id);
      note.textContent = entryNote(b);
      note.hidden = !note.textContent;
    }
  }

  // ---------- building list (touch fallback and static mode) ----------
  const directory = els('townDirectory');
  const listToggle = els('townListToggle');
  function setDirectory(open, { focus = true } = {}) {
    const show = open || state.static;
    directory.classList.toggle('is-open', show);
    listToggle.setAttribute('aria-expanded', String(show));
    if (!focus) return;
    if (show) directory.querySelector('a')?.focus({ preventScroll: true });
    else listToggle.focus({ preventScroll: true });
  }
  listToggle.addEventListener('click', () => setDirectory(!directory.classList.contains('is-open')));
  els('townDirectoryClose').addEventListener('click', () => setDirectory(false));

  /** Canvas or map art unavailable: keep the town usable as a plain list. */
  function enterStatic(reason) {
    if (state.static) return;
    state.static = true;
    doc.body.classList.add('town-static');
    state.tour = -1;
    els('townDialog').hidden = true;
    els('townPrompt').hidden = true;
    const note = els('townDirectoryNote');
    note.hidden = false;
    note.textContent = `${reason}，可以直接從下面的清單進入各建築。`;
    setDirectory(true, { focus: false });
  }

  // ---------- view math ----------
  function baseFit() {
    return Math.max(canvas.clientHeight / (MAP_H * 0.62), canvas.clientWidth / MAP_W);
  }
  function scale() { return baseFit() * state.zoom; }
  /** Smallest zoom that still covers the screen, so no empty band shows. */
  function minZoom() {
    const fit = baseFit();
    if (!fit) return 1;
    return Math.min(1, Math.max(canvas.clientWidth / MAP_W, canvas.clientHeight / MAP_H) / fit);
  }
  function setZoom(z) { state.zoom = Math.min(1.8, Math.max(minZoom(), z)); }
  function toScreen(p) {
    const s = scale();
    return { x: (p.x - state.camera.x) * s + canvas.clientWidth / 2, y: (p.y - state.camera.y) * s + canvas.clientHeight / 2 };
  }
  function toMap(x, y) {
    const s = scale();
    return { x: (x - canvas.clientWidth / 2) / s + state.camera.x, y: (y - canvas.clientHeight / 2) / s + state.camera.y };
  }
  function clampCamera(p) {
    const s = scale();
    const halfW = canvas.clientWidth / s / 2;
    const halfH = canvas.clientHeight / s / 2;
    return {
      x: Math.min(Math.max(p.x, halfW), Math.max(halfW, MAP_W - halfW)),
      y: Math.min(Math.max(p.y, halfH), Math.max(halfH, MAP_H - halfH)),
    };
  }

  let labelTop = 64;
  let zoomTouched = false;
  function resize() {
    if (!ctx) return;
    const dpr = Math.min(root.devicePixelRatio || 1, 2);
    canvas.width = Math.round(canvas.clientWidth * dpr);
    canvas.height = Math.round(canvas.clientHeight * dpr);
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    // Phones start zoomed out so nearby buildings are on screen.
    if (!zoomTouched) state.zoom = canvas.clientWidth < 560 ? minZoom() : 1;
    else setZoom(state.zoom);
    const tools = doc.querySelector('.town-hud-tools')?.getBoundingClientRect?.();
    labelTop = Math.max(64, (tools?.bottom || 0) + 36);
  }

  // ---------- interaction ----------
  function toast(text, ms = 3200) {
    const el = els('townToast');
    el.textContent = text;
    el.hidden = false;
    state.toastUntil = performance.now() + ms;
  }

  function enter(b) {
    if (!core.isUnlocked(b, state.level)) {
      toast(`${b.name}要角色 Lv ${b.minLevel} 才會開放，繼續累積真實行動吧！`);
      return;
    }
    if (b.game) { openGame(); return; }
    toast(`正在進入${b.name}…`);
    root.location.href = b.href;
  }

  function buildingAt(p) {
    return BUILDINGS.find(b => p.x >= b.rect.x && p.x <= b.rect.x + b.rect.w && p.y >= b.rect.y && p.y <= b.rect.y + b.rect.h) || null;
  }

  canvas.addEventListener('pointerdown', event => {
    if (state.tour >= 0 || !els('townGame').hidden) return;
    const rect = canvas.getBoundingClientRect();
    const p = toMap(event.clientX - rect.left, event.clientY - rect.top);
    const b = buildingAt(p);
    if (b && reducedMotion) {
      // No walking animation: arrive at the door and enter in one step.
      state.player = { ...b.door };
      state.target = null;
      state.pendingBuilding = null;
      enter(b);
    } else if (b) {
      state.target = { ...b.door };
      state.pendingBuilding = b;
      toast(`走向${b.name}…`, 1600);
    } else {
      state.target = p;
      state.pendingBuilding = null;
    }
  });

  doc.addEventListener('keydown', event => {
    if (event.target?.closest?.('input, textarea')) return;
    const key = event.key.toLowerCase();
    if (key === 'escape' && directory.classList.contains('is-open') && !state.static) {
      setDirectory(false);
      return;
    }
    if (state.static) return;
    if (state.tour >= 0) {
      if (key === ' ' || key === 'enter') { event.preventDefault(); nextTour(); }
      if (key === 'escape') endTour();
      return;
    }
    if (!els('townGame').hidden) {
      if (key === 'escape' || key === 'p') { event.preventDefault(); toggleGamePause(); }
      else if (['a', 'd', 'arrowleft', 'arrowright'].includes(key)) {
        event.preventDefault();
        if (game.running) state.keys.add(key);
      }
      return;
    }
    if (['w', 'a', 's', 'd', 'arrowup', 'arrowdown', 'arrowleft', 'arrowright'].includes(key)) {
      event.preventDefault();
      state.keys.add(key);
      state.target = null;
      state.pendingBuilding = null;
    }
    const onMap = !event.target || event.target === doc.body || event.target === canvas;
    if (state.near && (key === 'f' || (key === 'enter' && onMap))) enter(state.near);
  });
  doc.addEventListener('keyup', event => state.keys.delete(event.key.toLowerCase()));
  root.addEventListener('blur', () => { state.keys.clear(); if (game.running) toggleGamePause(); });
  doc.addEventListener('visibilitychange', () => { if (doc.hidden && game.running) toggleGamePause(); });

  els('townPromptEnter').addEventListener('click', () => state.near && enter(state.near));
  els('townZoomIn').addEventListener('click', () => { zoomTouched = true; setZoom(state.zoom + 0.2); });
  els('townZoomOut').addEventListener('click', () => { zoomTouched = true; setZoom(state.zoom - 0.2); });
  els('townHelp').addEventListener('click', startTour);

  // ---------- guided tour ----------
  function showTourStep() {
    const step = TOUR[state.tour];
    els('townDialog').hidden = false;
    els('townDialogText').textContent = step.text;
    els('townDialogStep').textContent = `${state.tour + 1} / ${TOUR.length}`;
    els('townDialogNext').focus({ preventScroll: true });
  }
  function startTour() { if (state.static) return; state.tour = 0; state.keys.clear(); state.target = null; showTourStep(); }
  function nextTour() { if (state.tour + 1 >= TOUR.length) endTour(); else { state.tour += 1; showTourStep(); } }
  function endTour() {
    state.tour = -1;
    els('townDialog').hidden = true;
    store.set('nudge_town_tour_done', '1');
  }
  els('townDialogNext').addEventListener('click', nextTour);
  els('townDialogSkip').addEventListener('click', endTour);

  // ---------- break tickets ----------
  function usedKey() { return `nudge_town_used_tickets_${state.uid || 'guest'}`; }
  function usedTickets() { try { return JSON.parse(store.get(usedKey()) || '[]'); } catch { return []; } }
  function tickets() { return core.breakTickets(state.receipts, Date.now(), usedTickets()); }
  function refreshTicket() {
    const list = tickets();
    const el = els('townTicket');
    el.hidden = list.length === 0;
    el.textContent = list.length ? `休息券 ×${list.length}（${list[0].minutes} 分鐘）` : '';
  }

  // ---------- catch-the-stars break game ----------
  const game = { running: false, paused: false, end: 0, started: 0, pausedTotal: 0,
    pauseStarted: 0, score: 0, combo: 0, x: 0.5, stars: [], clouds: [], last: 0,
    lastHudSecond: -1, lastHudScore: -1, lastHudCombo: -1, ticket: null };
  const gameCanvas = els('townGameCanvas');
  let gctx = null;
  try { gctx = gameCanvas.getContext ? gameCanvas.getContext('2d') : null; } catch { gctx = null; }
  function resizeGameCanvas() {
    if (!gctx) return;
    const dpr = Math.min(root.devicePixelRatio || 1, 2);
    gameCanvas.width = Math.round(gameCanvas.clientWidth * dpr);
    gameCanvas.height = Math.round(gameCanvas.clientHeight * dpr);
    gctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  }
  root.addEventListener('resize', () => { if (!els('townGame').hidden) resizeGameCanvas(); });
  function openGame() {
    if (!state.uid) { toast('登入後完成一次專注，就能拿到休息券。'); return; }
    if (!gctx) { toast('這個瀏覽器無法顯示小遊戲。'); return; }
    const list = tickets();
    if (!list.length) { toast('還沒有休息券。完成一次 25 分鐘以上、由雲端確認的專注，就能來玩。'); return; }
    game.ticket = list[0];
    store.set(usedKey(), JSON.stringify([...usedTickets(), game.ticket.receiptId].slice(-20)));
    refreshTicket();
    els('townGame').hidden = false;
    resizeGameCanvas();
    const now = performance.now();
    Object.assign(game, { running: true, paused: false, end: now + game.ticket.minutes * 60000,
      started: now, pausedTotal: 0, pauseStarted: 0, score: 0, combo: 0, x: 0.5,
      stars: [], clouds: [], last: now, lastHudSecond: -1, lastHudScore: -1, lastHudCombo: -1 });
    els('townGamePause').textContent = '暫停 Esc';
    els('townGamePause').setAttribute('aria-pressed', 'false');
    els('townGameCombo').textContent = '連續 0';
    els('townGameHint').textContent = '左右鍵、A/D、滑鼠或手指拖曳移動。連續接到五顆星會有加分，Esc 可暫停。遊戲分數不換自律幣或經驗值。';
    els('townGamePause').focus({ preventScroll: true });
  }
  function toggleGamePause() {
    if (els('townGame').hidden) return;
    const now = performance.now();
    if (game.running) {
      game.running = false;
      game.paused = true;
      game.pauseStarted = now;
      state.keys.clear();
      els('townGamePause').textContent = '繼續 Esc';
      els('townGamePause').setAttribute('aria-pressed', 'true');
      els('townGameHint').textContent = '已暫停。按 Esc 或「繼續」再回到遊戲。';
    } else if (game.paused) {
      game.end = gameCore.resumeDeadline(game.end, game.pauseStarted, now);
      game.pausedTotal += Math.max(0, now - game.pauseStarted);
      game.last = now;
      game.running = true;
      game.paused = false;
      els('townGamePause').textContent = '暫停 Esc';
      els('townGamePause').setAttribute('aria-pressed', 'false');
      els('townGameHint').textContent = '左右鍵、A/D、滑鼠或手指拖曳移動。連續接到五顆星會有加分，Esc 可暫停。遊戲分數不換自律幣或經驗值。';
    }
  }
  function closeGame() {
    if (!game.running && els('townGame').hidden) return;
    game.running = false;
    game.paused = false;
    els('townGame').hidden = true;
    const best = Number(store.get(`nudge_town_best_${state.uid}`) || 0);
    if (game.score > best) store.set(`nudge_town_best_${state.uid}`, String(game.score));
    toast(`休息結束！這次得到 ${game.score} 分。回到下一個委託吧。`, 4500);
  }
  els('townGamePause').addEventListener('click', toggleGamePause);
  els('townGameClose').addEventListener('click', closeGame);
  function moveGamePointer(event) {
    if (!game.running) return;
    const rect = gameCanvas.getBoundingClientRect();
    game.x = Math.min(0.95, Math.max(0.05, (event.clientX - rect.left) / rect.width));
  }
  gameCanvas.addEventListener('pointerdown', event => {
    event.preventDefault();
    gameCanvas.setPointerCapture?.(event.pointerId);
    moveGamePointer(event);
  });
  gameCanvas.addEventListener('pointermove', moveGamePointer);
  function tickGame(now) {
    const dt = Math.min(0.05, (now - game.last) / 1000);
    game.last = now;
    const w = gameCanvas.clientWidth;
    const h = gameCanvas.clientHeight;
    if (state.keys.has('arrowleft') || state.keys.has('a')) game.x = Math.max(0.05, game.x - dt * 0.9);
    if (state.keys.has('arrowright') || state.keys.has('d')) game.x = Math.min(0.95, game.x + dt * 0.9);
    const elapsed = (now - game.started - game.pausedTotal) / 1000;
    const rates = gameCore.spawnRates(elapsed);
    if (Math.random() < dt * rates.stars) game.stars.push({ x: Math.random(), y: -0.05, v: 0.25 + Math.random() * 0.2 });
    if (Math.random() < dt * rates.clouds) game.clouds.push({ x: Math.random(), y: -0.05, v: 0.2 + Math.random() * 0.15 });
    const catchY = 0.86;
    for (const s of game.stars) s.y += s.v * dt;
    for (const c of game.clouds) c.y += c.v * dt;
    game.stars = game.stars.filter(s => {
      if (s.y > catchY - 0.04 && s.y < catchY + 0.04 && Math.abs(s.x - game.x) < 0.08) {
        const result = gameCore.catchObject(game.score, game.combo, 'star');
        game.score = result.score; game.combo = result.combo;
        if (result.bonus) els('townGameHint').textContent = '五連星！多得 1 分。繼續保持節奏。';
        return false;
      }
      return s.y < 1.05;
    });
    game.clouds = game.clouds.filter(c => {
      if (c.y > catchY - 0.04 && c.y < catchY + 0.04 && Math.abs(c.x - game.x) < 0.09) {
        const result = gameCore.catchObject(game.score, game.combo, 'cloud');
        game.score = result.score; game.combo = result.combo;
        return false;
      }
      return c.y < 1.05;
    });
    gctx.clearRect(0, 0, w, h);
    gctx.font = `${Math.round(w * 0.06)}px sans-serif`;
    gctx.textAlign = 'center';
    gctx.fillStyle = '#ffcf5a';
    for (const s of game.stars) gctx.fillText('★', s.x * w, s.y * h);
    gctx.fillStyle = '#cfc6e8';
    for (const c of game.clouds) gctx.fillText('☁', c.x * w, c.y * h);
    const size = h * 0.16;
    if (playerImage.complete) {
      const crop = playerCrop || { x: 0, y: 0, w: playerImage.naturalWidth, h: playerImage.naturalHeight };
      const cw = size * crop.w / crop.h;
      gctx.drawImage(playerImage, crop.x, crop.y, crop.w, crop.h, game.x * w - cw / 2, catchY * h - size * 0.7, cw, size);
    }
    const left = Math.max(0, game.end - now);
    const second = Math.ceil(left / 1000);
    if (game.score !== game.lastHudScore || game.combo !== game.lastHudCombo || second !== game.lastHudSecond) {
      els('townGameScore').textContent = `${game.score} 分`;
      els('townGameCombo').textContent = `連續 ${game.combo}`;
      els('townGameTime').textContent = `${Math.floor(second / 60)}:${String(second % 60).padStart(2, '0')}`;
      game.lastHudSecond = second; game.lastHudScore = game.score; game.lastHudCombo = game.combo;
    }
    if (left <= 0) closeGame();
  }

  // ---------- main loop ----------
  function moveDirection() {
    let x = 0; let y = 0;
    if (state.keys.has('a') || state.keys.has('arrowleft')) x -= 1;
    if (state.keys.has('d') || state.keys.has('arrowright')) x += 1;
    if (state.keys.has('w') || state.keys.has('arrowup')) y -= 1;
    if (state.keys.has('s') || state.keys.has('arrowdown')) y += 1;
    if (x || y) { const len = Math.hypot(x, y); return { x: x / len, y: y / len }; }
    if (state.target) {
      const dir = core.directionTo(state.player, state.target, 4);
      if (dir) return dir;
      state.target = null;
      if (state.pendingBuilding) { const b = state.pendingBuilding; state.pendingBuilding = null; enter(b); }
    }
    return null;
  }

  let last = performance.now();
  function frame(now) {
    if (state.static || !ctx) return;
    const dt = Math.min(0.05, (now - last) / 1000);
    last = now;
    if (!els('townGame').hidden) { if (game.running) tickGame(now); root.requestAnimationFrame(frame); return; }

    const blockers = BUILDINGS.map(b => b.rect);
    const dir = state.tour < 0 ? moveDirection() : null;
    if (dir) {
      const before = state.player;
      state.player = core.step(state.player, dir, dt, SPEED, blockers, BOUNDS, RADIUS);
      if (dir.x) state.face = dir.x < 0 ? -1 : 1;
      state.walking += dt;
      if (state.target && Math.hypot(state.player.x - before.x, state.player.y - before.y) < 0.01) {
        state.target = null; // stuck against a wall
        if (state.pendingBuilding) { const b = state.pendingBuilding; state.pendingBuilding = null; enter(b); }
      }
    } else {
      state.walking = 0;
    }

    const tourStep = state.tour >= 0 ? TOUR[state.tour] : null;
    const focus = tourStep?.at ? BUILDINGS.find(b => b.id === tourStep.at).door : state.player;
    const goal = clampCamera(focus);
    const ease = reducedMotion ? 1 : Math.min(1, dt * 4);
    state.camera = { x: state.camera.x + (goal.x - state.camera.x) * ease, y: state.camera.y + (goal.y - state.camera.y) * ease };

    state.near = state.tour < 0 ? core.nearestDoor(state.player, BUILDINGS, REACH) : null;
    const prompt = els('townPrompt');
    prompt.hidden = !state.near;
    if (state.near) {
      els('townPromptText').textContent = core.isUnlocked(state.near, state.level)
        ? `按 F 進入${state.near.name}` : `${state.near.name}：Lv ${state.near.minLevel} 開放`;
    }

    const w = canvas.clientWidth;
    const h = canvas.clientHeight;
    const s = scale();
    ctx.imageSmoothingEnabled = false;
    ctx.fillStyle = '#1b1530';
    ctx.fillRect(0, 0, w, h);
    if (mapImage.complete) {
      const origin = toScreen({ x: 0, y: 0 });
      ctx.drawImage(mapImage, origin.x, origin.y, MAP_W * s, MAP_H * s);
    }
    if (playerImage.complete && playerImage.naturalWidth) {
      const p = toScreen(state.player);
      const crop = playerCrop || { x: 0, y: 0, w: playerImage.naturalWidth, h: playerImage.naturalHeight };
      const ph = 44 * s;
      const pw = ph * crop.w / crop.h;
      const bob = reducedMotion ? 0 : Math.abs(Math.sin(state.walking * 10)) * 3 * s;
      ctx.fillStyle = 'rgba(0,0,0,0.25)';
      ctx.beginPath();
      ctx.ellipse(p.x, p.y, pw * 0.35, ph * 0.07, 0, 0, Math.PI * 2);
      ctx.fill();
      ctx.save();
      ctx.translate(p.x, p.y - bob);
      if (state.face < 0) ctx.scale(-1, 1);
      ctx.drawImage(playerImage, crop.x, crop.y, crop.w, crop.h, -pw / 2, -ph, pw, ph);
      ctx.restore();
    }
    for (const b of BUILDINGS) {
      const p = toScreen(b.label);
      const el = labels.get(b.id);
      el.style.left = `${p.x}px`;
      el.style.top = `${Math.max(labelTop, p.y)}px`;
      el.classList.toggle('is-near', state.near === b);
    }
    if (state.toastUntil && now > state.toastUntil) { els('townToast').hidden = true; state.toastUntil = 0; }
    root.requestAnimationFrame(frame);
  }

  // ---------- clock ----------
  function tickClock() {
    const d = new Date();
    els('townClock').textContent = `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
  }

  // ---------- account data (read-only) ----------
  function applyUser(user, data) {
    state.uid = user?.uid || null;
    state.level = Math.max(1, Number(data?.avatarLevel) || 1);
    const face = Number(data?.avatarProfile?.faceShapeIndex);
    const sprite = `assets/avatar/characters/character_${Number.isInteger(face) && face >= 0 ? face : 0}.png`;
    if (!playerImage.src.endsWith(sprite)) playerImage.src = sprite;
    els('townAvatar').src = sprite;
    els('townName').textContent = user ? (data?.nickname || '自律夥伴') : '訪客';
    // Guests see no level, XP or sync status: there is no account data to show.
    els('townLevel').textContent = user ? `Lv ${state.level}` : '自由探索中';
    refreshLabels();
    refreshTicket();
  }
  function connect() {
    const fb = root.firebase;
    if (!fb?.apps?.length) return;
    let unsubUser = null;
    let unsubReceipts = null;
    fb.auth().onAuthStateChanged(user => {
      unsubUser?.();
      unsubReceipts?.();
      state.receipts = [];
      applyUser(user, null);
      if (!user) return;
      unsubUser = fb.firestore().collection('users').doc(user.uid)
        .onSnapshot(snap => applyUser(user, snap.exists ? snap.data() : null), () => {});
      unsubReceipts = fb.firestore().collection('activity_receipts')
        .where('actorUserId', '==', user.uid).orderBy('verifiedAt', 'desc').limit(10)
        .onSnapshot(snap => {
          state.receipts = snap.docs.map(d => ({ receiptId: d.id, ...d.data() }))
            .filter(d => root.NudgeConfirmedActivityFeedback?.parse(d.receiptId, d, user.uid));
          refreshTicket();
        }, () => {});
    });
  }

  root.addEventListener('resize', resize);
  doc.addEventListener('firebase-ready', connect);
  if (!ctx) enterStatic('這個瀏覽器無法顯示小鎮地圖');
  resize();
  if (ctx) state.camera = clampCamera(state.player);
  refreshLabels();
  tickClock();
  root.setInterval(tickClock, 15000);
  root.setInterval(refreshTicket, 60000);
  if (store.get('nudge_town_tour_done') !== '1') startTour();
  if (ctx) root.requestAnimationFrame(frame);
})(typeof globalThis !== 'undefined' ? globalThis : this);
