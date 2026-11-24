// Behavior of web_dashboard/assets/cabin.js on a fake DOM: the decorate mode
// (owned decor only, drag onto allowed spots, undo / redo / reset), one
// arrangeHomeDecor call on 「儲存」 with the page locked, revert on failure,
// retry after a lost answer, other devices, and the companion.
const test = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');

const html = fs.readFileSync('web_dashboard/cabin.html', 'utf8');
const sources = ['cabin_core.js', 'cabin_layout_core.js', 'cabin_companion_core.js', 'cabin.js']
  .map(f => fs.readFileSync(`web_dashboard/assets/${f}`, 'utf8'));
const json = {
  'assets/home/home_decor_catalog.json': JSON.parse(fs.readFileSync('web_dashboard/assets/home/home_decor_catalog.json', 'utf8')),
  'assets/home/cabin_layout.json': JSON.parse(fs.readFileSync('web_dashboard/assets/home/cabin_layout.json', 'utf8')),
};
const layout = json['assets/home/cabin_layout.json'];

let active = null;
class El {
  constructor(tag, id = '') {
    Object.assign(this, {
      tagName: tag.toUpperCase(), id, dataset: {}, children: [], listeners: {}, attrs: {},
      hidden: false, _text: '', disabled: false, inert: false, tabIndex: 0, type: '', name: '', value: '', className: '',
    });
    const style = {};
    style.setProperty = (k, v) => { style[k] = v; };
    this.style = style;
    const el = this;
    this.classList = {
      add: c => { if (!el.classList.contains(c)) el.className = `${el.className} ${c}`.trim(); },
      remove: c => { el.className = el.className.split(/\s+/).filter(x => x && x !== c).join(' '); },
      toggle: (c, on) => (on ?? !el.classList.contains(c)) ? el.classList.add(c) : el.classList.remove(c),
      contains: c => el.className.split(/\s+/).includes(c),
    };
  }
  get textContent() { return this._text + this.children.map(c => c.textContent).join(''); }
  set textContent(v) { this._text = String(v); this.children = []; }
  setAttribute(k, v) { this.attrs[k] = String(v); }
  getAttribute(k) { return this.attrs[k] ?? null; }
  addEventListener(n, cb) { (this.listeners[n] ||= []).push(cb); }
  fire(n, e = {}) { (this.listeners[n] || []).forEach(cb => cb({ preventDefault() {}, stopPropagation() {}, target: this, ...e })); }
  appendChild(c) { this.children.push(c); return c; }
  append(...c) { c.forEach(x => this.appendChild(x)); }
  all() { return this.children.flatMap(c => [c, ...c.all()]); }
  querySelectorAll(sel) { const cls = sel.replace(/^\./, ''); return this.all().filter(n => n.classList.contains(cls)); }
  querySelector() { return null; }
  focus() { active = this; }
  getBoundingClientRect() { return { left: 0, top: 0, width: 360, height: 640 }; }
  setPointerCapture() {}
  get offsetWidth() { return 0; }
  set src(v) { this.attrs.src = v; }
  get src() { return this.attrs.src || ''; }
}

const flush = () => new Promise(r => setImmediate(r));
const OWNED = ['homeDecor:101', 'homeDecor:202'];

