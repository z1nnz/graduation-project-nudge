(function (root) {
  'use strict';
  // Room layouts for pages that keep their own sections behind objects
  // (page_room.js). Rects are fractions of the art; sections are the page's
  // existing nodes, so every button keeps its Cloud call and its tests.
  const text = (doc, sel, fallback = '') => doc.querySelector(sel)?.textContent?.trim() || fallback;

  root.NudgePageRooms = Object.freeze({
    privacy: {
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

    quests: {
      art: 'assets/scenes/board/board.webp',
      title: '委託所',
      npc: 'scroll',
      npcAt: [0.18, 0.96],
      greeting: doc => [text(doc, '#qbRequestLine', '我是告示員阿紙。板子上釘的都是你自己的委託。')],
      tips: [
        '告示板上是進行中的委託，每一格印章都來自雲端確認的行動。',
        '右邊的冒險地圖，可以接一條新的委託路線。',
        '桌上的證書盒，收著你完成過的委託鏈。',
        '牆上的時鐘可以重新讀取雲端紀錄。',
      ],
      objects: [
        { id: 'board', label: '告示板', hint: '進行中的委託', x: 0.12, y: 0.17, w: 0.63, h: 0.36,
          section: '#qbChains', panelTitle: '告示板：進行中的委託', variant: 'board' },
        { id: 'map', label: '冒險地圖', hint: '接一條新委託', x: 0.76, y: 0.29, w: 0.22, h: 0.22,
          section: '#qbTemplates', panelTitle: '冒險地圖：接一條新委託' },
        { id: 'desk', label: '證書盒', hint: '完成的委託', x: 0.52, y: 0.63, w: 0.44, h: 0.2,
          section: '#qbCerts', panelTitle: '證書盒' },
        { id: 'clock', label: '掛鐘', hint: '委託冊與雲端紀錄', x: 0.0, y: 0.0, w: 0.16, h: 0.12,
          section: '.qb-hero', panelTitle: '委託冊' },
        { id: 'request', label: '鎮民的請託', hint: '今天的請託', x: 0.0, y: 0.2, w: 0.11, h: 0.4,
          section: '#request', panelTitle: '鎮民的請託' },
      ],
      hide: ['#qbActiveTitle', '#qbTemplatesTitle', '#qbCertsTitle', '.qb-note'],
      effects: [
        { type: 'glow', points: [[0.47, 0.07], [0.28, 0.06], [0.66, 0.06], [0.67, 0.67], [0.92, 0.2]], radius: 0.07 },
        { type: 'flutter', count: 5, top: 0.18, fall: 0.35, x: 0.44 },
        { type: 'dust', count: 12 },
      ],
    },

    login: {
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
