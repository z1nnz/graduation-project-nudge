// Behavior of web_dashboard/assets/cabin.js on a fake DOM: placing owned
// decor, saving through arrangeHomeDecor, retry after a lost answer, and
// another device changing the arrangement (#82 slice 3).
const test = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');

const html = fs.readFileSync('web_dashboard/cabin.html', 'utf8');
const sources = ['cabin_core.js', 'cabin.js'].map(f => fs.readFileSync(`web_dashboard/assets/${f}`, 'utf8'));
const json = {
  'assets/home/home_decor_catalog.json': JSON.parse(fs.readFileSync('web_dashboard/assets/home/home_decor_catalog.json', 'utf8')),
  'assets/home/cabin_layout.json': JSON.parse(fs.readFileSync('web_dashboard/assets/home/cabin_layout.json', 'utf8')),
};

class El {
  constructor(tag, id = '') {
    Object.assign(this, { tagName: tag.toUpperCase(), id, dataset: {}, style: {}, children: [], listeners: {}, attrs: {}, hidden: false, _text: '', disabled: false, checked: false });
  }
  get textContent() { return this._text + this.children.map(c => c.textContent).join(''); }
  set textContent(v) { this._text = String(v); this.children = []; }
  setAttribute(k, v) { this.attrs[k] = String(v); }
  getAttribute(k) { return this.attrs[k] ?? null; }
  addEventListener(n, cb) { (this.listeners[n] ||= []).push(cb); }
  fire(n, e = {}) { (this.listeners[n] || []).forEach(cb => cb({ preventDefault() {}, target: this, ...e })); }
  appendChild(c) { this.children.push(c); return c; }
  append(...c) { c.forEach(x => this.appendChild(x)); }
  all() { return this.children.flatMap(c => [c, ...c.all()]); }
  set src(v) { this.attrs.src = v; }
  get src() { return this.attrs.src || ''; }
}

const flush = () => new Promise(r => setImmediate(r));

