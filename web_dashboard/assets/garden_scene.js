(function (root) {
  'use strict';
  // The starlight garden as a place: each soil bed is one plant, one sprout
  // per week (newest on the right). Plants are buttons that open garden.js's
  // own dialog for that week, so the story always comes from Cloud records.
  const doc = root.document;
  const grid = doc.getElementById('gardenGrid');
  const scene = doc.getElementById('gardenScene');
  if (!grid || !scene || !root.NudgeSceneRoom) return;

  // garden plant id -> row in plants.webp (5 stages per row)
  const ROW = { flower: 4, tree: 3, moonflower: 2, meadow: 0 };
  // Soil inside each bed's stone border, measured from the art.
  const BEDS = {
    wide: [
      [0.31, 0.339, 0.13, 0.098], [0.462, 0.335, 0.134, 0.113], [0.62, 0.334, 0.128, 0.102],
      [0.291, 0.475, 0.145, 0.119], [0.456, 0.475, 0.146, 0.106], [0.628, 0.475, 0.148, 0.105],
    ],
    tall: [
      [0.136, 0.357, 0.235, 0.089], [0.403, 0.356, 0.212, 0.088], [0.654, 0.356, 0.226, 0.081],
      [0.082, 0.468, 0.275, 0.107], [0.375, 0.468, 0.261, 0.108], [0.654, 0.47, 0.263, 0.104],
    ],
  };
  const locked = () => !doc.getElementById('gardenLocked')?.hidden;

  let room = null;
  room = root.NudgeSceneRoom.mount({
    host: doc.querySelector('.g-main'),
    title: '星光花園',
    npc: 'sprout',
    onLayout: () => render(),
    layouts: {
      wide: {
        art: 'assets/scenes/garden/garden_wide_mid.webp', aspect: 1.5, npcAt: [0.22, 0.8],
        rects: { greenhouse: [0.1, 0.1, 0.18, 0.26], well: [0.79, 0.15, 0.11, 0.23], shed: [0.77, 0.5, 0.22, 0.3] },
        effects: [
          { type: 'stars', count: 26, height: 0.1 },
          { type: 'clouds', top: 0.0, band: 0.06, count: 3, alpha: 0.22 },
          { type: 'fireflies', count: 22, top: 0.25, band: 0.6 },
          { type: 'flicker', points: [[0.1, 0.12], [0.41, 0.07], [0.64, 0.07], [0.93, 0.12], [0.44, 0.83], [0.6, 0.83], [0.78, 0.62], [0.26, 0.22]], radius: 0.014 },
          { type: 'flutter', count: 8, color: '#f0b8e6', top: 0.0, fall: 0.35, x: 0.15 },
          { type: 'flutter', count: 6, color: '#f0b8e6', top: 0.0, fall: 0.3, x: 0.88 },
        ],
        walkers: [
          { id: 'letty', path: [[0.22, 0.6], [0.12, 0.66], [0.2, 0.72]], speed: 0.025, pause: 3000 },
        ],
      },
      tall: {
        art: 'assets/scenes/garden/garden_mid.webp', aspect: 2 / 3, npcAt: [0.4, 0.86],
        rects: { greenhouse: [0.03, 0.1, 0.3, 0.22], well: [0.76, 0.15, 0.2, 0.17], shed: [0.62, 0.6, 0.36, 0.22] },
        effects: [
          { type: 'stars', count: 18, height: 0.08 },
          { type: 'fireflies', count: 16, top: 0.3, band: 0.55 },
          { type: 'flicker', points: [[0.03, 0.1], [0.36, 0.09], [0.74, 0.09], [0.97, 0.12], [0.35, 0.88], [0.63, 0.88], [0.63, 0.7]], radius: 0.02 },
          { type: 'flutter', count: 5, color: '#e9c4ff', top: 0.05, fall: 0.3, x: 0.6 },
        ],
        walkers: [],
      },
    },
    greeting: () => [locked()
      ? (doc.getElementById('gardenLockedText')?.textContent || '花園還沒開門。')
      : '我是園丁苗苗。每一畦土是一種植物，一週長一株，越右邊越新。'],
    tips: [
      '星光百合靠專注長大，蘋果樹靠運動，月鈴花靠睡眠，向日葵靠走路。',
      '點植物，就能看到是哪一週、哪幾次行動讓它長出來的。',
      '水井的水只是讓植物開心，不會改變任何紀錄喔。',
      '溫室裡貼著植物的成長表，想知道還差多少可以去看看。',
    ],
    objects: [
      { id: 'greenhouse', label: '溫室', hint: '植物怎麼長',
        onSelect: (e, r) => r.openPanel({ title: '溫室：植物怎麼長', content: scene.querySelector('.g-legend'), from: r.object('greenhouse') }) },
      { id: 'well', label: '水井', hint: '幫全部植物澆水',
        onSelect: (e, r) => {
          const grown = [...doc.querySelectorAll('.gs-plant:not([data-stage="0"])')];
          if (!grown.length) { r.say(['花圃裡還沒有長出植物。先完成一次雲端確認的行動吧！']); return; }
          for (const p of grown.slice(-6)) r.burst({ kind: 'leaf', count: 3, from: p });
          r.announce('你幫花園澆了水。澆水只是互動，不會改變任何紀錄。');
        } },
      { id: 'shed', label: '工具小屋', hint: '整本花圃紀錄',
        onSelect: (e, r) => r.openPanel({ title: '工具小屋：整本花圃紀錄', content: scene, from: r.object('shed') }) },
    ],
  });


  function render() {
    if (!room) return;
    let layer = room.frame.querySelector('.gs-beds');
    if (!layer) { layer = doc.createElement('div'); layer.className = 'gs-beds'; room.frame.append(layer); }
    layer.textContent = '';
    const beds6 = BEDS[room.layout()] || BEDS.tall;
    const weeks = Number(grid.style.getPropertyValue('--g-weeks')) || 6;
    const plots = [...grid.querySelectorAll('.g-plot')];
    const beds = Math.floor(plots.length / weeks);
    for (let b = 0; b < beds && b < beds6.length; b++) {
      const [x, y, w, h] = beds6[b];
      const bed = doc.createElement('div');
      bed.className = 'gs-bed';
      Object.assign(bed.style, { left: x * 100 + '%', top: y * 100 + '%', width: w * 100 + '%', height: h * 100 + '%' });
      // The bed shows the last three weeks; the shed keeps the full record.
      for (let k = Math.max(0, weeks - 3); k < weeks; k++) {
        const source = plots[b * weeks + k];
        const sprite = source.querySelector('.g-sprite');
        const plant = sprite?.dataset.plant, stage = Number(sprite?.dataset.stage) || 0;
        const btn = doc.createElement('button');
        btn.type = 'button';
        btn.className = 'gs-plant';
        btn.dataset.stage = String(stage);
        btn.dataset.week = k === weeks - 1 ? 'now' : 'past';
        btn.style.setProperty('--row', String(ROW[plant] ?? 0));
        btn.style.setProperty('--col', String(Math.max(0, stage - 1)));
        btn.setAttribute('aria-label', source.getAttribute('aria-label') || '植物');
        btn.disabled = source.disabled;
        btn.addEventListener('click', () => { room.poke(btn); source.click(); });
        bed.append(btn);
      }
      layer.append(bed);
    }
  }
  root.NudgeGardenRoom = room;
  new MutationObserver(render).observe(grid, { childList: true, subtree: true, attributes: true, attributeFilter: ['data-stage', 'disabled'] });
  render();
})(typeof globalThis !== 'undefined' ? globalThis : this);
