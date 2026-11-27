(function (root) {
  'use strict';
  // Room layouts for pages that keep their own sections behind objects
  // (page_room.js). Rects are fractions of the art; sections are the page's
  // existing nodes, so every button keeps its Cloud call and its tests.
  const text = (doc, sel, fallback = '') => doc.querySelector(sel)?.textContent?.trim() || fallback;

  // Home and commission pages (today step, focus desk, profile, quest book).
  root.NudgePageRooms = Object.assign(root.NudgePageRooms || {}, {
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

    // J2: the name card page is the dressing room (dressing_room.js adds
    // the mirror, the rack and the flip card on top of this room).
    profile: {
      art: 'assets/scenes/cabin/room_base_mid.webp',
      aspect: 720 / 1279,
      title: '更衣室',
      npc: 'letty',
      npcAt: [0.2, 0.93],
      greeting: () => ['歡迎來到更衣室！站到鏡子前，衣架上的衣服都可以換上看看。', '名片在牆上的告示板，翻過來就能編輯。'],
      tips: ['換上新衣服時，你會在鏡子前轉一圈。', '衣架可以左右拖曳，找想穿的那一件。', '書架上記著你的成長軌跡。'],
      objects: [
        { id: 'mirror', label: '立鏡', hint: '照照鏡子', x: 0.64, y: 0.46, w: 0.24, h: 0.22 },
        { id: 'rack', label: '衣架', hint: '換衣服', x: 0.1, y: 0.56, w: 0.42, h: 0.1 },
        { id: 'card', label: '名片', hint: '翻面編輯', x: 0.43, y: 0.37, w: 0.18, h: 0.1 },
        { id: 'shelf', label: '書架', hint: '成長軌跡', x: 0.12, y: 0.29, w: 0.25, h: 0.2, section: '#profileGrowthTracks', panelTitle: '書架：成長軌跡' },
      ],
      effects: [{ type: 'flicker', points: [[0.12, 0.2], [0.88, 0.2]], radius: 0.05 }, { type: 'dust', count: 14 }],
      wide: {
        art: 'assets/scenes/workbench/cabin_wide_mid.webp', aspect: 1.5, npcAt: [0.12, 0.92],
        rects: { mirror: [0.66, 0.42, 0.08, 0.3], rack: [0.2, 0.55, 0.22, 0.15], card: [0.42, 0.39, 0.17, 0.13], shelf: [0.23, 0.34, 0.14, 0.2] },
        effects: [{ type: 'flicker', points: [[0.22, 0.24], [0.79, 0.24]], radius: 0.03 }, { type: 'dust', count: 20 }],
      },
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
  });
})(typeof globalThis !== 'undefined' ? globalThis : this);
