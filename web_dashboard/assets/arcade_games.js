(function (root) {
  'use strict';
  // The four arcade cabinets. Rules live in the *_core.js modules; this file
  // only draws, plays sound and routes input. Nothing here writes to the
  // Cloud: best records and the fish collection stay in localStorage.
  const arcade = root.NudgeArcade;
  const doc = root.document;
  const starsCore = root.NudgeTownGameCore;
  const fishCore = root.NudgeArcadeFishingCore;
  const rhythmCore = root.NudgeArcadeRhythmCore;
  const memoryCore = root.NudgeArcadeMemoryCore;
  const arcadeCore = root.NudgeArcadeCore;
  if (!arcade || !doc || !starsCore || !fishCore || !rhythmCore || !memoryCore || !arcadeCore) return;

  const els = id => doc.getElementById(id);
  const images = {};
  function image(src) {
    if (!images[src]) { const img = new Image(); img.src = src; images[src] = img; }
    return images[src];
  }
  const ready = img => img && img.complete && img.naturalWidth > 0;
  const PIXEL_FONT = '"Cubic11", "Noto Sans TC", sans-serif';
  // Canvas colours are read from the world_ui.css tokens, never hard-coded.
  const TOKENS = {
    ink: '--w-ink', inkDark: '--w-ink-dark', gold: '--w-gold', goldDeep: '--w-gold-deep', violet: '--w-violet',
    violetDeep: '--w-violet-deep', green: '--w-green', red: '--w-red', night: '--w-night', dusk: '--w-dusk-top',
    wood: '--w-wood', woodDeep: '--w-wood-deep', parchment: '--w-parchment', parchmentHi: '--w-parchment-hi',
  };
  const COLORS = {};
  function readTokens() {
    const css = root.getComputedStyle ? root.getComputedStyle(doc.documentElement) : null;
    for (const [k, v] of Object.entries(TOKENS)) COLORS[k] = (css && css.getPropertyValue(v).trim()) || 'black';
  }
  readTokens();


  /** Size a native-resolution canvas to the biggest whole multiple that fits. */
  // fullHeight: the canvas may use the whole viewport height; the sticky
  // game bar then sits over its top edge (used by the tall rhythm tower).
  function scaleCanvas(canvas, ctx, reserveH = 0, fullHeight = false) {
    const stage = els('gameStage');
    const availW = stage.clientWidth || 320;
    const top = fullHeight ? 0 : stage.getBoundingClientRect().top + (root.scrollY || 0);
    const availH = Math.max(canvas.height, (root.innerHeight || 720) - Math.max(0, top) - 24 - reserveH);
    const k = ctx.fitScale(canvas.width, canvas.height, availW, availH);
    canvas.style.width = `${canvas.width * k}px`;
    canvas.style.height = `${canvas.height * k}px`;
    return k;
  }
  function g2d(canvas) {
    let g = null;
    try { g = canvas.getContext('2d'); } catch { g = null; }
    if (g) g.imageSmoothingEnabled = false;
    return g;
  }
  /** Crisp 1-px line (no anti-aliasing), for fishing lines and rods. */
  function pxLine(g, x0, y0, x1, y1, color) {
    g.fillStyle = color;
    x0 = Math.round(x0); y0 = Math.round(y0); x1 = Math.round(x1); y1 = Math.round(y1);
    const dx = Math.abs(x1 - x0); const dy = -Math.abs(y1 - y0);
    const sx = x0 < x1 ? 1 : -1; const sy = y0 < y1 ? 1 : -1;
    let err = dx + dy;
    for (let i = 0; i < 2000; i += 1) {
      g.fillRect(x0, y0, 1, 1);
      if (x0 === x1 && y0 === y1) break;
      const e2 = 2 * err;
      if (e2 >= dy) { err += dy; x0 += sx; }
      if (e2 <= dx) { err += dx; y0 += sy; }
    }
  }
  function pointerLaneX(canvas, event) {
    const rect = canvas.getBoundingClientRect();
    return Math.min(0.999, Math.max(0, (event.clientX - rect.left) / Math.max(1, rect.width)));
  }

  // =====================================================================
  // 1. 接星星 (existing break game, rules from town_game_core.js)
  // =====================================================================
  const STAR = ['...#...', '..###..', '#######', '.#####.', '.##.##.', '#.....#'];
  const CLOUD = ['...####....', '.########..', '###########', '.#########.'];
  function sprite(g, rows, x, y, color, outline) {
    for (let r = 0; r < rows.length; r += 1) {
      for (let c = 0; c < rows[r].length; c += 1) {
        if (rows[r][c] !== '#') continue;
        g.fillStyle = color;
        g.fillRect(Math.round(x + c), Math.round(y + r), 1, 1);
      }
    }
    if (outline) { g.fillStyle = outline; g.fillRect(Math.round(x), Math.round(y + rows.length), rows[0].length, 1); }
  }

  const stars = (() => {
    const canvas = els('starsCanvas');
    const g = g2d(canvas);
    let ctx = null;
    let s = null;
    function reset() {
      s = { x: 0.5, score: 0, combo: 0, elapsed: 0, stars: [], clouds: [], keys: new Set(), done: false, twinkle: 0 };
    }
    function hud() { ctx.setScore(`${s.score} 分 · 連續 ${s.combo}`); }
    function draw() {
      if (!g) return;
      const grad = g.createLinearGradient(0, 0, 0, 180);
      grad.addColorStop(0, COLORS.night); grad.addColorStop(1, COLORS.dusk);
      g.fillStyle = grad; g.fillRect(0, 0, 320, 180);
      g.fillStyle = COLORS.wood; g.fillRect(0, 160, 320, 20);
      g.fillStyle = COLORS.woodDeep; g.fillRect(0, 160, 320, 2);
      for (const st of s.stars) sprite(g, STAR, st.x * 320 - 3, st.y * 180 - 3, COLORS.gold, ctx.reducedMotion || (s.twinkle | 0) % 2 ? null : COLORS.goldDeep);
      for (const c of s.clouds) sprite(g, CLOUD, c.x * 320 - 5, c.y * 180 - 2, COLORS.parchment);
      const hero = image(`assets/avatar/characters/character_${ctx.faceIndex()}.png`);
      const h = 40; const w = Math.round(h * 512 / 768);
      if (ready(hero)) g.drawImage(hero, Math.round(s.x * 320 - w / 2), 158 - h + 6, w, h);
      else { g.fillStyle = COLORS.violet; g.fillRect(Math.round(s.x * 320 - 6), 140, 12, 18); }
    }
    return {
      id: 'stars',
      title: '接星星',
      cabinet: 'blue',
      desc: '小鎮原本的休息遊戲：接住落下的星星，連續接到五顆會多 1 分；碰到雲朵會扣 2 分並中斷連續。',
      controls: '左右鍵或 A／D 移動；滑鼠或手指在畫面上拖曳。Esc 或 P 暫停。',
      bestLines(rec) { return rec.default ? [`最高 ${rec.default.score} 分`] : []; },
      enter(c) {
        ctx = c; reset();
        canvas.hidden = false;
        scaleCanvas(canvas, ctx);
        ctx.setHint('接住星星，避開雲朵。分數只留在這台裝置。');
        ctx.setPlaying(true);
        hud(); draw();
      },
      resize() { scaleCanvas(canvas, ctx); draw(); },
      focusTarget: () => canvas,
      key(type, key) {
        if (!['arrowleft', 'arrowright', 'a', 'd'].includes(key)) return false;
        if (type === 'down') s.keys.add(key); else s.keys.delete(key);
        return true;
      },
      pause() { s.keys.clear(); },
      tick(now, dtMs) {
        if (s.done) return;
        const dt = dtMs / 1000;
        s.elapsed += dt;
        s.twinkle += dt * 4;
        if (s.keys.has('arrowleft') || s.keys.has('a')) s.x = Math.max(0.05, s.x - dt * 0.9);
        if (s.keys.has('arrowright') || s.keys.has('d')) s.x = Math.min(0.95, s.x + dt * 0.9);
        const rates = starsCore.spawnRates(s.elapsed);
        if (Math.random() < dt * rates.stars) s.stars.push({ x: 0.04 + Math.random() * 0.92, y: -0.05, v: 0.25 + Math.random() * 0.2 });
        if (Math.random() < dt * rates.clouds) s.clouds.push({ x: 0.04 + Math.random() * 0.92, y: -0.05, v: 0.2 + Math.random() * 0.15 });
        const catchY = 0.8;
        let changed = false;
        for (const o of s.stars) o.y += o.v * dt;
        for (const o of s.clouds) o.y += o.v * dt;
        s.stars = s.stars.filter(o => {
          if (o.y > catchY - 0.06 && o.y < catchY + 0.06 && Math.abs(o.x - s.x) < 0.06) {
            const r = starsCore.catchObject(s.score, s.combo, 'star');
            s.score = r.score; s.combo = r.combo; changed = true;
            if (r.bonus) ctx.setHint('五連星！多得 1 分。');
            return false;
          }
          return o.y < 1.05;
        });
        s.clouds = s.clouds.filter(o => {
          if (o.y > catchY - 0.05 && o.y < catchY + 0.05 && Math.abs(o.x - s.x) < 0.07) {
            const r = starsCore.catchObject(s.score, s.combo, 'cloud');
            s.score = r.score; s.combo = r.combo; changed = true;
            return false;
          }
          return o.y < 1.05;
        });
        if (changed) hud();
        draw();
      },
      end(reason) {
        if (s.done) return;
        s.done = true;
        const newBest = ctx.records.offer('stars', 'default', { score: s.score }, 'high');
        if (reason !== 'exit') ctx.finish({ title: '接星星 結算', lines: [`得分 ${s.score} 分`], newBest });
      },
      leave() { s.keys.clear(); s.done = true; },
      _pointer(event) { if (!s.done) s.x = Math.min(0.95, Math.max(0.05, pointerLaneX(canvas, event))); },
    };
  })();
  els('starsCanvas').addEventListener('pointerdown', e => { els('starsCanvas').setPointerCapture?.(e.pointerId); stars._pointer(e); });
  els('starsCanvas').addEventListener('pointermove', e => { if (e.buttons || e.pointerType !== 'mouse') stars._pointer(e); });

  // =====================================================================
  // 2. 星光釣魚
  // =====================================================================
  const fishing = (() => {
    const canvas = els('fishingCanvas');
    const g = g2d(canvas);
    let ctx = null;
    let s = null;
    const dexKey = () => `nudge_arcade_dex_${ctx.uid()}`;
    const readDex = () => fishCore.readDex(ctx.store.get(dexKey()));
    function reset() {
      s = { phase: 'ready', holding: false, castAt: 0, landAt: 0, biteAt: null, catch: null, window: 600,
        sayUntil: 0, catches: 0, clock: 0, flashUntil: 0, done: false };
    }
    function say(text, ms = 1600) {
      els('fishingSay').textContent = text;
      s.sayUntil = s.clock + ms;
    }
    function hud() { ctx.setScore(`本次 ${s.catches} 條`); }
    function renderDex() {
      const dex = readDex();
      const list = els('fishingDex');
      list.textContent = '';
      let have = 0;
      fishCore.FISH.forEach((f, i) => {
        const li = doc.createElement('li');
        const entry = dex[f.id];
        const icon = doc.createElement('span');
        icon.className = `arcade-fish-icon${entry ? '' : ' is-unknown'}`;
        icon.style.setProperty('--i', String(i));
        icon.setAttribute('aria-hidden', 'true');
        const text = doc.createElement('span');
        if (entry) {
          have += 1;
          text.textContent = `${f.name}（${fishCore.rarityOf(f.rarity).name}）×${entry.count}`;
        } else {
          text.textContent = `？？？（${fishCore.rarityOf(f.rarity).name}）`;
        }
        li.append(icon, text);
        list.appendChild(li);
      });
      els('fishingDexCount').textContent = `${have} / ${fishCore.FISH.length}`;
    }
    function bobberPos() {
      const p = s.phase === 'casting' ? fishCore.castPower(s.clock - s.castAt) : 1;
      return { x: Math.round(118 + p * 120), y: Math.round(118 - Math.sin(Math.min(1, p) * Math.PI) * (s.phase === 'casting' ? 30 : 0)) };
    }
    function draw() {
      if (!g) return;
      const bg = image('assets/arcade/lake_bg.png');
      if (ready(bg)) g.drawImage(bg, 0, 0, 320, 180);
      else { g.fillStyle = COLORS.night; g.fillRect(0, 0, 320, 180); }
      // the player stands on the pier (existing character art) with a rod
      const hero = image(`assets/avatar/characters/character_${ctx.faceIndex()}.png`);
      if (ready(hero)) g.drawImage(hero, 70, 98, 24, 36);
      const tip = { x: 106, y: 96 };
      pxLine(g, 86, 118, tip.x, tip.y, COLORS.woodDeep);
      if (s.phase === 'ready') {
        g.font = `12px ${PIXEL_FONT}`;
        g.fillStyle = COLORS.ink; g.textAlign = 'center';
        g.fillText('按住拋竿', 200, 110);
        return;
      }
      if (s.phase === 'result' || s.phase === 'card') return;
      const b = bobberPos();
      let jitter = 0;
      if (s.phase === 'bite' && !ctx.reducedMotion) jitter = (Math.floor(s.clock / 50) % 2) ? 1 : -1;
      pxLine(g, tip.x, tip.y, b.x + jitter, b.y - 6, COLORS.parchment);
      const strip = image('assets/arcade/bobber.png');
      const frame = ctx.reducedMotion || s.phase === 'casting' ? 0 : Math.floor(s.clock / 220) % 3;
      if (ready(strip)) g.drawImage(strip, frame * 24, 0, 24, 24, b.x - 6 + jitter, b.y - 6, 12, 12);
      if (s.phase === 'bite') {
        g.fillStyle = COLORS.gold; g.fillRect(b.x - 6, b.y - 26, 12, 14);
        g.fillStyle = COLORS.woodDeep; g.fillRect(b.x - 6, b.y - 12, 12, 1);
        g.font = `12px ${PIXEL_FONT}`; g.textAlign = 'center'; g.fillStyle = COLORS.inkDark;
        g.fillText('！', b.x, b.y - 15);
      }
      if (!ctx.reducedMotion && s.clock < s.flashUntil) { g.globalAlpha = 0.35; g.fillStyle = COLORS.parchmentHi; g.fillRect(0, 0, 320, 180); g.globalAlpha = 1; }
    }
    function down() {
      if (s.done || s.phase !== 'ready') return;
      s.holding = true;
      s.phase = 'casting';
      s.castAt = s.clock;
      s.landAt = s.clock + 800;
      s.catch = fishCore.rollFish();
      s.window = fishCore.windowFor(s.catch.rarity.id);
      s.biteAt = s.landAt + fishCore.biteDelayMs();
      say('拋竿！繼續按住，等浮標出現「！」再放開。', 2400);
    }
    function up() {
      if (!s.holding) return;
      s.holding = false;
      if (!['casting', 'waiting', 'bite'].includes(s.phase)) return;
      const result = fishCore.judgeRelease(s.clock, s.phase === 'bite' ? s.biteAt : null, s.window);
      if (result === 'caught') { caught(); return; }
      s.phase = 'result';
      say(result === 'early' ? '太早收竿了，魚還沒上鉤。' : '慢了一點，魚溜走了。');
    }
    function caught() {
      const { fish, rarity } = s.catch;
      s.catches += 1;
      s.flashUntil = s.clock + 160;
      const dex = fishCore.addToDex(readDex(), fish.id, Date.now());
      ctx.store.set(dexKey(), JSON.stringify(dex));
      renderDex();
      hud();
      s.phase = 'card';
      ctx.hold(true);
      const chip = els('cardRarity');
      chip.textContent = rarity.name;
      chip.className = `w-chip arcade-rarity is-${rarity.id}`;
      const icon = els('cardFish');
      icon.style.setProperty('--i', String(fishCore.FISH.indexOf(fish)));
      els('cardTitle').textContent = `釣到了 ${fish.name}！`;
      els('cardNote').textContent = fish.note;
      els('cardCount').textContent = dex[fish.id].count === 1 ? '第一次釣到，已收進本機圖鑑。' : `圖鑑裡已經有 ${dex[fish.id].count} 條。`;
      ctx.openDialog('arcadeCard', canvas);
      say('');
    }
    els('cardClose').addEventListener('click', () => {
      if (!s || s.phase !== 'card') return;
      ctx.closeDialog('arcadeCard');
      ctx.hold(false);
      s.phase = 'ready';
      say('再拋一次吧。');
    });
    canvas.addEventListener('pointerdown', e => { e.preventDefault(); canvas.setPointerCapture?.(e.pointerId); if (ctx && !s.done) down(); });
    canvas.addEventListener('pointerup', () => { if (ctx) up(); });
    canvas.addEventListener('pointercancel', () => { if (ctx) up(); });
    canvas.addEventListener('contextmenu', e => e.preventDefault());

    return {
      id: 'fishing',
      title: '星光釣魚',
      cabinet: 'violet',
      desc: '夜晚的湖面。按住拋竿，浮標晃動後出現「！」時在 0.6 秒內放開就能釣到。魚分普通、少見、稀有、閃亮、傳說，越稀有的魚「！」出現的時間越短。',
      controls: '按住空白鍵或長按畫面拋竿，看到「！」立刻放開。Esc 或 P 暫停。',
      bestLines(rec, env) {
        const out = [];
        if (rec.default) out.push(`一次最多釣到 ${rec.default.score} 條`);
        const dex = fishCore.readDex(env.store.get(`nudge_arcade_dex_${env.uid}`));
        out.push(`圖鑑 ${Object.keys(dex).length} / ${fishCore.FISH.length}`);
        return out;
      },
      enter(c) {
        ctx = c; reset();
        scaleCanvas(canvas, ctx);
        renderDex();
        els('fishingSay').textContent = '';
        ctx.setHint('按住空白鍵或長按湖面拋竿，出現「！」時放開。');
        ctx.setPlaying(true);
        hud(); draw();
      },
      resize() { scaleCanvas(canvas, ctx); draw(); },
      focusTarget: () => canvas,
      key(type, key, event) {
        if (key !== ' ' && key !== 'spacebar') return false;
        if (type === 'down') { if (!event.repeat) down(); } else up();
        return true;
      },
      pause() { if (s.holding) { s.holding = false; if (['casting', 'waiting', 'bite'].includes(s.phase)) { s.phase = 'result'; say('暫停時收回了魚線。'); } } },
      tick(now, dtMs) {
        if (s.done) return;
        if (s.phase !== 'card') s.clock += dtMs;
        if (s.phase === 'casting' && s.clock >= s.landAt) s.phase = 'waiting';
        if (s.phase === 'waiting' && s.clock >= s.biteAt) { s.phase = 'bite'; say('！', s.window); }
        if (s.phase === 'bite' && fishCore.escaped(s.clock, s.biteAt, s.window)) {
          s.phase = 'result';
          say('慢了一點，魚溜走了。');
        }
        if (s.phase === 'result' && s.clock > s.sayUntil) { s.phase = 'ready'; say('再拋一次吧。', 1200); }
        if (s.sayUntil && s.clock > s.sayUntil && s.phase !== 'bite') { els('fishingSay').textContent = ''; s.sayUntil = 0; }
        draw();
      },
      end(reason) {
        if (s.done) return;
        s.done = true;
        if (s.phase === 'card') { ctx.closeDialog('arcadeCard', { restore: false }); ctx.hold(false); }
        const newBest = ctx.records.offer('fishing', 'default', { score: s.catches }, 'high');
        const dex = readDex();
        if (reason !== 'exit') {
          ctx.finish({ title: '星光釣魚 結算', lines: [`本次釣到 ${s.catches} 條`, `圖鑑 ${Object.keys(dex).length} / ${fishCore.FISH.length}`], newBest });
        }
      },
      leave() { if (s) { s.done = true; s.holding = false; } },
    };
  })();

  // =====================================================================
  // 3. 鐘塔節奏
  // =====================================================================
  const rhythm = (() => {
    const canvas = els('rhythmCanvas');
    const g = g2d(canvas);
    const LANE_X = [36, 90, 144];
    const JUDGE_Y = 287;
    const APPROACH_S = 1.5;
    let ctx = null;
    let s = null;

    function songTime() {
      if (!s) return 0;
      if (s.audio) return s.audio.currentTime - s.t0;
      return s.clock;
    }
    function makeAudio(chart, songDef) {
      const AC = root.AudioContext || root.webkitAudioContext;
      if (!AC) return null;
      let ac;
      try { ac = new AC(); } catch { return null; }
      const master = ac.createGain();
      master.gain.value = 0.32;
      master.connect(ac.destination);
      const t0 = ac.currentTime + 0.15;
      const voice = (ev, type, vol) => {
        const osc = ac.createOscillator();
        const gain = ac.createGain();
        osc.type = type;
        osc.frequency.value = ev.hz;
        const start = t0 + ev.t;
        gain.gain.setValueAtTime(0, start);
        gain.gain.linearRampToValueAtTime(vol, start + 0.005);
        gain.gain.setValueAtTime(vol, start + Math.max(0.01, ev.dur - 0.03));
        gain.gain.linearRampToValueAtTime(0, start + ev.dur);
        osc.connect(gain); gain.connect(master);
        osc.start(start); osc.stop(start + ev.dur + 0.02);
      };
      for (const ev of chart.melody) voice(ev, songDef.wave, 0.22);
      for (const ev of chart.bass) voice(ev, 'triangle', 0.3);
      // a soft tick on each beat helps keep time
      const beat = 60 / songDef.bpm;
      for (let t = rhythmCore.LEAD_IN_S - beat * 4; t < chart.duration - 1; t += beat) {
        if (t < 0) continue;
        voice({ t, dur: 0.03, hz: 1800 }, 'square', 0.04);
      }
      return { ac, t0 };
    }
    function renderSongs() {
      const list = els('rhythmSongs');
      list.textContent = '';
      const rec = ctx.records.get('rhythm');
      for (const songDef of rhythmCore.SONGS) {
        const chart = rhythmCore.buildChart(songDef);
        const li = doc.createElement('li');
        const btn = doc.createElement('button');
        btn.type = 'button';
        btn.className = 'w-btn arcade-song';
        const best = rec[songDef.id];
        btn.innerHTML = '';
        const t = doc.createElement('b'); t.textContent = songDef.title;
        const d = doc.createElement('span'); d.textContent = `${songDef.blurb}（${Math.round(chart.duration)} 秒・${chart.notes.length} 個音符）`;
        const b = doc.createElement('span'); b.className = 'arcade-song-best';
        b.textContent = best ? `最佳 ${best.score} 分・${best.grade}・最大連擊 ${best.maxCombo}` : '尚無紀錄';
        btn.append(t, d, b);
        btn.addEventListener('click', () => start(songDef));
        li.appendChild(btn);
        list.appendChild(li);
      }
    }
    function showPick() {
      els('rhythmPick').hidden = false;
      els('rhythmPlay').hidden = true;
      ctx.setPlaying(false);
      ctx.setScore('');
      ctx.setHint('選一首曲子。選曲時不會用到休息券的時間。');
      renderSongs();
      els('rhythmSongs').querySelector('button')?.focus({ preventScroll: true });
    }
    function start(songDef) {
      const chart = rhythmCore.buildChart(songDef);
      s = { song: songDef, chart, run: rhythmCore.newRun(chart.notes), clock: 0, flash: [0, 0, 0], judge: '', done: false, audio: null, t0: 0 };
      const audio = makeAudio(chart, songDef);
      if (audio) { s.audio = audio.ac; s.t0 = audio.t0; }
      els('rhythmPick').hidden = true;
      els('rhythmPlay').hidden = false;
      els('rhythmJudge').textContent = '';
      scaleCanvas(canvas, ctx, 16, true);
      els('rhythmJudge').scrollIntoView?.({ block: 'end', behavior: 'auto' });
      ctx.setHint(`${songDef.title}：音符碰到金色判定線時按 J、K、L 或點軌道。Perfect ±60 ms、Good ±120 ms。`);
      ctx.setPlaying(true);
      hud();
      canvas.focus?.({ preventScroll: true });
    }
    function hud() { ctx.setScore(`${s.run.score} 分 · 連擊 ${s.run.combo}`); }
    function hit(lane) {
      if (!s || s.done || els('rhythmPlay').hidden) return;
      const t = songTime();
      s.flash[lane] = t + 0.12;
      const out = rhythmCore.press(s.run, s.chart.notes, lane, t);
      if (out) {
        els('rhythmJudge').textContent = `${out.result === 'perfect' ? 'Perfect' : 'Good'}${s.run.combo > 1 ? ` ${s.run.combo} 連擊` : ''}`;
        hud();
      }
    }
    function draw(t) {
      if (!g) return;
      const bg = image('assets/arcade/tower_bg.png');
      if (ready(bg)) g.drawImage(bg, 0, 0, 180, 320);
      else { g.fillStyle = COLORS.night; g.fillRect(0, 0, 180, 320); }
      if (!ctx.reducedMotion) {
        for (let lane = 0; lane < 3; lane += 1) {
          if (t < s.flash[lane]) { g.globalAlpha = 0.28; g.fillStyle = COLORS.gold; g.fillRect(LANE_X[lane] - 17, 147, 35, 172); g.globalAlpha = 1; }
        }
      } else {
        for (let lane = 0; lane < 3; lane += 1) {
          if (t < s.flash[lane]) { g.fillStyle = COLORS.gold; g.fillRect(LANE_X[lane] - 17, JUDGE_Y + 5, 35, 3); }
        }
      }
      const gems = image('assets/arcade/gems.png');
      const notes = s.chart.notes;
      for (let i = s.run.next; i < notes.length; i += 1) {
        const n = notes[i];
        const ahead = n.t - t;
        if (ahead > APPROACH_S) break;
        if (s.run.judged.has(n.id)) continue;
        const y = Math.round(JUDGE_Y - (ahead / APPROACH_S) * JUDGE_Y);
        if (ready(gems)) g.drawImage(gems, [0, 32, 64][n.lane], 0, 32, 32, LANE_X[n.lane] - 8, y - 8, 16, 16);
        else { g.fillStyle = [COLORS.violet, COLORS.gold, COLORS.green][n.lane]; g.fillRect(LANE_X[n.lane] - 6, y - 6, 12, 12); }
      }
      g.font = `12px ${PIXEL_FONT}`; g.textAlign = 'center'; g.fillStyle = COLORS.ink;
      ['J', 'K', 'L'].forEach((k, i) => g.fillText(k, LANE_X[i], 308));
      if (t < rhythmCore.LEAD_IN_S) {
        g.fillStyle = COLORS.gold;
        g.fillText(String(Math.ceil(rhythmCore.LEAD_IN_S - t)), 90, 200);
      }
    }
    canvas.addEventListener('pointerdown', e => { e.preventDefault(); hit(Math.floor(pointerLaneX(canvas, e) * 3)); });

    function finish(reason) {
      if (!s || s.done) return;
      s.done = true;
      try { s.audio?.close(); } catch { /* already closed */ }
      ctx.setPlaying(false);
      if (reason === 'time' || reason === 'exit') rhythmCore.sweep(s.run, s.chart.notes, songTime());
      const played = s.run.counts.perfect + s.run.counts.good + s.run.counts.miss;
      const complete = played >= s.run.total;
      const grade = rhythmCore.grade(s.run.counts, s.run.total);
      const newBest = complete && ctx.records.offer('rhythm', s.song.id,
        { score: s.run.score, grade, maxCombo: s.run.maxCombo }, 'high');
      if (reason === 'exit') return;
      ctx.finish({
        title: `${s.song.title} 結算`,
        grade: complete ? grade : null,
        lines: [
          `得分 ${s.run.score}`,
          `Perfect ${s.run.counts.perfect}・Good ${s.run.counts.good}・Miss ${s.run.counts.miss}`,
          `最大連擊 ${s.run.maxCombo}`,
          ...(complete ? [] : ['時間到，這首還沒打完，所以不列入最佳紀錄。']),
        ],
        newBest,
      });
    }

    return {
      id: 'rhythm',
      title: '鐘塔節奏',
      cabinet: 'gold',
      desc: '黃昏的鐘塔裡有三條黃銅軌道。音符落到判定線時按下對應的鍵：Perfect ±60 ms、Good ±120 ms。三首自製 8-bit 短曲，結算評級 S／A／B／C。',
      controls: 'J、K、L 對應左、中、右軌道，也可以直接點軌道。Esc 或 P 暫停。',
      bestLines(rec) {
        return rhythmCore.SONGS.filter(x => rec[x.id]).map(x => `${x.title}：${rec[x.id].score} 分・${rec[x.id].grade}`);
      },
      enter(c) { ctx = c; s = null; showPick(); },
      resize() { if (s && !els('rhythmPlay').hidden) scaleCanvas(canvas, ctx, 16, true); },
      focusTarget: () => (s && !s.done ? canvas : els('rhythmSongs').querySelector('button')),
      key(type, key, event) {
        const lane = rhythmCore.KEYS.indexOf(key);
        if (lane < 0) return false;
        if (type === 'down' && !event.repeat) hit(lane);
        return true;
      },
      pause() { if (s?.audio && !s.done) s.audio.suspend?.(); },
      resume() { if (s?.audio && !s.done) s.audio.resume?.(); },
      tick(now, dtMs) {
        if (!s || s.done) return;
        if (!s.audio) s.clock += dtMs / 1000;
        const t = songTime();
        const missed = rhythmCore.sweep(s.run, s.chart.notes, t);
        if (missed.length) { els('rhythmJudge').textContent = 'Miss'; hud(); }
        draw(t);
        if (t >= s.chart.duration) finish('song');
      },
      end(reason) { finish(reason); },
      leave() { if (s && !s.done) { s.done = true; try { s.audio?.close(); } catch { /* closed */ } } },
    };
  })();

  // =====================================================================
  // 4. 夥伴記憶配對
  // =====================================================================
  const memory = (() => {
    const boardEl = els('memoryBoard');
    let ctx = null;
    let s = null;
    let settleTimer = 0;
    let lastDiff = 'easy';
    function hud() {
      if (!s) return;
      const sec = Math.floor(s.ms / 1000);
      ctx.setScore(`步數 ${s.board.moves} · ${Math.floor(sec / 60)}:${String(sec % 60).padStart(2, '0')}`);
    }
    function columns(diff) {
      const avail = boardEl.parentElement.clientWidth || 336;
      const fits = n => n * 64 + (n - 1) * 4 <= avail;
      return fits(diff.cols) ? diff.cols : diff.rows; // turn the board on narrow screens
    }
    function renderLevels() {
      const bar = els('memoryLevels');
      bar.textContent = '';
      for (const d of memoryCore.DIFFICULTIES) {
        const b = doc.createElement('button');
        b.type = 'button';
        b.setAttribute('role', 'tab');
        b.textContent = d.name;
        b.setAttribute('aria-selected', String(s?.diff.id === d.id));
        b.addEventListener('click', () => deal(d.id));
        bar.appendChild(b);
      }
    }
    function deal(diffId) {
      root.clearTimeout(settleTimer);
      const diff = memoryCore.difficultyById(diffId);
      lastDiff = diff.id;
      s = { diff, board: memoryCore.deal(diffId), ms: 0, started: false, done: false };
      ctx.setPlaying(false);
      renderLevels();
      build();
      hud();
      ctx.setHint(`${diff.name}：翻開兩張一樣的牌就配對成功。第一次翻牌才開始計時。`);
    }
    function build() {
      boardEl.textContent = '';
      boardEl.style.setProperty('--cols', String(columns(s.diff)));
      s.board.cards.forEach((card, i) => {
        const btn = doc.createElement('button');
        btn.type = 'button';
        btn.className = 'arcade-card';
        btn.dataset.index = String(i);
        btn.addEventListener('click', () => flip(i));
        const face = memoryCore.faceById(card.face);
        const img = doc.createElement('img');
        img.src = face.src; img.alt = ''; img.className = 'arcade-card-face';
        btn.appendChild(img);
        boardEl.appendChild(btn);
      });
      paint();
    }
    function paint() {
      const n = s.board.cards.length;
      [...boardEl.children].forEach((btn, i) => {
        const open = s.board.open.includes(i);
        const matched = s.board.matched.includes(i);
        btn.classList.toggle('is-open', open || matched);
        btn.classList.toggle('is-matched', matched);
        const face = memoryCore.faceById(s.board.cards[i].face);
        btn.setAttribute('aria-label', `第 ${i + 1} 張，共 ${n} 張：${open || matched ? face.label : '蓋著'}${matched ? '（已配對）' : ''}`);
        btn.setAttribute('aria-disabled', String(matched));
      });
    }
    function flip(i) {
      if (!s || s.done) return;
      root.clearTimeout(settleTimer);
      if (!s.started) { s.started = true; ctx.setPlaying(true); }
      const { board, event } = memoryCore.flip(s.board, i);
      if (event === 'ignored') return;
      s.board = board;
      paint();
      hud();
      if (event === 'miss') {
        settleTimer = root.setTimeout(() => { if (s && !s.done) { s.board = memoryCore.settle(s.board); paint(); } }, 800);
      }
      if (event === 'match') ctx.setHint('配對成功！');
      if (event === 'done') complete('done');
    }
    function complete(reason) {
      if (!s || s.done) return;
      s.done = true;
      ctx.setPlaying(false);
      const finished = s.board.done;
      const newBest = finished && ctx.records.offer('memory', s.diff.id, { moves: s.board.moves, ms: Math.round(s.ms) }, 'low');
      if (reason === 'exit') return;
      const sec = Math.round(s.ms / 1000);
      ctx.finish({
        title: `夥伴記憶配對 ${s.diff.name}`,
        lines: finished
          ? [`全部配對完成！`, `步數 ${s.board.moves}`, `時間 ${Math.floor(sec / 60)} 分 ${sec % 60} 秒`]
          : [`配對了 ${s.board.matched.length / 2} / ${s.board.cards.length / 2} 組`, '時間到，沒完成的盤面不列入最佳紀錄。'],
        newBest,
      });
    }
    boardEl.addEventListener('keydown', event => {
      const btn = event.target.closest?.('.arcade-card');
      if (!btn || !s) return;
      const cols = Number(boardEl.style.getPropertyValue('--cols')) || s.diff.cols;
      const i = Number(btn.dataset.index);
      const moves = { arrowleft: -1, arrowright: 1, arrowup: -cols, arrowdown: cols };
      const d = moves[event.key.toLowerCase()];
      if (d === undefined) return;
      event.preventDefault();
      const next = boardEl.children[i + d];
      next?.focus();
    });
    return {
      id: 'memory',
      title: '夥伴記憶配對',
      cabinet: 'green',
      desc: '把夥伴和徽章牌兩兩配對。有 4×4、5×4、6×5 三種難度，記錄步數和時間。',
      controls: '點牌或用 Tab／方向鍵移到牌上按 Enter 翻牌。Esc 或 P 暫停。',
      bestLines(rec) {
        return memoryCore.DIFFICULTIES.filter(d => rec[d.id]).map(d => {
          const sec = Math.round(rec[d.id].ms / 1000);
          return `${d.name}：${rec[d.id].moves} 步・${Math.floor(sec / 60)}:${String(sec % 60).padStart(2, '0')}`;
        });
      },
      enter(c) { ctx = c; deal(lastDiff); },
      resize() { if (s) boardEl.style.setProperty('--cols', String(columns(s.diff))); },
      focusTarget: () => boardEl.querySelector('.arcade-card'),
      tick(now, dtMs) {
        if (!s || s.done || !s.started) return;
        const before = Math.floor(s.ms / 1000);
        s.ms += dtMs;
        if (Math.floor(s.ms / 1000) !== before) hud();
      },
      end(reason) { complete(reason); },
      leave() { root.clearTimeout(settleTimer); if (s) s.done = true; },
    };
  })();

  arcade.register(stars);
  arcade.register(fishing);
  arcade.register(rhythm);
  arcade.register(memory);
})(typeof globalThis !== 'undefined' ? globalThis : this);
