// web_dashboard/assets/npc_dialog.js on a fake DOM: typewriter timing,
// click / keys to continue, reduced motion, actions, focus return and the
// shared world_ui.css styles.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const sprites = require('../web_dashboard/assets/sprite_player.js');
const dialog = require('../web_dashboard/assets/npc_dialog.js');

const css = fs.readFileSync(path.join(__dirname, '..', 'web_dashboard/assets/world_ui.css'), 'utf8');

class El {
  constructor(tag, doc) {
    Object.assign(this, { tagName: tag.toUpperCase(), doc, children: [], parent: null, listeners: {},
      attrs: {}, dataset: {}, style: {}, className: '', hidden: false, id: '', _text: '' });
    const el = this;
    this.classList = {
      add: c => { if (!el.className.split(' ').includes(c)) el.className = `${el.className} ${c}`.trim(); },
      contains: c => el.className.split(' ').includes(c),
    };
  }
  get textContent() { return this._text + this.children.map(c => c.textContent).join(''); }
  set textContent(v) { this._text = String(v); this.children = []; }
  setAttribute(k, v) { this.attrs[k] = String(v); }
  getAttribute(k) { return this.attrs[k] ?? null; }
  appendChild(c) { c.parent = this; this.children.push(c); return c; }
  append(...c) { c.forEach(x => this.appendChild(x)); }
  remove() { if (this.parent) this.parent.children = this.parent.children.filter(c => c !== this); this.parent = null; }
  addEventListener(n, cb) { (this.listeners[n] ||= []).push(cb); }
  removeEventListener() {}
  fire(n, e = {}) {
    let stopped = false;
    const ev = { target: this, preventDefault() {}, stopPropagation() { stopped = true; }, ...e };
    for (let node = this; node && !stopped; node = node.parent) (node.listeners[n] || []).forEach(cb => cb(ev));
  }
  focus() { this.doc.activeElement = this; }
  find(cls) { return [this, ...this.all()].find(n => n.classList.contains(cls)); }
  all() { return this.children.flatMap(c => [c, ...c.all()]); }
}

function env({ reduced = false } = {}) {
  let t = 0;
  let queue = [];
  let id = 0;
  const doc = { createElement: tag => new El(tag, doc), addEventListener() {}, removeEventListener() {} };
  doc.body = new El('body', doc);
  const opener = doc.body.appendChild(new El('button', doc));
  opener.focus();
  return {
    document: doc, opener, NudgeSpritePlayer: sprites,
    performance: { now: () => t },
    matchMedia: () => ({ matches: reduced, addEventListener() {}, removeEventListener() {} }),
    requestAnimationFrame(cb) { queue.push({ id: ++id, cb }); return id; },
    cancelAnimationFrame(x) { queue = queue.filter(q => q.id !== x); },
    advance(ms) {
      const end = t + ms;
      while (t < end) { t = Math.min(end, t + 16); const run = queue; queue = []; run.forEach(q => q.cb(t)); }
    },
  };
}

const LINES = ['歡迎光臨！', '貨架上的東西都可以拿起來看看。'];
const text = box => box.find('w-npc-dialog__text').textContent;

test('typedLength counts whole characters at the typing speed', () => {
  assert.equal(dialog.typedLength('歡迎光臨！', 0), 0);
  assert.equal(dialog.typedLength('歡迎光臨！', 50), 2);
  assert.equal(dialog.typedLength('歡迎光臨！', 5000), 5);
  assert.equal(dialog.typedLength('🌟ab', 25), 1, 'emoji count as one');
});

