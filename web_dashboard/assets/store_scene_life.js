(function (root) {
  'use strict';
  // Store 2.0 (J5) on top of store_scene.js: the player walks to each shelf,
  // Chestnut greets, lifts the item you picked to show it, wraps your
  // purchase, takes the coins into the cash box and waves you out; the cat
  // wakes up; a new item is unboxed in the shop. The mirror lets you try a
  // garment on (layered character, nothing saved or bought) and furniture is
  // previewed inside your own cabin. All money still goes through the Cloud
  // ledger in reward_shop.js; this file only animates.
  const doc = root.document;
  const room = root.NudgeStoreRoom;
  const A = root.NudgeAvatarLayers;
  if (!doc || !room || !root.NudgeWorldLife) return;

  const life = root.NudgeWorldLife.attach(room, {
    layouts: {
      wide: {
        rects: { clothes: [0.05, 0.2, 0.24, 0.45], furniture: [0.33, 0.2, 0.24, 0.35], cabinet: [0.59, 0.17, 0.16, 0.46], cashbox: [0.26, 0.5, 0.09, 0.12], cat: [0.43, 0.55, 0.1, 0.07], mirror: [0.76, 0.33, 0.23, 0.42] },
        spots: { cashbox: [0.32, 0.78], cat: [0.48, 0.78] }, start: [0.55, 0.9], floor: [0.72, 0.96], skyRect: [0.08, 0.04, 0.22, 0.1],
        near: { fall: 'dust', count: 16, plants: [{ x: 0.99, size: 0.18, kind: 'fern' }] },
      },
      tall: {
        rects: { clothes: [0.03, 0.235, 0.3, 0.225], furniture: [0.35, 0.235, 0.265, 0.23], cabinet: [0.65, 0.19, 0.215, 0.27], cashbox: [0.06, 0.49, 0.15, 0.085], cat: [0.29, 0.51, 0.25, 0.065], mirror: [0.75, 0.48, 0.24, 0.3] },
        spots: { cashbox: [0.2, 0.7], cat: [0.4, 0.7], mirror: [0.78, 0.84] }, start: [0.5, 0.9], floor: [0.66, 0.95], skyRect: [0.12, 0.03, 0.15, 0.1],
        near: { fall: 'dust', count: 12, plants: [{ x: 0.99, size: 0.12, kind: 'fern' }] },
      },
    },
    acts: {
      clothes: { fx: 'shake', sfx: 'open', face: 'up', anim: 'look' },
      furniture: { fx: 'shake', sfx: 'open', face: 'up', anim: 'look' },
      cabinet: { fx: 'lamp', sfx: 'sparkle', face: 'up', anim: 'think' },
      cashbox: { fx: 'pull', sfx: 'coin', face: 'up' },
      cat: { fx: 'pop', sfx: 'heart', face: 'up', anim: 'wave', emote: 'heart' },
      mirror: { fx: 'pop', sfx: 'sparkle', face: 'up', after: () => tryOn() },
    },
  });

  const make = (tag, cls, text) => { const n = doc.createElement(tag); n.className = cls; if (text != null) n.textContent = text; return n; };

  // Chestnut greets the customer as the door opens.
  root.setTimeout(() => { life.npcAct('wave'); life.emote(room.npcButton, 'wave'); }, 500);

  // Showing the lifted item: Chestnut holds it up, furniture is previewed at home.
  let held = null, preview = null;
  root.addEventListener('nudge-shop-lift', e => {
    const item = e.detail.item;
    held?.remove();
    held = make('span', 'ss-held');
    const img = make('img', 'ss-held-img');
    img.src = item.image;
    img.alt = '';
    held.append(img);
    room.npcButton?.append(held);
    life.npcAct('happy');
    if (item.kind === 'decor') showInCabin(item);
  });

  async function showInCabin(item) {
    preview?.remove();
    let layout = null;
    try { layout = await (await root.fetch('assets/home/cabin_layout.json')).json(); } catch { return; }
    const layer = layout?.layers?.[item.slot];
    if (!layer) return;
    preview = make('figure', 'ss-cabin w-parchment');
    preview.setAttribute('aria-label', `「${item.name}」擺在你的小屋裡的樣子`);
    const box = make('div', 'ss-cabin-room');
    const base = make('img', 'ss-cabin-base');
    base.src = 'assets/scenes/cabin/room_base_mid.webp';
    base.alt = '';
    const sky = make('span', 'ss-cabin-sky');
    const piece = make('img', 'ss-cabin-piece');
    piece.src = item.image;
    piece.alt = '';
    const r = (layer.rects && layer.rects[item.variant - 1]) || layer.rect;
    Object.assign(piece.style, { left: r[0] * 100 + '%', top: r[1] * 100 + '%', width: r[2] * 100 + '%', height: r[3] * 100 + '%' });
    box.append(sky, base, piece);
    const cap = make('figcaption', '', `在你的小屋試擺：${item.name}`);
    const close = make('button', 'w-btn', '收起');
    close.type = 'button';
    close.addEventListener('click', () => { preview?.remove(); preview = null; });
    preview.append(box, cap, close);
    doc.body.append(preview);
  }

  // Purchase: wrap, take the coins, wake the cat, unbox, wave goodbye.
  root.addEventListener('nudge-shop-purchase', e => {
    const { item, alreadyUnlocked } = e.detail;
    held?.remove();
    preview?.remove();
    if (alreadyUnlocked) return;
    const L = life.layout();
    life.piece('cashbox', 'pull');
    root.setTimeout(() => { life.piece('cat', 'pop'); life.emote(room.object('cat'), '!'); }, 600);
    unbox(item);
    root.setTimeout(() => { life.npcAct('wave'); life.player()?.play('happy'); }, 2600);
    void L;
  });

  function unbox(item) {
    const reduced = root.matchMedia('(prefers-reduced-motion: reduce)').matches;
    const stage = make('div', 'ss-unbox');
    stage.setAttribute('role', 'status');
    stage.setAttribute('aria-live', 'polite');
    const gift = make('div', 'ss-gift');
    gift.append(make('span', 'ss-gift-lid'), make('span', 'ss-gift-body'), make('span', 'ss-gift-ribbon'));
    const prize = make('img', 'ss-prize');
    prize.src = item.image;
    prize.alt = '';
    const label = make('p', 'ss-unbox-text', `打開包裹：${item.name}！`);
    stage.append(gift, prize, label);
    room.stage.append(stage);
    root.NudgeSfx?.play('open');
    root.setTimeout(() => root.NudgeSfx?.play('sparkle'), 900);
    root.setTimeout(() => stage.remove(), reduced ? 1800 : 3000);
    stage.addEventListener('click', () => stage.remove());
  }

  // Try-on at the mirror: nothing is saved or bought.
  let fitting = null;
  function tryOn() {
    if (!A) { root.location.href = 'profile.html'; return; }
    fitting?.remove();
    fitting = make('section', 'ss-fitting w-parchment');
    fitting.setAttribute('aria-label', '鏡子：試穿看看');
    const mirror = make('div', 'ss-mirror');
    const me = make('span', 'ss-mirror-me');
    mirror.append(me);
    const base = A.loadLook();
    const p = A.create(me, { look: base, scale: 2, animation: 'idle', label: '鏡子裡的你' });
    const rail = make('div', 'ss-try');
    for (const o of A.MANIFEST.layers.outfit) {
      const b = make('button', 'w-btn', o.name);
      b.type = 'button';
      b.addEventListener('click', () => { p.setLook({ outfit: o.id }, { spin: true }); root.NudgeSfx?.play('sparkle'); });
      rail.append(b);
    }
    for (const h of A.MANIFEST.layers.headwear) {
      const b = make('button', 'w-btn', h.name);
      b.type = 'button';
      b.addEventListener('click', () => { p.setLook({ headwear: h.id }, { spin: true }); });
      rail.append(b);
    }
    const note = make('p', 'w-muted', '試穿不會花錢，也不會換掉你身上的衣服。喜歡的話到更衣室換上。');
    const go = make('a', 'w-btn is-gold', '去更衣室');
    go.href = 'profile.html';
    go.dataset.wlDoor = '1';
    const close = make('button', 'w-btn', '離開鏡子');
    close.type = 'button';
    close.addEventListener('click', () => { p.destroy(); fitting.remove(); fitting = null; room.object('mirror')?.focus(); });
    fitting.append(mirror, rail, note, go, close);
    room.stage.append(fitting);
    close.focus();
  }

  root.NudgeStoreLife = Object.freeze({ life, tryOn, unbox });
})(typeof globalThis !== 'undefined' ? globalThis : this);
