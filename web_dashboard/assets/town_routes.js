(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.NudgeTownRoutes = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';
  // World entry contract for the Web companion town (issue #82).
  //
  // One table says which Web page each town building opens, who may use it,
  // where its data comes from and how the player gets back. The town reads it
  // to draw building panels and the text directory; other pages read it (via
  // town_return.js) to build their "back to town" link. Pages keep their own
  // login and role gates: this table only explains them, it never grants
  // access.
  //
  // Sibling packages add or flip their own scene rows here
  // (status 'planned' -> 'available') when their page lands. Nothing else in
  // the town core needs to change for a new scene to become reachable.

  const BUILDINGS = Object.freeze({
    cabin: { name: '你的小屋', desc: '夥伴、家具與書桌' },
    board: { name: '委託告示板', desc: '今天的下一步與任務' },
    tower: { name: '專注塔', desc: '自律房，一起專注' },
    family: { name: '家庭庭院', desc: '家庭連結、鼓勵與共同目標' },
    guild: { name: '團體會館', desc: '團體挑戰與成員' },
    library: { name: '紀錄館', desc: '個人分析與每週回顧' },
    store: { name: '雜貨店', desc: '角色與家具商城' },
    park: { name: '遊樂園', desc: '用休息券玩小遊戲' },
    observatory: { name: '天文台', desc: '自律星球與每週成果' },
    garden: { name: '星光花園', desc: '本人行動長出的花園' },
    plaza: { name: '小鎮廣場', desc: '郵箱、好友與帳號設定' },
  });

  // audience: 'player' pages belong in the world; 'tool' pages (management,
  // research, presentation, admin) keep a plain labelled entry instead.
  // auth: 'public' | 'login'. gate: extra check the page itself enforces.
  // source: 'cloud' | 'mixed' (Cloud plus fixed/demo parts) | 'demo' | 'static'.
  const DESTINATIONS = Object.freeze([
    // ----- world -----
    d('town', 'town.html', null, '夥伴小鎮', 'player', 'public', null, 'cloud', '#82'),
    scene('cabin-feedback', 'cabin', 'cabin', '夥伴的反應', '#82'),
    scene('desk-scene', 'desk', 'cabin', '坐到書桌前專注', '#82'),
    d('cabin-scene', 'cabin.html', 'cabin', '布置小屋', 'player', 'login', null, 'cloud', '#82'),
    d('focus-desk', 'personal-focus.html', 'cabin', '書桌專注', 'player', 'login', null, 'cloud', '#82'),
    d('profile', 'profile.html', 'cabin', '我的名片與角色', 'player', 'login', null, 'cloud', '#82'),
    scene('quest-board-scene', 'board', 'board', '看告示板：今天的一步', '#82'),
    d('quest-board', 'dashboard.html', 'board', '今日下一步', 'player', 'public', null, 'mixed', '#82'),
    d('tasks', 'planet.html', 'board', '今日任務清單', 'player', 'login', null, 'mixed', '#82'),
    d('quest-book', 'quests.html', 'board', '委託冊：每週挑戰', 'player', 'login', null, 'cloud', 'core'),
    d('townsfolk-request', 'quests.html?view=request', 'board', '鎮民的請託', 'player', 'login', null, 'cloud', 'core'),
    d('rooms', 'rooms.html', 'tower', '自律房', 'player', 'login', null, 'cloud', '#83'),
    d('room-chat', 'room-chat.html', 'tower', '房間聊天室', 'player', 'login', 'roomMember', 'cloud', '#83'),
    d('guardian', 'guardian.html', 'family', '家長陪伴中心', 'player', 'login', 'family', 'cloud', '#83'),
    d('guardian-link', 'guardian-link.html', 'family', '連結家人', 'player', 'login', null, 'cloud', '#83'),
    d('family-courtyard', 'family-courtyard.html', 'family', '家庭庭院場景', 'player', 'login', 'family', 'cloud', '#83'),
    d('groups', 'groups.html', 'guild', '團體任務與共同進度', 'player', 'login', 'group', 'cloud', '#83'),
    d('guardian-report', 'guardian-report.html', 'family', '孩子週報', 'player', 'login', 'family', 'cloud', '#83'),
    d('guardian-encouragement', 'guardian-encouragement.html', 'family', '鼓勵卡', 'player', 'login', 'family', 'cloud', '#83'),
    d('guardian-goals', 'guardian-goals.html', 'family', '共同目標', 'player', 'login', 'family', 'cloud', '#83'),
    d('guardian-permissions', 'guardian-permissions.html', 'family', '家庭資料同意', 'player', 'login', 'family', 'cloud', '#83'),
    d('groups-link', 'groups-link.html', 'guild', '加入或建立團體', 'player', 'login', null, 'cloud', '#83'),
    d('groups-ranking', 'groups-ranking.html', 'guild', '團體成果排行', 'player', 'login', 'group', 'cloud', '#83'),
    d('groups-challenge', 'groups-challenge.html', 'guild', '團體挑戰建立器', 'player', 'login', 'groupManager', 'cloud', '#83'),
    d('groups-study-schedule', 'groups-study-schedule.html', 'guild', '讀書時段管理', 'player', 'login', 'groupManager', 'cloud', '#83'),
    d('groups-templates', 'groups-templates.html', 'guild', '考試倒數模板', 'player', 'login', 'groupManager', 'cloud', '#83'),
    d('group-hall', 'group-hall.html', 'guild', '團體會館場景', 'player', 'login', 'group', 'cloud', '#83'),
    d('clubs', 'clubs.html', 'guild', '社團佈告欄', 'player', 'login', null, 'cloud', '#83'),
    d('museum', 'personal.html', 'library', '成長紀錄館', 'player', 'login', null, 'cloud', '#84'),
    d('onboarding', 'onboarding.html', 'library', '新手角色建立', 'player', 'login', null, 'cloud', '#124'),
    d('identity', 'personal-identity.html', 'library', '自律身分書', 'player', 'login', null, 'cloud', '#84'),
    d('trends', 'personal-trends.html', 'library', '成長年鑑翻頁書', 'player', 'login', null, 'cloud', '#124'),
    d('skill-tree', 'personal-skill-tree.html', 'library', '技能書籤', 'player', 'login', null, 'cloud', '#84'),
    d('weather', 'personal-weather.html', 'library', '生活天氣回顧', 'player', 'login', null, 'cloud', '#84'),
    d('pressure', 'personal-pressure.html', 'library', '溫柔整理', 'player', 'login', null, 'cloud', '#84'),
    d('task-template', 'personal-template.html', 'library', '下一步工坊', 'player', 'login', null, 'cloud', '#84'),
    d('future-letter', 'personal-letter.html', 'library', '未來的信', 'player', 'login', null, 'cloud', '#84'),
    d('share-card', 'personal-share.html', 'library', '成長分享卡', 'player', 'login', null, 'cloud', '#124'),
    d('time-capsule', 'personal-time-capsule.html', 'library', '自律時間膠囊', 'player', 'login', null, 'cloud', '#84'),
    d('achievements', 'achievements.html', 'library', '成就大廳（二樓）', 'player', 'login', null, 'cloud', '#124'),
    d('shop', 'operations.html', 'store', '角色商城', 'player', 'login', null, 'cloud', '#82'),
    // Arcade hall: catch-the-stars plus three break games, all on break tickets.
    d('arcade', 'arcade.html', 'park', '遊戲機台大廳（休息券）', 'player', 'login', null, 'cloud', '#82'),
    d('planet', 'planet.html', 'observatory', '自律星球', 'player', 'login', null, 'mixed', '#82'),
    d('virtual-devices', 'observatory.html', 'observatory', 'Orbit／Station 虛擬裝置', 'player', 'login', null, 'mixed', '#124'),
    d('planet-builder', 'planet-builder.html', 'observatory', '星球建築規劃器（示範）', 'player', 'login', null, 'demo', 'core'),
    d('garden-scene', 'garden.html', 'garden', '星光花園', 'player', 'login', 'level10', 'cloud', '#82'),
    d('town-goals', 'town-goals.html', 'plaza', '小鎮廣場與共同目標', 'player', 'login', null, 'cloud', '#83'),
    d('mailbox', 'mailbox.html', 'plaza', '小鎮郵箱', 'player', 'login', null, 'cloud', '#83'),
    d('notifications', 'notifications.html', 'plaza', '通知與邀請', 'player', 'login', null, 'cloud', '#83'),
    d('safety-center', 'safety-center.html', 'plaza', '安全與管理中心', 'player', 'login', null, 'cloud', '#83'),
    d('buddies', 'buddies.html', 'plaza', '自律夥伴', 'player', 'login', null, 'cloud', '#83'),
    d('thanks-cards', 'thanks-cards.html', 'plaza', '感謝卡冊', 'player', 'login', null, 'cloud', '#83'),
    d('exchange-journal', 'exchange-journal.html', 'plaza', '交換日記', 'player', 'login', null, 'cloud', '#83'),
    d('friends', 'friend.html', 'plaza', '好友', 'player', 'login', null, 'cloud', '#83'),
    d('friend-visits', 'friend-visits.html', 'plaza', '好友拜訪紀錄', 'player', 'login', null, 'cloud', '#83'),
    d('privacy', 'privacy.html', 'plaza', '隱私與資料', 'player', 'login', null, 'cloud', 'core'),
    d('login', 'login.html', 'plaza', '登入／註冊', 'player', 'public', null, 'cloud', 'core'),
    d('weekly-planner', 'weekly-planner.html', 'board', '七日委託規劃', 'player', 'login', null, 'cloud', 'core'),
    d('story-chapters', 'story-chapters.html', 'plaza', '旅程手冊', 'player', 'login', null, 'cloud', 'core'),
    d('seasonal-event', 'seasonal-event.html', 'plaza', '季節活動', 'player', 'login', null, 'cloud', 'core'),
    // ----- tools: labelled entries only, not world buildings -----
    d('landing', 'index.html', null, '產品介紹首頁', 'tool', 'public', null, 'static', 'core'),
    d('operations-economy', 'operations-economy.html', null, '自律幣經濟檢查', 'tool', 'login', 'staff', 'static', 'core'),
    d('operations-room-review', 'operations-room-review.html', null, '自律房審核', 'tool', 'login', 'staff', 'static', 'core'),
    d('operations-shop-campaign', 'operations-shop-campaign.html', null, '商城活動配置', 'tool', 'login', 'staff', 'cloud', 'core'),
    d('admin', 'admin_dashboard.html', null, '營運後台', 'tool', 'public', 'staff', 'cloud', 'core'),
    d('research', 'research.html', null, '研究中心', 'tool', 'login', null, 'static', 'core'),
    d('research-anonymized', 'research-anonymized.html', null, '匿名資料分析', 'tool', 'login', null, 'static', 'core'),
    d('research-scenario', 'research-scenario.html', null, 'Demo 場景產生器', 'tool', 'login', null, 'static', 'core'),
    d('research-score-demo', 'research-score-demo.html', null, '自律分數展示', 'tool', 'login', null, 'static', 'core'),
    d('presentation', 'presentation.html', null, '專題發表流程', 'tool', 'login', null, 'static', 'core'),
    d('museum-demo', 'museum-demo.html', null, '紀錄館展示', 'tool', 'public', null, 'demo', '#84'),
    d('world-ui-kit', 'world-ui-kit.html', null, '像素介面元件', 'tool', 'public', null, 'static', 'core'),
  ]);

  function d(id, href, building, title, audience, auth, gate, source, owner, status) {
    return Object.freeze({
      id, href, building, title, audience, auth, gate: gate || null, source, owner,
      status: status || 'available', scene: null,
    });
  }

  // An in-town scene: opened inside town.html by the script that registered it.
  function scene(id, sceneId, building, title, owner) {
    return Object.freeze({
      ...d(id, `town.html#${sceneId}`, building, title, 'player', 'login', null, 'cloud', owner),
      scene: sceneId,
    });
  }

  // Scene registry: a scene script calls registerScene('desk', open) and the
  // town panel opens it in place. Other packages can register their own
  // in-town scenes the same way.
  const scenes = new Map();
  function registerScene(sceneId, open) {
    if (typeof sceneId !== 'string' || !/^[a-z][a-z0-9-]*$/.test(sceneId) || typeof open !== 'function') {
      throw new Error('registerScene needs a lowercase id and an open() function');
    }
    scenes.set(sceneId, open);
  }
  function sceneOpener(sceneId) { return scenes.get(sceneId) || null; }

  const ARRIVAL_PARAM = 'at';
  const TOWN_PAGE = 'town.html';

  function isBuilding(id) {
    return typeof id === 'string' && Object.prototype.hasOwnProperty.call(BUILDINGS, id);
  }

  function fileOf(href) {
    return String(href || '').split('#')[0].split('?')[0].split('/').pop();
  }

  /** Town link that puts the player at a building's door (unknown ids are dropped). */
  function townHref(buildingId) {
    return isBuilding(buildingId) ? `${TOWN_PAGE}?${ARRIVAL_PARAM}=${buildingId}` : TOWN_PAGE;
  }

  /** Building id requested by ?at=…, or null. Never trusts anything else in the URL. */
  function arrivalBuilding(search) {
    let value = null;
    try { value = new URLSearchParams(String(search || '')).get(ARRIVAL_PARAM); } catch { value = null; }
    return isBuilding(value) ? value : null;
  }

  function destinationsFor(buildingId, options = {}) {
    const includePlanned = Boolean(options.includePlanned);
    return DESTINATIONS.filter(x => x.building === buildingId && (includePlanned || x.status === 'available'));
  }

  function destinationForPage(pathOrFile) {
    const file = fileOf(pathOrFile);
    if (!file) return null;
    return DESTINATIONS.find(x => fileOf(x.href) === file && !x.href.includes('#')) || null;
  }

  /** Where a page's "back to town" link should land. Tool pages and unknown pages return to the square. */
  function returnHrefForPage(pathOrFile) {
    const dest = destinationForPage(pathOrFile);
    return townHref(dest && dest.audience === 'player' && dest.building ? dest.building : null);
  }

  /**
   * How the town should present an entry for this viewer.
   * viewer = { signedIn, level }. Role gates are explained, not decided:
   * the page's own guard redirects (e.g. guardian.html -> guardian-link.html).
   */
  function entryState(dest, viewer = {}) {
    if (!dest) return { kind: 'missing', reason: '找不到這個入口' };
    if (dest.status !== 'available') return { kind: 'planned', reason: '這個場景還在建造中' };
    if (dest.auth === 'login' && !viewer.signedIn) {
      return { kind: 'login', href: 'login.html', reason: '登入後才能進入；登入完成會回到這裡' };
    }
    if (dest.gate === 'level10' && !(Number(viewer.level) >= 10)) {
      return { kind: 'locked', reason: `角色 Lv 10 開放（目前 Lv ${Math.max(1, Number(viewer.level) || 1)}）` };
    }
    return { kind: 'open', href: dest.href, reason: GATE_NOTES[dest.gate] || '' };
  }

  const GATE_NOTES = Object.freeze({
    family: '需要已連結的家庭；尚未連結會先帶你到連結頁',
    group: '需要已加入的團體；尚未加入會先帶你到加入頁',
    groupManager: '只有團體管理者能使用；成員會被帶回團體頁',
    roomMember: '只有已核准的房間成員能進入',
    staff: '營運人員專用，權限由 Cloud 檢查',
    level10: '',
  });

  return Object.freeze({
    BUILDINGS,
    DESTINATIONS,
    ARRIVAL_PARAM,
    isBuilding,
    townHref,
    arrivalBuilding,
    destinationsFor,
    destinationForPage,
    returnHrefForPage,
    entryState,
    registerScene,
    sceneOpener,
  });
});
