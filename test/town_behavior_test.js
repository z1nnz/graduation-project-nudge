// Behavior tests for the Web companion town (web_dashboard/town.html).
// They load the real town scripts into a small fake DOM built from the ids in
// town.html, then drive pointer, keyboard and animation frames.
const test = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');

const html = fs.readFileSync('web_dashboard/town.html', 'utf8');
const sources = ['town_core.js', 'town_game_core.js', 'town.js']
  .map(name => fs.readFileSync(`web_dashboard/assets/${name}`, 'utf8'));

const MAP_W = 1672;
const MAP_H = 941;
// Canvas sized so the map draws at scale 1: screen = map - camera + half view.
const VIEW = { w: 1036, h: MAP_H * 0.62 };
const START = { x: Math.round(0.475 * MAP_W), y: Math.round(0.66 * MAP_H) };

class FakeClassList {
  constructor() { this.set = new Set(); }
  add(...names) { names.forEach(n => this.set.add(n)); }
  remove(...names) { names.forEach(n => this.set.delete(n)); }
  contains(name) { return this.set.has(name); }
  toggle(name, force) {
    const on = force === undefined ? !this.set.has(name) : Boolean(force);
    if (on) this.set.add(name); else this.set.delete(name);
    return on;
  }
}

class FakeElement {
  constructor(tagName, id = '') {
    this.tagName = tagName.toUpperCase();
    this.id = id;
    this.dataset = {};
    this.style = {};
    this.classList = new FakeClassList();
    this.attributes = {};
    this.children = [];
    this.listeners = {};
    this.hidden = false;
    this._text = '';
    this.href = '';
  }
  get textContent() { return this._text + this.children.map(c => c.textContent).join(''); }
  set textContent(value) { this._text = String(value); this.children = []; }
  set innerHTML(_) { this.children = []; }
  setAttribute(name, value) { this.attributes[name] = String(value); }
  getAttribute(name) { return this.attributes[name] ?? null; }
  addEventListener(name, callback) { (this.listeners[name] ||= []).push(callback); }
  dispatch(name, event = {}) {
    const e = { preventDefault() { this.defaultPrevented = true; }, target: this, ...event };
    (this.listeners[name] || []).forEach(cb => cb(e));
    return e;
  }
  click() { return this.dispatch('click'); }
  appendChild(child) { this.children.push(child); child.parent = this; return child; }
  append(...nodes) { nodes.forEach(n => this.appendChild(n)); }
  descendants() { return this.children.flatMap(c => [c, ...c.descendants()]); }
  querySelector(selector) { return this.descendants().find(n => n.tagName === selector.toUpperCase()) || null; }
  querySelectorAll(selector) { return this.descendants().filter(n => n.tagName === selector.toUpperCase()); }
  closest() { return null; }
  focus() { this.ownerDocument.activeElement = this; }
  getBoundingClientRect() { return { left: 0, top: 0, right: 200, bottom: 60, width: 200, height: 60 }; }
}

