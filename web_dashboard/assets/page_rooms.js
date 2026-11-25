(function (root) {
  'use strict';
  // Room layouts for pages that keep their own sections behind objects
  // (page_room.js). Rects are fractions of the art; sections are the page's
  // existing nodes, so every button keeps its Cloud call and its tests.
  const text = (doc, sel, fallback = '') => doc.querySelector(sel)?.textContent?.trim() || fallback;

  root.NudgePageRooms = Object.freeze({
    home: {
      art: 'assets/scenes/board/study_nook.webp',
      title: '今日的一步',
      npc: 'scroll',
      npcAt: [0.2, 0.95],
      greeting: doc => [text(doc, '#dailyActionTitle', '今天從一件小事開始吧。'), text(doc, '#dailyActionDetail', '')].filter(Boolean),
      tips: ['黑板上寫著接下來可以去的地方。', '桌上的書裡有更多去處和使用說明。', '完成一小步，就是很棒的一天。'],
      float: ['.quest-board-feature'],
      hide: ['.quest-board-heading'],
      objects: [
        { id: 'chalkboard', label: '黑板', hint: '想從哪裡開始', x: 0.5, y: 0.1, w: 0.35, h: 0.22, section: '.quest-board-paths', panelTitle: '黑板：下一站' },
        { id: 'book', label: '翻開書', hint: '其他去處與說明', x: 0.27, y: 0.38, w: 0.41, h: 0.2, section: '.quest-board-more', panelTitle: '其他去處與使用說明' },
      ],
      effects: [{ type: 'steam', points: [[0.45, 0.42], [0.6, 0.44]] }, { type: 'flicker', points: [[0.82, 0.68], [0.88, 0.1]], radius: 0.03 }, { type: 'dust', count: 14 }],
      wide: {
        art: 'assets/scenes/board/study_nook_wide.webp', aspect: 1.5, npcAt: [0.2, 0.92],
        rects: { chalkboard: [0.4, 0.1, 0.28, 0.24], book: [0.32, 0.5, 0.26, 0.16] },
        effects: [
          { type: 'steam', points: [[0.455, 0.46], [0.39, 0.5], [0.52, 0.5]] },
          { type: 'flicker', points: [[0.75, 0.15], [0.19, 0.42], [0.86, 0.55]], radius: 0.02 },
          { type: 'dust', count: 20 }, { type: 'birds', y: 0.2, count: 3 },
        ],
        walkers: [{ id: 'companion', path: [[0.15, 0.85], [0.3, 0.8], [0.22, 0.92]], speed: 0.03, pause: 3000 }],
      },
    },

    focus: {
      art: 'assets/home/room_base.png',
      aspect: 720 / 1279,
      title: '小屋書桌',
      npc: 'companion',
      npcAt: [0.3, 0.86],
      greeting: () => ['我陪你一起讀書！選好時間就開始吧。'],
      tips: ['書架上放著你的各種紀錄。', '專注結束後，活動會送到雲端確認。', '累了就休息五分鐘，看看窗外吧。'],
      float: ['.focus-timer-section'],
      hide: ['main > .hero'],
      objects: [
        { id: 'shelf', label: '書架', hint: '我的紀錄', x: 0.12, y: 0.29, w: 0.25, h: 0.27, section: 'main .subnav', panelTitle: '書架：我的紀錄' },
        { id: 'window', label: '窗戶', hint: '看看外面', x: 0.31, y: 0.08, w: 0.38, h: 0.21, say: () => ['外面的天色很美。專注一段時間後，記得讓眼睛休息一下。'] },
      ],
      effects: [{ type: 'flicker', points: [[0.12, 0.2], [0.88, 0.2]], radius: 0.05 }, { type: 'stars', count: 8, height: 0.2 }, { type: 'dust', count: 14 }],
      wide: {
        art: 'assets/scenes/workbench/cabin_wide.webp', aspect: 1.5, npcAt: [0.3, 0.9],
        rects: { shelf: [0.23, 0.34, 0.14, 0.36], window: [0.39, 0.1, 0.23, 0.26] },
        effects: [{ type: 'flicker', points: [[0.22, 0.24], [0.79, 0.24]], radius: 0.03 }, { type: 'stars', count: 12, height: 0.3 }, { type: 'dust', count: 20 }],
      },
    },

    profile: {
      art: 'assets/home/room_base.png',
      aspect: 720 / 1279,
      title: '夥伴名片',
      npc: 'companion',
      npcAt: [0.25, 0.92],
      greeting: () => ['這是你的名片，朋友來拜訪時會看到它。'],
      tips: ['書架上記著你的成長軌跡。', '名片可以換稱號、簽名和顏色。'],
      float: ['.profile-container'],
      objects: [
        { id: 'shelf', label: '書架', hint: '成長軌跡', x: 0.12, y: 0.29, w: 0.25, h: 0.27, section: '#profileGrowthTracks', panelTitle: '書架：成長軌跡' },
      ],
      effects: [{ type: 'flicker', points: [[0.12, 0.2], [0.88, 0.2]], radius: 0.05 }, { type: 'dust', count: 14 }],
      wide: {
        art: 'assets/scenes/workbench/cabin_wide.webp', aspect: 1.5, npcAt: [0.12, 0.92],
        rects: { shelf: [0.23, 0.34, 0.14, 0.36] },
        effects: [{ type: 'flicker', points: [[0.22, 0.24], [0.79, 0.24]], radius: 0.03 }, { type: 'stars', count: 12, height: 0.3 }, { type: 'dust', count: 20 }],
        walkers: [{ id: 'letty', path: [[0.05, 0.85], [0.2, 0.82]], speed: 0.02, pause: 4000 }],
      },
    },

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

    quests: {
      wide: {
        art: 'assets/scenes/board/board_wide.webp', aspect: 1.5, npcAt: [0.36, 0.92],
        rects: { board: [0.21, 0.18, 0.47, 0.4], map: [0.73, 0.25, 0.18, 0.3], desk: [0.63, 0.6, 0.3, 0.24], clock: [0.08, 0.02, 0.1, 0.16], request: [0.01, 0.25, 0.17, 0.46] },
        effects: [
          { type: 'flicker', points: [[0.43, 0.06], [0.5, 0.07], [0.57, 0.06], [0.94, 0.22], [0.72, 0.63]], radius: 0.018 },
          { type: 'flutter', count: 6, top: 0.2, fall: 0.4, x: 0.45 },
          { type: 'dust', count: 18 },
        ],
        walkers: [{ id: 'chestnut', path: [[0.25, 0.8], [0.55, 0.75], [0.45, 0.88]], speed: 0.03, pause: 3000 }],
      },
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
