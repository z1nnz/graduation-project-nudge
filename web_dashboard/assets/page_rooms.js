(function (root) {
  'use strict';
  // Room layouts for pages that keep their own sections behind objects
  // (page_room.js). Rects are fractions of the art; sections are the page's
  // existing nodes, so every button keeps its Cloud call and its tests.
  const text = (doc, sel, fallback = '') => doc.querySelector(sel)?.textContent?.trim() || fallback;

  // Account pages (privacy vault, town gate).
  root.NudgePageRooms = Object.assign(root.NudgePageRooms || {}, {
    privacy: {
      wide: {
        art: 'assets/scenes/vault/vault_wide.webp', aspect: 1.5, npcAt: [0.3, 0.9],
        rects: { door: [0.4, 0.15, 0.4, 0.53], seal: [0.81, 0.43, 0.16, 0.39], scrolls: [0.02, 0.12, 0.24, 0.61], banner: [0.5, 0.0, 0.2, 0.2] },
        effects: [
          { type: 'flicker', points: [[0.37, 0.16], [0.81, 0.16]], radius: 0.03, color: '#ff9a3c' },
          { type: 'glow', points: [[0.37, 0.18], [0.81, 0.18], [0.7, 0.45]], radius: 0.06, color: 'rgba(255,170,70,0.45)' },
          { type: 'sparkle', points: [[0.86, 0.46], [0.94, 0.48], [0.89, 0.42], [0.72, 0.4], [0.74, 0.55]] },
          { type: 'dust', count: 16 },
        ],
        walkers: [{ id: 'inky', path: [[0.55, 0.9], [0.75, 0.86], [0.62, 0.95]], speed: 0.025, pause: 3500 }],
      },
      art: 'assets/scenes/vault/vault.webp',
      title: '資料保險箱',
      npc: 'bell',
      npcAt: [0.2, 0.95],
      greeting: doc => [`我是保險箱的守門人鐘鐘。${text(doc, '[data-privacy-status]', '正在讀取你的同意狀態')}。`],
      tips: [
        '中間的大門後面是正式的資料匯出和刪除申請。',
        '右邊台座上的封蠟，是健康資料的同意書：同意或撤回都在那裡。',
        '左邊卷軸架寫著我們到底收了什麼、不會公開什麼。',
        '清除本機快取不等於刪除雲端資料，這點我們不會騙你。',
      ],
      objects: [
        { id: 'door', label: '保險箱大門', hint: '匯出與刪除申請', x: 0.28, y: 0.15, w: 0.5, h: 0.4,
          section: '[data-privacy-data-rights]', variant: 'iron', panelTitle: '保險箱：匯出與刪除' },
        { id: 'seal', label: '同意封蠟', hint: '健康資料同意', x: 0.72, y: 0.43, w: 0.27, h: 0.37,
          section: '[data-privacy-consent]', panelTitle: '封蠟台：健康資料同意' },
        { id: 'scrolls', label: '卷軸架', hint: '收什麼、不公開什麼', x: 0.0, y: 0.2, w: 0.24, h: 0.5,
          section: 'main .card-grid-3', panelTitle: '卷軸：資料怎麼被使用' },
        { id: 'banner', label: '政策旗幟', hint: '目前政策版本', x: 0.42, y: 0.0, w: 0.18, h: 0.12,
          section: 'main > .hero', panelTitle: '政策版本' },
      ],
      effects: [
        { type: 'glow', points: [[0.24, 0.13], [0.84, 0.13], [0.7, 0.33], [0.86, 0.52]], radius: 0.09, color: 'rgba(255,170,70,0.5)' },
        { type: 'sparkle', points: [[0.76, 0.32], [0.72, 0.4], [0.88, 0.47], [0.79, 0.24]] },
        { type: 'dust', count: 10 },
      ],
    },

    login: {
      wide: {
        art: 'assets/scenes/gate/gate_wide.webp', aspect: 1.5, npcAt: [0.25, 0.85],
        rects: { pass: [0.78, 0.57, 0.15, 0.28], gate: [0.36, 0.3, 0.33, 0.35] },
        effects: [
          { type: 'clouds', top: 0.0, band: 0.1, count: 5, alpha: 0.3 },
          { type: 'birds', y: 0.08 },
          { type: 'flicker', points: [[0.33, 0.35], [0.72, 0.35], [0.48, 0.5]], radius: 0.02 },
          { type: 'fountain', points: [[0.525, 0.5]], scale: 0.4, basin: 1.5 },
          { type: 'flicker', points: [[0.44, 0.45], [0.47, 0.42], [0.58, 0.45], [0.6, 0.48]], radius: 0.006, color: '#ffe08a' },
          { type: 'flutter', count: 10, color: '#f0b8e6', top: 0.0, fall: 0.6, x: 0.1 },
        ],
        walkers: [
          { id: 'letty', path: [[0.5, 0.6], [0.5, 0.8], [0.6, 0.95], [0.5, 0.8]], speed: 0.03, pause: 2500 },
          { id: 'sprout', path: [[0.48, 0.55], [0.53, 0.56]], speed: 0.01, pause: 4000 },
        ],
      },
      host: '#gateMain',
      art: 'assets/scenes/gate/gate.webp',
      title: '小鎮大門',
      npc: 'bell',
      npcAt: [0.22, 0.95],
      greeting: () => ['歡迎來到小鎮！請在右邊的台子上填好入鎮通行證。'],
      tips: [
        '第一次來的話，選「建立帳號」就能拿到你自己的通行證。',
        '登入之後，你的私人紀錄只有你自己的帳號打得開。',
        '大門後面就是小鎮廣場，噴水池那裡會有人等你。',
      ],
      objects: [
        { id: 'pass', label: '入鎮通行證', hint: '登入或註冊', x: 0.68, y: 0.6, w: 0.27, h: 0.25,
          say: () => ['通行證就在旁邊，填好電子郵件和密碼就能進鎮。'] },
        { id: 'gate', label: '小鎮大門', hint: '回到小鎮', x: 0.25, y: 0.27, w: 0.5, h: 0.4, href: 'town.html' },
      ],
      effects: [
        { type: 'glow', points: [[0.31, 0.27], [0.69, 0.27], [0.5, 0.52]], radius: 0.07 },
        { type: 'stars', count: 18, height: 0.1 },
        { type: 'flutter', count: 6, color: '#f0b8e6', top: 0.0, fall: 0.4, x: 0.2 },
      ],
    },
  });
})(typeof globalThis !== 'undefined' ? globalThis : this);
