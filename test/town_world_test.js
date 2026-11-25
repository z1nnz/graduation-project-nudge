const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const world = require('../web_dashboard/assets/town_world_core.js');

const DOORS = [[0.165, 0.585], [0.327, 0.555], [0.447, 0.345], [0.18, 0.345], [0.648, 0.365],
  [0.875, 0.585], [0.205, 0.82], [0.6, 0.79], [0.93, 0.28], [0.88, 0.92], [0.48, 0.61]]
  .map(([x, y]) => ({ x: Math.round(x * 1672), y: Math.round(y * 941) }));
const START = { x: Math.round(0.475 * 1672), y: Math.round(0.66 * 941) };

test('the world is at least twice the old map and keeps it as the market district', () => {
  assert.ok(world.WORLD.w >= world.MAP.w * 2);
  assert.ok(world.WORLD.h >= world.MAP.h * 2);
  assert.equal(world.districtAt({ x: 800, y: 600 }).id, 'market');
  assert.equal(world.districtAt({ x: -400, y: 600 }).id, 'residential');
  assert.equal(world.districtAt({ x: 2000, y: 400 }).id, 'lakeside');
  assert.equal(world.districtAt({ x: 800, y: 1200 }).id, 'lakeside');
  assert.equal(world.districtAt({ x: 800, y: -200 }).id, 'forest');
  assert.deepEqual(world.DISTRICTS.map(d => d.name).sort(), ['住宅區', '市集', '森林步道', '湖畔'].sort());
});

test('every district is reachable: doors and start stay walkable and inside bounds', () => {
  const blocked = p => world.BLOCKERS.some(r => world.inRect(p, r));
  for (const p of [START, ...DOORS]) {
    assert.ok(world.inRect(p, world.BOUNDS), `${p.x},${p.y} in bounds`);
    assert.ok(!blocked(p), `${p.x},${p.y} walkable`);
  }
  for (const p of [{ x: -400, y: 630 }, { x: 1760, y: 630 }, { x: 2200, y: 300 }, { x: 800, y: -310 }, { x: 800, y: 1050 }]) {
    assert.ok(world.inRect(p, world.BOUNDS) && !blocked(p), `district path ${p.x},${p.y}`);
  }
  assert.ok(blocked({ x: 800, y: 100 }), 'the painted river band of the market stays a wall');
});

test('four light states blend and night is darker than dusk', () => {
  const names = ['dawn', 'day', 'dusk', 'night'].map(p => world.lighting(p, p, 1).name);
  assert.deepEqual(names, ['morning', 'day', 'dusk', 'night']);
  assert.equal(world.lighting('day', 'day', 1).alpha, 0);
  assert.ok(world.lighting('night', 'night', 1).alpha > world.lighting('dusk', 'dusk', 1).alpha);
  const half = world.lighting('night', 'dusk', 0.5);
  assert.ok(half.alpha > world.lighting('dusk', 'dusk', 1).alpha && half.alpha < world.lighting('night', 'night', 1).alpha);
});

test('windows light one by one at dusk, all at night, none by day', () => {
  const ids = world.HOUSES.flatMap(h => h.windows.map((_, i) => `${h.id}:${i}`));
  const litAt = minute => ids.filter(id => world.windowLit(id, 'dusk', minute, 18)).length;
  assert.equal(litAt(-1), 0);
  assert.ok(litAt(20) > 0 && litAt(20) < ids.length, 'some, not all, lit 20 minutes into dusk');
  assert.equal(litAt(45), ids.length);
  assert.ok(ids.every(id => world.windowLit(id, 'night', 30, 20)));
  assert.ok(ids.some(id => !world.windowLit(id, 'night', 300, 23)), 'a few go dark late at night');
  assert.ok(ids.every(id => !world.windowLit(id, 'day', 100, 12)));
});

test('NPCs follow a daily routine: shop in the morning, plaza at noon, home at night', () => {
  assert.equal(world.routineFor('baker', 8).mode, 'shop');
  assert.equal(world.routineFor('baker', 12).mode, 'plaza');
  assert.equal(world.routineFor('baker', 21).mode, 'home');
  const npc = { id: 'baker', route: [[0.2, 0.8], [0.3, 0.7]] };
  const atNoon = world.scheduledPosition(npc, { x: 0.25, y: 0.75 }, 12);
  assert.deepEqual([atNoon.x, atNoon.y], [0.48, 0.62]);
  assert.ok(world.scheduledPosition(npc, { x: 0.25, y: 0.75 }, 22).x < 0, 'home is in the residential district');
  assert.deepEqual(world.scheduledPosition({ id: 'owl' }, { x: 0.1, y: 0.2 }, 12), { x: 0.1, y: 0.2, mode: 'plaza' });
});