function cabinPage({ user = { unlockedAvatarItems: ['homeDecor:101', 'homeDecor:202'], disciplineCoins: 40, homeDecor: { rug: 0, curtain: 1, lamp: 0 } } } = {}) {
  const nodes = new Map();
  for (const [, tag, id] of html.matchAll(/<(\w+)[^>]*\sid="([^"]+)"/g)) nodes.set(id, new El(tag, id));
  for (const [, id] of html.matchAll(/\sid="([^"]+)"[^>]*\shidden[\s>]/g)) nodes.get(id).hidden = true;
  const docListeners = {};
  const doc = {
    body: { dataset: { page: 'cabin' } },
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
    addEventListener: () => {},
    Date,
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
  return {
    el, calls, replies,
    push: data => snapshot({ exists: true, data: () => structuredClone(data) }),
    choice: (slot, index) => el('cabinSlots').all().find(n => n.tagName === 'INPUT' && n.name === `decor-${slot}` && n.value === String(index)),
    pick(slot, index) { const input = this.choice(slot, index); input.checked = true; input.fire('change'); },
    save: () => el('cabinForm').fire('submit'),
  };
}

test('the cabin shows the Cloud arrangement and only owned decor is selectable', async () => {
  const page = cabinPage();
  await flush();
  assert.equal(page.el('cabinScene').hidden, false);
  assert.equal(page.el('cabinCoins').textContent, '自律幣 40');
  assert.equal(page.choice('curtain', 1).checked, true, 'saved curtain from users.homeDecor');
  assert.equal(page.choice('rug', 0).disabled, false, 'free default');
  assert.equal(page.choice('rug', 1).disabled, true, 'unowned rug cannot be placed');
  assert.equal(page.choice('lamp', 2).disabled, false, 'owned lamp');
  assert.match(page.el('cabinSummary').textContent, /窗簾：星點紗簾/);
  assert.equal(page.el('cabinSave').disabled, true, 'nothing to save yet');
});

test('saving sends one arrangeHomeDecor call; a second press is ignored', async () => {
  const page = cabinPage();
  await flush();
  page.pick('lamp', 2);
  assert.equal(page.el('cabinSave').disabled, false);
  let release;
  page.replies.push(payload => new Promise(r => { release = () => r({ data: { homeDecor: payload.arrangement, replayed: false } }); }));
  page.save();
  page.save();
  await flush();
  assert.equal(page.calls.length, 1);
  assert.deepEqual(page.calls[0].payload.arrangement, { rug: 0, curtain: 1, lamp: 2 });
  assert.equal(page.calls[0].payload.sourceSurface, 'web');
  release();
  await flush();
  assert.match(page.el('cabinSaveStatus').textContent, /已保存到雲端/);
  assert.equal(page.el('cabinSave').disabled, true);
});

test('after a lost answer the retry reuses the same request id; a new layout gets a new one', async () => {
  const page = cabinPage();
  await flush();
  page.pick('lamp', 2);
  page.replies.push(() => Promise.reject(Object.assign(new Error('offline'), { code: 'functions/unavailable' })));
  page.save();
  await flush();
  assert.match(page.el('cabinSaveStatus').textContent, /無法確認是否已保存/);
  page.replies.push(payload => ({ data: { homeDecor: payload.arrangement, replayed: true } }));
  page.save();
  await flush();
  assert.equal(page.calls[1].payload.clientRequestId, page.calls[0].payload.clientRequestId);
  assert.match(page.el('cabinSaveStatus').textContent, /已經保存過/);
  page.pick('rug', 0);
  page.pick('curtain', 0);
  page.replies.push(payload => ({ data: { homeDecor: payload.arrangement, replayed: false } }));
  page.save();
  await flush();
  assert.notEqual(page.calls[2].payload.clientRequestId, page.calls[0].payload.clientRequestId);
});

test('a refused save keeps the draft and says nothing was saved; revert restores Cloud', async () => {
  const page = cabinPage();
  await flush();
  page.pick('lamp', 2);
  page.replies.push(() => Promise.reject(Object.assign(new Error('Only owned home decor variants can be arranged.'), { code: 'functions/failed-precondition' })));
  page.save();
  await flush();
  assert.match(page.el('cabinSaveStatus').textContent, /雲端沒有保存/);
  assert.equal(page.choice('lamp', 2).checked, true);
  page.el('cabinRevert').fire('click');
  assert.equal(page.choice('lamp', 0).checked, true);
  assert.equal(page.el('cabinSave').disabled, true);
});

test('another device changing the arrangement does not overwrite an unsaved draft', async () => {
  const page = cabinPage();
  await flush();
  page.push({ unlockedAvatarItems: ['homeDecor:101', 'homeDecor:202'], homeDecor: { rug: 0, curtain: 0, lamp: 2 } });
  assert.equal(page.choice('lamp', 2).checked, true, 'clean view follows Cloud');
  page.pick('curtain', 1);
  page.push({ unlockedAvatarItems: ['homeDecor:101', 'homeDecor:202'], homeDecor: { rug: 0, curtain: 0, lamp: 0 } });
  assert.equal(page.choice('curtain', 1).checked, true, 'draft kept');
  assert.match(page.el('cabinSaveStatus').textContent, /另一台裝置更新了擺設/);
  page.el('cabinRevert').fire('click');
  assert.equal(page.choice('lamp', 0).checked, true);
  assert.equal(page.choice('curtain', 0).checked, true);
});

test('a refund removes decor from view even if it was saved', async () => {
  const page = cabinPage({ user: { unlockedAvatarItems: [], homeDecor: { rug: 0, curtain: 1, lamp: 0 } } });
  await flush();
  assert.equal(page.choice('curtain', 0).checked, true);
  assert.equal(page.choice('curtain', 1).disabled, true);
});
