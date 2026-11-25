(function(root) {
  'use strict';
  // Living town renderer (#200 H1): far / mid / near layers, district ground,
  // day-night light and building reactions around the market map.
  // Generated art is read from assets/scenes/town_world/; until a file exists
  // the same layer is drawn here as crisp pixel shapes, so the world is never
  // blank. Everything is presentation only.
  const world = root.NudgeTownWorldCore;
  const doc = root.document;
  if (!world || !doc) return;

  const ART_DIR = 'assets/scenes/town_world/';
  // Ground is a seamless tile; buildings, trees and bushes are keyed sprites
  // placed by the engine so art never disagrees with walls and doors.
  const ART = { far: 'far_mountains.webp', grass: 'grass_tile.webp', forest: 'forest_tile.webp',
    cottageA: 'cottage_a.png', cottageB: 'cottage_b.png', treeA: 'tree_oak.png', treeB: 'tree_pine.png',
    bush: 'bush_flowers.png', windmill: 'windmill.png' };
  const art = {};
  for (const [key, file] of Object.entries(ART)) {
    const image = new Image();
    image.decoding = 'async';
    image.onerror = () => { art[key] = null; };
    image.src = ART_DIR + file;
    art[key] = image;
  }
  const ready = key => art[key]?.complete && art[key].naturalWidth > 0;

  const C = { grass: '#5d7a3e', grassDark: '#4a6332', path: '#c7a46a', pathEdge: '#9b7a46', water: '#3d6f9e',
    waterLight: '#7fb2d6', wood: '#6b452c', woodDark: '#3b261d', roof: '#8e3f3a', roofDark: '#6a2c2a',
    wall: '#e9d2a6', window: '#2a2440', glow: '#ffd77a', trunk: '#5a3a24', leaf: '#3f6b35', leafLight: '#5f8f45',
    stone: '#9c95a3', mountain: '#4b3f78', mountainFar: '#6a5c96', snow: '#e7e2f4', cloud: '#f1e6ff' };

  let lastNear = null;
  const t = (now, reduced) => (reduced ? 0 : now / 1000);
  const px = (ctx, x, y, w, h, color) => { ctx.fillStyle = color; ctx.fillRect(Math.round(x), Math.round(y), Math.ceil(w), Math.ceil(h)); };

  function screenRect(view, r) {
    const a = view.toScreen({ x: r.x, y: r.y });
    return { x: a.x, y: a.y, w: r.w * view.scale, h: r.h * view.scale };
  }
  function visible(view, r) {
    const s = screenRect(view, r);
    return s.x < view.width && s.y < view.height && s.x + s.w > 0 && s.y + s.h > 0;
  }

  // ---------- far layer: sky band, mountains, castle, clouds (parallax) ----------
  function drawFar(ctx, view, now) {
    const top = screenRect(view, { x: world.WORLD.x, y: world.WORLD.y, w: world.WORLD.w, h: 120 });
    if (top.y + top.h < 0) return;
    const shift = -(view.camera.x - world.WORLD.x) * view.scale * 0.25;
    const sky = view.light.name === 'night' ? '#241c46' : view.light.name === 'dusk' ? '#6b3f6e' : view.light.name === 'morning' ? '#d9a0a0' : '#8fb6dd';
    px(ctx, 0, top.y - view.height, view.width, view.height + top.h, sky);
    if (ready('far')) {
      const image = art.far;
      const h = top.h + 60 * view.scale;
      const w = h * image.naturalWidth / image.naturalHeight;
      for (let x = (shift % w) - w; x < view.width; x += w) ctx.drawImage(image, x, top.y + top.h - h, w, h);
    } else {
      const unit = Math.max(2, Math.round(3 * view.scale));
      for (const [color, height, period, offset] of [[C.mountainFar, 0.95, 260, 0.6], [C.mountain, 0.7, 190, 1]]) {
        for (let x = 0; x < view.width; x += unit) {
          const wx = (x - shift * offset) / view.scale;
          const peak = (Math.sin(wx / period) * 0.5 + Math.sin(wx / (period * 0.37)) * 0.25 + 0.75) * height;
          const ph = Math.round((top.h * peak) / unit) * unit;
          px(ctx, x, top.y + top.h - ph, unit, ph, color);
          if (color === C.mountainFar && peak > 0.85) px(ctx, x, top.y + top.h - ph, unit, unit * 2, C.snow);
        }
      }
      const castle = view.toScreen({ x: 1500, y: world.WORLD.y + 40 });
      const cx = castle.x + shift * 0.4, cy = top.y + top.h * 0.35, u = unit;
      px(ctx, cx, cy, u * 14, u * 10, C.mountain);
      for (let i = 0; i < 4; i++) px(ctx, cx + i * u * 4, cy - u * 3, u * 2, u * 3, C.mountain);
      px(ctx, cx + u * 5, cy - u * 8, u * 4, u * 8, C.mountain);
      if (view.light.name !== 'day') px(ctx, cx + u * 6, cy - u * 6, u * 2, u * 2, C.glow);
    }
    const drift = t(now, view.reducedMotion) * 8 * view.scale;
    const unit = Math.max(2, Math.round(3 * view.scale));
    for (let i = 0; i < 5; i++) {
      const span = view.width + 240;
      const x = ((i * 337 + drift + shift * 0.1) % span + span) % span - 120;
      const y = top.y + 10 + (i % 3) * 18 * view.scale;
      ctx.globalAlpha = view.light.name === 'night' ? 0.35 : 0.8;
      px(ctx, x, y, unit * 18, unit * 3, C.cloud);
      px(ctx, x + unit * 4, y - unit * 2, unit * 9, unit * 2, C.cloud);
      ctx.globalAlpha = 1;
    }
  }

  // Seamless ground tile, aligned to world coordinates so it never swims.
  const TILE = 256;
  function tile(ctx, view, image, r) {
    const x0 = Math.max(r.x, view.camera.x - view.width / view.scale / 2 - TILE);
    const y0 = Math.max(r.y, view.camera.y - view.height / view.scale / 2 - TILE);
    const x1 = Math.min(r.x + r.w, view.camera.x + view.width / view.scale / 2 + TILE);
    const y1 = Math.min(r.y + r.h, view.camera.y + view.height / view.scale / 2 + TILE);
    ctx.save();
    const clip = screenRect(view, r);
    ctx.beginPath();
    ctx.rect(clip.x, clip.y, clip.w, clip.h);
    ctx.clip();
    for (let wy = Math.floor(y0 / TILE) * TILE; wy < y1; wy += TILE) {
      for (let wx = Math.floor(x0 / TILE) * TILE; wx < x1; wx += TILE) {
        const p = view.toScreen({ x: wx, y: wy });
        ctx.drawImage(image, Math.floor(p.x), Math.floor(p.y), Math.ceil(TILE * view.scale) + 1, Math.ceil(TILE * view.scale) + 1);
      }
    }
    ctx.restore();
  }

  // ---------- district ground (art or pixel stand-in) ----------
  function drawGround(ctx, view) {
    const fills = [
      ['forest', world.DISTRICTS[1].rects[0]], ['grass', world.DISTRICTS[2].rects[0]],
      ['grass', world.DISTRICTS[3].rects[0]], ['grass', world.DISTRICTS[3].rects[1]],
    ];
    for (const [key, r] of fills) {
      if (!visible(view, r)) continue;
      const s = screenRect(view, r);
      if (ready(key)) { tile(ctx, view, art[key], r); continue; }
      px(ctx, s.x, s.y, s.w, s.h, key === 'forest' ? C.grassDark : C.grass);
      const step = Math.max(8, Math.round(24 * view.scale));
      for (let y = 0; y < s.h; y += step) {
        for (let x = (y / step) % 2 ? step / 2 : 0; x < s.w; x += step * 2) px(ctx, s.x + x, s.y + y, step / 3, step / 3, key === 'forest' ? C.leaf : C.grassDark);
      }
    }
    // Dirt paths joining the districts to the market roads.
    for (const path of [
      { x: -836, y: 610, w: 836, h: 46 }, { x: -450, y: 0, w: 46, h: 1411 }, { x: 1672, y: 610, w: 300, h: 46 },
      { x: 780, y: 941, w: 46, h: 200 }, { x: -836, y: -330, w: 3344, h: 40 }, { x: 760, y: -330, w: 46, h: 330 },
    ]) {
      if (!visible(view, path)) continue;
      const s = screenRect(view, path);
      px(ctx, s.x, s.y, s.w, s.h, C.pathEdge);
      px(ctx, s.x + 3 * view.scale, s.y + 3 * view.scale, s.w - 6 * view.scale, s.h - 6 * view.scale, C.path);
    }
  }

  // ---------- mid layer: water, houses, windmill, waterwheel, flags, trees ----------
  function drawWater(ctx, view, r, now) {
    if (!visible(view, r)) return;
    const s = screenRect(view, r);
    px(ctx, s.x, s.y, s.w, s.h, C.water);
    const unit = Math.max(2, Math.round(3 * view.scale));
    const time = t(now, view.reducedMotion);
    for (let i = 0; i < 9; i++) {
      const x = s.x + ((i * 97 + time * 22 * view.scale) % s.w);
      const y = s.y + ((i * 43) % Math.max(1, s.h - unit));
      px(ctx, x, y, unit * 6, unit, C.waterLight);
    }
  }

  function drawHouse(ctx, view, house, now) {
    const r = { x: house.x, y: house.y, w: house.w, h: house.h };
    if (!visible(view, r)) return [];
    const s = screenRect(view, r);
    const u = Math.max(2, Math.round(3 * view.scale));
    const spriteKey = Number(house.id.slice(1)) % 2 ? 'cottageA' : 'cottageB';
    const sprite = ready(spriteKey) ? art[spriteKey] : null;
    if (sprite) {
      const h = s.w * sprite.naturalHeight / sprite.naturalWidth;
      ctx.drawImage(sprite, Math.round(s.x), Math.round(s.y + s.h - h), Math.round(s.w), Math.round(h));
    } else {
      px(ctx, s.x, s.y + s.h * 0.4, s.w, s.h * 0.6, C.wall);
      for (let i = 0; i < 6; i++) px(ctx, s.x - u + i * u, s.y + s.h * 0.4 - i * s.h * 0.066, s.w + 2 * u - i * 2 * u, s.h * 0.07, i % 2 ? C.roofDark : C.roof);
      px(ctx, s.x + s.w * 0.44, s.y + s.h * 0.68, s.w * 0.14, s.h * 0.32, C.woodDark);
    }
    const chimney = { x: s.x + s.w * house.chimney[0], y: s.y + s.h * 0.08 };
    if (!sprite) px(ctx, chimney.x, chimney.y, u * 4, s.h * 0.2, C.woodDark);
    const time = t(now, view.reducedMotion);
    for (let i = 0; i < 3; i++) {
      const rise = view.reducedMotion ? i * 10 : ((time * 14 + i * 12) % 36);
      ctx.globalAlpha = Math.max(0, 0.7 - rise / 50);
      px(ctx, chimney.x + Math.sin(time + i) * u, chimney.y - rise * view.scale - u * 2, u * 3, u * 3, '#d8d0e0');
    }
    ctx.globalAlpha = 1;
    return house.windows.map(([wx, wy], index) => ({
      id: `${house.id}:${index}`, art: Boolean(sprite), x: s.x + s.w * wx - u * 3, y: s.y + s.h * wy, w: u * 6, h: u * 6,
    }));
  }

  function drawWheel(ctx, view, centre, radius, spokes, now, speed, colors) {
    const p = view.toScreen(centre);
    const u = Math.max(2, Math.round(3 * view.scale));
    const angle = t(now, view.reducedMotion) * speed;
    for (let i = 0; i < spokes; i++) {
      const a = angle + (i * Math.PI * 2) / spokes;
      for (let d = 0; d < radius; d += 3) px(ctx, p.x + Math.cos(a) * d * view.scale, p.y + Math.sin(a) * d * view.scale, u * 2, u * 2, colors[i % colors.length]);
    }
    px(ctx, p.x - u * 2, p.y - u * 2, u * 4, u * 4, C.woodDark);
  }

  function drawTrees(ctx, view, now) {
    const time = t(now, view.reducedMotion);
    const u = Math.max(2, Math.round(3 * view.scale));
    for (let i = 0; i < 140; i++) {
      const tree = { x: -820 + (i * 211) % 3320, y: -350 + (i * 53) % 260, w: 40, h: 60 };
      if (!visible(view, tree)) continue;
      const p = view.toScreen({ x: tree.x, y: tree.y + 60 });
      const sway = Math.round(Math.sin(time * 1.4 + i) * 2) * u * 0.5;
      const treeSprite = ready(i % 3 ? 'treeA' : 'treeB') ? art[i % 3 ? 'treeA' : 'treeB'] : null;
      if (treeSprite) {
        const th = 70 * view.scale, tw = th * treeSprite.naturalWidth / treeSprite.naturalHeight;
        ctx.drawImage(treeSprite, Math.round(p.x - tw / 2 + sway), Math.round(p.y - th), Math.round(tw), Math.round(th));
        continue;
      }
      px(ctx, p.x - u, p.y - 18 * view.scale, u * 2, 18 * view.scale, C.trunk);
      px(ctx, p.x - 14 * view.scale + sway, p.y - 46 * view.scale, 28 * view.scale, 30 * view.scale, C.leaf);
      px(ctx, p.x - 8 * view.scale + sway, p.y - 52 * view.scale, 16 * view.scale, 10 * view.scale, C.leafLight);
    }
  }

  function drawFlags(ctx, view, now) {
    const time = t(now, view.reducedMotion);
    const u = Math.max(2, Math.round(2 * view.scale));
    for (const [i, flag] of world.LANDMARKS.flags.entries()) {
      const p = view.toScreen(flag);
      px(ctx, p.x, p.y, u, 26 * view.scale, C.woodDark);
      for (let k = 0; k < 6; k++) px(ctx, p.x + u + k * u * 2, p.y + Math.round(Math.sin(time * 4 + k * 0.8 + i) * 1.5) * u, u * 2, (10 - k) * view.scale, i % 2 ? '#c94f4f' : '#ffc54d');
    }
  }

  function drawFountain(ctx, view, now) {
    const p = view.toScreen(world.LANDMARKS.fountain);
    const u = Math.max(2, Math.round(2 * view.scale));
    const time = t(now, view.reducedMotion);
    for (let i = 0; i < 8; i++) {
      const phase = view.reducedMotion ? i / 8 : (time * 1.3 + i / 8) % 1;
      const angle = (i / 8) * Math.PI * 2;
      const r = phase * 16 * view.scale;
      ctx.globalAlpha = 0.85 - phase * 0.6;
      px(ctx, p.x + Math.cos(angle) * r, p.y - 10 * view.scale - Math.sin(phase * Math.PI) * 12 * view.scale, u, u, C.waterLight);
    }
    ctx.globalAlpha = 1;
  }

  function drawQueue(ctx, view, hour, dayKey) {
    const u = Math.max(2, Math.round(2 * view.scale));
    const colors = ['#8a472e', '#496b9b', '#566e43', '#7a4f8f'];
    for (const person of world.bakeryQueue(hour, dayKey)) {
      const p = view.toScreen(person);
      px(ctx, p.x - u * 2, p.y - u * 9, u * 4, u * 4, '#f2cba0');
      px(ctx, p.x - u * 3, p.y - u * 5, u * 6, u * 5, colors[person.look]);
    }
  }

  // Building reaction: doorway opens and the sign glows when the player is near.
  function drawDoors(ctx, view, buildings, player) {
    let near = null;
    for (const b of buildings) {
      const d = Math.hypot(player.x - b.door.x, player.y - b.door.y);
      const state = world.doorState(d);
      if (state.open > 0) {
        const p = view.toScreen(b.door);
        const w = 12 * view.scale, h = 18 * view.scale;
        px(ctx, p.x - w / 2, p.y - h, w, h, C.woodDark);
        px(ctx, p.x - w / 2, p.y - h, w * (1 - state.open), h, C.wood);
        ctx.globalAlpha = 0.55 * state.open;
        px(ctx, p.x - w / 2 + w * (1 - state.open), p.y - h, w * state.open, h, C.glow);
        ctx.globalAlpha = 1;
      }
      if (state.sign && (!near || d < near.d)) near = { id: b.id, d };
    }
    if (near?.id !== lastNear) {
      if (near) root.NudgeTownAudio?.effect?.('door_open.wav');
      lastNear = near?.id || null;
    }
    return near?.id || null;
  }

  // ---------- near layer: foreground foliage and falling petals ----------
  function drawNear(ctx, view, now) {
    const time = t(now, view.reducedMotion);
    const u = Math.max(3, Math.round(4 * view.scale));
    const shift = -(view.camera.x) * view.scale * 0.15;
    for (let i = 0; i < 7; i++) {
      const span = view.width + 200;
      const x = ((i * 233 + shift) % span + span) % span - 100;
      const sway = Math.round(Math.sin(time * 1.8 + i) * 2) * u * 0.5;
      const y = view.height - u * 4;
      if (ready('bush')) {
        const bw = u * 16, bh = bw * art.bush.naturalHeight / art.bush.naturalWidth;
        ctx.drawImage(art.bush, Math.round(x + sway), Math.round(view.height - bh * 0.7), Math.round(bw), Math.round(bh));
        continue;
      }
      px(ctx, x + sway, y - u * 3, u * 8, u * 7, C.leaf);
      px(ctx, x + u * 2 + sway, y - u * 5, u * 4, u * 3, C.leafLight);
      if (i % 2) px(ctx, x + u * 5 + sway, y - u * 4, u, u, '#f2a7c3');
    }
    if (view.reducedMotion) return;
    for (let i = 0; i < 10; i++) {
      const fall = (time * 30 + i * 70) % (view.height + 40);
      const x = (i * 157 + Math.sin(time + i) * 30 + shift * 0.5) % view.width;
      px(ctx, (x + view.width) % view.width, fall - 20, u * 0.75, u * 0.5, '#f6c1d6');
    }
  }

  function drawLight(ctx, view, windows, now) {
    const { rgb, alpha } = view.light;
    const sky = world.skyFor(view.weather);
    if (alpha > 0) {
      ctx.fillStyle = `rgba(${rgb[0]},${rgb[1]},${rgb[2]},${alpha})`;
      ctx.fillRect(0, 0, view.width, view.height);
    }
    if (sky === 'rain') { ctx.fillStyle = 'rgba(60,64,90,0.18)'; ctx.fillRect(0, 0, view.width, view.height); }
    if (sky === 'snow') { ctx.fillStyle = 'rgba(235,235,255,0.1)'; ctx.fillRect(0, 0, view.width, view.height); }
    for (const win of windows) {
      if (!world.windowLit(win.id, view.phase, view.minutesIntoPhase, view.hour)) {
        if (!win.art) px(ctx, win.x, win.y, win.w, win.h, C.window);
        continue;
      }
      ctx.globalAlpha = 0.35;
      px(ctx, win.x - win.w * 0.5, win.y - win.h * 0.5, win.w * 2, win.h * 2, C.glow);
      ctx.globalAlpha = 1;
      px(ctx, win.x, win.y, win.w, win.h, C.glow);
    }
  }

  /** Behind the market map: sky, far layer, district ground and water. */
  function drawBehind(ctx, view, now) {
    drawGround(ctx, view);
    drawFar(ctx, view, now);
    drawWater(ctx, view, world.LANDMARKS.lake, now);
    drawWater(ctx, view, world.LANDMARKS.pond, now);
  }

  /** On top of the market map, below characters: the mid-layer life. */
  function drawMid(ctx, view, now) {
    const windows = world.HOUSES.flatMap(house => drawHouse(ctx, view, house, now));
    drawTrees(ctx, view, now);
    if (ready('windmill')) {
      const p = view.toScreen(world.LANDMARKS.windmill);
      const mh = 120 * view.scale, mw = mh * art.windmill.naturalWidth / art.windmill.naturalHeight;
      ctx.drawImage(art.windmill, Math.round(p.x - mw / 2), Math.round(p.y - mh * 0.15), Math.round(mw), Math.round(mh));
    }
    drawWheel(ctx, view, world.LANDMARKS.windmill, 46, 4, now, 0.8, ['#e9d2a6', '#c9a46b']);
    drawWheel(ctx, view, world.LANDMARKS.waterwheel, 30, 8, now, 1.2, [C.wood, C.woodDark]);
    drawFlags(ctx, view, now);
    drawFountain(ctx, view, now);
    drawQueue(ctx, view, view.hour, view.dayKey);
    const nearId = drawDoors(ctx, view, view.buildings, view.player);
    return { windows, nearId };
  }

  /** Above everything in the world: near foliage, light and window glow. */
  function drawFront(ctx, view, mid, now) {
    drawNear(ctx, view, now);
    drawLight(ctx, view, mid.windows, now);
  }

  root.NudgeTownWorld = { drawBehind, drawMid, drawFront, ART_DIR, ART };
})(typeof globalThis !== 'undefined' ? globalThis : this);
