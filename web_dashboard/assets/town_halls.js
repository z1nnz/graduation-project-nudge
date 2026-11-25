(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.NudgeTownHalls = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';
  // Building interiors for the town. Entering a building opens its room full
  // screen; each destination from town_routes.js becomes an object on the
  // art. Desktop (wide) and phone (tall) have their own art and spots; rects
  // are fractions of that art [x, y, w, h]. Destinations without a spot hang
  // as signs in the room, so nothing is ever unreachable.

  const W = (art, aspect, spots, extra = {}) => ({ art, aspect, spots, ...extra });
  const lights = (points, radius = 0.014) => ({ type: 'flicker', points, radius });

  const HALLS = Object.freeze({
    cabin: {
      npc: 'companion', line: '回家了！要坐到書桌前專注，還是看看我今天的樣子？',
      tall: W('assets/home/room_base.png', 720 / 1279, {
        'focus-desk': [0.39, 0.44, 0.45, 0.13], 'desk-scene': [0.39, 0.3, 0.26, 0.12],
        'cabin-feedback': [0.31, 0.08, 0.38, 0.21], 'cabin-scene': [0.12, 0.29, 0.25, 0.27], profile: [0.67, 0.31, 0.2, 0.1],
      }, { npcAt: [0.5, 0.82], effects: [lights([[0.12, 0.2], [0.88, 0.2]], 0.04), { type: 'dust', count: 14 }, { type: 'stars', count: 8, height: 0.2 }] }),
    },
    board: {
      npc: 'scroll', line: '我是告示員阿紙。板子上釘的都是你自己的委託，挑一張開始吧！',
      wide: W('assets/scenes/board/board_wide.webp', 1.5, {
        tasks: [0.21, 0.18, 0.24, 0.4], 'quest-board': [0.45, 0.18, 0.23, 0.4], 'quest-book': [0.73, 0.25, 0.18, 0.3],
        'weekly-planner': [0.08, 0.02, 0.1, 0.16], 'townsfolk-request': [0.63, 0.6, 0.3, 0.24], 'quest-board-scene': [0.01, 0.25, 0.17, 0.46],
      }, {
        npcAt: [0.36, 0.92],
        effects: [lights([[0.5, 0.07], [0.43, 0.06], [0.57, 0.06], [0.94, 0.22], [0.72, 0.63]], 0.02), { type: 'flutter', count: 6, top: 0.2, fall: 0.4, x: 0.45 }, { type: 'dust', count: 18 }],
        walkers: [{ id: 'chestnut', path: [[0.25, 0.8], [0.55, 0.75], [0.45, 0.88]], speed: 0.03, pause: 3000 }],
      }),
      tall: W('assets/scenes/board/board.webp', 2 / 3, {
        tasks: [0.12, 0.17, 0.33, 0.36], 'quest-board': [0.45, 0.17, 0.3, 0.36], 'quest-book': [0.76, 0.29, 0.22, 0.22],
        'weekly-planner': [0.0, 0.0, 0.16, 0.12], 'townsfolk-request': [0.52, 0.63, 0.44, 0.2], 'quest-board-scene': [0.0, 0.2, 0.11, 0.4],
      }, { npcAt: [0.2, 0.95], effects: [lights([[0.47, 0.07], [0.67, 0.67], [0.92, 0.2]], 0.03), { type: 'dust', count: 12 }] }),
    },
    tower: {
      npc: 'bell', line: '我是守門人鐘鐘。塔裡每一層都是一間自律房，推門就能上去。',
      wide: W('assets/scenes/focus_tower/gate.webp', 512 / 216, {
        rooms: [0.38, 0.1, 0.27, 0.75], 'room-chat': [0.68, 0.1, 0.12, 0.45],
      }, { npcAt: [0.22, 0.95], effects: [lights([[0.3, 0.3], [0.72, 0.3]], 0.03), { type: 'fireflies', count: 12, top: 0.5, band: 0.45 }] }),
      tall: W('assets/scenes/focus_tower/tower_tall.webp', 2 / 3, {
        rooms: [0.52, 0.72, 0.18, 0.14], 'room-chat': [0.55, 0.25, 0.14, 0.12],
      }, {
        npcAt: [0.28, 0.9],
        effects: [{ type: 'stars', count: 30, height: 0.3 }, { type: 'clouds', top: 0.12, band: 0.1, count: 3, alpha: 0.25 },
          lights([[0.62, 0.21], [0.61, 0.3], [0.62, 0.39], [0.61, 0.48], [0.62, 0.57], [0.61, 0.66], [0.47, 0.76], [0.75, 0.76]], 0.02),
          { type: 'birds', y: 0.18, count: 4 }],
        walkers: [{ id: 'companion', path: [[0.2, 0.97], [0.45, 0.88], [0.6, 0.86]], speed: 0.04, pause: 2000 }],
      }),
    },
    family: {
      npc: 'sprout', line: '這是家人的庭院。中間的花圃是大家一起照顧的共同目標喔。',
      wide: W('assets/scenes/family_courtyard/courtyard.webp', 3 / 2, {
        'family-courtyard': [0.33, 0.43, 0.34, 0.22], guardian: [0.31, 0.22, 0.08, 0.21], 'guardian-link': [0.69, 0.22, 0.08, 0.21],
        'guardian-report': [0.08, 0.38, 0.2, 0.17], 'guardian-goals': [0.48, 0.26, 0.12, 0.12], 'guardian-permissions': [0.6, 0.27, 0.08, 0.1],
        'guardian-encouragement': [0.89, 0.35, 0.1, 0.18],
      }, {
        npcAt: [0.2, 0.85],
        effects: [lights([[0.38, 0.17], [0.67, 0.17], [0.36, 0.47], [0.65, 0.47], [0.33, 0.8], [0.67, 0.8], [0.81, 0.23]], 0.015), { type: 'fireflies', count: 14, top: 0.4, band: 0.5 }, { type: 'flutter', count: 6, color: '#e9c4ff', top: 0.0, fall: 0.5, x: 0.15 }],
        walkers: [{ id: 'letty', path: [[0.9, 0.62], [0.75, 0.68], [0.6, 0.72], [0.75, 0.66]], speed: 0.035, pause: 2500 }],
      }),
    },
    guild: {
      npc: 'scroll', line: '團體會館到了。牆上的拼圖，每完成一塊就是大家一起努力的成果。',
      wide: W('assets/scenes/guild_hall/hall.webp', 3 / 2, {
        groups: [0.58, 0.15, 0.25, 0.42], 'groups-study-schedule': [0.18, 0.33, 0.17, 0.25], clubs: [0.37, 0.36, 0.1, 0.11],
        'groups-ranking': [0.49, 0.36, 0.07, 0.11], 'group-hall': [0.37, 0.48, 0.19, 0.13], 'groups-link': [0.0, 0.3, 0.05, 0.3],
        'groups-templates': [0.06, 0.33, 0.11, 0.27], 'groups-challenge': [0.87, 0.3, 0.12, 0.32],
      }, {
        npcAt: [0.25, 0.9],
        effects: [lights([[0.04, 0.24], [0.36, 0.24], [0.56, 0.24], [0.97, 0.24]], 0.02), { type: 'dust', count: 18 }, { type: 'sparkle', points: [[0.71, 0.18], [0.66, 0.3], [0.77, 0.4]] }],
        walkers: [{ id: 'inky', path: [[0.4, 0.75], [0.7, 0.72], [0.55, 0.85]], speed: 0.03, pause: 3000 }],
      }),
    },
    library: {
      npc: 'inky', line: '我是館員墨墨。每一本書都是你自己的紀錄，想翻哪一本？',
      tall: W('assets/scenes/library/library_room.webp', 3 / 4, {
        museum: [0.2, 0.5, 0.2, 0.16], 'task-template': [0.02, 0.44, 0.18, 0.2], identity: [0.15, 0.27, 0.21, 0.22],
        'skill-tree': [0.37, 0.27, 0.26, 0.24], weather: [0.64, 0.27, 0.22, 0.22], 'time-capsule': [0.76, 0.47, 0.2, 0.17],
        'future-letter': [0.3, 0.66, 0.4, 0.13], 'share-card': [0.25, 0.2, 0.11, 0.07], onboarding: [0.0, 0.27, 0.07, 0.25], pressure: [0.93, 0.27, 0.07, 0.25],
      }, { npcAt: [0.12, 0.97], effects: [lights([[0.08, 0.19], [0.91, 0.19], [0.17, 0.15], [0.82, 0.15], [0.31, 0.68], [0.69, 0.68]], 0.025), { type: 'dust', count: 20 }] }),
    },
    store: {
      npc: 'chestnut', line: '歡迎光臨！貨架、玻璃櫃和錢箱都在裡面，推門進來吧。',
      wide: W('assets/scenes/store/store_wide.webp', 1.5, { shop: [0.05, 0.17, 0.7, 0.48] }, {
        npcAt: [0.17, 0.9], effects: [lights([[0.43, 0.13], [0.62, 0.13], [0.59, 0.54]], 0.03), { type: 'dust', count: 18 }],
        walkers: [{ id: 'letty', path: [[0.4, 0.9], [0.62, 0.86], [0.72, 0.95]], speed: 0.05, pause: 1800 }],
      }),
      tall: W('assets/scenes/store/store.webp', 2 / 3, { shop: [0.03, 0.19, 0.84, 0.3] }, { npcAt: [0.3, 0.9] }),
    },
    park: {
      npc: 'bounce', line: '我是跳跳！每天可以免費玩 3 次，四個遊樂設施隨你挑～',
      wide: W('assets/scenes/park/park_wide.webp', 1.5, { arcade: [0.47, 0.68, 0.13, 0.2] }, {
        npcAt: [0.42, 0.9],
        effects: [{ type: 'clouds', top: 0.0, band: 0.07, count: 5, alpha: 0.3 }, { type: 'birds', y: 0.06 }, { type: 'balloons', points: [[0.36, 0.73], [0.38, 0.72], [0.71, 0.74], [0.73, 0.75]], radius: 0.01 }],
        walkers: [{ id: 'companion', path: [[0.535, 0.97], [0.535, 0.62], [0.44, 0.48], [0.4, 0.3]], speed: 0.05, pause: 1500 }],
      }),
      tall: W('assets/scenes/park/park.webp', 2 / 3, { arcade: [0.36, 0.76, 0.28, 0.2] }, { npcAt: [0.24, 0.95] }),
    },
    observatory: {
      npc: 'stella', line: '我是星婆。抬頭看看，你的自律星球就在穹頂上轉喔。',
      tall: W('assets/scenes/observatory/observatory_room.webp', 3 / 4, {
        planet: [0.2, 0.05, 0.6, 0.32], trends: [0.3, 0.45, 0.14, 0.15], 'virtual-devices': [0.47, 0.45, 0.16, 0.17],
        achievements: [0.06, 0.43, 0.18, 0.2], 'planet-builder': [0.01, 0.66, 0.32, 0.2],
      }, { npcAt: [0.72, 0.95], effects: [{ type: 'stars', count: 40, height: 0.36 }, lights([[0.06, 0.24], [0.94, 0.24], [0.17, 0.68]], 0.03), { type: 'birds', y: 0.2, count: 3, color: '#ffffff' }] }),
    },
    garden: {
      npc: 'sprout', line: '我是園丁苗苗。你的每個真實行動，都會在這裡長出一株植物。',
      wide: W('assets/scenes/garden/garden_wide.webp', 1.5, { 'garden-scene': [0.29, 0.33, 0.49, 0.28] }, {
        npcAt: [0.22, 0.8], effects: [{ type: 'stars', count: 24, height: 0.1 }, { type: 'fireflies', count: 20, top: 0.25, band: 0.6 }],
        walkers: [{ id: 'companion', path: [[0.52, 0.96], [0.52, 0.64]], speed: 0.04, pause: 2500 }],
      }),
      tall: W('assets/scenes/garden/garden.webp', 2 / 3, { 'garden-scene': [0.2, 0.33, 0.6, 0.3] }, { npcAt: [0.4, 0.86] }),
    },
    plaza: {
      npc: 'letty', line: '我是郵差小信！噴水池是全鎮的共同目標，郵筒裡有給你的信。',
      wide: W('assets/scenes/town_plaza/plaza.webp', 3 / 2, {
        'town-goals': [0.35, 0.3, 0.3, 0.36], mailbox: [0.82, 0.27, 0.09, 0.16], 'thanks-cards': [0.1, 0.22, 0.11, 0.18],
        buddies: [0.05, 0.68, 0.15, 0.16], friends: [0.8, 0.68, 0.16, 0.16], notifications: [0.46, 0.13, 0.08, 0.11],
        'exchange-journal': [0.69, 0.15, 0.12, 0.12], 'safety-center': [0.0, 0.2, 0.08, 0.18],
      }, {
        npcAt: [0.62, 0.9],
        effects: [
          { type: 'stars', count: 22, height: 0.1 }, { type: 'birds', y: 0.05 }, { type: 'clouds', top: 0.0, band: 0.06, count: 3, alpha: 0.25 },
          { type: 'fountain', points: [[0.5, 0.47]], scale: 1.1, basin: 2 },
          lights([[0.07, 0.62], [0.93, 0.62], [0.39, 0.4], [0.61, 0.4], [0.36, 0.53], [0.64, 0.53], [0.5, 0.33]], 0.015),
          { type: 'flicker', points: [[0.21, 0.16], [0.27, 0.23], [0.47, 0.15], [0.53, 0.15], [0.79, 0.1], [0.88, 0.15], [0.12, 0.3]], radius: 0.008, color: '#ffe08a' },
          { type: 'smoke', points: [[0.2, 0.03], [0.62, 0.05], [0.88, 0.02]], rise: 0.06 },
        ],
        walkers: [
          { id: 'chestnut', path: [[0.25, 0.55], [0.3, 0.75], [0.5, 0.82], [0.7, 0.75], [0.75, 0.55], [0.5, 0.25]], speed: 0.04, pause: 2000 },
          { id: 'inky', path: [[0.78, 0.5], [0.6, 0.27], [0.4, 0.27], [0.22, 0.5]], speed: 0.03, pause: 2500 },
          { id: 'sprout', path: [[0.45, 0.95], [0.5, 0.7], [0.55, 0.95]], speed: 0.03, pause: 3000 },
        ],
      }),
      tall: W('assets/scenes/town_plaza/plaza_tall.webp', 2 / 3, {
        'town-goals': [0.3, 0.25, 0.4, 0.27], mailbox: [0.8, 0.25, 0.13, 0.1], 'thanks-cards': [0.1, 0.24, 0.17, 0.1],
        buddies: [0.06, 0.53, 0.19, 0.1], friends: [0.75, 0.57, 0.2, 0.1], notifications: [0.43, 0.12, 0.14, 0.12],
        'exchange-journal': [0.8, 0.16, 0.15, 0.07], 'safety-center': [0.0, 0.2, 0.08, 0.13],
      }, {
        npcAt: [0.5, 0.88],
        effects: [
          { type: 'stars', count: 24, height: 0.08 }, { type: 'birds', y: 0.05, count: 4 },
          { type: 'fountain', points: [[0.5, 0.39]], scale: 1.6, basin: 2 },
          lights([[0.07, 0.48], [0.92, 0.5], [0.35, 0.36], [0.65, 0.36], [0.5, 0.3]], 0.025),
          { type: 'flicker', points: [[0.2, 0.13], [0.45, 0.14], [0.55, 0.14], [0.86, 0.13], [0.06, 0.25]], radius: 0.012, color: '#ffe08a' },
          { type: 'smoke', points: [[0.18, 0.08], [0.5, 0.09], [0.85, 0.08]], rise: 0.05 },
        ],
        walkers: [
          { id: 'chestnut', path: [[0.2, 0.7], [0.5, 0.78], [0.8, 0.72], [0.7, 0.5], [0.3, 0.5]], speed: 0.04, pause: 2000 },
          { id: 'inky', path: [[0.4, 0.95], [0.45, 0.72], [0.6, 0.9]], speed: 0.03, pause: 2500 },
        ],
      }),
    },
  });

  function hallFor(buildingId) { return HALLS[buildingId] || null; }

  /** Layouts in the shape scene_room.js expects (rects keyed by destination id). */
  function layoutsFor(buildingId) {
    const hall = HALLS[buildingId];
    if (!hall) return null;
    const out = {};
    for (const key of ['wide', 'tall']) {
      const l = hall[key];
      if (l) out[key] = { art: l.art, aspect: l.aspect, rects: l.spots, npcAt: l.npcAt, effects: l.effects || [], walkers: l.walkers || [] };
    }
    return out;
  }

  /** Spot for a destination as fractions on one layout, or null. */
  function spotFor(buildingId, destId, layout) {
    const hall = HALLS[buildingId];
    const l = hall && (hall[layout] || hall.tall || hall.wide);
    return l?.spots?.[destId] || null;
  }

  return Object.freeze({ HALLS, hallFor, layoutsFor, spotFor });
});
