// Behavior tests for the Web companion town (web_dashboard/town.html).
// They load the real town scripts into a small fake DOM built from the ids in
// town.html, then drive pointer, keyboard, auth and animation frames.
const test = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const routes = require('../web_dashboard/assets/town_routes.js');

const html = fs.readFileSync('web_dashboard/town.html', 'utf8');
const sources = ['town_core.js', 'town_avatar_core.js', 'town_game_core.js', 'town_routes.js', 'town.js']
  .map(name => fs.readFileSync(`web_dashboard/assets/${name}`, 'utf8'));

const MAP_W = 1672;
const MAP_H = 941;
// Canvas sized so the map draws at scale 1: screen = map - camera + half view.
const VIEW = { w: 1036, h: MAP_H * 0.62 };
const START = { x: Math.round(0.475 * MAP_W), y: Math.round(0.66 * MAP_H) };
const BOARD_CENTRE = { x: (0.29 + 0.0375) * MAP_W, y: (0.405 + 0.06) * MAP_H };

class FakeClassList {
  constructor(owner) { this.owner = owner; this.set = new Set(); }
  add(...names) { names.forEach(n => this.set.add(n)); }
  remove(...names) { names.forEach(n => this.set.delete(n)); }
  contains(name) { return this.set.has(name) || String(this.owner.className || '').split(/\s+/).includes(name); }
  toggle(name, force) {
    const on = force === undefined ? !this.set.has(name) : Boolean(force);
    if (on) this.set.add(name); else this.set.delete(name);
    return on;
  }
}

/** Matches the last compound of each comma part: `tag`, `.class` or `#id`. */
function matches(node, selector) {
  return selector.split(',').some(part => {
    const last = part.trim().split(/\s+/).pop();
    if (last.startsWith('.')) return node.classList.contains(last.slice(1));
    if (last.startsWith('#')) return node.id === last.slice(1);
    return node.tagName === last.toUpperCase();
  });
}

class FakeElement {
  constructor(tagName, id = '') {
    this.tagName = tagName.toUpperCase();
    this.id = id;
    this.dataset = {};
    this.style = {};
    this.classList = new FakeClassList(this);
    this.className = '';
    this.attributes = {};
    this.children = [];
    this.listeners = {};
    this.hidden = false;
    this._text = '';
    this.href = '';
  }
  get textContent() { return this._text + this.children.map(c => c.textContent).join(''); }
  set textContent(value) { this._text = String(value); this.children = []; }
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
  querySelector(selector) { return this.descendants().find(n => matches(n, selector)) || null; }
  querySelectorAll(selector) { return this.descendants().filter(n => matches(n, selector)); }
  closest() { return null; }
  focus() { this.ownerDocument.activeElement = this; }
  getBoundingClientRect() { return { left: 0, top: 0, right: 200, bottom: 60, width: 200, height: 60 }; }
}

/**
 * user: null for a guest, or { uid, data } for a signed-in account whose
 * users/{uid} document is `data`. Firebase is only read, never written.
 */
