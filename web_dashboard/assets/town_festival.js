(function(root) {
  'use strict';
  // #200 H3: dress the town for the running festival (lantern strings, cherry
  // trees, snowmen or star garlands on the market map) and launch town-wide
  // fireworks once after the shared town goal was reached this week.
  // Drawn from town.js each frame; reduced motion shows static decorations.
  const core = root.NudgeFestivalCore;
  const doc = root.document;
  if (!core || !doc || doc.body?.dataset.page !== 'town') return;

  const preview = (() => { try { return new URLSearchParams(root.location.search).get('festival'); } catch { return null; } })();
  const festival = core.festivalAt(new Date(), preview);
  const DIR = 'assets/scenes/social_world/festival/';
  const sprites = {};
  for (const name of ['lantern_string', 'cherry_tree', 'snowman', 'star_garland']) {
    const image = new Image();
    image.src = `${DIR}${name}.png`;
    sprites[name] = image;
  }
  const ready = name => sprites[name]?.complete && sprites[name].naturalWidth > 0;
  // Market-map fractions where each kind of decoration stands.
  const SPOTS = {
    lantern_string: [[0.4, 0.47, 150], [0.56, 0.47, 150], [0.44, 0.74, 170]],
    star_garland: [[0.4, 0.47, 150], [0.56, 0.47, 150], [0.44, 0.74, 170]],
    cherry_tree: [[0.38, 0.62, 70], [0.6, 0.64, 70], [0.7, 0.74, 76], [0.28, 0.58, 66]],
    snowman: [[0.44, 0.67, 34], [0.53, 0.69, 34], [0.31, 0.61, 32]],
  };

  let fireworksUntil = 0;
  const bursts = [];
  if (core.takeFireworks(root.localStorage, core.weekKey(new Date()))) startFireworks();
  function startFireworks() {
    if (root.matchMedia?.('(prefers-reduced-motion: reduce)').matches) return;
    fireworksUntil = root.performance.now() + 7000;
    root.NudgeTownAudio?.effect?.('level_up.wav');
  }

  function draw(ctx, view, now) {
    if (festival) {
      for (const name of festival.decor) {
        if (!ready(name)) continue;
        const image = sprites[name];
        for (const [i, [fx, fy, width]] of SPOTS[name].entries()) {
          const p = view.toScreen({ x: fx * view.mapW, y: fy * view.mapH });
          const w = width * view.scale, h = w * image.naturalHeight / image.naturalWidth;
          const sway = view.reducedMotion ? 0 : Math.round(Math.sin(now / 700 + i) * 1.5) * view.scale;
          ctx.drawImage(image, Math.round(p.x - w / 2 + sway), Math.round(p.y - h), Math.round(w), Math.round(h));
        }
      }
      if (festival.key === 'snowman') { ctx.fillStyle = 'rgba(236,240,255,0.08)'; ctx.fillRect(0, 0, view.width, view.height); }
    }
    if (now < fireworksUntil) {
      if (bursts.length < 6 && Math.random() < 0.06) {
        bursts.push({ x: view.width * (0.2 + Math.random() * 0.6), y: view.height * (0.15 + Math.random() * 0.3), start: now, seed: Math.random() * 6,
          color: ['#ffd77a', '#f6a7c3', '#8bd3ff', '#c9a2ff'][bursts.length % 4] });
      }
    }
    for (let i = bursts.length - 1; i >= 0; i--) {
      const b = bursts[i];
      const t = (now - b.start) / 1400;
      if (t >= 1) { bursts.splice(i, 1); continue; }
      ctx.fillStyle = b.color;
      for (const p of core.fireworkParticles(b.seed, t)) {
        ctx.globalAlpha = p.alpha;
        ctx.fillRect(Math.round(b.x + p.x * 70), Math.round(b.y + p.y * 70), 4, 4);
      }
      ctx.globalAlpha = 1;
    }
  }

  root.NudgeTownFestival = { draw, festival, startFireworks };
})(typeof globalThis !== 'undefined' ? globalThis : this);
