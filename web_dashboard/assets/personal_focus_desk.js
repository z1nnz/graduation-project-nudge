(function (root) {
  'use strict';
  // Focus desk (J8) on personal-focus.html: the companion sits at the desk
  // and reads, turning pages, while a pixel hourglass on the desk runs out
  // with the timer; on completion it cheers and rewards fly out of the book;
  // then the hourglass flips for the break while it stretches, has tea and
  // looks out of the window. Reads the page's own timer; writes nothing.
  const doc = root.document;
  const room = root.NudgePageRoom;
  if (!doc || !room || !root.NudgeWorldLife || (doc.body.dataset.roomKey || doc.body.dataset.page) !== 'focus') return;
  const reduced = () => root.matchMedia('(prefers-reduced-motion: reduce)').matches;
  const els = id => doc.getElementById(id);

  const DESK = {
    tall: { seat: [0.6, 0.66], glass: [0.7, 0.385, 0.07, 0.065], book: [0.47, 0.44, 0.1, 0.04], window: [0.5, 0.62] },
    wide: { seat: [0.5, 0.74], glass: [0.6, 0.43, 0.035, 0.08], book: [0.47, 0.5, 0.06, 0.04], window: [0.5, 0.72] },
  };
  const D = () => DESK[room.layout()] || DESK.tall;
  const life = root.NudgeWorldLife.attach(room, {
    layouts: {
      tall: { rects: { shelf: [0.12, 0.29, 0.25, 0.27], window: [0.31, 0.08, 0.38, 0.21] }, start: DESK.tall.seat, skyRect: [0.3, 0.05, 0.4, 0.19], floor: [0.62, 0.9],
        near: { fall: 'dust', count: 14, plants: [{ x: 0.02, y: 0, size: 0.12, kind: 'ivy' }] } },
      wide: { rects: { shelf: [0.23, 0.34, 0.14, 0.36], window: [0.39, 0.1, 0.23, 0.26] }, start: DESK.wide.seat, skyRect: [0.38, 0.09, 0.26, 0.26], floor: [0.7, 0.94],
        near: { fall: 'dust', count: 18, plants: [{ x: 0.01, y: 0, size: 0.14, kind: 'ivy' }] } },
    },
    acts: { shelf: { face: 'up', anim: 'read', fx: 'pull', sfx: 'page' }, window: { face: 'up', anim: 'look', fx: 'pop', sfx: 'tap' } },
  });
  const player = () => life.player();

  // ---- the hourglass on the desk ----
  const glass = doc.createElement('canvas');
  glass.className = 'fd-glass';
  glass.width = 14; glass.height = 22;
  glass.setAttribute('role', 'img');
  room.frame.append(glass);
  function place() {
    const r = D().glass;
    Object.assign(glass.style, { left: r[0] * 100 + '%', top: r[1] * 100 + '%', width: r[2] * 100 + '%', height: r[3] * 100 + '%' });
  }
  function drawGlass(left, flipped, f) {
    const g = glass.getContext('2d');
    if (!g) return;
    g.clearRect(0, 0, 14, 22);
    g.fillStyle = '#8a5a34'; g.fillRect(0, 0, 14, 2); g.fillRect(0, 20, 14, 2);
    g.fillStyle = '#3a2216'; g.fillRect(1, 2, 1, 18); g.fillRect(12, 2, 1, 18);
    g.fillStyle = 'rgba(190,220,255,0.55)';
    for (let y = 2; y < 20; y++) { const w = Math.max(1, Math.round(5 * Math.abs(y - 11) / 9)); g.fillRect(7 - w, y, w * 2, 1); }
    const top = flipped ? 1 - left : left;
    g.fillStyle = '#ffc54d';
    const upRows = Math.round(8 * top), downRows = Math.round(8 * (1 - top));
    for (let k = 0; k < upRows; k++) { const y = 10 - k; const w = Math.max(1, Math.round(5 * Math.abs(y - 11) / 9)); g.fillRect(7 - w, y, w * 2, 1); }
    for (let k = 0; k < downRows; k++) { const y = 19 - k; const w = Math.max(1, Math.round(5 * Math.abs(y - 11) / 9)); g.fillRect(7 - w, y, w * 2, 1); }
    if (top > 0 && top < 1 && !reduced() && f % 2) { g.fillRect(6, 11, 1, 8 - downRows); }
    glass.setAttribute('aria-label', `沙漏：${flipped ? '休息' : '專注'}還剩 ${Math.round(left * 100)}%`);
  }
  glass.classList.toggle('is-flipped', false);

  // ---- follow the page's timer ----
  const parse = t => { const m = String(t || '').match(/(\d+):(\d\d)/); return m ? Number(m[1]) * 60 + Number(m[2]) : 0; };
  let total = parse(els('focusTimerDisplay')?.textContent) || 1500;
  let mode = 'ready', breakLeft = 0, breakTotal = 0, lastDisplay = '', f = 0;
  function setMode(next) {
    if (next === mode) return;
    mode = next;
    room.stage.dataset.focus = mode;
    const p = player();
    if (!p) return;
    if (mode === 'focus') { life.walkTo(D().seat, { face: 'up' }).then(() => p.play('read')); }
    else if (mode === 'paused') p.play('sit');
    else if (mode === 'done') celebrate();
    else if (mode === 'break') breakActs();
    else p.play('idle');
  }
  function celebrate() {
    const p = player();
    p?.play('happy', { onEnd: () => p.play('wave') });
    life.emote('player', 'star');
    root.NudgeSfx?.play('sparkle');
    const b = D().book;
    if (!reduced()) {
      for (let i = 0; i < 10; i++) {
        const s = doc.createElement('i');
        s.className = 'fd-reward';
        s.textContent = i % 3 ? '★' : '◆';
        Object.assign(s.style, { left: (b[0] + b[2] / 2) * 100 + '%', top: b[1] * 100 + '%', animationDelay: `${i * 70}ms` });
        s.style.setProperty('--fd-dx', `${(i - 5) * 14}px`);
        room.frame.append(s);
        s.addEventListener('animationend', () => s.remove(), { once: true });
      }
    }
    const brk = Number(doc.querySelector('[data-focus-mins][aria-pressed="true"]')?.dataset.focusMins) === 50 ? 600 : 300;
    breakTotal = breakLeft = brk;
    root.setTimeout(() => { if (mode === 'done') setMode('break'); }, reduced() ? 0 : 2200);
  }
  function breakActs() {
    glass.classList.add('is-flipped');
    const p = player();
    const seq = ['stretch', 'snack', 'look'];
    let i = 0;
    const next = () => {
      if (mode !== 'break' || !p) return;
      const a = seq[i++ % seq.length];
      if (a === 'look') life.walkTo(D().window, { face: 'up' }).then(() => p.play('look'));
      else p.play(a, { onEnd: () => root.setTimeout(next, 600) });
      if (a === 'look') root.setTimeout(next, 8000);
    };
    next();
  }
  function poll() {
    const shown = els('focusTimerDisplay')?.textContent || '';
    const status = els('focusTimerStatus')?.textContent || '';
    const settled = els('focusSettlement');
    const secs = parse(shown);
    const running = /專注中/.test(status);
    if (shown !== lastDisplay) { if (!running && mode === 'ready') total = Math.max(1, secs); lastDisplay = shown; }
    if (running) { total = Math.max(total, secs); setMode('focus'); }
    else if (/暫停/.test(status)) setMode('paused');
    else if (settled && !settled.hidden && /完成/.test(settled.textContent)) { if (mode !== 'break') setMode('done'); }
    else if (mode !== 'break' && mode !== 'done') setMode('ready');
    if (mode === 'break') {
      breakLeft = Math.max(0, breakLeft - 0.25);
      if (breakLeft <= 0) { glass.classList.remove('is-flipped'); setMode('ready'); }
    }
    const left = mode === 'break' ? breakLeft / Math.max(1, breakTotal) : secs / Math.max(1, total);
    drawGlass(Math.max(0, Math.min(1, left)), mode === 'break', f++);
  }
  place();
  poll();
  // One rAF loop at 4 Hz; a hidden tab stops it until it is shown again.
  let raf = 0, lastPoll = 0;
  function loop(now) {
    raf = 0;
    if (doc.hidden) return;
    if (now - lastPoll >= 250) { lastPoll = now; poll(); }
    raf = root.requestAnimationFrame(loop);
  }
  const kick = () => { if (!raf && !doc.hidden) raf = root.requestAnimationFrame(loop); };
  doc.addEventListener('visibilitychange', kick);
  kick();
  root.addEventListener('resize', () => root.setTimeout(place, 140));
  root.NudgeFocusDesk = Object.freeze({ mode: () => mode, poll });
})(typeof globalThis !== 'undefined' ? globalThis : this);
