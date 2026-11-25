const test = require("node:test"),
  assert = require("node:assert/strict"),
  fs = require("node:fs"),
  vm = require("node:vm");
function fixture(reduced = false) {
  const nodes = [],
    callbacks = new Map(),
    events = {},
    frames = new Map();
  let doc,
    id = 0,
    stops = 0;
  class Element {
    constructor(tag) {
      this.tag = tag;
      this.children = [];
      this.style = {};
      this.attrs = {};
      this.events = {};
      this.open = false;
      nodes.push(this);
    }
    setAttribute(k, v) {
      this.attrs[k] = v;
    }
    append(...a) {
      for (const n of a) {
        this.children.push(n);
        n.parent = this;
      }
    }
    before(n) {
      this.parent?.append(n);
    }
    replaceChildren(...a) {
      this.children = [];
      this.append(...a);
    }
    addEventListener(k, fn) {
      (this.events[k] ??= []).push(fn);
    }
    emit(k, e = {}) {
      for (const fn of this.events[k] || []) fn(e);
    }
    focus() {
      doc.activeElement = this;
    }
    showModal() {
      this.open = true;
    }
    close() {
      this.open = false;
    }
    getBoundingClientRect() {
      return { width: 360, height: 680 };
    }
    getContext() {
      return { setTransform() {}, clearRect() {}, fillRect() {} };
    }
    querySelectorAll() {
      return [];
    }
    remove() {
      this.removed = true;
    }
  }
  doc = {
    body: new Element("body"),
    documentElement: {},
    activeElement: null,
    hidden: false,
    createElement: (t) => new Element(t),
    addEventListener: (k, fn) => (events[k] = fn),
    removeEventListener() {},
    querySelector: () => null,
  };
  const main = new Element("main");
  doc.body.append(main);
  const media = {
    matches: reduced,
    addEventListener() {},
    removeEventListener() {},
  };
  const root = {
    document: doc,
    NudgeSpritePlayer: {
      CATALOG: { characters: [{ id: "inky", name: "墨墨" }] },
      characterPlayer: () => ({
        play() {},
        stop() {
          stops++;
        },
        destroy() {},
      }),
    },
    NudgeNpcDialog: { open: () => ({ close() {} }) },
    getComputedStyle: () => ({ getPropertyValue: (k) => k }),
    matchMedia: () => media,
    requestAnimationFrame: (fn) => {
      frames.set(++id, fn);
      return id;
    },
    cancelAnimationFrame: (id) => frames.delete(id),
    addEventListener: (k, fn) => callbacks.set(k, fn),
    removeEventListener() {},
  };
  vm.runInNewContext(
    fs.readFileSync(
      require.resolve("../web_dashboard/assets/facility_scene.js"),
      "utf8",
    ),
    {
      globalThis: root,
      IntersectionObserver: class {
        observe() {}
        disconnect() {}
      },
    },
  );
  const api = root.NudgeFacilityScene.mount({
    title: "紀錄館",
    background: "assets/scenes/library/library_room.webp",
    content: main,
    objects: [{ label: "閱讀工具", x: 50, y: 80 }],
  });
  return {
    api,
    doc,
    events,
    nodes,
    frames,
    media,
    stops: () => stops,
    flush(now) {
      const list = [...frames.values()];
      frames.clear();
      for (const fn of list) fn(now);
    },
  };
}
test("facility objects open the original feature and Escape closes only that panel with focus restored", () => {
  const f = fixture(),
    object = f.nodes.find((n) => n.attrs["aria-label"] === "閱讀工具");
  object.focus();
  object.emit("click");
  assert.equal(f.api.dialog.open, true);
  let prevented = false,
    stopped = false;
  f.api.dialog.emit("keydown", {
    key: "Escape",
    preventDefault: () => (prevented = true),
    stopPropagation: () => (stopped = true),
  });
  assert.equal(f.api.dialog.open, false);
  assert.equal(f.doc.activeElement, object);
  assert.ok(prevented && stopped);
  assert.ok(f.nodes.some((n) => n.attrs["aria-label"] === "與墨墨交談"));
});
test("reduced motion paints one complete frame without scheduling animation", () => {
  const f = fixture(true);
  f.flush(0);
  assert.equal(f.frames.size, 0);
  assert.equal(f.api.stage.style.opacity, "1");
  assert.equal(f.api.stage.style.transform, "scale(1)");
});
test("hidden facilities cancel environment and NPC animation work", () => {
  const f = fixture();
  f.flush(0);
  assert.ok(f.frames.size > 0);
  f.doc.hidden = true;
  f.events.visibilitychange();
  assert.equal(f.frames.size, 0);
  assert.ok(f.stops() > 0);
});