function town({ reducedMotion = false, canvas = true, tourDone = true, failMap = false } = {}) {
  const storage = new Map(tourDone ? [['nudge_town_tour_done', '1']] : []);
  const frames = [];
  const images = [];
  const docListeners = {};
  const nodes = new Map();
  const doc = {
    activeElement: null,
    body: null,
    hidden: false,
    getElementById: id => nodes.get(id) || null,
    createElement: tag => Object.assign(new FakeElement(tag), { ownerDocument: doc }),
    querySelector: selector => (selector === '.town-hud-tools' ? nodes.get('__tools') : null),
    addEventListener: (name, cb) => { (docListeners[name] ||= []).push(cb); },
  };
  for (const [, tag, id] of html.matchAll(/<(\w+)[^>]*\sid="([^"]+)"/g)) {
    nodes.set(id, Object.assign(new FakeElement(tag, id), { ownerDocument: doc }));
  }
  nodes.set('__tools', Object.assign(new FakeElement('nav'), { ownerDocument: doc }));
  nodes.get('townDirectory').appendChild(nodes.get('townDirectoryList'));
  doc.body = Object.assign(new FakeElement('body'), { ownerDocument: doc });
  doc.body.dataset.page = 'town';
  // Hidden state from the markup (dialog, prompt, game, toast, note start hidden).
  for (const [, id] of html.matchAll(/\sid="([^"]+)"[^>]*\shidden[\s>]/g)) nodes.get(id).hidden = true;

  const fakeCtx = new Proxy({}, { get: (t, k) => (k in t ? t[k] : () => ({ data: [], width: 0, height: 0 })), set: (t, k, v) => { t[k] = v; return true; } });
  for (const id of ['townCanvas', 'townGameCanvas']) {
    const el = nodes.get(id);
    el.clientWidth = VIEW.w;
    el.clientHeight = VIEW.h;
    el.getContext = () => (canvas ? fakeCtx : null);
  }

  class FakeImage {
    constructor() { this.listeners = {}; this.complete = false; this.naturalWidth = 0; images.push(this); }
    addEventListener(name, cb) { (this.listeners[name] ||= []).push(cb); }
    set src(value) { this._src = value; }
    get src() { return this._src || ''; }
    fire(name) { (this.listeners[name] || []).forEach(cb => cb()); }
  }

  let clock = 0;
  const location = { href: 'town.html' };
  const context = {
    document: doc,
    location,
    Image: FakeImage,
    devicePixelRatio: 1,
    performance: { now: () => clock },
    matchMedia: query => ({ matches: reducedMotion && query.includes('reduced-motion') }),
    localStorage: { getItem: k => storage.get(k) ?? null, setItem: (k, v) => storage.set(k, String(v)) },
    requestAnimationFrame: cb => { frames.push(cb); return frames.length; },
    setInterval: () => 0,
    addEventListener: () => {},
    // Signed-out Firebase: auth resolves to no user, so no account reads happen.
    firebase: { apps: [{}], auth: () => ({ onAuthStateChanged: cb => cb(null) }) },
  };
  vm.createContext(context);
  for (const source of sources) vm.runInContext(source, context);
  if (failMap) images.find(i => i.src.includes('town_map')).fire('error');

  const key = (type, k, target = doc.body) => {
    const e = { key: k, target, preventDefault() {} };
    (docListeners[type] || []).forEach(cb => cb(e));
  };
  return {
    nodes, doc, location, storage, frames,
    el: id => nodes.get(id),
    links: () => nodes.get('townDirectoryList').querySelectorAll('a'),
    link: name => nodes.get('townDirectoryList').querySelectorAll('a').find(a => a.querySelector('strong').textContent === name),
    keydown: (k, target) => key('keydown', k, target),
    firebaseReady: () => (docListeners['firebase-ready'] || []).forEach(cb => cb()),
    keyup: k => key('keyup', k),
    /** Run animation frames 50 ms apart (the loop caps dt at 0.05 s). */
    run(count) {
      for (let i = 0; i < count; i++) {
        const cb = frames.shift();
        if (!cb) return;
        clock += 50;
        cb(clock);
      }
    },
    /** Map point to canvas client coordinates while the camera sits at START. */
    tap(p) {
      const cam = { x: START.x, y: Math.min(Math.max(START.y, VIEW.h / 2), MAP_H - VIEW.h / 2) };
      nodes.get('townCanvas').dispatch('pointerdown', { clientX: p.x - cam.x + VIEW.w / 2, clientY: p.y - cam.y + VIEW.h / 2 });
    },
  };
}

const ROUTES = {
  你的小屋: 'personal.html',
  委託告示板: 'dashboard.html',
  專注塔: 'rooms.html',
  家庭庭院: 'guardian.html',
  團體會館: 'groups.html',
  紀錄館: 'personal-trends.html',
  雜貨店: 'profile.html',
  天文台: 'personal-focus.html',
};
const BOARD_CENTRE = { x: (0.29 + 0.0375) * MAP_W, y: (0.405 + 0.06) * MAP_H };

test('every building in the list opens its existing Web page by relative path', () => {
  for (const [name, href] of Object.entries(ROUTES)) {
    const t = town();
    const link = t.link(name);
    assert.ok(link, `${name} is listed`);
    assert.equal(link.href, href);
    const event = link.click();
    assert.equal(event.defaultPrevented, true);
    assert.equal(t.location.href, href, `${name} navigates`);
    assert.match(t.el('townToast').textContent, new RegExp(`正在進入${name}`));
  }
  const t = town();
  assert.equal(t.links().length, 10, 'eight pages plus the park and locked garden');
});

test('guests explore freely without fake level, XP or sync status', () => {
  const t = town();
  assert.match(html, /<strong id="townName">訪客<\/strong>/);
  assert.match(html, /<span id="townLevel">自由探索中<\/span>/);
  t.firebaseReady();
  assert.equal(t.el('townName').textContent, '訪客');
  assert.equal(t.el('townLevel').textContent, '自由探索中');
  assert.doesNotMatch(html, /登入後同步/);
  assert.doesNotMatch(t.el('townLevel').textContent, /Lv|XP|金幣|在線|同步/);
  // Pages with their own sign-in guard are labelled honestly; the public board is not.
  assert.equal(t.link('專注塔').querySelector('em').textContent, '進入時需要登入');
  assert.equal(t.link('委託告示板').querySelector('em').hidden, true);
  // Guests still navigate: the destination page's existing guard decides.
  t.link('你的小屋').click();
  assert.equal(t.location.href, 'personal.html');
});