function town({ reducedMotion = false, canvas = true, tourDone = true, failMap = false,
  search = '', user = null, cachedUser = false } = {}) {
  const storage = new Map(tourDone ? [['nudge_town_tour_done', '1']] : []);
  const frames = [];
  const images = [];
  const docListeners = {};
  const nodes = new Map();
  const doc = {
    activeElement: null,
    body: null,
    hidden: false,
    contains: () => true,
    getElementById: id => nodes.get(id) || null,
    createElement: tag => Object.assign(new FakeElement(tag), { ownerDocument: doc }),
    querySelector: selector => (selector === '.town-hud-tools' ? nodes.get('__tools') : null),
    addEventListener: (name, cb) => { (docListeners[name] ||= []).push(cb); },
  };
  for (const [, tag, id] of html.matchAll(/<(\w+)[^>]*\sid="([^"]+)"/g)) {
    nodes.set(id, Object.assign(new FakeElement(tag, id), { ownerDocument: doc }));
  }
  nodes.set('__tools', Object.assign(new FakeElement('nav'), { ownerDocument: doc }));
  for (const child of ['townDirectoryNote', 'townDirectoryList', 'townToolList']) {
    nodes.get('townDirectory').appendChild(nodes.get(child));
  }
  nodes.get('townPanel').appendChild(nodes.get('townPanelList'));
  doc.body = Object.assign(new FakeElement('body'), { ownerDocument: doc });
  doc.body.dataset.page = 'town';
  // Hidden state from the markup (dialog, prompt, game, toast, panel, note start hidden).
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

  const callback = (options, listener) => typeof options === 'function' ? options : listener;
  const snapshot = cb => cb({ exists: true, data: () => user.data, docs: [],
    metadata: { fromCache: cachedUser, hasPendingWrites: false } });
  const query = { where: () => query, orderBy: () => query, limit: () => query,
    onSnapshot: (options, listener) => {
      callback(options, listener)({ docs: [], size: 0, metadata: { fromCache: false, hasPendingWrites: false } });
      return () => {};
    } };
  const firestore = () => ({
    collection: name => (name === 'users'
      ? { doc: () => ({ onSnapshot: (options, listener) => {
        snapshot(callback(options, listener)); return () => {};
      } }) }
      : query),
  });

  let clock = 0;
  const location = { href: 'town.html', search };
  const context = {
    document: doc,
    location,
    URLSearchParams,
    Image: FakeImage,
    devicePixelRatio: 1,
    performance: { now: () => clock },
    matchMedia: q => ({ matches: reducedMotion && q.includes('reduced-motion') }),
    localStorage: { getItem: k => storage.get(k) ?? null, setItem: (k, v) => storage.set(k, String(v)) },
    requestAnimationFrame: cb => { frames.push(cb); return frames.length; },
    setInterval: () => 0,
    addEventListener: () => {},
    firebase: {
      apps: [{}],
      auth: () => ({ onAuthStateChanged: cb => cb(user ? { uid: user.uid } : null) }),
      firestore,
    },
  };
  vm.createContext(context);
  // Stand-ins for the in-town scenes town_scenes.js registers (board, desk, cabin).
  const sceneCalls = [];
  for (const [i, source] of sources.entries()) {
    if (i === sources.length - 1) {
      for (const id of new Set(routes.DESTINATIONS.filter(x => x.scene).map(x => x.scene))) {
        context.NudgeTownRoutes.registerScene(id, opts => sceneCalls.push({ id, opts }));
      }
    }
    vm.runInContext(source, context);
  }
  if (failMap) images.find(i => i.src.includes('town_map')).fire('error');
  (docListeners['firebase-ready'] || []).forEach(cb => cb());

  const key = (type, k, target = doc.body) => {
    const e = { key: k, target, preventDefault() {} };
    (docListeners[type] || []).forEach(cb => cb(e));
  };
  const t = {
    nodes, doc, location, storage, frames, sceneCalls,
    el: id => nodes.get(id),
    keydown: (k, target) => key('keydown', k, target),
    keyup: k => key('keyup', k),
    /** Directory button for a building, by its route-table name. */
    building: name => nodes.get('townDirectoryList').querySelectorAll('button').find(b => b.textContent.startsWith(`${name}：`)),
    /** Entries in the open building panel. */
    entries: () => nodes.get('townPanelList').children.map(li => li.children[0]).map(c => ({
      control: c, tag: c.tagName.toLowerCase(), href: c.href, kind: c.className.replace(/.*is-/, ''),
      title: c.children[0].textContent, note: c.children[1].textContent,
    })),
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
  return t;
}

const member = level => ({ uid: 'u1', data: { nickname: '小安', avatarLevel: level } });