function cabinPage({ user = { unlockedAvatarItems: OWNED, disciplineCoins: 40, homeDecor: { rug: 0, curtain: 1, lamp: 0 } }, storage = {} } = {}) {
  active = null;
  const nodes = new Map();
  for (const [, tag, id] of html.matchAll(/<(\w+)[^>]*\sid="([^"]+)"/g)) nodes.set(id, new El(tag, id));
  for (const [, id] of html.matchAll(/\sid="([^"]+)"[^>]*\shidden[\s>]/g)) nodes.get(id).hidden = true;
  const docListeners = {};
  const rootListeners = {};
  const doc = {
    body: { dataset: { page: 'cabin' } },
    hidden: false,
    get activeElement() { return active; },
    contains: () => true,
    getElementById: id => nodes.get(id) || null,
    createElement: tag => new El(tag),
    addEventListener: (n, cb) => { (docListeners[n] ||= []).push(cb); },
  };
  let snapshot = null;
  const calls = [];
  const replies = [];
  const context = {
    document: doc,
    fetch: async path => ({ ok: Boolean(json[path]), json: async () => structuredClone(json[path]) }),
    addEventListener: (n, cb) => { (rootListeners[n] ||= []).push(cb); },
    matchMedia: () => ({ matches: false, addEventListener() {} }),
    localStorage: { getItem: k => storage[k] ?? null },
    setTimeout: () => 1, clearTimeout: () => {}, setInterval: () => 1,
    Date, Math, JSON,
    firebase: {
      apps: [{}],
      auth: () => ({ onAuthStateChanged: cb => cb({ uid: 'u1' }) }),
      firestore: () => ({ collection: () => ({ doc: () => ({ onSnapshot: cb => { snapshot = cb; cb({ exists: true, data: () => structuredClone(user) }); return () => {}; } }) }) }),
      app: () => ({ functions: () => ({ httpsCallable: name => async payload => { calls.push({ name, payload: structuredClone(payload) }); return replies.shift()(payload); } }) }),
    },
  };
  vm.createContext(context);
  for (const s of sources) vm.runInContext(s, context);
  const el = id => nodes.get(id);
  const tiles = () => el('cabinSlots').all().filter(n => n.classList.contains('cabin-tile'));
  const pointer = (type, x, y) => (rootListeners[type] || []).forEach(cb => cb({ pointerId: 1, clientX: x, clientY: y }));
  const centre = slot => { const [x, y, w, h] = layout.layers[slot].rect; return [(x + w / 2) * 360, (y + h / 2) * 640]; };
  return {
    el, calls, replies,
    push: data => snapshot({ exists: true, data: () => structuredClone(data) }),
    tile: (slot, index) => tiles().find(n => n.name === `decor-${slot}` && n.value === String(index)),
    spot: slot => el('cabinSpots').children.find(n => n.dataset.slot === slot),
    current: () => Object.fromEntries(['rug', 'curtain', 'lamp'].map(s => [s, Number(tiles().find(n => n.name === `decor-${s}` && n.getAttribute('aria-pressed') === 'true')?.value)])),
    decorate() { el('cabinDecorate').fire('click'); },
    pick(slot, index) { this.tile(slot, index).fire('click'); },
    drag(slot, index, [x, y]) {
      const tile = this.tile(slot, index);
      tile.fire('pointerdown', { pointerId: 1, button: 0, clientX: 600, clientY: 300 });
      pointer('pointermove', 610, 300);
      pointer('pointermove', x, y);
      pointer('pointerup', x, y);
      tile.fire('click'); // the browser's click after a drag is swallowed
    },
    centre,
    key: (key, extra = {}) => (docListeners.keydown || []).forEach(cb => cb({ key, preventDefault() {}, ...extra })),
    save: () => el('cabinSave').fire('click'),
  };
}

test('the cabin shows the Cloud arrangement; decorate mode lists only owned decor as usable', async () => {
  const page = cabinPage();
  await flush();
  assert.equal(page.el('cabinScene').hidden, false);
  assert.equal(page.el('cabinCoins').textContent, '自律幣 40');
  assert.match(page.el('cabinSummary').textContent, /窗簾：星點紗簾/);
  assert.equal(page.el('cabinTray').hidden, true, 'tray only in decorate mode');
  assert.equal(page.el('cabinGrid').hidden, true);
  page.decorate();
  assert.equal(page.el('cabinTray').hidden, false);
  assert.equal(page.el('cabinGrid').hidden, false, 'grid shows while decorating');
  assert.equal(page.el('cabinEditTools').hidden, false);
  assert.deepEqual(page.current(), { rug: 0, curtain: 1, lamp: 0 });
  assert.equal(page.tile('rug', 0).disabled, false, 'free default');
  assert.equal(page.tile('rug', 1).disabled, true, 'unowned rug cannot be placed');
  assert.match(page.tile('rug', 1).textContent, /未擁有・30 自律幣/);
  assert.equal(page.tile('lamp', 2).disabled, false, 'owned lamp');
  assert.equal(page.el('cabinSave').disabled, true, 'nothing to save yet');
  assert.equal(page.el('cabinSpots').children.length, 3, 'one allowed spot per slot');
});

