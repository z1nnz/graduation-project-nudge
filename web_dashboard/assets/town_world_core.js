(function(root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  root.NudgeTownWorldCore = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function() {
  'use strict';
  // The living town world (#200 H1). The original map (1672x941) stays the
  // market district at its own coordinates, so building doors, NPC routes and
  // shared friend positions keep their meaning; the new districts extend the
  // world outwards (negative x/y and beyond the map) to 2x its width and height.
  // Pure data and maths only: drawing lives in town_world.js.

  const MAP = Object.freeze({ w: 1672, h: 941 });
  const WORLD = Object.freeze({ x: -836, y: -470, w: 3344, h: 1882 });
  const rect = (x, y, w, h) => Object.freeze({ x, y, w, h });

  const DISTRICTS = Object.freeze([
    Object.freeze({ id: 'market', name: '市集', rects: [rect(0, 0, 1672, 941)] }),
    Object.freeze({ id: 'forest', name: '森林步道', rects: [rect(-836, -470, 3344, 470)] }),
    Object.freeze({ id: 'residential', name: '住宅區', rects: [rect(-836, 0, 836, 1411)] }),
    Object.freeze({ id: 'lakeside', name: '湖畔', rects: [rect(1672, 0, 836, 1411), rect(0, 941, 1672, 470)] }),
  ]);

  // Mid-layer life: every point is in world coordinates.
  const HOUSES = Object.freeze([
    { id: 'h1', x: -720, y: 130, w: 150, h: 120 }, { id: 'h2', x: -520, y: 110, w: 170, h: 130 },
    { id: 'h3', x: -300, y: 150, w: 140, h: 115 }, { id: 'h4', x: -700, y: 470, w: 160, h: 125 },
    { id: 'h5', x: -470, y: 500, w: 150, h: 120 }, { id: 'h6', x: -260, y: 470, w: 160, h: 130 },
    { id: 'h7', x: -690, y: 820, w: 150, h: 120 }, { id: 'h8', x: -440, y: 850, w: 170, h: 125 },
  ].map(h => Object.freeze({ ...h, windows: [[0.28, 0.55], [0.72, 0.55]], chimney: [0.78, 0] })));
  const LANDMARKS = Object.freeze({
    windmill: Object.freeze({ x: -180, y: 1120 }),
    waterwheel: Object.freeze({ x: 1860, y: 900 }),
    fountain: Object.freeze({ x: Math.round(0.48 * 1672), y: Math.round(0.52 * 941) }),
    flags: Object.freeze([{ x: 1090, y: 105 }, { x: 1250, y: 105 }, { x: 760, y: 30 }]),
    lake: Object.freeze({ x: 1880, y: 560, w: 520, h: 330 }),
    pond: Object.freeze({ x: 260, y: 1120, w: 900, h: 220 }),
    bakery: Object.freeze({ x: Math.round(0.205 * 1672), y: Math.round(0.82 * 941) }),
  });

  // Not walkable: the market's painted river/hill band (the old map bounds
  // started at 22% height), the lake water and the forest's tree line.
  const BLOCKERS = Object.freeze([
    rect(0, 0, 1672, 0.22 * 941),
    rect(1880, 560, 520, 330),
    rect(260, 1120, 900, 220),
    rect(-836, -470, 3344, 120),
    // House walls (the roof overhang stays walkable so labels never trap the player).
    ...HOUSES.map(h => rect(h.x, h.y + h.h * 0.4, h.w, h.h * 0.6)),
  ]);
  const BOUNDS = rect(WORLD.x + 24, WORLD.y + 24, WORLD.w - 48, WORLD.h - 48);

  function inRect(p, r) { return p.x >= r.x && p.x <= r.x + r.w && p.y >= r.y && p.y <= r.y + r.h; }

  function districtAt(p) {
    return DISTRICTS.find(d => d.rects.some(r => inRect(p, r))) || null;
  }

  // Four light states the issue asks for; dawn from the atmosphere clock is
  // the morning light.
  const LIGHT = Object.freeze({
    morning: Object.freeze({ tint: [255, 196, 140], alpha: 0.12 }),
    day: Object.freeze({ tint: [255, 255, 255], alpha: 0 }),
    dusk: Object.freeze({ tint: [190, 92, 120], alpha: 0.22 }),
    night: Object.freeze({ tint: [40, 30, 96], alpha: 0.42 }),
  });
  function lightName(phase) { return phase === 'dawn' ? 'morning' : phase; }

  /** Overlay colour for a phase, blended in over the first 20 minutes. */
  function lighting(phase, from, blend = 1) {
    const to = LIGHT[lightName(phase)] || LIGHT.day;
    const was = LIGHT[lightName(from)] || to;
    const t = Math.min(1, Math.max(0, blend));
    const mix = (a, b) => Math.round(a + (b - a) * t);
    return {
      name: lightName(phase),
      rgb: [mix(was.tint[0], to.tint[0]), mix(was.tint[1], to.tint[1]), mix(was.tint[2], to.tint[2])],
      alpha: was.alpha + (to.alpha - was.alpha) * t,
    };
  }

  function hash(value) {
    let h = 2166136261;
    for (let i = 0; i < value.length; i++) { h ^= value.charCodeAt(i); h = Math.imul(h, 16777619); }
    return h >>> 0;
  }

  /**
   * Windows light one by one from dusk: each window has its own delay within
   * the first 45 minutes of dusk. At night all are lit until 23:00, after
   * which a few go dark again. Morning and day keep them dark.
   */
  function windowLit(windowId, phase, minutesIntoPhase, hour) {
    const delay = hash(`window:${windowId}`) % 45;
    if (phase === 'dusk') return minutesIntoPhase >= delay;
    if (phase === 'night') return !(hour >= 23 || hour < 5) || hash(`late:${windowId}`) % 3 !== 0;
    return false;
  }

  // NPC daily routine (Asia/Taipei hour): open the shop in the morning, stroll
  // the plaza at noon, work in the afternoon, go home in the evening.
  const ROUTINE = Object.freeze([
    { from: 0, to: 7, mode: 'home' },
    { from: 7, to: 11, mode: 'shop' },
    { from: 11, to: 14, mode: 'plaza' },
    { from: 14, to: 18, mode: 'shop' },
    { from: 18, to: 24, mode: 'home' },
  ]);
  const NPC_PLACES = Object.freeze({
    baker: { shop: [0.24, 0.84], home: [-0.30, 0.55] },
    gardener: { shop: [0.66, 0.80], home: [-0.40, 0.95] },
    postman: { shop: [0.52, 0.60], home: [-0.18, 0.18] },
  });
  const PLAZA = [0.48, 0.62];

  /** Where an NPC spends this hour, in map-normalised coordinates. */
  function routineFor(npcId, hour) {
    const slot = ROUTINE.find(r => hour >= r.from && hour < r.to) || ROUTINE[0];
    const places = NPC_PLACES[npcId];
    if (!places) return { mode: slot.mode, anchor: null };
    const anchor = slot.mode === 'plaza' ? PLAZA : places[slot.mode === 'shop' ? 'shop' : 'home'];
    return { mode: slot.mode, anchor: { x: anchor[0], y: anchor[1] } };
  }

  /**
   * Move an NPC's short patrol route to where they are this hour: the route
   * keeps its shape (half size) around the routine anchor.
   */
  function scheduledPosition(npc, routePosition, hour) {
    const { mode, anchor } = routineFor(npc.id, hour);
    if (!anchor || !Array.isArray(npc.route) || !npc.route.length) return { ...routePosition, mode };
    const cx = npc.route.reduce((sum, p) => sum + p[0], 0) / npc.route.length;
    const cy = npc.route.reduce((sum, p) => sum + p[1], 0) / npc.route.length;
    return { ...routePosition, mode,
      x: anchor.x + (routePosition.x - cx) * 0.5,
      y: anchor.y + (routePosition.y - cy) * 0.5 };
  }

  /** Customers queuing at the bakery while it is open (fixed per hour). */
  function bakeryQueue(hour, dayKey) {
    if (hour < 7 || hour >= 19) return [];
    const count = 1 + hash(`queue:${dayKey}:${hour}`) % 3;
    return Array.from({ length: count }, (_, i) => ({
      x: LANDMARKS.bakery.x + 26 + i * 22,
      y: LANDMARKS.bakery.y + 10,
      look: hash(`queue-look:${dayKey}:${hour}:${i}`) % 4,
    }));
  }

  /** Building reaction: the door swings open and the sign glows when close. */
  function doorState(distance) {
    if (!(distance >= 0)) return { open: 0, sign: false };
    const open = distance >= 90 ? 0 : distance <= 40 ? 1 : (90 - distance) / 50;
    return { open, sign: distance < 110 };
  }

  /** Desktop (wide) or phone (tall) composition and their framing. */
  function layoutFor(width, height) {
    const tall = height > width * 1.05;
    return tall
      ? { name: 'tall', zoomFloor: 0.55, labelScale: 1.15, buttonScale: 1.25 }
      : { name: 'wide', zoomFloor: 0.38, labelScale: 1, buttonScale: 1 };
  }

  /** Map the shared daily weather onto the issue's clear / rain / snow skies. */
  function skyFor(weatherKind) {
    if (weatherKind === 'rain') return 'rain';
    if (weatherKind === 'snow') return 'snow';
    return 'clear';
  }

  return Object.freeze({
    MAP, WORLD, DISTRICTS, BLOCKERS, BOUNDS, HOUSES, LANDMARKS, ROUTINE,
    inRect, districtAt, lighting, windowLit, routineFor, scheduledPosition, bakeryQueue, doorState, layoutFor, skyFor, hash,
  });
});