test('every building panel lists exactly its route-table destinations', () => {
  for (const [id, b] of Object.entries(routes.BUILDINGS)) {
    const t = town({ user: member(10) });
    t.building(b.name).click();
    assert.equal(t.el('townPanel').hidden, false, `${b.name} opens its panel`);
    assert.equal(t.el('townPanelTitle').textContent, b.name);
    const expected = routes.destinationsFor(id, { includePlanned: true });
    const shown = t.entries();
    assert.deepEqual(shown.map(e => e.title), expected.map(d => d.title), b.name);
    for (const [i, dest] of expected.entries()) {
      if (dest.status !== 'available') assert.equal(shown[i].tag, 'span', `${dest.id} under construction is not linked`);
      else if (dest.id === 'break-game') assert.equal(shown[i].tag, 'button');
      else if (dest.scene) {
        assert.equal(shown[i].tag, 'button', `${dest.id} opens in town`);
        shown[i].control.click();
        assert.equal(t.sceneCalls.at(-1).id, dest.scene);
        assert.equal(t.el('townPanel').hidden, true, 'the panel closes for the scene');
        t.building(b.name).click();
      }
      else assert.equal(shown[i].href, dest.href, `${dest.id} links to its page`);
    }
  }
});

test('the #79 name/destination fixes are what players actually reach', () => {
  const t = town({ user: member(3) });
  t.building('雜貨店').click();
  assert.deepEqual(t.entries().map(e => e.href), ['operations.html']);
  t.building('天文台').click();
  assert.ok(t.entries().some(e => e.href === 'planet.html'));
  t.building('你的小屋').click();
  assert.ok(!t.entries().some(e => e.href === 'personal.html'));
  assert.ok(t.entries().some(e => e.href === 'personal-focus.html'));
});

test('guests explore with no fake level and every login page says so', () => {
  const t = town();
  assert.match(html, /<span id="townLevel">自由探索中<\/span>/);
  assert.doesNotMatch(html, /登入後同步/);
  assert.equal(t.el('townName').textContent, '訪客');
  assert.equal(t.el('townLevel').textContent, '自由探索中');
  t.building('雜貨店').click();
  const [shop] = t.entries();
  assert.equal(shop.kind, 'login');
  assert.equal(shop.href, 'login.html', 'the page guard is not bypassed');
  assert.equal(shop.title, '角色商城（先登入）');
  shop.control.click();
  assert.equal(t.storage.get('nudgePostLoginRedirect'), 'operations.html');
  t.building('委託告示板').click();
  const board = t.entries();
  assert.ok(board.some(e => e.href === 'dashboard.html' && e.kind === 'open'), 'the public board page opens for guests');
  const scene = board.find(e => e.title.startsWith('看告示板'));
  assert.equal(scene.kind, 'login', 'in-town scenes need sign-in');
  assert.equal(t.sceneCalls.length, 0);
});

test('signed-in identity shows the Cloud level and the garden follows it', () => {
  const low = town({ user: member(3) });
  assert.equal(low.el('townName').textContent, '小安');
  assert.equal(low.el('townLevel').textContent, 'Lv 3');
  low.building('星光花園').click();
  assert.match(low.el('townPanelDesc').textContent, /Lv 10.*目前 Lv 3/);
  const [locked] = low.entries();
  assert.equal(locked.tag, 'span');
  assert.equal(locked.control.getAttribute('aria-disabled'), 'true');
  const high = town({ user: member(10) });
  high.building('星光花園').click();
  assert.equal(high.entries()[0].href, 'garden.html');
});

test('cached account values do not unlock a garden before Cloud confirmation', () => {
  const cached = town({ user: member(10), cachedUser: true });
  assert.equal(cached.el('townLevel').textContent, '雲端同步中');
  cached.building('星光花園').click();
  assert.equal(cached.entries()[0].tag, 'span');
});

test('tapping a building walks the companion to its door, then opens the panel', () => {
  const t = town();
  t.tap(BOARD_CENTRE);
  assert.match(t.el('townToast').textContent, /走向委託告示板/);
  assert.equal(t.el('townPanel').hidden, true, 'walks first, no instant jump');
  t.run(80);
  assert.equal(t.el('townPanel').hidden, false);
  assert.equal(t.el('townPanelTitle').textContent, '委託告示板');
});

test('walking to the tower crosses the plaza instead of stalling at the fountain', () => {
  const t = town();
  t.tap({ x: (0.42 + 0.0275) * MAP_W, y: 0.2 * MAP_H });
  t.run(60); // 40 steps reach the door; stalling at the fountain took 146
  assert.equal(t.el('townPanel').hidden, false);
  assert.equal(t.el('townPanelTitle').textContent, '專注塔');
});

