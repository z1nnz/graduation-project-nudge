// Focus desk (J8): the desk follows the page's own timer, keeps every
// control, and only animates.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const read = f => fs.readFileSync(path.join(__dirname, '..', f), 'utf8');

test('personal-focus keeps its timer controls and adds the desk after the room', () => {
  const html = read('web_dashboard/personal-focus.html');
  for (const id of ['focusTimerDisplay', 'focusTimerStatus', 'btnStartFocus', 'btnPauseFocus', 'btnStopFocus', 'focusSettlement']) {
    assert.ok(html.includes(`id="${id}"`), id);
  }
  assert.ok(html.indexOf('page_room.js') < html.indexOf('personal_focus_desk.js'));
});

test('the desk reads the timer, writes nothing, and runs on rAF', () => {
  const js = read('web_dashboard/assets/personal_focus_desk.js');
  for (const a of ["'read'", "'stretch'", "'snack'", "'look'", "'happy'"]) assert.ok(js.includes(a), a);
  assert.ok(!/firestore|httpsCallable|fetch\(/.test(js));
  assert.ok(js.includes('requestAnimationFrame') && js.includes('visibilitychange'));
  assert.ok(!/setInterval\(/.test(js));
  assert.ok(read('web_dashboard/assets/personal_focus_desk.css').includes('prefers-reduced-motion'));
});

test('the focus room has both layouts with a live sky window', () => {
  globalThis.NudgePageRooms = undefined;
  require('../web_dashboard/assets/page_rooms_home.js');
  const cfg = globalThis.NudgePageRooms.focus;
  assert.ok(cfg.art.endsWith('_mid.webp') && cfg.wide.art.endsWith('_mid.webp'));
  assert.ok(cfg.aspect < 1 && cfg.wide.aspect > 1);
});
