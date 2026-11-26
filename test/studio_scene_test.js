const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
function fixture({ gate = false, reduced = false } = {}) {
  const nodes = [],
    events = {},
    frames = new Map();
  let id = 0,
    stops = 0,
    plays = 0,
    submits = 0,
    closed = 0,
    auth;
  class Element {
    constructor(tag, text = "") {
      this.tag = tag;
      this.textContent = text;
      this.children = [];
      this.events = {};
      this.isConnected = true;
      this.disabled = false;
      nodes.push(this);
    }
    setAttribute() {}
    append(...nodes) {
      this.children.push(...nodes);
    }
    remove() {
      this.isConnected = false;
    }
    showModal() {
      this.open = true;
    }
    close() {
      this.open = false;
    }
    focus() {
      doc.activeElement = this;
    }
    getContext() {
      return { clearRect() {}, fillRect() {} };
    }
    addEventListener(name, fn, capture = false) {
      (this.events[name] ??= []).push({ fn, capture });
    }
    click() {
      const e = {
        preventDefault() {},
        stopImmediatePropagation() {
          this.stopped = true;
        },
      };
      for (const { fn } of [...(this.events.click || [])].sort(
        (a, b) => Number(b.capture) - Number(a.capture),
      )) {
        fn(e);
        if (e.stopped) break;
      }
    }
  }
  const doc = {
    body: new Element("body"),
    hidden: false,
    activeElement: null,
    addEventListener: (k, f) => (events[k] ??= []).push(f),
    removeEventListener: (k, f) =>
      (events[k] = events[k]?.filter((x) => x !== f)),
    createElement: (tag) => new Element(tag),
    querySelector: () => button,
  };
  doc.body.dataset = gate ? { townGate: "login" } : { page: "privacy" };
  const button = new Element("button");
  button.addEventListener("click", () => submits++);
  button.focus();
  const media = {
    matches: reduced,
    addEventListener: (k, f) => (events.media ??= []).push(f),
    removeEventListener: (k, f) =>
      (events.media = events.media.filter((x) => x !== f)),
  };
  const root = {
    document: doc,
    NudgePageRoom: {
      stage: new Element("stage"),
      frame: new Element("frame"),
      closePanel: () => closed++,
    },
    NudgeSceneRoom: {},
    NudgeSpritePlayer: {
      characterPlayer: () => ({ stop: () => stops++, play: () => plays++ }),
    },
    firebase: {
      apps: [{}],
      auth: () => ({
        onAuthStateChanged: (fn) => {
          auth = fn;
          return () => {};
        },
      }),
    },
    matchMedia: () => media,
    IntersectionObserver: class {
      constructor(fn) {
        this.fn = fn;
      }
      observe() {
        this.fn([{ isIntersecting: true }]);
      }
    },
    getComputedStyle: () => ({ getPropertyValue: () => "#123456" }),
    requestAnimationFrame: (fn) => {
      frames.set(++id, fn);
      return id;
    },
    cancelAnimationFrame: (id) => frames.delete(id),
    addEventListener: (k, f) => (events[k] ??= []).push(f),
    removeEventListener: (k, f) =>
      (events[k] = events[k]?.filter((x) => x !== f)),
  };
  vm.runInNewContext(
    fs.readFileSync("web_dashboard/assets/studio_scene.js", "utf8"),
    root,
  );
  return {
    nodes,
    button,
    doc,
    media,
    frames,
    auth: (uid) => auth({ uid }),
    get submits() {
      return submits;
    },
    get closed() {
      return closed;
    },
    get stops() {
      return stops;
    },
    get plays() {
      return plays;
    },
    click: (text) =>
      nodes.findLast((n) => n.isConnected && n.textContent === text).click(),
    emit: (name) => events[name]?.forEach((fn) => fn()),
    frame: (now) => {
      const pending = [...frames.values()];
      frames.clear();
      pending.forEach((fn) => fn(now));
    },
  };
}
const flush = async () => {
  await Promise.resolve();
  await Promise.resolve();
};
test("vault requires a seal before invoking the existing second confirmation; cancel never forwards", async () => {
  const f = fixture();
  f.button.click();
  f.button.click();
  assert.equal(f.nodes.filter((n) => n.tag === "dialog").length, 1);
  assert.equal(f.submits, 0);
  f.click("返回，保留帳號");
  await flush();
  assert.equal(f.submits, 0);
  f.button.click();
  f.click("閱讀完成，前往第二步");
  await flush();
  assert.equal(f.submits, 1);
  assert.equal(f.doc.activeElement, f.button);
});
test("owner change closes the seal and original panel without submitting", async () => {
  const f = fixture();
  f.auth("alice");
  f.button.click();
  f.auth("bob");
  await flush();
  assert.equal(f.nodes.find((n) => n.tag === "dialog").isConnected, false);
  assert.equal(f.closed, 1);
  assert.equal(f.submits, 0);
});
test("seal stops at its complete first frame under reduced motion and pauses while hidden", async () => {
  const f = fixture({ reduced: true });
  f.button.click();
  f.frame(0);
  assert.equal(f.frames.size, 0);
  f.media.matches = false;
  f.emit("media");
  f.frame(100);
  assert.equal(f.frames.size, 1);
  f.doc.hidden = true;
  f.emit("visibilitychange");
  assert.equal(f.frames.size, 0);
  f.doc.hidden = false;
  f.emit("visibilitychange");
  assert.equal(f.frames.size, 1);
  f.emit("pagehide");
  await flush();
  assert.equal(f.frames.size, 0);
  assert.equal(f.submits, 0);
});
test("gate companion waves only when visible and motion is allowed", () => {
  const f = fixture({ gate: true });
  assert.ok(f.plays > 0);
  const initial = f.stops;
  f.doc.hidden = true;
  f.emit("visibilitychange");
  assert.ok(f.stops > initial);
  f.doc.hidden = false;
  f.media.matches = true;
  f.emit("media");
  const plays = f.plays;
  f.emit("pageshow");
  assert.equal(f.plays, plays);
});
