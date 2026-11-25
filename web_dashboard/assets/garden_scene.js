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
  const BEDS = [
    [0.14, 0.35, 0.22, 0.09], [0.4, 0.35, 0.22, 0.09], [0.65, 0.35, 0.22, 0.09],
    [0.1, 0.47, 0.24, 0.1], [0.38, 0.47, 0.24, 0.1], [0.66, 0.47, 0.25, 0.1],
  ];
  const locked = () => !doc.getElementById('gardenLocked')?.hidden;

  const room = root.NudgeSceneRoom.mount({
    host: doc.querySelector('.g-main'),
    art: 'assets/scenes/garden/garden.webp',
    title: '星光花園',
    npc: 'sprout',
    npcAt: [0.4, 0.86],
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
      { id: 'greenhouse', label: '溫室', hint: '植物怎麼長', x: 0.03, y: 0.1, w: 0.3, h: 0.22,
        onSelect: (e, r) => r.openPanel({ title: '溫室：植物怎麼長', content: scene.querySelector('.g-legend'), from: r.object('greenhouse') }) },
      { id: 'well', label: '水井', hint: '幫全部植物澆水', x: 0.76, y: 0.15, w: 0.2, h: 0.17,
        onSelect: (e, r) => {
          const grown = [...doc.querySelectorAll('.gs-plant:not([data-stage="0"])')];
          if (!grown.length) { r.say(['花圃裡還沒有長出植物。先完成一次雲端確認的行動吧！']); return; }
          for (const p of grown.slice(-6)) r.burst({ kind: 'leaf', count: 3, from: p });
          r.announce('你幫花園澆了水。澆水只是互動，不會改變任何紀錄。');
        } },
      { id: 'shed', label: '工具小屋', hint: '整本花圃紀錄', x: 0.62, y: 0.6, w: 0.36, h: 0.22,
        onSelect: (e, r) => r.openPanel({ title: '工具小屋：整本花圃紀錄', content: scene, from: r.object('shed') }) },
    ],
    effects: [
      { type: 'fireflies', count: 16, top: 0.3, band: 0.55 },
      { type: 'glow', points: [[0.03, 0.1], [0.36, 0.09], [0.74, 0.09], [0.97, 0.12], [0.35, 0.88], [0.63, 0.88], [0.63, 0.7]], radius: 0.05 },
      { type: 'stars', count: 18, height: 0.08 },
      { type: 'flutter', count: 5, color: '#e9c4ff', top: 0.05, fall: 0.3, x: 0.6 },
    ],
  });

  const layer = doc.createElement('div');
  layer.className = 'gs-beds';
  room.frame.append(layer);

  function render() {
    layer.textContent = '';
    const weeks = Number(grid.style.getPropertyValue('--g-weeks')) || 6;
    const plots = [...grid.querySelectorAll('.g-plot')];
    const beds = Math.floor(plots.length / weeks);
    for (let b = 0; b < beds && b < BEDS.length; b++) {
      const [x, y, w, h] = BEDS[b];
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
  new MutationObserver(render).observe(grid, { childList: true, subtree: true, attributes: true, attributeFilter: ['data-stage', 'disabled'] });
  render();
})(typeof globalThis !== 'undefined' ? globalThis : this);
