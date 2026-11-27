(function (root) {
  'use strict';
  // Two new park games (J6) on the arcade's session, ticket and record
  // rules (arcade.js): Firefly lanterns and Constellation. Pixel canvases at
  // native size, scaled with whole pixels; motion stops with reduced motion
  // (the game still plays, nothing drifts); hits spark, results stamp.
  const arcade = root.NudgeArcade;
  const core = root.NudgeArcadeMoreCore;
  const doc = root.document;
  if (!arcade || !core || !doc) return;
  const els = id => doc.getElementById(id);
  const FONT = '"Cubic11", "Noto Sans TC", sans-serif';

  function view(id, label, extra = '') {
    const stage = els('gameStage');
    let v = doc.querySelector(`.arcade-view[data-view="${id}"]`);
    if (!v) {
      v = doc.createElement('div');
      v.className = 'arcade-view';
      v.dataset.view = id;
      v.hidden = true;
      v.innerHTML = `<canvas class="arcade-canvas" width="320" height="180" tabindex="0" role="img" aria-label="${label}"></canvas>${extra}`;
      stage.insertBefore(v, els('gamePaused'));
    }
    return v;
  }
  function fit(canvas) {
    const avail = canvas.parentElement.clientWidth || 320;
    const k = Math.max(1, Math.floor(Math.min(avail / 320, (root.innerHeight - 200) / 180)));
    canvas.style.width = `${320 * k}px`;
    canvas.style.height = `${180 * k}px`;
    return k;
  }
  function toNative(canvas, e) {
    const r = canvas.getBoundingClientRect();
    return { x: ((e.clientX - r.left) / r.width) * 320, y: ((e.clientY - r.top) / r.height) * 180 };
  }
  function nightBg(g, t, still) {
    const bands = ['#160f2e', '#2a1d52', '#3a2766', '#4a2f6e'];
    bands.forEach((c, i) => { g.fillStyle = c; g.fillRect(0, i * 30, 320, 31); });
    for (let i = 0; i < 40; i++) {
      if (!still && (Math.floor(t / 400) + i) % 11 === 0) continue;
      g.fillStyle = i % 5 ? '#f6f0ff' : '#ffe7a8';
      g.fillRect((i * 73) % 320, (i * 37) % 110, 1, 1);
    }
    g.fillStyle = '#2b2050';
    for (let x = 0; x < 320; x++) g.fillRect(x, 120 - Math.round(6 + 4 * Math.sin(x / 23) + 2 * Math.sin(x / 7)), 1, 60);
    g.fillStyle = '#1f3a2a';
    g.fillRect(0, 150, 320, 30);
    for (let x = 0; x < 320; x += 3) {
      const sway = still ? 0 : Math.round(Math.sin(t / 500 + x) * 1);
      g.fillRect(x + sway, 146 - (x * 7) % 5, 1, 6);
    }
  }
  const sparks = [];
  function spark(x, y, color = '#ffe36b', n = 8) {
    for (let i = 0; i < n; i++) sparks.push({ x, y, vx: Math.cos(i * 0.785) * (1 + (i % 3)), vy: Math.sin(i * 0.785) * (1 + (i % 3)) - 1, life: 14, color });
  }
  function drawSparks(g) {
    for (let i = sparks.length - 1; i >= 0; i--) {
      const p = sparks[i];
      p.x += p.vx; p.y += p.vy; p.vy += 0.15; p.life -= 1;
      g.fillStyle = p.color;
      g.fillRect(p.x | 0, p.y | 0, 2, 2);
      if (p.life <= 0) sparks.splice(i, 1);
    }
  }
  function popText(g, text, x, y, age) {
    g.font = `8px ${FONT}`;
    g.fillStyle = '#2a1a14';
    g.fillText(text, x + 1, y - age / 3 + 1);
    g.fillStyle = '#ffc54d';
    g.fillText(text, x, y - age / 3);
  }

  // ---------------------------------------------------------------- fireflies
  const fireflies = (() => {
    const v = view('fireflies', '螢火蟲燈籠：點正在發亮的螢火蟲把牠收進燈籠',
      '<p class="arcade-say" data-fire-say aria-live="polite"></p>');
    const canvas = v.querySelector('canvas');
    const g = canvas.getContext('2d');
    let ctx = null, s = null, cursor = { x: 160, y: 90 }, pops = [];
    function hud() { ctx.setScore(`光點 ${s.score} · 連擊 ${s.combo} · ${Math.ceil((core.FIREFLY.MS - s.t) / 1000)} 秒`); }
    function tryCatch(x, y) {
      if (!s || s.done) return;
      ctx.setPlaying(true);
      const r = core.catchAt(s, x, y);
      if (r.event === 'catch') {
        spark(x, y);
        pops.push({ text: `+${r.points}${s.combo > 1 ? ` ×${s.combo}` : ''}`, x, y, age: 0 });
        root.NudgeSfx?.play('sparkle');
        root.dispatchEvent(new root.CustomEvent('nudge-arcade-hit', { detail: { game: 'fireflies', combo: s.combo } }));
      } else {
        root.dispatchEvent(new root.CustomEvent('nudge-arcade-miss', { detail: { game: 'fireflies' } }));
        v.querySelector('[data-fire-say]').textContent = r.event === 'dark' ? '牠現在沒發光，等牠亮起來再抓！' : '';
      }
      hud();
    }
    canvas.addEventListener('pointerdown', e => { const p = toNative(canvas, e); cursor = p; tryCatch(p.x, p.y); });
    canvas.addEventListener('keydown', e => {
      const k = e.key.toLowerCase();
      const d = { arrowleft: [-8, 0], arrowright: [8, 0], arrowup: [0, -8], arrowdown: [0, 8] }[k];
      if (d) { e.preventDefault(); cursor = { x: Math.max(4, Math.min(316, cursor.x + d[0])), y: Math.max(4, Math.min(176, cursor.y + d[1])) }; }
      if (k === ' ' || k === 'enter') { e.preventDefault(); tryCatch(cursor.x, cursor.y); }
    });
    function draw(still) {
      nightBg(g, s.t, still);
      // lantern meter at the right: fills with every catch
      const fill = Math.min(1, s.caught / 30);
      g.fillStyle = '#3a2216'; g.fillRect(292, 40, 20, 70);
      g.fillStyle = '#5a3a26'; g.fillRect(294, 42, 16, 66);
      g.fillStyle = '#ffd56b'; g.fillRect(294, 108 - Math.round(66 * fill), 16, Math.round(66 * fill));
      g.fillStyle = '#3a2216'; g.fillRect(298, 34, 8, 6); g.fillRect(300, 110, 4, 8);
      for (const f of s.flies) {
        const p = core.flyAt(f, s.t);
        if (p.lit) {
          g.fillStyle = 'rgba(233,255,138,0.25)';
          g.fillRect((p.x - 4) | 0, (p.y - 4) | 0, 9, 9);
          g.fillStyle = '#e9ff8a';
          g.fillRect((p.x - 1) | 0, (p.y - 1) | 0, 3, 3);
        } else {
          g.fillStyle = '#5a5a3a';
          g.fillRect(p.x | 0, p.y | 0, 2, 2);
        }
      }
      g.strokeStyle = '#fff6e4';
      g.strokeRect((cursor.x - 6) | 0, (cursor.y - 6) | 0, 12, 12);
      drawSparks(g);
      pops = pops.filter(p => (p.age += 1) < 24);
      for (const p of pops) popText(g, p.text, p.x, p.y, p.age);
    }
    function complete(reason) {
      if (!s || s.finished) return;
      s.finished = true;
      ctx.setPlaying(false);
      const newBest = ctx.records.offer('fireflies', 'default', { score: s.score }, 'high');
      if (reason === 'exit') return;
      ctx.finish({
        title: '螢火蟲燈籠',
        grade: core.fireflyGrade(s.score),
        lines: [`收進燈籠的螢火蟲 ${s.caught} 隻`, `光點 ${s.score}`, `最長連擊 ${s.best}`],
        newBest,
      });
    }
    return {
      id: 'fireflies', title: '螢火蟲燈籠', cabinet: 'green',
      desc: '夜晚的草地上，點正在發亮的螢火蟲把牠收進燈籠。快速連續抓到會有連擊加分，45 秒。',
      controls: '點螢火蟲，或用方向鍵移動網子、空白鍵抓。Esc 或 P 暫停。',
      bestLines: rec => (rec.default ? [`最高光點 ${rec.default.score}`] : []),
      enter(c) { ctx = c; s = core.newFireflies(Date.now() % 100000); pops = []; fit(canvas); hud(); ctx.setHint('等螢火蟲亮起來再點牠！'); draw(c.reducedMotion?.()); },
      resize() { fit(canvas); },
      focusTarget: () => canvas,
      tick(now, dtMs) {
        if (!s || s.finished) return;
        const before = Math.ceil((core.FIREFLY.MS - s.t) / 1000);
        core.stepFireflies(s, dtMs);
        if (Math.ceil((core.FIREFLY.MS - s.t) / 1000) !== before) hud();
        draw(ctx.reducedMotion?.());
        if (s.done) complete('time');
      },
      end(reason) { complete(reason); },
      leave() { if (s) s.finished = true; },
    };
  })();

  // ---------------------------------------------------------------- constellation
  const constellation = (() => {
    const v = view('constellation', '星座連線：看星星依序亮起，再照順序點回去', '<p class="arcade-say" data-star-say aria-live="polite"></p>');
    const canvas = v.querySelector('canvas');
    const g = canvas.getContext('2d');
    let ctx = null, s = null, focus = 0, flash = { i: -1, t: 0, ok: true }, pops = [];
    const say = t => { v.querySelector('[data-star-say]').textContent = t; };
    function hud() { ctx.setScore(`第 ${s.round} 夜 · 連線 ${s.score} · 失誤 ${s.slips}/${core.CONST.SLIPS}`); }
    function choose(i) {
      if (!s || s.done || i < 0) return;
      ctx.setPlaying(true);
      const r = core.pick(s, i);
      const p = s.stars[i] || { x: 160, y: 90 };
      if (r.event === 'link' || r.event === 'complete') {
        spark(p.x, p.y, '#bfe3ff');
        root.NudgeSfx?.play(r.event === 'complete' ? 'sparkle' : 'tap');
        root.dispatchEvent(new root.CustomEvent('nudge-arcade-hit', { detail: { game: 'constellation' } }));
        if (r.event === 'complete') { say('星座完成！下一夜多一顆星。'); pops.push({ text: '星座完成！', x: 120, y: 90, age: 0 }); }
      } else if (r.event === 'slip' || r.event === 'over') {
        flash = { i, t: 0, ok: false };
        root.dispatchEvent(new root.CustomEvent('nudge-arcade-miss', { detail: { game: 'constellation' } }));
        say(r.event === 'over' ? '星星躲進雲裡了。' : '順序不對，再看一次！');
      }
      hud();
      if (s.done) complete('over');
    }
    canvas.addEventListener('pointerdown', e => { const q = toNative(canvas, e); choose(core.starAt(s, q.x, q.y)); });
    canvas.addEventListener('keydown', e => {
      if (!s) return;
      const k = e.key.toLowerCase();
      if (k === 'arrowright' || k === 'arrowdown') { e.preventDefault(); focus = (focus + 1) % s.stars.length; }
      if (k === 'arrowleft' || k === 'arrowup') { e.preventDefault(); focus = (focus - 1 + s.stars.length) % s.stars.length; }
      if (k === ' ' || k === 'enter') { e.preventDefault(); choose(focus); }
    });
    function draw(still) {
      nightBg(g, s.t, still);
      const lit = core.showing(s);
      const done = s.order.slice(0, s.pos);
      g.strokeStyle = '#bfe3ff';
      g.beginPath();
      done.forEach((i, k) => { const p = s.stars[i]; if (k) g.lineTo(p.x, p.y); else g.moveTo(p.x, p.y); });
      g.stroke();
      s.stars.forEach((p, i) => {
        const on = i === lit || done.includes(i);
        const bad = flash.i === i && !flash.ok && flash.t < 20;
        g.fillStyle = bad ? '#d8452e' : on ? '#ffe7a8' : '#8a7ab8';
        g.fillRect(p.x - 2, p.y - 2, 5, 5);
        g.fillRect(p.x - 4, p.y, 9, 1);
        g.fillRect(p.x, p.y - 4, 1, 9);
        if (i === focus && s.phase === 'input') { g.strokeStyle = '#fff6e4'; g.strokeRect(p.x - 7, p.y - 7, 15, 15); }
      });
      flash.t += 1;
      drawSparks(g);
      pops = pops.filter(p => (p.age += 1) < 30);
      for (const p of pops) popText(g, p.text, p.x, p.y, p.age);
    }
    function complete(reason) {
      if (!s || s.finished) return;
      s.finished = true;
      ctx.setPlaying(false);
      const newBest = ctx.records.offer('constellation', 'default', { score: s.score }, 'high');
      if (reason === 'exit') return;
      ctx.finish({
        title: '星座連線',
        grade: core.constellationGrade(s.score),
        lines: [`連到第 ${s.round} 夜`, `連線 ${s.score} 條`],
        newBest,
      });
    }
    return {
      id: 'constellation', title: '星座連線', cabinet: 'purple',
      desc: '看星星依序亮起，再照同樣的順序點回去。每過一夜多一顆星，失誤兩次就天亮了。',
      controls: '點星星，或用方向鍵選星、空白鍵連線。Esc 或 P 暫停。',
      bestLines: rec => (rec.default ? [`最多連線 ${rec.default.score} 條`] : []),
      enter(c) { ctx = c; s = core.newConstellation(Date.now() % 100000); focus = 0; pops = []; fit(canvas); hud(); say('先看清楚星星亮起的順序。'); draw(c.reducedMotion?.()); },
      resize() { fit(canvas); },
      focusTarget: () => canvas,
      tick(now, dtMs) {
        if (!s || s.finished) return;
        const was = s.phase;
        core.stepConstellation(s, dtMs);
        if (was === 'show' && s.phase === 'input') say('換你了！照順序點星星。');
        draw(ctx.reducedMotion?.());
        if (s.done) complete('time');
      },
      end(reason) { complete(reason); },
      leave() { if (s) s.finished = true; },
    };
  })();

  arcade.register(fireflies);
  arcade.register(constellation);
})(typeof globalThis !== 'undefined' ? globalThis : this);
