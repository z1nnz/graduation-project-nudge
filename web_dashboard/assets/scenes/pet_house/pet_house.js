(function (root) {
  'use strict';
  // Pet house (J3): a garden corner behind the cabin. Walk to a pet to pick
  // it, fill the bowl with a treat, pat it on the cushion, read the growth
  // board. Choice stays on this device; growth reads existing Cloud-confirmed
  // focus minutes only; treats and pats change no numbers.
  const doc = root.document;
  const Pets = root.NudgePets;
  if (!doc || !Pets || !root.NudgeSceneRoom) return;
  const BASE = 'assets/scenes/pet_house/';

  const LAYOUTS = {
    wide: {
      art: 'assets/scenes/garden/garden_wide_mid.webp', aspect: 1.5, npcAt: [0.62, 0.92],
      rects: {
        house: [0.08, 0.54, 0.12, 0.2], bowl: [0.2, 0.82, 0.05, 0.05], cushion: [0.31, 0.83, 0.08, 0.06],
        board: [0.57, 0.62, 0.07, 0.13], pick_owl: [0.23, 0.62, 0.045, 0.08], pick_fox: [0.3, 0.68, 0.045, 0.08],
        pick_slime: [0.37, 0.62, 0.045, 0.08],
      },
      skyRect: [0, 0, 1, 0.1], floor: [0.62, 0.92], start: [0.45, 0.86],
      near: { fall: 'petals', count: 16, plants: [{ x: 0.02, size: 0.22, kind: 'flowers' }, { x: 0.98, size: 0.2, kind: 'fern' }] },
    },
    tall: {
      art: 'assets/scenes/garden/garden_mid.webp', aspect: 2 / 3, npcAt: [0.75, 0.93],
      rects: {
        house: [0.05, 0.55, 0.26, 0.12], bowl: [0.08, 0.84, 0.1, 0.035], cushion: [0.24, 0.84, 0.16, 0.04],
        board: [0.44, 0.6, 0.14, 0.09], pick_owl: [0.1, 0.69, 0.1, 0.06], pick_fox: [0.23, 0.73, 0.1, 0.06],
        pick_slime: [0.35, 0.68, 0.1, 0.06],
      },
      skyRect: [0, 0, 1, 0.07], floor: [0.62, 0.95], start: [0.5, 0.9],
      near: { fall: 'petals', count: 12, plants: [{ x: 0.03, size: 0.14, kind: 'flowers' }, { x: 0.97, size: 0.12, kind: 'fern' }] },
    },
  };

  let overlay = null;

  function open() {
    if (overlay) return;
    overlay = doc.createElement('div');
    overlay.className = 'ph-overlay';
    overlay.setAttribute('role', 'dialog');
    overlay.setAttribute('aria-modal', 'true');
    overlay.setAttribute('aria-label', '寵物小屋');
    const bar = doc.createElement('div');
    bar.className = 'ph-bar';
    const back = doc.createElement('button');
    back.type = 'button';
    back.className = 'w-btn';
    back.textContent = '← 回小屋';
    back.addEventListener('click', close);
    const title = doc.createElement('h2');
    title.textContent = '寵物小屋';
    const growth = doc.createElement('span');
    growth.className = 'w-chip is-wait';
    growth.id = 'petGrowthChip';
    growth.textContent = '雲端確認中';
    bar.append(back, title, growth);
    const host = doc.createElement('div');
    host.className = 'ph-host';
    overlay.append(bar, host);
    doc.body.append(overlay);
    doc.body.classList.add('ph-open');

    let minutes = null;
    let stage = Pets.cachedStage();
    let choice = Pets.loadChoice();
    const name = id => Pets.speciesInfo(id)?.name || '寵物';
    let life = null;
    const say = (lines, actions) => (life ? life.say(lines, actions) : room.say(lines, actions));

    const room = root.NudgeSceneRoom.mount({
      host, title: '寵物小屋', npc: 'sprout', npcSize: 112,
      layouts: LAYOUTS,
      greeting: () => [choice ? `${name(choice.species)}今天也很有精神！` : '這三個小傢伙在等一個家，走過去看看誰跟你最合得來？'],
      tips: ['點心只是一起玩，不會改變任何數字。', '專注分鐘累積起來，寵物就會慢慢長大。', '摸摸牠，牠會撒嬌喔。'],
      objects: [
        { id: 'house', label: '寵物屋', hint: choice ? '看看牠' : '選一隻寵物', onSelect: () => say([choice ? `${name(choice.species)}的家。屋頂上的星星是牠最喜歡的。` : '先在屋前挑一隻吧！']) },
        { id: 'bowl', label: '飯碗', hint: '放一塊點心', onSelect: () => treat() },
        { id: 'cushion', label: '坐墊', hint: '摸摸牠', onSelect: () => pat() },
        { id: 'board', label: '成長板', hint: '牠長大了多少', onSelect: (_, r) => r.openPanel({ title: '成長板', content: board(), from: r.object('board') }) },
        ...Pets.MANIFEST.species.map(s => ({
          id: `pick_${s.id}`, label: s.name, hint: '就是牠了嗎？',
          onSelect: () => say([`${s.name}歪著頭看你，好像在問「要帶我回家嗎？」`], [{ label: `帶${s.name}回家`, onSelect: () => choose(s.id) }]),
        })),
      ],
    });
    life = root.NudgeWorldLife?.attach(room, {
      layouts: LAYOUTS,
      acts: {
        bowl: { anim: 'snack', fx: 'pop', sfx: 'coin', face: 'up' },
        cushion: { anim: 'sit', fx: 'pop', face: 'down' },
        board: { fx: 'pop', face: 'up', anim: 'think' },
        house: { fx: 'shake', face: 'up', anim: 'wave' },
        pick_owl: { face: 'up', anim: 'wave' }, pick_fox: { face: 'up', anim: 'wave' }, pick_slime: { face: 'up', anim: 'wave' },
      },
      pet: false,
    });

    // Props and pets drawn on the art.
    const props = {};
    function prop(id, file, rect) {
      const img = doc.createElement('img');
      img.className = 'ph-prop';
      img.alt = '';
      img.src = BASE + file;
      img.dataset.prop = id;
      room.frame.append(img);
      props[id] = img;
      return img;
    }
    prop('house', 'house.png');
    prop('bowl', 'bowl.png');
    prop('cushion', 'cushion.png');
    const boardNode = doc.createElement('div');
    boardNode.className = 'ph-board';
    boardNode.setAttribute('aria-hidden', 'true');
    room.frame.append(boardNode);
    const pets = {};
    const petScale = () => Math.max(2, Math.min(4, Math.round((room.frame.clientWidth || 600) / 340)));
    for (const s of Pets.MANIFEST.species) {
      const n = doc.createElement('span');
      n.className = 'ph-pet';
      n.dataset.species = s.id;
      const sprite = doc.createElement('span');
      n.append(sprite);
      room.frame.append(n);
      pets[s.id] = { node: n, sprite, player: Pets.player(sprite, { species: s.id, stage, scale: petScale() }) };
    }
    function layoutProps() {
      const L = LAYOUTS[room.layout()];
      for (const [id, img] of Object.entries(props)) place(img, L.rects[id]);
      place(boardNode, L.rects.board);
      for (const s of Pets.MANIFEST.species) {
        const r = choice?.species === s.id ? L.rects.cushion : L.rects[`pick_${s.id}`];
        place(pets[s.id].node, r);
        pets[s.id].node.hidden = Boolean(choice && choice.species !== s.id);
      }
      paintBoard();
    }
    function place(node, r) {
      if (!r) return;
      Object.assign(node.style, { left: r[0] * 100 + '%', top: r[1] * 100 + '%', width: r[2] * 100 + '%', height: r[3] * 100 + '%', zIndex: String(Math.round((r[1] + r[3]) * 100)) });
    }
    function paintBoard() {
      const lvl = Pets.MANIFEST.stageNames.indexOf(stage);
      boardNode.dataset.stage = stage;
      boardNode.style.setProperty('--ph-grow', String((lvl + 1) / 3));
      boardNode.innerHTML = '<i class="ph-star"></i><i class="ph-star"></i><i class="ph-star"></i><b class="ph-sprout"></b>';
      [...boardNode.querySelectorAll('.ph-star')].forEach((st, i) => st.classList.toggle('is-on', i <= lvl));
    }
    function board() {
      const sec = doc.createElement('div');
      sec.className = 'ph-board-panel';
      const lvl = Pets.MANIFEST.stageNames.indexOf(stage);
      const sp = choice?.species || 'owl';
      const stars = [0, 1, 2].map(i => `<span class="ph-star ${i <= lvl ? 'is-on' : ''}" aria-hidden="true"></span>`).join('');
      const rows = Pets.MANIFEST.stageNames.map((st, i) => `<li class="${i <= lvl ? 'is-done' : ''}"><span class="ph-mini" data-species="${sp}" data-stage="${st}"></span>${Pets.stageName(sp, st)}<small>${i === 0 ? '一開始' : `專注 ${i === 1 ? Pets.MANIFEST.growth.teen : Pets.MANIFEST.growth.adult} 分鐘`}</small></li>`).join('');
      sec.innerHTML = `<p class="ph-stars">${stars}</p><ol class="ph-stages">${rows}</ol>`
        + `<p class="w-muted">${minutes == null ? '雲端確認中…' : `雲端確認的專注共 ${minutes} 分鐘${Pets.toNext(minutes) ? `，再 ${Pets.toNext(minutes)} 分鐘長大。` : '，已經長到最大了！'}`}</p>`
        + '<p class="w-muted">只讀你本人雲端確認完成的專注紀錄；寵物不會發放經驗值或自律幣。</p>';
      return sec;
    }
    function choose(species) {
      choice = Pets.saveChoice(species);
      root.NudgeSfx?.play('heart');
      const p = pets[species];
      p.player.play('happy', { onEnd: () => p.player.play('idle') });
      life?.emote(p.node, 'heart');
      layoutProps();
      room.announce?.(`${name(species)}成為你的寵物了，會跟著你在小屋和小鎮散步。`);
    }
    function treat() {
      if (!choice) { say(['先選一隻寵物，牠才會來吃點心喔。']); return; }
      props.bowl.src = BASE + 'bowl_full.png';
      const p = pets[choice.species];
      place(p.node, LAYOUTS[room.layout()].rects.bowl);
      p.player.play('happy', { onEnd: () => p.player.play('idle') });
      life?.emote(p.node, 'heart');
      root.setTimeout(() => { props.bowl.src = BASE + 'bowl.png'; layoutProps(); }, 2400);
      room.announce?.('喀滋喀滋，牠吃得好開心。點心只是互動，不會改變任何數字。');
    }
    function pat() {
      if (!choice) { say(['坐墊上還沒有人，先挑一隻寵物吧。']); return; }
      const p = pets[choice.species];
      p.player.play('cuddle');
      life?.emote(p.node, 'heart');
      root.NudgeSfx?.play('heart');
      root.setTimeout(() => p.player.play('sleep'), 3200);
    }
    for (const [id, p] of Object.entries(pets)) {
      p.node.addEventListener('click', () => (choice?.species === id ? pat() : room.object(`pick_${id}`)?.click()));
    }

    layoutProps();
    const resize = () => root.setTimeout(layoutProps, 140);
    root.addEventListener('resize', resize);

    // Growth: existing Cloud records only.
    const auth = root.firebase?.auth?.();
    const unsub = auth?.onAuthStateChanged?.(async user => {
      if (!user) { growth.textContent = '登入後讀取成長'; return; }
      try {
        minutes = await Pets.loadFocusMinutes(root.firebase.firestore(), user.uid);
        const next = Pets.stageFor(minutes);
        if (next !== stage) {
          stage = next;
          Pets.cacheStage(stage);
          for (const s of Pets.MANIFEST.species) {
            pets[s.id].player.destroy();
            pets[s.id].player = Pets.player(pets[s.id].sprite, { species: s.id, stage, scale: petScale() });
          }
        }
        growth.className = 'w-chip';
        growth.textContent = `✓ 專注 ${minutes} 分`;
        layoutProps();
      } catch {
        growth.className = 'w-chip is-alert';
        growth.textContent = '尚未確認';
      }
    });

    overlay._close = () => {
      unsub?.();
      root.removeEventListener('resize', resize);
      life?.destroy();
      for (const p of Object.values(pets)) p.player.destroy();
      room.destroy();
    };
    back.focus();
  }

  function close() {
    if (!overlay) return;
    overlay._close?.();
    overlay.remove();
    overlay = null;
    doc.body.classList.remove('ph-open');
    if (root.location.hash === '#pets') root.history.replaceState(null, '', root.location.pathname);
    doc.getElementById('petHouseOpen')?.focus();
  }

  root.NudgePetHouse = Object.freeze({ open, close, LAYOUTS });
  doc.getElementById('petHouseOpen')?.addEventListener('click', open);
  doc.addEventListener('keydown', e => { if (e.key === 'Escape' && overlay && !doc.querySelector('.room-panel[open]')) close(); });
  if (root.location.hash === '#pets') open();
})(typeof globalThis !== 'undefined' ? globalThis : this);
