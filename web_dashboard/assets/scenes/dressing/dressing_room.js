(function (root) {
  'use strict';
  // Dressing room (J2) on profile.html: walk to the rack and pull garments
  // along it, put one on and turn once in the mirror (the reflection is the
  // live character), and flip the name card on the wall to edit it.
  // The look is kept on this device (avatar_layers.js); the name card keeps
  // every original control and Cloud call (it is the same .profile-container).
  const doc = root.document;
  const room = root.NudgePageRoom;
  const A = root.NudgeAvatarLayers;
  if (!doc || !room || !A || doc.body.dataset.page !== 'profile') return;

  const BASE = 'assets/scenes/dressing/';
  const PLACES = {
    tall: { mirror: [0.64, 0.46, 0.24, 0.22], rack: [0.1, 0.56, 0.42, 0.1], start: [0.5, 0.84], mirrorSpot: [0.6, 0.74], rackSpot: [0.3, 0.74] },
    wide: { mirror: [0.66, 0.42, 0.08, 0.3], rack: [0.2, 0.55, 0.22, 0.15], start: [0.5, 0.86], mirrorSpot: [0.62, 0.78], rackSpot: [0.3, 0.8] },
  };
  const TABS = [['outfit', '衣服'], ['headwear', '頭飾'], ['accessory', '配件'], ['body', '髮色']];
  const key = () => room.layout();
  const P = () => PLACES[key()] || PLACES.tall;

  const life = root.NudgeWorldLife?.attach(room, {
    layouts: {
      tall: { rects: { mirror: PLACES.tall.mirror, rack: PLACES.tall.rack, card: [0.43, 0.37, 0.18, 0.1], shelf: [0.12, 0.29, 0.25, 0.2] }, spots: { mirror: PLACES.tall.mirrorSpot, rack: PLACES.tall.rackSpot }, start: PLACES.tall.start, skyRect: [0.3, 0.05, 0.4, 0.19], floor: [0.64, 0.9], near: { fall: 'dust', plants: [{ x: 0.02, y: 0, size: 0.12, kind: 'ivy' }] } },
      wide: { rects: { mirror: PLACES.wide.mirror, rack: PLACES.wide.rack, card: [0.42, 0.39, 0.17, 0.13], shelf: [0.23, 0.34, 0.14, 0.2] }, spots: { mirror: PLACES.wide.mirrorSpot, rack: PLACES.wide.rackSpot }, start: PLACES.wide.start, skyRect: [0.38, 0.09, 0.26, 0.26], floor: [0.72, 0.94], near: { fall: 'dust', plants: [{ x: 0.01, y: 0, size: 0.14, kind: 'ivy' }] } },
    },
    acts: {
      mirror: { face: 'up', anim: 'look', fx: 'pop', sfx: 'sparkle', after: api => { api.player()?.spin('idle'); reflect.spin('idle'); } },
      rack: { face: 'up', fx: 'shake', sfx: 'open', after: () => openRack() },
      card: { face: 'up', anim: 'think', fx: 'lift', sfx: 'page', after: () => openCard() },
      shelf: { face: 'up', anim: 'read', fx: 'pull', sfx: 'page' },
    },
  });

  // ---- props on the art ----
  const make = (tag, cls) => { const n = doc.createElement(tag); n.className = cls; return n; };
  const mirrorImg = make('img', 'dr-prop dr-mirror');
  mirrorImg.src = BASE + 'mirror.png';
  mirrorImg.alt = '';
  const glass = make('span', 'dr-glass');
  const reflectNode = make('span', 'dr-reflect');
  glass.append(reflectNode);
  const rackImg = make('img', 'dr-prop dr-rack-art');
  rackImg.src = BASE + 'rack.png';
  rackImg.alt = '';
  const hung = make('div', 'dr-hung');
  hung.setAttribute('aria-hidden', 'true');
  room.frame.append(rackImg, hung, glass, mirrorImg);
  let reflect = A.create(reflectNode, { look: A.loadLook(), scale: 2, animation: 'idle' });

  function place(n, r) {
    Object.assign(n.style, { left: r[0] * 100 + '%', top: r[1] * 100 + '%', width: r[2] * 100 + '%', height: r[3] * 100 + '%' });
  }
  function layout() {
    const p = P();
    place(mirrorImg, p.mirror);
    place(glass, [p.mirror[0] + p.mirror[2] * 0.18, p.mirror[1] + p.mirror[3] * 0.09, p.mirror[2] * 0.64, p.mirror[3] * 0.72]);
    place(rackImg, p.rack);
    place(hung, [p.rack[0] + p.rack[2] * 0.08, p.rack[1] + p.rack[3] * 0.2, p.rack[2] * 0.84, p.rack[3] * 0.75]);
    const h = glass.getBoundingClientRect().height || 120;
    const s = Math.max(1, Math.round(h / 56));
    reflect.destroy();
    reflect = A.create(reflectNode, { look: life?.player()?.look || A.loadLook(), scale: s, animation: 'idle' });
    paintHung();
  }
  // A few garments always hang on the rack art itself.
  function paintHung() {
    hung.textContent = '';
    const look = A.loadLook();
    for (const id of A.MANIFEST.layers.outfit.map(x => x.id).slice(0, 4)) {
      const g = make('span', 'dr-garment');
      g.style.backgroundImage = `url("${A.BASE}outfit_${id}.webp")`;
      if (id === look.outfit) g.classList.add('is-worn');
      hung.append(g);
    }
  }

  // ---- the rack: drag along, tap to wear ----
  let rackPanel = null;
  function openRack() {
    if (rackPanel) { rackPanel.remove(); rackPanel = null; }
    rackPanel = make('section', 'dr-rack w-parchment');
    rackPanel.setAttribute('aria-label', '衣架：左右拖曳挑衣服');
    const tabs = make('div', 'dr-tabs');
    tabs.setAttribute('role', 'tablist');
    const rail = make('div', 'dr-rail');
    rail.setAttribute('role', 'listbox');
    rail.tabIndex = 0;
    const close = make('button', 'w-btn dr-close');
    close.type = 'button';
    close.textContent = '收起衣架';
    close.addEventListener('click', () => { rackPanel?.remove(); rackPanel = null; room.object('rack')?.focus(); });
    let tab = 'outfit';
    function fill() {
      rail.textContent = '';
      const look = life?.player()?.look || A.loadLook();
      const items = A.MANIFEST.layers[tab].map(x => ({ ...x }));
      if (tab === 'headwear' || tab === 'accessory') items.unshift({ id: null, name: '不戴' });
      for (const it of items) {
        const b = make('button', 'dr-item');
        b.type = 'button';
        b.setAttribute('role', 'option');
        b.setAttribute('aria-selected', String(look[tab] === it.id));
        b.dataset.part = `${tab}:${it.id ?? 'none'}`;
        const pic = make('span', 'dr-item-pic');
        if (it.id) {
          const stack = tab === 'body' ? [`body_${it.id}`] : tab === 'outfit' ? [`outfit_${it.id}`] : [`body_${look.body}`, `${tab}_${it.id}`];
          pic.style.backgroundImage = stack.reverse().map(f => `url("${A.BASE}${f}.webp")`).join(',');
        }
        b.append(make('i', 'dr-hook'), pic, Object.assign(make('span', 'dr-item-name'), { textContent: it.name }));
        b.addEventListener('click', () => {
          if (moved > 6) return;
          life?.setLook({ [tab]: it.id }, { spin: true, save: true });
          reflect.setLook({ [tab]: it.id }, { spin: true });
          root.NudgeSfx?.play('sparkle');
          life?.emote('player', 'star');
          room.announce?.(`換上了${it.name}`);
          paintHung();
          fill();
        });
        rail.append(b);
      }
    }
    for (const [id, label] of TABS) {
      const t = make('button', 'w-btn dr-tab');
      t.type = 'button';
      t.setAttribute('role', 'tab');
      t.textContent = label;
      t.setAttribute('aria-selected', String(id === tab));
      t.addEventListener('click', () => {
        tab = id;
        [...tabs.children].forEach(c => c.setAttribute('aria-selected', String(c === t)));
        fill();
        rail.scrollLeft = 0;
      });
      tabs.append(t);
    }
    // Drag the rail like sliding hangers along a pole.
    let down = null, moved = 0;
    rail.addEventListener('pointerdown', e => { down = { x: e.clientX, left: rail.scrollLeft }; moved = 0; });
    rail.addEventListener('pointermove', e => {
      if (!down) return;
      moved = Math.abs(e.clientX - down.x);
      rail.scrollLeft = down.left - (e.clientX - down.x);
      rail.classList.toggle('is-sliding', moved > 6);
    });
    const up = () => { down = null; root.setTimeout(() => { moved = 0; rail.classList.remove('is-sliding'); }, 0); };
    rail.addEventListener('pointerup', up);
    rail.addEventListener('pointerleave', up);
    rail.addEventListener('keydown', e => {
      if (e.key === 'ArrowRight') rail.scrollBy({ left: 120 });
      if (e.key === 'ArrowLeft') rail.scrollBy({ left: -120 });
    });
    fill();
    rackPanel.append(tabs, rail, close);
    room.stage.append(rackPanel);
    tabs.firstChild.focus();
  }

  // ---- the name card: flip to edit ----
  const profile = doc.querySelector('.profile-container');
  const flip = make('div', 'dr-card');
  const inner = make('div', 'dr-card-inner');
  const front = make('div', 'dr-card-face dr-card-front w-parchment');
  const back = make('div', 'dr-card-face dr-card-back');
  const portrait = make('span', 'dr-card-portrait');
  const fName = make('h3', 'dr-card-name');
  const fSign = make('p', 'dr-card-sign');
  const fTitle = make('p', 'dr-card-title w-chip');
  const toBack = make('button', 'w-btn is-gold');
  toBack.type = 'button';
  toBack.textContent = '翻到背面編輯 ↻';
  const toFront = make('button', 'w-btn dr-card-turn');
  toFront.type = 'button';
  toFront.textContent = '↺ 翻回正面';
  front.append(portrait, fName, fTitle, fSign, toBack);
  if (profile) back.append(toFront, profile);
  inner.append(front, back);
  flip.append(inner);
  flip.hidden = true;
  room.stage.after(flip);
  let cardAvatar = null;
  const sync = () => {
    fName.textContent = doc.getElementById('profileMainName')?.textContent || '你的名片';
    fSign.textContent = doc.getElementById('profileMainSignature')?.textContent || '';
    fTitle.textContent = doc.getElementById('profileMainBadge')?.textContent?.trim() || '小鎮居民';
  };
  function turn(toBackSide) {
    root.NudgeSfx?.play('page');
    flip.classList.toggle('is-flipped', toBackSide);
    (toBackSide ? toFront : toBack).focus();
  }
  toBack.addEventListener('click', () => turn(true));
  toFront.addEventListener('click', () => turn(false));
  function openCard() {
    sync();
    if (profile) profile.hidden = false;
    cardAvatar?.destroy();
    cardAvatar = A.create(portrait, { look: A.loadLook(), scale: 2, animation: 'wave' });
    flip.classList.remove('is-flipped');
    room.openPanel({ title: '名片', content: flip, from: room.object('card'), onClose: () => { cardAvatar?.destroy(); cardAvatar = null; } });
  }

  layout();
  root.addEventListener('resize', () => root.setTimeout(layout, 160));
  root.NudgeDressingRoom = Object.freeze({ openRack, openCard, life });
})(typeof globalThis !== 'undefined' ? globalThis : this);
