(function (root) {
  'use strict';
  // Living scene configs for the town-world social pages (#200 H3-H8), keyed
  // by <body data-living-room>. Rects are [x, y, w, h] fractions of the art.
  // Each object opens one of the page's existing sections, or leads to a
  // sibling room of the same facility.
  const S = 'assets/scenes/';
  const text = (doc, sel, fallback) => doc.querySelector(sel)?.textContent?.trim() || fallback;
  const glow = (points, radius = 0.04) => ({ type: 'glow', points, radius });
  const dust = { type: 'dust', count: 14 };

  // ---------- family courtyard + guardian rooms ----------
  const COURTYARD = {
    wide: { art: S + 'family_courtyard/courtyard.webp', aspect: 840 / 560, npcAt: [0.86, 0.86], playerAt: [0.5, 0.86],
      effects: [glow([[0.33, 0.33], [0.66, 0.33], [0.36, 0.83], [0.66, 0.83]]), dust],
      walkers: [{ id: 'sprout', path: [[0.18, 0.78], [0.3, 0.88], [0.7, 0.88], [0.82, 0.78]], speed: 0.03, pause: 1800 }],
      rects: { desk: [0.06, 0.36, 0.2, 0.17], mailbox: [0.87, 0.39, 0.11, 0.24], garden: [0.32, 0.45, 0.36, 0.27],
        board: [0.47, 0.22, 0.23, 0.11], hut: [0.3, 0.19, 0.07, 0.22], gate: [0.69, 0.2, 0.08, 0.22] } },
    tall: { art: S + 'family_courtyard/courtyard_tall.webp', aspect: 900 / 1350, npcAt: [0.82, 0.62], playerAt: [0.5, 0.62],
      effects: [glow([[0.32, 0.33], [0.68, 0.33]], 0.05), dust],
      rects: { desk: [0.0, 0.17, 0.24, 0.11], mailbox: [0.85, 0.19, 0.14, 0.13], garden: [0.26, 0.3, 0.48, 0.13],
        board: [0.38, 0.15, 0.24, 0.07], hut: [0.24, 0.13, 0.1, 0.12], gate: [0.74, 0.13, 0.1, 0.12] } },
  };
  const COURTYARD_LINKS = {
    desk: { label: '週報書桌', hint: '孩子同意分享的摘要', href: 'guardian-report.html', action: 'read', change: 'open' },
    mailbox: { label: '鼓勵卡信箱', hint: '送出鼓勵卡', href: 'guardian-encouragement.html', action: 'write', change: 'open' },
    garden: { label: '共同目標花圃', hint: '提議與決定共同目標', href: 'guardian-goals.html', action: 'cheer', change: 'rise' },
    board: { label: '分享同意告示', hint: '孩子決定的分享範圍', href: 'guardian-permissions.html', action: 'read', change: 'flutter' },
    hut: { label: '陪伴小屋', hint: '家庭樹與陪伴工具', href: 'guardian.html', action: 'open', change: 'open' },
    gate: { label: '連結家人', hint: '家庭連結邀請', href: 'guardian-link.html', action: 'greet', change: 'open' },
  };
  function courtyard(title, local, extra = {}) {
    const objects = Object.entries(COURTYARD_LINKS).map(([id, link]) => (local[id]
      ? { id, ...link, href: undefined, section: local[id].section, panelTitle: local[id].panelTitle || link.label }
      : { id, ...link }));
    return { title, npc: 'sprout', companion: 'companion', layouts: COURTYARD, objects,
      far: { band: [0, 0.12], kind: 'clouds' }, near: { plants: true, petals: 'petal' },
      greeting: doc => [`歡迎回到家庭庭院。${text(doc, '[data-family-role]', '家長提議，孩子決定')}。`],
      tips: ['花圃是共同目標；信箱是鼓勵卡；書桌上是孩子同意分享的週報。', '家庭樹只隨家庭互動長大，不會變成個人經驗值。'],
      hide: ['main > header.hero', 'main > header.community-scope'], ...extra };
  }

  // ---------- group hall + group rooms ----------
  const HALL = {
    wide: { art: S + 'guild_hall/hall.webp', aspect: 840 / 560, npcAt: [0.12, 0.86], playerAt: [0.5, 0.82],
      effects: [glow([[0.24, 0.2], [0.68, 0.2], [0.27, 0.36]]), dust],
      walkers: [{ id: 'scroll', path: [[0.25, 0.75], [0.75, 0.75]], speed: 0.03, pause: 2200 }],
      rects: { mural: [0.56, 0.17, 0.25, 0.45], notices: [0.37, 0.28, 0.16, 0.11], shelf: [0.06, 0.27, 0.1, 0.29],
        book: [0.19, 0.33, 0.15, 0.22], bench: [0.38, 0.43, 0.16, 0.13], door: [0.83, 0.3, 0.1, 0.28] } },
    tall: { art: S + 'guild_hall/guild_hall_tall.webp', aspect: 900 / 1350, npcAt: [0.16, 0.7], playerAt: [0.5, 0.66],
      effects: [glow([[0.22, 0.16], [0.7, 0.16]], 0.05), dust],
      rects: { mural: [0.55, 0.08, 0.3, 0.22], notices: [0.37, 0.15, 0.19, 0.06], shelf: [0.05, 0.15, 0.13, 0.13],
        book: [0.18, 0.16, 0.17, 0.11], bench: [0.36, 0.2, 0.2, 0.07], door: [0.87, 0.15, 0.12, 0.15] } },
  };
  const HALL_LINKS = {
    mural: { label: '團體挑戰拼圖', hint: '越拼越完整的團體挑戰', href: 'groups-challenge.html', action: 'cheer', change: 'pulse' },
    notices: { label: '共讀大日曆', hint: '共同讀書時段', href: 'groups-study-schedule.html', action: 'read', change: 'flutter' },
    shelf: { label: '倒數模板書架', hint: '考試倒數模板', href: 'groups-templates.html', action: 'read', change: 'shake' },
    book: { label: '成果之書', hint: '成員同意分享的成果', href: 'groups-ranking.html', action: 'read', change: 'open' },
    bench: { label: '共同進度長桌', hint: '團體星球與參與', href: 'groups.html', action: 'rest', change: 'pulse' },
    door: { label: '入會大門', hint: '加入或建立團體', href: 'groups-link.html', action: 'greet', change: 'open' },
  };
  function hall(title, local, extra = {}) {
    const objects = Object.entries(HALL_LINKS).map(([id, link]) => (local[id]
      ? { id, ...link, href: undefined, section: local[id].section, panelTitle: local[id].panelTitle || link.label }
      : { id, ...link }));
    return { title, npc: 'scroll', layouts: HALL, objects,
      far: { band: [0, 0.1], kind: 'stars' }, near: { plants: false, petals: false },
      greeting: () => ['歡迎來到團體會館。管理者提出邀請，成員自己決定要不要參加。'],
      tips: ['拼圖越完整，代表大家一起完成的挑戰越多。', '成果之書只收錄成員自己同意分享的摘要。'],
      hide: ['main > header.hero', 'main > header.community-scope'], ...extra };
  }

  // ---------- plaza, post office and other rooms ----------
  const PLAZA = {
    wide: { art: S + 'town_plaza/plaza.webp', aspect: 840 / 560, npcAt: [0.12, 0.88], playerAt: [0.5, 0.88],
      effects: [glow([[0.08, 0.62], [0.92, 0.62]]), { type: 'fireflies', top: 0.4, band: 0.4, count: 10 }],
      walkers: [{ id: 'letty', path: [[0.3, 0.7], [0.7, 0.7], [0.7, 0.9], [0.3, 0.9]], speed: 0.03, pause: 1600 }],
      rects: { board: [0.14, 0.18, 0.16, 0.14], mailbox: [0.7, 0.2, 0.08, 0.15], fountain: [0.38, 0.3, 0.24, 0.3],
        benchL: [0.15, 0.7, 0.17, 0.12], benchR: [0.68, 0.7, 0.17, 0.12] } },
    tall: { art: S + 'town_plaza/plaza_tall.webp', aspect: 900 / 1350, npcAt: [0.14, 0.78], playerAt: [0.5, 0.75],
      effects: [{ type: 'fireflies', top: 0.3, band: 0.3, count: 8 }],
      rects: { board: [0.08, 0.13, 0.22, 0.1], mailbox: [0.74, 0.14, 0.12, 0.1], fountain: [0.3, 0.24, 0.4, 0.17],
        benchL: [0.08, 0.5, 0.25, 0.08], benchR: [0.67, 0.5, 0.25, 0.08] } },
  };
  const POST = {
    wide: { art: S + 'post_office/post_office.webp', aspect: 840 / 560, npcAt: [0.82, 0.86], playerAt: [0.45, 0.86],
      effects: [glow([[0.08, 0.16], [0.88, 0.16]]), dust],
      rects: { counter: [0.3, 0.44, 0.33, 0.18], cubbies: [0.25, 0.08, 0.18, 0.32], window: [0.62, 0.08, 0.14, 0.18],
        parcels: [0.0, 0.24, 0.18, 0.26], sorter: [0.82, 0.24, 0.14, 0.22] } },
    tall: { art: S + 'social_world/post_office_tall.webp', aspect: 1024 / 1536, npcAt: [0.8, 0.8], playerAt: [0.45, 0.8],
      effects: [dust],
      rects: { counter: [0.3, 0.38, 0.52, 0.14], cubbies: [0.06, 0.1, 0.34, 0.28], window: [0.66, 0.05, 0.2, 0.12],
        parcels: [0.42, 0.1, 0.22, 0.22], sorter: [0.66, 0.24, 0.2, 0.12] } },
  };
  const scene = (dir, base, tallBase, rectsWide, rectsTall, npcWide = [0.85, 0.86], npcTall = [0.82, 0.8]) => ({
    wide: { art: S + `${dir}/${base}`, aspect: 1536 / 1024, npcAt: npcWide, playerAt: [0.5, 0.86], effects: [dust], rects: rectsWide },
    tall: { art: S + `${dir}/${tallBase}`, aspect: 1024 / 1536, npcAt: npcTall, playerAt: [0.5, 0.8], effects: [dust], rects: rectsTall },
  });

  const rooms = {
    // ===== H8: family =====
    'family-courtyard': courtyard('家庭庭院', {
      garden: { section: '[data-family-garden]', panelTitle: '共同花圃' },
      mailbox: { section: 'main > [data-social-scene]', panelTitle: '鼓勵卡與共同目標' },
      gate: { section: '[data-safety-family]', panelTitle: '未成年保護' },
    }, { hide: ['main > header.community-scope', 'main > section.community-ground'] }),
    guardian: courtyard('陪伴小屋', {
      hut: { section: '[data-family-outcome]', panelTitle: '家庭樹' },
      board: { section: '#guardianCareNote', panelTitle: '陪伴語氣' },
    }),
    'guardian-link': courtyard('連結家人', { gate: { section: 'main > section:not(.hero)', panelTitle: '親屬帳號連結' } }),
    'guardian-report': courtyard('週報書桌', { desk: { section: 'main > section.workspace-layout', panelTitle: '孩子同意分享的週報' } },
      { prepare: doc => {
        // The consented numbers sit on the desk with the report, not over the scene.
        const metrics = doc.querySelector('main > section.metric-grid');
        doc.querySelector('main > section.workspace-layout')?.prepend(metrics || '');
      } }),
    'guardian-encouragement': courtyard('鼓勵卡信箱', { mailbox: { section: 'main > section.workspace-layout', panelTitle: '製作鼓勵卡' } }),
    'guardian-goals': courtyard('共同目標花圃', { garden: { section: 'main > section.tool-panel', panelTitle: '共同目標提議器' } }),
    'guardian-permissions': courtyard('分享同意告示', { board: { section: 'main > section.permission-grid', panelTitle: '孩子目前同意的範圍' } }),

    // ===== H8: groups =====
    'group-hall': hall('團體會館', {
      notices: { section: 'main > div[data-community-panel]', panelTitle: '團體活動行事曆' },
      mural: { section: 'main > section[data-community-panel]:nth-of-type(2)', panelTitle: '團體挑戰拼圖' },
      book: { section: 'main > [data-social-scene]', panelTitle: '團體成果' },
      shelf: { section: 'main > section[data-community-panel]:nth-of-type(3)', panelTitle: '管理員辦公室' },
    }, { hide: ['main > header.community-scope', 'main > section.community-ground'] }),
    groups: hall('共同進度', {
      bench: { section: '[data-group-outcome]', panelTitle: '團體星球' },
      book: { section: '[data-group-publications]', panelTitle: '目前挑戰與我的參與' },
    }),
    'groups-link': hall('入會大門', { door: { section: '#groupsLinkContainer', panelTitle: '加入或建立團體' } }),
    'groups-ranking': hall('成果之書', { book: { section: 'main > section.two-col', panelTitle: '團體成果與同意摘要' } }),
    'groups-challenge': hall('團體挑戰拼圖', { mural: { section: 'main > section.tool-panel', panelTitle: '團體挑戰建立器' } }),
    'groups-study-schedule': hall('共讀大日曆', { notices: { section: 'main > section.workspace-layout', panelTitle: '共同自律時段' } }),
    'groups-templates': hall('倒數模板書架', { shelf: { section: 'main > section.program-builder', panelTitle: '考試倒數模板' } }),

    // ===== H6: social and notifications =====
    notifications: {
      title: '郵局', npc: 'letty', layouts: POST, far: { band: [0, 0.06], kind: 'clouds' }, near: { plants: true, petals: false },
      greeting: () => ['我是郵差小信！通知都會變成信送到這裡。'],
      tips: ['櫃台上是站內通知；信件格是待處理邀請。', '推播還沒在實機驗收，站內信不會漏。'],
      hide: ['main > section.post-office-scene', 'main > header.w-parchment'],
      objects: [
        { id: 'counter', label: '郵局櫃台', hint: '站內通知', section: 'main > section:nth-of-type(4)', action: 'read', change: 'pulse' },
        { id: 'cubbies', label: '信件格', hint: '待處理邀請', section: 'main > section:nth-of-type(5)', action: 'read', change: 'shake' },
        { id: 'window', label: '推播窗口', hint: '瀏覽器推播', section: '[data-web-push]', action: 'think', change: 'lit' },
        { id: 'parcels', label: '提醒包裹架', hint: 'App／Web 共用提醒', section: 'main > section:nth-of-type(3)', action: 'open', change: 'open' },
        { id: 'sorter', label: '郵箱', hint: '小鎮郵箱', href: 'mailbox.html', action: 'greet', change: 'flutter' },
      ],
    },
    mailbox: {
      title: '小鎮郵箱', npc: 'letty', layouts: POST, far: { band: [0, 0.06], kind: 'clouds' }, near: { plants: true, petals: false },
      greeting: doc => [`信來了！${text(doc, '[data-mailbox-status]', '正在整理你的信')}`],
      hide: ['main > section.post-office-scene', 'main > header.w-parchment'],
      openOnArrive: 'counter',
      objects: [
        { id: 'counter', label: '你的信', hint: '未讀信件', section: 'main > section.w-parchment', action: 'read', change: 'open' },
        { id: 'cubbies', label: '通知中心', hint: '通知與邀請', href: 'notifications.html', action: 'greet', change: 'shake' },
        { id: 'sorter', label: '寄出邀請', hint: '加好友', href: 'friend.html', action: 'write', change: 'flutter' },
      ],
    },
    buddies: {
      title: '搭檔長椅', npc: 'letty', layouts: PLAZA, far: { band: [0, 0.12], kind: 'clouds' }, near: { plants: true, petals: 'petal' },
      greeting: () => ['想找個一起前進的搭檔嗎？坐下來聊聊吧。'],
      objects: [
        { id: 'benchL', label: '我的夥伴', hint: '搭檔名單', section: 'main > section:nth-of-type(3)', action: 'rest', change: 'pulse' },
        { id: 'mailbox', label: '邀請郵筒', hint: '邀請搭檔', section: 'main > section:nth-of-type(1)', action: 'write', change: 'flutter' },
        { id: 'board', label: '輕推告示', hint: '接收設定', section: 'main > section:nth-of-type(2)', action: 'read', change: 'flutter' },
        { id: 'fountain', label: '好友廣場', hint: '好友', href: 'friend.html', action: 'greet', change: 'lit' },
      ],
    },
    'thanks-cards': {
      title: '感謝信紙桌', npc: 'letty', far: { band: [0, 0.1], kind: 'clouds' }, near: { plants: true, petals: 'petal' },
      layouts: scene('social_world', 'thanks_wide.webp', 'thanks_tall.webp',
        { desk: [0.43, 0.36, 0.27, 0.18], postbox: [0.72, 0.27, 0.12, 0.32], cards: [0.38, 0.04, 0.38, 0.24] },
        { desk: [0.3, 0.26, 0.36, 0.11], postbox: [0.74, 0.23, 0.16, 0.12], cards: [0.24, 0.15, 0.48, 0.1] }),
      greeting: () => ['寫一張感謝卡吧，信紙已經鋪好了。'],
      objects: [
        { id: 'desk', label: '信紙', hint: '送感謝卡', section: '#thanksCompose', action: 'write', change: 'pulse' },
        { id: 'postbox', label: '收信郵筒', hint: '待收藏', section: 'main > section:nth-of-type(2)', action: 'open', change: 'open' },
        { id: 'cards', label: '感謝卡串', hint: '卡片冊', section: 'main > section:nth-of-type(3)', action: 'read', change: 'flutter' },
      ],
    },
    'exchange-journal': {
      title: '交換日記', npc: 'inky', far: { band: [0, 0.1], kind: 'clouds' }, near: { plants: true, petals: false },
      layouts: scene('social_world', 'exchange_wide.webp', 'exchange_tall.webp',
        { book: [0.34, 0.35, 0.3, 0.17], shelf: [0.33, 0.05, 0.47, 0.22] },
        { book: [0.3, 0.35, 0.38, 0.12], shelf: [0.76, 0.08, 0.22, 0.3] }, [0.86, 0.86], [0.82, 0.78]),
      greeting: () => ['這本日記由兩個人輪流寫，輪到你時再拿起筆就好。'],
      objects: [
        { id: 'book', label: '兩人的日記', hint: '交換日記', section: '#journalBook', action: 'write', change: 'open' },
        { id: 'shelf', label: '日記書架', hint: '選擇一本日記', section: 'main > section:nth-of-type(1)', action: 'read', change: 'shake' },
      ],
    },
    clubs: {
      title: '社團公告欄', npc: 'scroll', far: { band: [0, 0.08], kind: 'stars' }, near: { plants: true, petals: false },
      layouts: {
        wide: { art: S + 'board/board_wide.webp', aspect: 1440 / 960, npcAt: [0.9, 0.88], playerAt: [0.45, 0.88], effects: [dust],
          rects: { board: [0.25, 0.15, 0.45, 0.4], desk: [0.65, 0.6, 0.2, 0.2], map: [0.72, 0.25, 0.16, 0.25], shelf: [0.0, 0.15, 0.15, 0.45] } },
        tall: { art: S + 'board/board.webp', aspect: 720 / 1080, npcAt: [0.85, 0.82], playerAt: [0.45, 0.82], effects: [dust],
          rects: { board: [0.08, 0.05, 0.54, 0.3], desk: [0.5, 0.4, 0.4, 0.2], map: [0.68, 0.15, 0.27, 0.17], shelf: [0.0, 0.36, 0.2, 0.25] } },
      },
      greeting: () => ['公告欄上的海報都是成員自己發起的社團。'],
      objects: [
        { id: 'board', label: '社團海報', hint: '公開社團', section: 'main > section:nth-of-type(1)', action: 'read', change: 'flutter' },
        { id: 'desk', label: '申請桌', hint: '申請成立社團', section: 'main > section:nth-of-type(2)', action: 'write', change: 'pulse' },
        { id: 'map', label: '社團介紹', hint: '社團詳細', section: '#clubDetail', action: 'think', change: 'lit' },
        { id: 'shelf', label: '審核櫃', hint: '待營運審核', section: '#clubReview', action: 'read', change: 'shake' },
      ],
    },
    'safety-center': {
      title: '守衛小屋', npc: 'bell', far: { band: [0, 0.1], kind: 'clouds' }, near: { plants: true, petals: false },
      layouts: scene('social_world', 'safety_wide.webp', 'safety_tall.webp',
        { log: [0.3, 0.34, 0.24, 0.2], bell: [0.53, 0.32, 0.08, 0.12], keys: [0.67, 0.13, 0.15, 0.18], crest: [0.58, 0.06, 0.11, 0.2] },
        { log: [0.2, 0.29, 0.36, 0.1], bell: [0.5, 0.29, 0.14, 0.08], keys: [0.56, 0.11, 0.26, 0.12], crest: [0.32, 0.05, 0.24, 0.15] }),
      greeting: () => ['我是守門人鐘鐘。封鎖和檢舉都會好好保管，放心。'],
      objects: [
        { id: 'log', label: '封鎖名冊', hint: '你的封鎖名單', section: 'main > section:nth-of-type(1)', action: 'read', change: 'open' },
        { id: 'bell', label: '求助鈴', hint: '我的檢舉', section: 'main > section:nth-of-type(2)', action: 'cheer', change: 'shake' },
        { id: 'keys', label: '處理紀錄鑰匙板', hint: '與我相關的處理', section: 'main > section:nth-of-type(3)', action: 'think', change: 'pulse' },
        { id: 'crest', label: '守衛徽章', hint: '檢舉審核（營運）', section: '[data-safety-staff]', action: 'read', change: 'lit' },
      ],
    },

    // ===== H5: friends =====
    friend: {
      title: '好友廣場', npc: 'letty', layouts: PLAZA, far: { band: [0, 0.12], kind: 'clouds' }, near: { plants: true, petals: 'petal' },
      greeting: () => ['好友都在這裡！看看大家今天過得怎麼樣。'],
      hide: ['#friendHeroHeader'],
      float: ['#friendDetailView'],
      objects: [
        { id: 'board', label: '好友動態板', hint: '好友列表與動態', section: '#friendListView', action: 'read', change: 'flutter' },
        { id: 'fountain', label: '拜訪好友小屋', hint: '好友拜訪', href: 'friend-visits.html', action: 'greet', change: 'lit' },
        { id: 'mailbox', label: '邀請郵筒', hint: '寄出好友邀請', href: 'mailbox.html', action: 'write', change: 'flutter' },
        { id: 'benchR', label: '搭檔長椅', hint: '搭檔', href: 'buddies.html', action: 'rest', change: 'pulse' },
      ],
    },
    'friend-visits': {
      title: '好友的小屋', npc: 'chestnut', far: { band: [0, 0.08], kind: 'clouds' }, near: { plants: true, petals: false },
      layouts: {
        wide: { art: S + 'social_world/cabin_wide.webp', aspect: 1536 / 1024, npcAt: [0.86, 0.86], playerAt: [0.45, 0.86], effects: [dust],
          rects: { guestbook: [0.84, 0.4, 0.14, 0.16], window: [0.41, 0.12, 0.15, 0.18], shelf: [0.24, 0.24, 0.12, 0.27] } },
        tall: { art: 'assets/home/room_base.png', aspect: 720 / 1279, npcAt: [0.82, 0.82], playerAt: [0.45, 0.8], effects: [dust],
          rects: { guestbook: [0.55, 0.55, 0.3, 0.12], window: [0.3, 0.12, 0.4, 0.16], shelf: [0.04, 0.2, 0.26, 0.24] } },
      },
      greeting: () => ['進來坐坐！留言簿就在桌上，挑一句鼓勵吧。'],
      hide: ['main > header.hero'],
      objects: [
        { id: 'guestbook', label: '留言簿', hint: '拜訪好友', section: 'main > section.scene-panel:nth-of-type(2)', action: 'write', change: 'open' },
        { id: 'window', label: '我的拜訪窗', hint: '我的拜訪設定', section: 'main > section.visit-settings', action: 'think', change: 'lit' },
        { id: 'shelf', label: '訪客紀錄', hint: '誰來拜訪過我', section: 'main > section.planet-depth', action: 'read', change: 'shake' },
      ],
    },

    // ===== H3 / H4: festival, town goals, journey book =====
    'town-goals': {
      title: '全鎮目標', npc: 'stella', layouts: PLAZA, far: { band: [0, 0.14], kind: 'lanterns' }, near: { plants: true, petals: 'petal' },
      greeting: () => ['全鎮一起完成的目標寫在噴泉上，水位越高代表大家越接近。'],
      hide: ['main > section.plaza-scene'],
      objects: [
        { id: 'fountain', label: '目標噴泉', hint: '這週的全鎮目標', section: 'main > section.town-goal-scene', action: 'cheer', change: 'rise' },
        { id: 'benchL', label: '好友長椅', hint: '在場的好友', section: 'main > section.friend-presence', action: 'rest', change: 'pulse' },
        { id: 'board', label: '參與設定', hint: '選擇是否參加', section: '#townOptOut', action: 'read', change: 'flutter' },
        { id: 'mailbox', label: '節慶廣場', hint: '季節活動', href: 'seasonal-event.html', action: 'greet', change: 'lit' },
      ],
    },
    'seasonal-event': {
      title: '節慶廣場', npc: 'stella', layouts: PLAZA, far: { band: [0, 0.14], kind: 'lanterns' }, near: { plants: true, petals: 'petal' },
      greeting: () => ['節慶來了！整個小鎮都換上了新裝。'],
      hide: ['main > header.story-topbar', 'main > section.story-hero'],
      objects: [
        { id: 'board', label: '節慶地圖', hint: '季節探索地圖', section: 'main > section.story-panel', action: 'read', change: 'flutter' },
        { id: 'fountain', label: '全鎮目標', hint: '一起放煙火', href: 'town-goals.html', action: 'cheer', change: 'lit' },
      ],
    },
    'story-chapters': {
      title: '旅程手冊', npc: 'inky', far: { band: [0, 0.1], kind: 'clouds' }, near: { plants: true, petals: false },
      layouts: {
        wide: { art: S + 'journal/journal_room_wide.webp', aspect: 1440 / 960, npcAt: [0.88, 0.88], playerAt: [0.45, 0.88], effects: [dust],
          rects: { book: [0.35, 0.34, 0.27, 0.22], closed: [0.5, 0.65, 0.15, 0.3], shelf: [0.0, 0.1, 0.2, 0.42] } },
        tall: { art: S + 'journal/journal_room.webp', aspect: 720 / 960, npcAt: [0.84, 0.84], playerAt: [0.45, 0.84], effects: [dust],
          rects: { book: [0.25, 0.25, 0.5, 0.16], closed: [0.3, 0.6, 0.4, 0.25], shelf: [0.0, 0.08, 0.3, 0.28] } },
      },
      greeting: () => ['完成的鎮民任務都寫進這本手冊了，一頁一頁翻吧。'],
      hide: ['main > header.story-topbar', 'main > section.story-hero'],
      objects: [
        { id: 'book', label: '旅程手冊', hint: '你的冒險章節', section: 'main > section.story-panel', action: 'read', change: 'open' },
        { id: 'closed', label: '鎮民任務冊', hint: '進行中的任務', section: '[data-quest-book]', action: 'think', change: 'open' },
      ],
    },

    // ===== H7: focus tower =====
    rooms: {
      title: '自習大廳', npc: 'bell', far: { band: [0, 0.08], kind: 'stars' }, near: { plants: true, petals: false },
      layouts: {
        wide: { art: S + 'study_hall/hall.webp', aspect: 960 / 640, npcAt: [0.06, 0.88], playerAt: [0.5, 0.88], effects: [glow([[0.17, 0.25], [0.83, 0.25]]), dust],
          rects: { clock: [0.41, 0.0, 0.18, 0.24], table: [0.27, 0.52, 0.46, 0.25], shelf: [0.18, 0.2, 0.17, 0.29], lamp: [0.4, 0.22, 0.05, 0.08], board: [0.67, 0.23, 0.16, 0.18], notes: [0.77, 0.02, 0.14, 0.18], roster: [0.9, 0.18, 0.09, 0.35], door: [0.01, 0.18, 0.09, 0.35], window: [0.08, 0.02, 0.14, 0.18] } },
        tall: { art: S + 'social_world/study_hall_tall.webp', aspect: 1024 / 1536, npcAt: [0.12, 0.84], playerAt: [0.5, 0.82], effects: [dust],
          rects: { clock: [0.38, 0.03, 0.24, 0.17], table: [0.15, 0.38, 0.7, 0.34], shelf: [0.06, 0.21, 0.2, 0.1], lamp: [0.06, 0.31, 0.2, 0.07], board: [0.72, 0.24, 0.18, 0.06], notes: [0.72, 0.3, 0.18, 0.06], roster: [0.7, 0.73, 0.26, 0.09], door: [0.0, 0.73, 0.14, 0.11], window: [0.74, 0.06, 0.18, 0.14] } },
      },
      greeting: () => ['歡迎來到自習大廳。大家專注就是在合力打倒拖延怪！'],
      hide: ['main > section.card-grid-3'],
      objects: [
        { id: 'clock', label: '番茄大鐘', hint: '一起專注', section: '[data-focus-round]', action: 'think', change: 'pulse' },
        { id: 'table', label: '自習長桌', hint: '大家的座位', section: 'main > section.room-stage-panel', action: 'rest', change: 'pulse' },
        { id: 'shelf', label: '我的房間', hint: '選房與我的活動', section: 'main > section.room-workspace', action: 'read', change: 'shake' },
        { id: 'lamp', label: '共振燈', hint: '非同步共振', section: 'main > section.room-resonance-panel', action: 'think', change: 'lit' },
        { id: 'board', label: '樓層告示', hint: '專注塔各房', section: '[data-room-lobby]', action: 'read', change: 'flutter' },
        { id: 'notes', label: '房間歷程', hint: '活動紀錄', section: 'main > section.room-events-panel', action: 'read', change: 'flutter' },
        { id: 'roster', label: '成員名冊', hint: '最新訊息與成員管理', section: 'main > section.room-interaction-grid', action: 'read', change: 'open' },
        { id: 'window', label: '語音窗', hint: '語音自習室', section: '[data-voice-room]', action: 'greet', change: 'lit' },
        { id: 'door', label: '聊天室', hint: '夥伴聊天室', href: 'room-chat.html', action: 'greet', change: 'open' },
      ],
    },
    'room-chat': {
      title: '夥伴聊天室', npc: 'bell', far: { band: [0, 0.08], kind: 'stars' }, near: { plants: true, petals: false },
      layouts: {
        wide: { art: S + 'board/study_nook_wide.webp', aspect: 1440 / 960, npcAt: [0.9, 0.88], playerAt: [0.45, 0.88], effects: [dust],
          rects: { desk: [0.3, 0.4, 0.4, 0.3], shelf: [0.0, 0.1, 0.2, 0.45], back: [0.82, 0.2, 0.15, 0.4] } },
        tall: { art: S + 'board/study_nook.webp', aspect: 720 / 1080, npcAt: [0.85, 0.84], playerAt: [0.45, 0.84], effects: [dust],
          rects: { desk: [0.15, 0.4, 0.7, 0.2], shelf: [0.0, 0.1, 0.3, 0.25], back: [0.7, 0.1, 0.28, 0.22] } },
      },
      greeting: () => ['坐下來和夥伴聊聊，離開房間後就不能再讀寫囉。'],
      hide: ['main > header.room-chat-hero'],
      openOnArrive: 'desk',
      objects: [
        { id: 'desk', label: '聊天桌', hint: '房間對話', section: 'main > div.room-chat-layout', action: 'write', change: 'pulse' },
        { id: 'shelf', label: '共振書架', hint: '非同步共振', section: 'main > section.room-resonance-panel', action: 'think', change: 'shake' },
        { id: 'back', label: '回自習大廳', hint: '自習大廳', href: 'rooms.html', action: 'greet', change: 'open' },
      ],
    },
  };
  root.NudgeSocialRooms = rooms;
})(typeof globalThis !== 'undefined' ? globalThis : this);