test('picking, undo, redo and reset change only the draft; nothing is sent before 「儲存」', async () => {
  const page = cabinPage();
  await flush();
  page.decorate();
  page.pick('lamp', 2);
  assert.deepEqual(page.current(), { rug: 0, curtain: 1, lamp: 2 });
  assert.equal(page.el('cabinSave').disabled, false);
  page.el('cabinUndo').fire('click');
  assert.equal(page.current().lamp, 0);
  assert.equal(page.el('cabinSave').disabled, true);
  page.key('y', { ctrlKey: true });
  assert.equal(page.current().lamp, 2, 'Ctrl+Y redoes');
  page.key('z', { ctrlKey: true });
  assert.equal(page.current().lamp, 0, 'Ctrl+Z undoes');
  page.el('cabinReset').fire('click');
  assert.deepEqual(page.current(), { rug: 0, curtain: 0, lamp: 0 });
  page.el('cabinUndo').fire('click');
  assert.deepEqual(page.current(), { rug: 0, curtain: 1, lamp: 0 }, 'reset is one undoable step');
  assert.equal(page.calls.length, 0);
});

test('dragging onto the allowed spot places the piece; elsewhere it is refused with a reason', async () => {
  const page = cabinPage();
  await flush();
  page.decorate();
  page.drag('lamp', 2, page.centre('rug'));
  assert.equal(page.current().lamp, 0, 'a lamp cannot go on the rug spot');
  assert.match(page.el('cabinSaveStatus').textContent, /那裡是地毯的位置/);
  page.drag('lamp', 2, [10, 620]);
  assert.equal(page.current().lamp, 0);
  assert.match(page.el('cabinSaveStatus').textContent, /只能放在房間裡發光的位置/);
  page.drag('lamp', 2, page.centre('lamp'));
  assert.equal(page.current().lamp, 2, 'dropped on its own spot');
  assert.equal(page.el('cabinGhost').hidden, true);
  assert.equal(page.calls.length, 0);
});

test('the arrow keys on a room spot switch to the next owned style', async () => {
  const page = cabinPage();
  await flush();
  page.decorate();
  page.spot('lamp').fire('keydown', { key: 'ArrowRight' });
  assert.equal(page.current().lamp, 2, 'skips the unowned lamp 1');
  page.spot('lamp').fire('keydown', { key: 'ArrowRight' });
  assert.equal(page.current().lamp, 0, 'wraps');
  page.spot('rug').fire('click');
  assert.equal(page.current().rug, 0, 'only one rug owned');
  assert.match(page.el('cabinSaveStatus').textContent, /地毯目前只有這一款/);
});

test('saving sends one arrangeHomeDecor call, locks the page while waiting, then leaves decorate mode', async () => {
  const page = cabinPage();
  await flush();
  page.decorate();
  page.pick('lamp', 2);
  let release;
  page.replies.push(payload => new Promise(r => { release = () => r({ data: { homeDecor: payload.arrangement, replayed: false } }); }));
  page.save();
  page.save();
  await flush();
  assert.equal(page.calls.length, 1);
  assert.equal(page.calls[0].name, 'arrangeHomeDecor');
  assert.deepEqual(page.calls[0].payload.arrangement, { rug: 0, curtain: 1, lamp: 2 });
  assert.equal(page.calls[0].payload.sourceSurface, 'web');
  assert.equal(page.el('cabinLock').hidden, false, 'locked while Cloud answers');
  assert.equal(page.el('cabinMain').inert, true);
  assert.equal(page.el('cabinUndo').disabled, true);
  assert.match(page.el('cabinSaveStatus').textContent, /雲端確認中/);
  release();
  await flush();
  assert.equal(page.el('cabinLock').hidden, true);
  assert.equal(page.el('cabinMain').inert, false);
  assert.equal(page.el('cabinTray').hidden, true, 'back to the room view');
  assert.match(page.el('cabinSaveStatus').textContent, /已儲存到雲端/);
  assert.match(page.el('cabinSummary').textContent, /桌燈：水晶星燈/);
});

test('a refused save restores the Cloud arrangement and says why; undo brings the attempt back', async () => {
  const page = cabinPage();
  await flush();
  page.decorate();
  page.pick('lamp', 2);
  page.replies.push(() => Promise.reject(Object.assign(new Error('Only owned home decor variants can be arranged.'), { code: 'functions/failed-precondition' })));
  page.save();
  await flush();
  assert.equal(page.el('cabinLock').hidden, true);
  assert.match(page.el('cabinSaveStatus').textContent, /雲端沒有保存/);
  assert.match(page.el('cabinSaveStatus').textContent, /已還原成雲端的擺設/);
  assert.equal(page.current().lamp, 0, 'reverted to Cloud');
  assert.equal(page.el('cabinSave').disabled, true);
  page.el('cabinUndo').fire('click');
  assert.equal(page.current().lamp, 2, 'the attempt is one undo away');
});

