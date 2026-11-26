// Commission hall 2.0 (J9): notes on the board, the adventure path and
// today's slip are read from the page's own DOM and only animate.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const read = f => fs.readFileSync(path.join(__dirname, '..', f), 'utf8');

test('quests and the home page load the board life after their room', () => {
  for (const f of ['web_dashboard/quests.html', 'web_dashboard/dashboard.html']) {
    const html = read(f);
    assert.ok(html.indexOf('page_room.js') < html.indexOf('quest_board_life.js'), f);
    assert.ok(html.indexOf('avatar_layers.js') < html.indexOf('quest_board_life.js'), f);
  }
  const q = read('web_dashboard/quests.html');
  for (const id of ['qbChains', 'qbTemplates', 'qbCerts', 'qbCertDialog']) assert.ok(q.includes(`id="${id}"`), id);
});

test('the board reads stamps from the quest book and writes nothing', () => {
  const js = read('web_dashboard/assets/quest_board_life.js');
  for (const s of ['.qb-chain', '.qb-slot.is-stamped', 'dailyActionTitle']) assert.ok(js.includes(s), s);
  assert.ok(!/firestore|httpsCallable|localStorage\.setItem/.test(js));
  const css = read('web_dashboard/assets/quest_board_life.css');
  for (const c of ['.qbl-pin', '.qbl-stamp', '.qbl-note.is-torn', '.qbl-step.is-flag', '.qbl-slip']) assert.ok(css.includes(c), c);
  assert.ok(css.includes('prefers-reduced-motion'));
});

test('board and study nook rooms keep both layouts with a live window', () => {
  globalThis.NudgePageRooms = undefined;
  require('../web_dashboard/assets/page_rooms_home.js');
  for (const k of ['quests', 'home']) {
    const cfg = globalThis.NudgePageRooms[k];
    assert.ok(cfg.art.endsWith('_mid.webp') && cfg.wide.art.endsWith('_mid.webp'), k);
  }
});
