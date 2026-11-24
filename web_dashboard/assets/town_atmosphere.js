(function(root) {
  'use strict';
  const core = root.NudgeTownAtmosphereCore;
  if (!core) return;

  const TINT = {
    dawn: [207, 220, 244, .17], day: [255, 244, 206, .11],
    dusk: [157, 80, 177, .08], night: [12, 23, 56, .58],
  };
  const LAMPS = [[.096,.205],[.153,.302],[.236,.202],[.417,.295],[.481,.296],
    [.413,.452],[.563,.448],[.597,.663],[.758,.694],[.757,.454],[.839,.192]];
  const WINDOWS = [[.156,.424],[.195,.517],[.442,.199],[.59,.216],[.727,.226],
    [.865,.452],[.926,.455],[.237,.754],[.181,.754]];
  const OWL = { id: 'owl', name: '貓頭鷹館長・歐莉', x: .505, y: .615 };
  const PORTRAITS = { baker: 'assets/avatar/characters/character_0.png',
    gardener: 'assets/avatar/characters/character_3.png',
    postman: 'assets/avatar/characters/character_6.png',
    owl: 'assets/town/guide.png' };
  const hashUnit = value => core.hash(value) / 4294967295;
  const mix = (a, b, t) => a + (b - a) * t;
  const glowCache = new Map();
  const actorImages = new Map();
  function imageFor(actor) {
    if (actorImages.has(actor.id)) return actorImages.get(actor.id);
    const image = new Image();
    const item = { image, crop: null };
    actorImages.set(actor.id, item);
    image.addEventListener('load', () => {
      const c = root.document.createElement('canvas');
      c.width = image.naturalWidth; c.height = image.naturalHeight;
      const g = c.getContext('2d');
      try {
        g.drawImage(image, 0, 0);
        const pixels = g.getImageData(0, 0, c.width, c.height).data;
        let left = c.width, top = c.height, right = 0, bottom = 0;
        for (let y = 0; y < c.height; y += 2) for (let x = 0; x < c.width; x += 2) {
          if (pixels[(y * c.width + x) * 4 + 3] > 20) {
            left = Math.min(left, x); top = Math.min(top, y);
            right = Math.max(right, x); bottom = Math.max(bottom, y);
          }
        }
        if (right > left) item.crop = { x: left, y: top, w: right - left + 2, h: bottom - top + 2 };
      } catch { /* Cross-origin images retain their full bounds. */ }
    });
    image.src = PORTRAITS[actor.id];
    return item;
  }

  function tint(ctx, width, height, phase) {
    const a = TINT[phase.from], b = TINT[phase.name], t = phase.blend;
    const rgba = [0, 1, 2].map(i => Math.round(mix(a[i], b[i], t)));
    ctx.fillStyle = `rgba(${rgba.join(',')},${mix(a[3], b[3], t)})`;
    ctx.fillRect(0, 0, width, height);
  }

  function glow(ctx, x, y, radius, strength) {
    const bucket = Math.max(1, Math.round(strength * 10));
    const key = `${radius}:${bucket}`;
    let sprite = glowCache.get(key);
    if (!sprite) {
      sprite = root.document.createElement('canvas');
      sprite.width = sprite.height = radius * 2;
      const paint = sprite.getContext('2d');
      const gradient = paint.createRadialGradient(radius, radius, 2, radius, radius, radius);
      gradient.addColorStop(0, `rgba(255,215,125,${bucket / 10})`);
      gradient.addColorStop(.45, `rgba(255,186,72,${bucket / 28})`);
    gradient.addColorStop(1, 'rgba(255,186,72,0)');
      paint.fillStyle = gradient;
      paint.fillRect(0, 0, radius * 2, radius * 2);
      glowCache.set(key, sprite);
    }
    ctx.drawImage(sprite, x - radius, y - radius);
  }

  function drawAmbient(ctx, view, phase, now) {
    const { toScreen, mapW, mapH, reducedMotion } = view;
    const p = (x, y) => toScreen({ x: x * mapW, y: y * mapH });
    if (phase.name === 'night' || phase.name === 'dusk') {
      const amount = phase.name === 'night' ? phase.blend : .24;
      for (const [x, y] of LAMPS) {
        const q = p(x, y);
        glow(ctx, q.x, q.y, 36, amount * (reducedMotion ? .55 : .52 + Math.sin(now / 700 + x * 22) * .035));
      }
      for (const [x, y] of WINDOWS) {
        const q = p(x, y);
        glow(ctx, q.x, q.y, 20, amount * .55);
      }
    }
    if (phase.name === 'dawn') {
      const fog = ctx.createLinearGradient(0, view.height * .55, 0, view.height);
      fog.addColorStop(0, 'rgba(230,235,245,0)');
      fog.addColorStop(1, 'rgba(230,235,245,.13)');
      ctx.fillStyle = fog;
      ctx.fillRect(0, 0, view.width, view.height);
    }
  }

  function drawFountain(ctx, view, now) {
    const q = view.toScreen({ x: .48 * view.mapW, y: .52 * view.mapH });
    const frame = Math.floor(now / 140) % 6;
    ctx.fillStyle = 'rgba(181,240,255,.8)';
    for (let i = 0; i < 3; i++) {
      const lift = ((frame + i * 2) % 6) * 2;
      ctx.fillRect(Math.round(q.x + (i - 1) * 8), Math.round(q.y - 13 - lift), 3, 5);
    }
  }

  function drawFlagsAndSmoke(ctx, view, now) {
    const p = (x, y) => view.toScreen({ x: x * view.mapW, y: y * view.mapH });
    const flagFrame = Math.floor(now / 180) % 4;
    for (const [x, y] of [[.596,.229],[.698,.23]]) {
      const q = p(x, y);
      ctx.fillStyle = '#bb9b64'; ctx.fillRect(q.x, q.y, 2, 30);
      ctx.fillStyle = '#8050b6'; ctx.fillRect(q.x + 2, q.y + 2, 9 + flagFrame, 7);
      ctx.fillStyle = '#f4c85b'; ctx.fillRect(q.x + 7, q.y + 4, 2, 2);
    }
    for (const [x, y] of [[.09,.367],[.035,.351]]) {
      const q = p(x, y);
      for (let i = 0; i < 3; i++) {
        const rise = (now / 90 + i * 13) % 43;
        ctx.fillStyle = `rgba(228,218,211,${.23 * (1 - rise / 43)})`;
        ctx.beginPath(); ctx.arc(q.x + Math.sin(now / 1200 + i) * 4, q.y - rise, 5 + rise / 7, 0, Math.PI * 2); ctx.fill();
      }
    }
  }

  function drawCloudAndBirds(ctx, view, now) {
    const drift = (now / 70) % (view.width + 500) - 250;
    ctx.fillStyle = 'rgba(26,27,56,.07)';
    ctx.beginPath(); ctx.ellipse(drift, view.height * .53, 110, 28, -.17, 0, Math.PI * 2); ctx.fill();
    if (Math.floor(now / 20000) % 3 !== 0) return;
    const flight = (now / 40) % (view.width + 140) - 70;
    ctx.strokeStyle = 'rgba(36,26,53,.65)'; ctx.lineWidth = 1.5;
    for (let i = 0; i < 5; i++) {
      const x = flight - i * 15, y = view.height * .18 + (i % 2) * 7;
      ctx.beginPath(); ctx.moveTo(x - 4, y - 2); ctx.lineTo(x, y); ctx.lineTo(x + 4, y - 2); ctx.stroke();
    }
  }

  function drawParticles(ctx, view, weather, phase, now) {
    if (weather.kind === 'firefly' && phase.name !== 'night') return;
    const count = core.particleLimit(view.width, view.height);
    for (let i = 0; i < count; i++) {
      const seed = `${weather.key}:${i}`;
      const x0 = hashUnit(`${seed}:x`), y0 = hashUnit(`${seed}:y`);
      const speed = .012 + hashUnit(`${seed}:speed`) * .035;
      const kind = weather.kind;
      const x = ((x0 + (kind === 'rain' ? -.17 : .03) * now / 1000) % 1 + 1) % 1 * view.width;
      const y = ((y0 + speed * now / 1000) % 1) * view.height;
      if (kind === 'rain') {
        ctx.strokeStyle = 'rgba(208,228,255,.45)'; ctx.lineWidth = 1;
        ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(x - 4, y + 10); ctx.stroke();
      } else if (kind === 'firefly') {
        glow(ctx, x, y, 7, .35 + Math.sin(now / 300 + i) * .15);
      } else {
        ctx.fillStyle = kind === 'petal' ? '#ffd4db' : kind === 'leaf' ? '#e4a252' : '#f3f8ff';
        ctx.fillRect(Math.round(x), Math.round(y), kind === 'snow' ? 2 : 4, kind === 'snow' ? 2 : 3);
      }
    }
    if (weather.kind === 'rain') {
      ctx.fillStyle = 'rgba(201,220,255,.12)';
      for (const [x, y] of [[.48,.62],[.35,.72],[.72,.82]]) {
        const q = view.toScreen({ x: x * view.mapW, y: y * view.mapH });
        ctx.beginPath(); ctx.ellipse(q.x, q.y, 18, 3, 0, 0, Math.PI * 2); ctx.fill();
      }
    }
  }

  function actors(now, reducedMotion) {
    return [...core.NPCS.map(npc => ({ ...npc,
      ...core.npcPosition(npc, reducedMotion ? 0 : now / 1000) })), OWL];
  }

  function drawActors(ctx, view, now) {
    for (const actor of actors(now, view.reducedMotion)) {
      const q = view.toScreen({ x: actor.x * view.mapW, y: actor.y * view.mapH });
      const s = Math.max(.8, view.scale);
      const { image, crop } = imageFor(actor);
      if (image.complete && image.naturalWidth) {
        const bounds = crop || { x: 0, y: 0, w: image.naturalWidth, h: image.naturalHeight };
        const height = (actor.id === 'owl' ? 31 : 40) * s;
        const width = height * bounds.w / bounds.h;
        const bob = view.reducedMotion ? 0 : Math.floor(now / 240) % 2;
        ctx.fillStyle = 'rgba(20,10,30,.3)';
        ctx.beginPath(); ctx.ellipse(q.x, q.y, width * .3, 2.5 * s, 0, 0, Math.PI * 2); ctx.fill();
        ctx.drawImage(image, bounds.x, bounds.y, bounds.w, bounds.h,
          q.x - width / 2, q.y - height - bob, width, height);
        continue;
      }
      if (actor.id === 'owl') {
        ctx.fillStyle = '#5b3658'; ctx.fillRect(q.x - 8*s, q.y - 18*s, 16*s, 15*s);
        ctx.fillStyle = '#f4d276'; ctx.fillRect(q.x - 5*s, q.y - 14*s, 3*s, 3*s); ctx.fillRect(q.x + 3*s, q.y - 14*s, 3*s, 3*s);
      } else {
        const [coat, skin, cap] = actor.colors;
        const bob = view.reducedMotion ? 0 : Math.floor(now / 220) % 2;
        ctx.fillStyle = 'rgba(20,10,30,.3)'; ctx.fillRect(q.x - 7*s, q.y - 2*s, 14*s, 3*s);
        ctx.fillStyle = coat; ctx.fillRect(q.x - 7*s, q.y - (15+bob)*s, 14*s, 12*s);
        ctx.fillStyle = skin; ctx.fillRect(q.x - 5*s, q.y - (24+bob)*s, 10*s, 9*s);
        ctx.fillStyle = cap; ctx.fillRect(q.x - 6*s, q.y - (26+bob)*s, 12*s, 4*s);
        ctx.fillStyle = '#2d2020'; ctx.fillRect(q.x - 4*s, q.y - (19+bob)*s, 2*s, 2*s); ctx.fillRect(q.x + 2*s, q.y - (19+bob)*s, 2*s, 2*s);
        ctx.fillStyle = '#47323a'; ctx.fillRect(q.x - 5*s, q.y - 3*s, 4*s, 3*s); ctx.fillRect(q.x + s, q.y - 3*s, 4*s, 3*s);
      }
    }
  }

  function create() {
    let cachedMinute = -1, phase, weather;
    return {
      actors,
      draw(ctx, view, now) {
        const minute = Math.floor(Date.now() / 60000);
        if (minute !== cachedMinute) {
          const date = new Date();
          phase = core.phaseAt(date); weather = core.weatherAt(date); cachedMinute = minute;
        }
        tint(ctx, view.width, view.height, phase);
        if (view.reducedMotion || view.hidden) { drawActors(ctx, view, 0); return; }
        drawAmbient(ctx, view, phase, now);
        drawFountain(ctx, view, now);
        drawFlagsAndSmoke(ctx, view, now);
        drawCloudAndBirds(ctx, view, now);
        drawParticles(ctx, view, weather, phase, now);
        drawActors(ctx, view, now);
      },
      line(actor, now) {
        const date = new Date();
        return core.npcLine(actor, core.phaseAt(date).name, core.weatherAt(date).key);
      },
    };
  }
  root.NudgeTownAtmosphere = { create };
})(typeof globalThis !== 'undefined' ? globalThis : this);