test('locked garden and the park never navigate and say why', () => {
  const t = town();
  t.link('星光花園').click();
  assert.equal(t.location.href, 'town.html');
  assert.match(t.el('townToast').textContent, /Lv 10/);
  t.link('遊樂園').click();
  assert.equal(t.location.href, 'town.html');
  assert.match(t.el('townToast').textContent, /登入後完成一次專注/);
  assert.equal(t.el('townGame').hidden, true);
});

test('tapping a building walks the companion to its door, then enters', () => {
  const t = town();
  t.tap(BOARD_CENTRE);
  assert.match(t.el('townToast').textContent, /走向委託告示板/);
  assert.equal(t.location.href, 'town.html', 'walks first, no instant jump');
  t.run(80);
  assert.equal(t.location.href, 'dashboard.html');
});

test('keyboard: arrows walk, the door prompt appears, F and Enter enter', () => {
  for (const enterKey of ['f', 'Enter']) {
    const t = town();
    t.keydown('ArrowLeft');
    t.run(33);
    t.keyup('ArrowLeft');
    t.keydown('ArrowUp');
    t.run(13);
    t.keyup('ArrowUp');
    t.run(1);
    assert.equal(t.el('townPrompt').hidden, false);
    assert.equal(t.el('townPromptText').textContent, '按 F 進入委託告示板');
    t.keydown(enterKey);
    assert.equal(t.location.href, 'dashboard.html', `${enterKey} enters`);
  }
});

test('the building list opens from a touch button and closes with Escape', () => {
  const t = town();
  const toggle = t.el('townListToggle');
  assert.match(html, /id="townListToggle"[^>]*aria-expanded="false"/);
  toggle.click();
  assert.equal(t.el('townDirectory').classList.contains('is-open'), true);
  assert.equal(toggle.getAttribute('aria-expanded'), 'true');
  assert.equal(t.doc.activeElement, t.links()[0], 'focus moves into the list');
  t.keydown('Escape');
  assert.equal(t.el('townDirectory').classList.contains('is-open'), false);
  assert.equal(t.doc.activeElement, toggle, 'focus returns to the button');
  assert.match(html, /<a class="town-skip" href="#townDirectory">/);
  assert.match(html, /href="index.html"[^>]*>⌂<\/a>|<a href="index.html" title="回到入口"/);
});

test('reduced motion enters a tapped building at once with no walking', () => {
  const t = town({ reducedMotion: true });
  t.tap(BOARD_CENTRE);
  assert.equal(t.location.href, 'dashboard.html');
});

test('without Canvas the town becomes a static, usable building list', () => {
  const t = town({ canvas: false, tourDone: false });
  assert.equal(t.doc.body.classList.contains('town-static'), true);
  assert.equal(t.el('townDirectory').classList.contains('is-open'), true);
  assert.equal(t.el('townDirectoryNote').hidden, false);
  assert.match(t.el('townDirectoryNote').textContent, /無法顯示小鎮地圖/);
  assert.equal(t.el('townDialog').hidden, true, 'no walking tour in static mode');
  assert.equal(t.frames.length, 0, 'no animation loop');
  t.link('專注塔').click();
  assert.equal(t.location.href, 'rooms.html');
});

test('a failed map image switches to the static list', () => {
  const t = town({ failMap: true });
  assert.equal(t.doc.body.classList.contains('town-static'), true);
  assert.match(t.el('townDirectoryNote').textContent, /小鎮地圖載入失敗/);
  t.run(2);
  t.link('雜貨店').click();
  assert.equal(t.location.href, 'profile.html');
});

test('first visit shows the skippable tour and Escape ends it for good', () => {
  const t = town({ tourDone: false });
  assert.equal(t.el('townDialog').hidden, false);
  t.keydown('Escape');
  assert.equal(t.el('townDialog').hidden, true);
  assert.equal(t.storage.get('nudge_town_tour_done'), '1');
});

test('the public landing page offers 探索小鎮 and keeps 進入 Nudge', () => {
  const index = fs.readFileSync('web_dashboard/index.html', 'utf8');
  assert.match(index, /<a href="town.html"[^>]*>探索小鎮<\/a>/);
  assert.match(index, /<a href="dashboard.html"[^>]*>進入 Nudge<\/a>/);
  const townHrefs = [...index.matchAll(/href="([^"]*town[^"]*)"/g)].map(m => m[1]);
  assert.ok(townHrefs.length >= 2);
  assert.deepEqual([...new Set(townHrefs)], ['town.html'], 'relative GitHub Pages paths');
});