test('after a lost answer the retry reuses the same request id; a new layout gets a new one', async () => {
  const page = cabinPage();
  await flush();
  page.decorate();
  page.pick('lamp', 2);
  page.replies.push(() => Promise.reject(Object.assign(new Error('offline'), { code: 'functions/unavailable' })));
  page.save();
  await flush();
  assert.match(page.el('cabinSaveStatus').textContent, /無法確認是否已保存/);
  page.el('cabinUndo').fire('click');
  page.replies.push(payload => ({ data: { homeDecor: payload.arrangement, replayed: true } }));
  page.save();
  await flush();
  assert.equal(page.calls[1].payload.clientRequestId, page.calls[0].payload.clientRequestId);
  assert.match(page.el('cabinSaveStatus').textContent, /已經儲存過/);
  page.decorate();
  page.pick('curtain', 0);
  page.replies.push(payload => ({ data: { homeDecor: payload.arrangement, replayed: false } }));
  page.save();
  await flush();
  assert.notEqual(page.calls[2].payload.clientRequestId, page.calls[0].payload.clientRequestId);
});

test('leaving with unsaved changes asks in a dialog; staying restores focus, leaving reverts', async () => {
  const page = cabinPage();
  await flush();
  page.decorate();
  page.el('cabinCancel').fire('click');
  assert.equal(page.el('cabinTray').hidden, true, 'no changes: leaves at once');
  page.decorate();
  page.pick('curtain', 0);
  page.el('cabinCancel').focus();
  page.el('cabinCancel').fire('click');
  assert.equal(page.el('cabinDialog').hidden, false);
  assert.match(html, /role="dialog" aria-modal="true"/);
  assert.equal(page.el('cabinDialogStay').id, 'cabinDialogStay');
  page.el('cabinDialogStay').fire('click');
  assert.equal(page.el('cabinDialog').hidden, true);
  assert.equal(page.current().curtain, 0, 'draft kept');
  page.key('Escape');
  assert.equal(page.el('cabinDialog').hidden, false, 'Escape asks too');
  page.el('cabinDialogLeave').fire('click');
  assert.equal(page.el('cabinTray').hidden, true);
  assert.match(page.el('cabinSummary').textContent, /窗簾：星點紗簾/, 'back to Cloud');
  assert.equal(page.calls.length, 0);
});

test('another device: the room follows Cloud; an unsaved draft is kept and the player is told', async () => {
  const page = cabinPage();
  await flush();
  page.push({ unlockedAvatarItems: OWNED, homeDecor: { rug: 0, curtain: 0, lamp: 2 } });
  assert.match(page.el('cabinSummary').textContent, /桌燈：水晶星燈/, 'clean view follows Cloud');
  page.decorate();
  page.pick('curtain', 1);
  page.push({ unlockedAvatarItems: OWNED, homeDecor: { rug: 0, curtain: 0, lamp: 0 } });
  assert.equal(page.current().curtain, 1, 'draft kept');
  assert.match(page.el('cabinSaveStatus').textContent, /另一台裝置更新了擺設/);
});

test('a refund removes decor from view and from an open draft', async () => {
  const page = cabinPage({ user: { unlockedAvatarItems: [], homeDecor: { rug: 0, curtain: 1, lamp: 0 } } });
  await flush();
  assert.match(page.el('cabinSummary').textContent, /窗簾：紫絨窗簾/);
  page.push({ unlockedAvatarItems: OWNED, homeDecor: { rug: 0, curtain: 1, lamp: 0 } });
  page.decorate();
  page.pick('lamp', 2);
  page.push({ unlockedAvatarItems: ['homeDecor:101'], homeDecor: { rug: 0, curtain: 1, lamp: 0 } });
  assert.equal(page.current().lamp, 0);
  assert.equal(page.tile('lamp', 2).disabled, true);
});

test('the companion answers a tap, reads at the desk during a desk focus, and sits out decorating', async () => {
  const focus = JSON.stringify({ sessionId: 'web_focus_1_abc', status: 'active' });
  const page = cabinPage({ storage: { nudge_town_desk_session_v1_u1: focus } });
  await flush();
  const pal = page.el('cabinCompanion');
  pal.fire('click');
  assert.equal(page.el('cabinBubble').hidden, false);
  assert.match(page.el('cabinBubble').textContent, /書桌|專注/);
  assert.equal(pal.dataset.pose, 'cheer');
  assert.equal(pal.classList.contains('is-jump'), true);
  page.decorate();
  assert.equal(pal.tabIndex, -1, 'not focusable while decorating');
});
