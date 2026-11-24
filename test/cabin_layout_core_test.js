// Pure decorate-mode rules for the Web cabin: grid snapping, where furniture
// may be dropped, and the undo / redo stack.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');

const L = require('../web_dashboard/assets/cabin_layout_core.js');
const cabin = require('../web_dashboard/assets/cabin_core.js');

const catalog = JSON.parse(fs.readFileSync('web_dashboard/assets/home/home_decor_catalog.json', 'utf8'));
const layout = JSON.parse(fs.readFileSync('web_dashboard/assets/home/cabin_layout.json', 'utf8'));
const near = (a, b) => Math.abs(a - b) < 1e-9;

test('the grid has square cells over the stage', () => {
  const g = L.grid(layout.aspect);
  assert.equal(g.cols, 24);
  assert.ok(near(g.cellW, 1 / 24));
  assert.ok(near(g.cellH, layout.aspect / 24), 'a cell is as tall on screen as it is wide');
  assert.equal(g.rows, Math.floor(24 / layout.aspect));
  assert.equal(L.grid(0).cellH, L.grid(0.5629).cellH, 'bad aspect falls back to the App room');
});

test('snapping puts the top-left corner on a grid line and keeps the rect on the stage', () => {
  const g = L.grid(layout.aspect);
  const [x, y, w, h] = L.snapRect([0.101, 0.33, 0.2, 0.1], g);
  assert.ok(near(x / g.cellW, Math.round(x / g.cellW)));
  assert.ok(near(y / g.cellH, Math.round(y / g.cellH)));
  assert.deepEqual([w, h], [0.2, 0.1], 'size never changes');
  const edge = L.snapRect([0.95, 0.97, 0.2, 0.1], g);
  assert.ok(near(edge[0], 0.8) && near(edge[1], 0.9), 'clamped inside the stage');
  const low = L.snapRect([-0.3, -0.2, 0.2, 0.1], g);
  assert.deepEqual(low.slice(0, 2), [0, 0]);
  const centred = L.rectAt({ x: 0.5, y: 0.5 }, [0.2, 0.1], g);
  assert.ok(Math.abs(centred[0] + 0.1 - 0.5) <= g.cellW / 2 + 1e-9);
  assert.deepEqual(L.cellAt({ x: 0.999, y: 2 }, g), { col: 23, row: g.rows - 1 });
});

test('every catalog slot has exactly one allowed spot from the shared layout', () => {
  const spots = L.spots(layout, catalog);
  assert.deepEqual(spots.map(s => s.slot), catalog.slots.map(s => s.slot));
  for (const s of spots) assert.deepEqual([...s.rect], layout.layers[s.slot].rect);
  for (let i = 0; i < spots.length; i++) {
    for (let j = i + 1; j < spots.length; j++) {
      assert.equal(L.intersection(spots[i].rect, spots[j].rect), 0, 'spots never overlap each other');
    }
  }
  assert.deepEqual(L.spots(null, catalog), []);
});

test('a drop lands only on its own spot; other spots collide; empty floor is refused', () => {
  const spots = L.spots(layout, catalog);
  const g = L.grid(layout.aspect);
  const rug = layout.layers.rug.rect;
  const onRug = L.rectAt({ x: rug[0] + rug[2] / 2, y: rug[1] + rug[3] / 2 }, [rug[2], rug[3]], g);
  assert.deepEqual(L.dropTarget(spots, 'rug', onRug), { ok: true, slot: 'rug', rect: spots[0].rect });
  const lamp = layout.layers.lamp.rect;
  const rugOnLamp = L.rectAt({ x: lamp[0] + lamp[2] / 2, y: lamp[1] + lamp[3] / 2 }, [lamp[2], lamp[3]], g);
  const hit = L.dropTarget(spots, 'rug', rugOnLamp);
  assert.equal(hit.ok, false);
  assert.equal(hit.reason, 'occupied');
  assert.equal(hit.by, 'lamp');
  assert.equal(hit.byLabel, '桌燈');
  const lampOnLamp = L.dropTarget(spots, 'lamp', rugOnLamp);
  assert.equal(lampOnLamp.ok, true);
  const nowhere = L.dropTarget(spots, 'lamp', [0.02, 0.9, 0.075, 0.072]);
  assert.deepEqual(nowhere, { ok: false, reason: 'outside' });
  const barely = L.dropTarget(spots, 'lamp', [lamp[0] + lamp[2] * 0.8, lamp[1], lamp[2], lamp[3]]);
  assert.equal(barely.ok, false, 'a sliver of overlap is not a drop');
  assert.equal(L.dropTarget(spots, 'sofa', onRug).reason, 'unknown');
});

test('undo / redo keeps at most 20 steps and a new step clears redo', () => {
  let h = L.createHistory({ rug: 0, curtain: 0, lamp: 0 });
  assert.equal(L.canUndo(h), false);
  assert.equal(L.undo(h), h, 'nothing to undo');
  const same = L.record(h, { rug: 0, curtain: 0, lamp: 0 });
  assert.equal(same, h, 'an unchanged arrangement is not a step');
  for (let i = 1; i <= 25; i++) h = L.record(h, { rug: i % 3, curtain: i, lamp: 0 });
  assert.equal(h.past.length, 20, 'capped at 20');
  let back = h;
  for (let i = 0; i < 25; i++) back = L.undo(back);
  assert.deepEqual(back.present, { rug: 5 % 3, curtain: 5, lamp: 0 }, 'oldest kept step');
  assert.equal(L.canUndo(back), false);
  assert.equal(back.future.length, 20);
  const forward = L.redo(L.redo(back));
  assert.deepEqual(forward.present, { rug: 7 % 3, curtain: 7, lamp: 0 });
  const branched = L.record(L.undo(h), { rug: 2, curtain: 99, lamp: 1 });
  assert.equal(L.canRedo(branched), false, 'a new step drops the redo branch');
  assert.equal(L.redo(branched), branched);
  assert.ok(Object.isFrozen(h.present) && Object.isFrozen(h.past), 'steps are frozen');
});

test('reset uses the free defaults, and style cycling only visits owned variants', () => {
  assert.deepEqual(L.defaultArrangement(catalog), { rug: 0, curtain: 0, lamp: 0 });
  const owned = cabin.ownedVariants(catalog, ['homeDecor:2', 'homeDecor:202']);
  assert.equal(L.cycleVariant(catalog, owned, 'rug', 0, 1), 2, 'skips the unowned rug 1');
  assert.equal(L.cycleVariant(catalog, owned, 'rug', 2, 1), 0, 'wraps around');
  assert.equal(L.cycleVariant(catalog, owned, 'rug', 0, -1), 2);
  assert.equal(L.cycleVariant(catalog, owned, 'curtain', 0, 1), 0, 'only the free curtain is owned');
  assert.equal(L.cycleVariant(catalog, owned, 'lamp', 1, 1), 0, 'unowned current falls back to the first owned');
  assert.deepEqual(L.changes({ rug: 0, lamp: 1 }, { rug: 2, lamp: 1 }), ['rug']);
});
