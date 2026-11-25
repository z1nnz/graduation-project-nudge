(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.NudgeTownHalls = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';
  // Building interiors for the town panel. Entering a building shows its room
  // art; each destination from town_routes.js becomes an object on that art.
  // Rects are fractions of the art [x, y, w, h]. Destinations without a spot
  // hang on the signpost at the bottom, so nothing is ever unreachable.

  const HALLS = Object.freeze({
    cabin: {
      art: 'assets/home/room_base.png', aspect: 720 / 1279, npc: 'companion',
      line: '回家了！要坐到書桌前專注，還是看看我今天的樣子？',
      spots: {
        'focus-desk': [0.39, 0.44, 0.45, 0.13],
        'desk-scene': [0.39, 0.3, 0.26, 0.12],
        'cabin-feedback': [0.31, 0.08, 0.38, 0.21],
        'cabin-scene': [0.12, 0.29, 0.25, 0.27],
        profile: [0.67, 0.31, 0.2, 0.1],
      },
    },
    board: {
      art: 'assets/scenes/board/board.webp', aspect: 2 / 3, npc: 'scroll',
      line: '我是告示員阿紙。板子上釘的都是你自己的委託，挑一張開始吧！',
      spots: {
        tasks: [0.12, 0.17, 0.33, 0.36],
        'quest-board': [0.45, 0.17, 0.3, 0.36],
        'quest-book': [0.76, 0.29, 0.22, 0.22],
        'weekly-planner': [0.0, 0.0, 0.16, 0.12],
        'townsfolk-request': [0.52, 0.63, 0.44, 0.2],
        'quest-board-scene': [0.0, 0.2, 0.11, 0.4],
      },
    },
    tower: {
      art: 'assets/scenes/focus_tower/gate.webp', aspect: 512 / 216, npc: 'bell',
      line: '我是守門人鐘鐘。塔裡每一層都是一間自律房，推門就能上去。',
      spots: {
        rooms: [0.38, 0.1, 0.27, 0.75],
        'room-chat': [0.68, 0.1, 0.12, 0.45],
      },
    },
    family: {
      art: 'assets/scenes/family_courtyard/courtyard.webp', aspect: 3 / 2, npc: 'sprout',
      line: '這是家人的庭院。中間的花圃是大家一起照顧的共同目標喔。',
      spots: {
        'family-courtyard': [0.33, 0.43, 0.34, 0.22],
        guardian: [0.31, 0.22, 0.08, 0.21],
        'guardian-link': [0.69, 0.22, 0.08, 0.21],
        'guardian-report': [0.08, 0.38, 0.2, 0.17],
        'guardian-goals': [0.48, 0.26, 0.12, 0.12],
        'guardian-permissions': [0.6, 0.27, 0.08, 0.1],
        'guardian-encouragement': [0.89, 0.35, 0.1, 0.18],
      },
    },
    guild: {
      art: 'assets/scenes/guild_hall/hall.webp', aspect: 3 / 2, npc: 'scroll',
      line: '團體會館到了。牆上的拼圖，每完成一塊就是大家一起努力的成果。',
      spots: {
        groups: [0.58, 0.15, 0.25, 0.42],
        'groups-study-schedule': [0.18, 0.33, 0.17, 0.25],
        clubs: [0.37, 0.36, 0.1, 0.11],
        'groups-ranking': [0.49, 0.36, 0.07, 0.11],
        'group-hall': [0.37, 0.48, 0.19, 0.13],
        'groups-link': [0.0, 0.3, 0.05, 0.3],
        'groups-templates': [0.06, 0.33, 0.11, 0.27],
        'groups-challenge': [0.87, 0.3, 0.12, 0.32],
      },
    },
    library: {
      art: 'assets/scenes/library/library_room.webp', aspect: 3 / 4, npc: 'inky',
      line: '我是館員墨墨。每一本書都是你自己的紀錄，想翻哪一本？',
      spots: {
        museum: [0.2, 0.5, 0.2, 0.16],
        'task-template': [0.02, 0.44, 0.18, 0.2],
        identity: [0.15, 0.27, 0.21, 0.22],
        'skill-tree': [0.37, 0.27, 0.26, 0.24],
        weather: [0.64, 0.27, 0.22, 0.22],
        'time-capsule': [0.76, 0.47, 0.2, 0.17],
        'future-letter': [0.3, 0.66, 0.4, 0.13],
        'share-card': [0.25, 0.2, 0.11, 0.07],
        onboarding: [0.0, 0.27, 0.07, 0.25],
        pressure: [0.93, 0.27, 0.07, 0.25],
      },
    },
    store: {
      art: 'assets/scenes/store/store.webp', aspect: 2 / 3, npc: 'chestnut',
      line: '歡迎光臨！貨架、玻璃櫃和錢箱都在裡面，推門進來吧。',
      spots: { shop: [0.03, 0.19, 0.84, 0.3] },
    },
    park: {
      art: 'assets/scenes/park/park.webp', aspect: 2 / 3, npc: 'bounce',
      line: '我是跳跳！拿休息券，四個遊樂設施隨你玩～',
      spots: { arcade: [0.36, 0.76, 0.28, 0.2] },
    },
    observatory: {
      art: 'assets/scenes/observatory/observatory_room.webp', aspect: 3 / 4, npc: 'stella',
      line: '我是星婆。抬頭看看，你的自律星球就在穹頂上轉喔。',
      spots: {
        planet: [0.2, 0.05, 0.6, 0.32],
        trends: [0.3, 0.45, 0.14, 0.15],
        'virtual-devices': [0.47, 0.45, 0.16, 0.17],
        achievements: [0.06, 0.43, 0.18, 0.2],
        'planet-builder': [0.01, 0.66, 0.32, 0.2],
      },
    },
    garden: {
      art: 'assets/scenes/garden/garden.webp', aspect: 2 / 3, npc: 'sprout',
      line: '我是園丁苗苗。你的每個真實行動，都會在這裡長出一株植物。',
      spots: { 'garden-scene': [0.2, 0.33, 0.6, 0.3] },
    },
    plaza: {
      art: 'assets/scenes/town_plaza/plaza.webp', aspect: 3 / 2, npc: 'letty',
      line: '我是郵差小信！噴水池是全鎮的共同目標，郵筒裡有給你的信。',
      spots: {
        'town-goals': [0.35, 0.3, 0.3, 0.36],
        mailbox: [0.82, 0.27, 0.09, 0.16],
        'thanks-cards': [0.1, 0.22, 0.11, 0.18],
        buddies: [0.05, 0.68, 0.15, 0.16],
        friends: [0.8, 0.68, 0.16, 0.16],
        notifications: [0.46, 0.13, 0.08, 0.11],
        'exchange-journal': [0.69, 0.15, 0.12, 0.12],
        'safety-center': [0.0, 0.2, 0.08, 0.18],
      },
    },
  });

  function hallFor(buildingId) { return HALLS[buildingId] || null; }

  /** Spot for a destination as CSS percentages, or null for the signpost. */
  function spotFor(buildingId, destId) {
    const r = HALLS[buildingId]?.spots?.[destId];
    if (!r) return null;
    return { left: r[0] * 100, top: r[1] * 100, width: r[2] * 100, height: r[3] * 100 };
  }

  return Object.freeze({ HALLS, hallFor, spotFor });
});