test('types a line, finishes it on click, then goes on and closes', () => {
  const e = env();
  let closed = 0;
  const d = dialog.open({ speaker: 'chestnut', lines: LINES, env: e, onClose: () => closed++ });
  const box = d.el;
  assert.equal(box.getAttribute('role'), 'dialog');
  assert.equal(box.find('w-npc-dialog__name').textContent, '栗子');
  assert.equal(box.find('w-npc-dialog__portrait').dataset.character, 'chestnut');
  assert.equal(box.find('w-npc-dialog__portrait').dataset.animation, 'talk');
  assert.equal(e.document.activeElement, box, 'focus moves into the dialog');
  assert.equal(box.find('w-npc-dialog__sr').textContent, LINES[0], 'screen readers get the whole line');
  assert.equal(box.find('w-npc-dialog__sr').getAttribute('aria-live'), 'polite');

  e.advance(60);
  assert.equal(text(box), '歡迎');
  assert.equal(d.typing, true);
  box.fire('click');
  assert.equal(text(box), LINES[0]);
  assert.equal(box.find('w-npc-dialog__more').hidden, false);
  assert.equal(box.find('w-npc-dialog__portrait').dataset.animation, 'idle', 'stops talking');

  box.fire('click');
  assert.equal(d.line, 1);
  assert.equal(text(box), '');
  e.advance(2000);
  assert.equal(text(box), LINES[1]);
  assert.equal(box.find('w-npc-dialog__more').hidden, true, 'no arrow on the last line');

  box.fire('click');
  assert.equal(closed, 1);
  assert.equal(e.document.body.children.includes(box), false);
  assert.equal(e.document.activeElement, e.opener, 'focus goes back');
});

test('Enter and Space continue, Escape closes', () => {
  const e = env();
  let closed = 0;
  const d = dialog.open({ speaker: 'scroll', lines: LINES, env: e, onClose: () => closed++ });
  d.el.fire('keydown', { key: 'Enter', target: d.el });
  assert.equal(d.typing, false);
  d.el.fire('keydown', { key: ' ', target: d.el });
  assert.equal(d.line, 1);
  d.el.fire('keydown', { key: 'Escape' });
  assert.equal(closed, 1);
});

test('reduced motion shows each line at once and never schedules frames', () => {
  const e = env({ reduced: true });
  const d = dialog.open({ speaker: 'bell', lines: LINES, env: e });
  assert.equal(text(d.el), LINES[0]);
  d.next();
  assert.equal(text(d.el), LINES[1]);
  d.close();
});

test('actions show after the last line and close the box when chosen', () => {
  const e = env();
  let went = 0;
  const d = dialog.open({
    speaker: 'chestnut', lines: ['還差 3 枚金幣，去委託所看看吧'], env: e,
    actions: [{ label: '去委託所', onSelect: () => went++ }],
  });
  const actions = d.el.find('w-npc-dialog__actions');
  assert.equal(actions.hidden, true);
  d.next();
  assert.equal(actions.hidden, false);
  d.next();
  assert.equal(e.document.body.children.includes(d.el), true, 'waits for a choice');
  actions.children[0].fire('click');
  assert.equal(went, 1);
  assert.equal(e.document.body.children.includes(d.el), false);
});

test('the close button is labelled and only one dialog is open at a time', () => {
  const e = env();
  const a = dialog.open({ speaker: 'letty', lines: LINES, env: e });
  const close = a.el.find('w-npc-dialog__close');
  assert.equal(close.getAttribute('aria-label'), '關閉對話');
  const b = dialog.open({ speaker: { name: '路人', portrait: 'x.png' }, lines: ['嗨'], env: e });
  assert.equal(e.document.body.children.includes(a.el), false);
  assert.equal(b.el.find('w-npc-dialog__name').textContent, '路人');
  b.el.find('w-npc-dialog__close').fire('click');
  assert.equal(e.document.body.children.includes(b.el), false);
  assert.throws(() => dialog.open({ speaker: 'letty', lines: [], env: e }));
});

test('world_ui.css styles the box with tokens, 44 px targets and reduced motion', () => {
  for (const cls of ['.w-sprite', '.w-npc-dialog', '.w-npc-dialog__portrait', '.w-npc-dialog__name',
    '.w-npc-dialog__text', '.w-npc-dialog__close']) {
    assert.ok(css.includes(cls), cls);
  }
  const block = css.slice(css.indexOf('/* ---------- NPC speech box'), css.indexOf('/* ---------- small screens'));
  assert.doesNotMatch(block, /#[0-9a-f]{3,8}\b/i, 'colours come from --w-* tokens');
  assert.match(block, /\.w-npc-dialog__close \{[^}]*width: 44px;[^}]*height: 44px;/);
  assert.match(block, /prefers-reduced-motion: reduce/);
  for (const m of block.matchAll(/font-size: (\d+)px/g)) assert.ok(Number(m[1]) >= 14, m[0]);
});