test('keyboard: arrows walk, the door prompt appears, F and Enter open, Esc closes', () => {
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
    assert.equal(t.el('townPanel').hidden, false, `${enterKey} opens the panel`);
    assert.equal(t.doc.activeElement, t.entries()[0].control, 'focus moves into the panel');
    t.keydown('Escape');
    assert.equal(t.el('townPanel').hidden, true);
  }
});

test('the ☰ list opens from a touch button and Esc returns focus to it', () => {
  const t = town();
  const toggle = t.el('townDirectoryToggle');
  assert.match(html, /id="townDirectoryToggle"[^>]*aria-expanded="false"/);
  toggle.click();
  assert.equal(t.el('townDirectory').classList.contains('is-open'), true);
  assert.equal(toggle.getAttribute('aria-expanded'), 'true');
  assert.equal(t.doc.activeElement, t.el('townDirectoryList').querySelector('button'));
  t.keydown('Escape');
  assert.equal(t.el('townDirectory').classList.contains('is-open'), false);
  assert.equal(t.doc.activeElement, toggle);
  assert.match(html, /<a class="town-skip" href="#townDirectory">/);
});

test('reduced motion opens a tapped building at once with no walking', () => {
  const t = town({ reducedMotion: true });
  t.tap(BOARD_CENTRE);
  assert.equal(t.el('townPanel').hidden, false);
  assert.equal(t.el('townPanelTitle').textContent, '委託告示板');
});

test('without Canvas the town becomes a static, usable building list', () => {
  const t = town({ canvas: false, tourDone: false });
  assert.equal(t.doc.body.classList.contains('town-static'), true);
  assert.equal(t.el('townDirectory').classList.contains('is-open'), true);
  assert.equal(t.el('townDirectoryNote').hidden, false);
  assert.match(t.el('townDirectoryNote').textContent, /無法顯示小鎮地圖/);
  assert.equal(t.el('townDialog').hidden, true, 'no walking tour in static mode');
  assert.equal(t.frames.length, 0, 'no animation loop');
  const tower = t.building('專注塔');
  tower.click();
  assert.equal(t.el('townPanel').hidden, false);
  assert.equal(t.el('townDirectory').classList.contains('is-open'), true, 'the list stays');
  t.keydown('Escape');
  assert.equal(t.el('townPanel').hidden, true);
  assert.equal(t.doc.activeElement, tower, 'focus returns to the building');
  t.keydown('Escape');
  assert.equal(t.el('townDirectory').classList.contains('is-open'), true, 'static list cannot be closed');
});

test('a failed map image switches to the static list', () => {
  const t = town({ failMap: true });
  assert.equal(t.doc.body.classList.contains('town-static'), true);
  assert.match(t.el('townDirectoryNote').textContent, /小鎮地圖載入失敗/);
  t.run(2);
  t.building('雜貨店').click();
  assert.equal(t.el('townPanelTitle').textContent, '雜貨店');
});

test('?at= returns the player to that door without the tour; other values are ignored', () => {
  const back = town({ tourDone: false, search: '?at=store' });
  assert.equal(back.el('townDialog').hidden, true);
  assert.match(back.el('townToast').textContent, /回到雜貨店門口/);
  back.run(1);
  assert.equal(back.el('townPromptText').textContent, '按 F 進入雜貨店');
  const odd = town({ tourDone: false, search: '?at=https://example.invalid' });
  assert.equal(odd.el('townDialog').hidden, false, 'unknown ids fall back to the normal start');
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
  assert.match(index, /<a\b[^>]*href="town.html"[^>]*>探索小鎮<\/a>/);
  assert.match(index, /<a\b[^>]*href="dashboard.html"[^>]*>進入 Nudge<\/a>/);
  const townHrefs = [...index.matchAll(/<a\b[^>]*href="([^"]*town[^"]*)"/g)].map(m => m[1]);
  assert.ok(townHrefs.length >= 2);
  assert.deepEqual([...new Set(townHrefs)], ['town.html'], 'relative GitHub Pages paths');
});