test('the bakery has a queue only while open and buildings react as the player nears', () => {
  assert.deepEqual(world.bakeryQueue(22, '2026-11-26'), []);
  const queue = world.bakeryQueue(9, '2026-11-26');
  assert.ok(queue.length >= 1 && queue.length <= 3);
  assert.deepEqual(world.doorState(200), { open: 0, sign: false });
  assert.deepEqual(world.doorState(100), { open: 0, sign: true });
  assert.equal(world.doorState(20).open, 1);
  assert.ok(world.doorState(65).open > 0 && world.doorState(65).open < 1);
});

test('desktop and phone get separate compositions', () => {
  assert.equal(world.layoutFor(1280, 800).name, 'wide');
  const tall = world.layoutFor(390, 844);
  assert.equal(tall.name, 'tall');
  assert.ok(tall.buttonScale > 1);
  assert.equal(world.skyFor('snow'), 'snow');
  assert.equal(world.skyFor('petal'), 'clear');
});

function fakeContext(log) {
  const ctx = { globalAlpha: 1, fillStyle: '', imageSmoothingEnabled: false };
  for (const name of ['fillRect', 'drawImage', 'save', 'restore', 'beginPath', 'fill', 'rect', 'clip']) {
    ctx[name] = (...args) => log.push([name, ...args.map(a => (typeof a === 'number' ? Math.round(a) : 'x')), ctx.fillStyle, ctx.globalAlpha]);
  }
  return ctx;
}

function loadRenderer(withArt = false) {
  const sandbox = { Image: class { constructor() { this.complete = withArt; this.naturalWidth = withArt ? 64 : 0; this.naturalHeight = withArt ? 64 : 0; } }, document: {}, Math, Object, Array };
  sandbox.globalThis = sandbox;
  vm.createContext(sandbox);
  vm.runInContext(fs.readFileSync('web_dashboard/assets/town_world_core.js', 'utf8'), sandbox);
  vm.runInContext(fs.readFileSync('web_dashboard/assets/town_world.js', 'utf8'), sandbox);
  return sandbox.NudgeTownWorld;
}

function frame(renderer, now, reducedMotion, overrides = {}) {
  const log = [];
  const ctx = fakeContext(log);
  const camera = { x: 300, y: 400 };
  const view = {
    toScreen: p => ({ x: p.x - camera.x + 640, y: p.y - camera.y + 400 }), scale: 1, width: 1280, height: 800, camera,
    light: world.lighting('dusk', 'dusk', 1), phase: 'dusk', minutesIntoPhase: 50, hour: 18, dayKey: '2026-11-26',
    weather: 'clear', reducedMotion, player: { x: 300, y: 560 },
    buildings: [{ id: 'cabin', door: { x: 276, y: 550 } }], ...overrides,
  };
  renderer.drawBehind(ctx, view, now);
  const mid = renderer.drawMid(ctx, view, now);
  renderer.drawFront(ctx, view, mid, now);
  return { log, mid };
}

test('the renderer draws every layer from pixel stand-ins before art exists', () => {
  const renderer = loadRenderer();
  const { log, mid } = frame(renderer, 1000, false);
  assert.ok(log.length > 200, 'far, ground, mid and near layers all draw');
  assert.ok(mid.windows.length > 0, 'house windows are on screen');
  assert.equal(mid.nearId, 'cabin', 'the nearby building reacts');
  assert.ok(log.some(entry => entry[0] === 'fillRect' && entry.includes('#ffd77a')), 'lit windows glow at dusk');
});

test('the world keeps moving over time and freezes on one complete frame with reduced motion', () => {
  const renderer = loadRenderer();
  const a = JSON.stringify(frame(renderer, 1000, false).log);
  const b = JSON.stringify(frame(renderer, 4000, false).log);
  assert.notEqual(a, b, 'clouds, smoke, water, wheels and foliage animate');
  const still1 = frame(renderer, 1000, true).log;
  const still2 = frame(renderer, 9000, true).log;
  assert.deepEqual(still1, still2, 'reduced motion shows the same frame');
  assert.ok(still1.length > 200, 'and that frame is not blank');
});

test('town.html loads the living world before the town script', () => {
  const html = fs.readFileSync('web_dashboard/town.html', 'utf8');
  const core = html.indexOf('assets/town_world_core.js');
  const view = html.indexOf('assets/town_world.js');
  const town = html.indexOf('assets/town.js');
  assert.ok(core > 0 && core < view && view < town);
  const source = fs.readFileSync('web_dashboard/assets/town.js', 'utf8');
  assert.match(source, /worldView\.drawBehind/);
  assert.match(source, /worldView\.drawMid/);
  assert.match(source, /worldView\.drawFront/);
  assert.match(source, /concat\(WORLD_BLOCKERS\)/);
});

test('generated art replaces each stand-in layer once the files exist', () => {
  const renderer = loadRenderer(true);
  const { log } = frame(renderer, 1000, false);
  const images = log.filter(entry => entry[0] === 'drawImage').length;
  assert.ok(images > 20, 'ground tiles, far band, houses, trees and bushes draw from art');
  assert.deepEqual(Object.keys(renderer.ART).sort(),
    ['bush', 'cottageA', 'cottageB', 'far', 'forest', 'grass', 'treeA', 'treeB', 'windmill']);
});