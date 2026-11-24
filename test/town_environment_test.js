const test = require("node:test"),
  assert = require("node:assert/strict"),
  vm = require("node:vm"),
  fs = require("node:fs"),
  core = require("../web_dashboard/assets/town_atmosphere_core.js");
function fixture() {
  const events = {},
    root = {
      NudgeTownAtmosphereCore: core,
      NudgeTownImage: { load: (im, src) => (im.src = src) },
      document: {
        documentElement: {},
        getElementById: () => null,
        addEventListener: (k, fn) => (events[k] = fn),
      },
      getComputedStyle: () => ({ getPropertyValue: (k) => k }),
      addEventListener() {},
    };
  class Image {
    constructor() {
      this.complete = true;
      this.naturalWidth = 512;
      this.naturalHeight = 768;
    }
  }
  vm.runInNewContext(
    fs.readFileSync(
      require.resolve("../web_dashboard/assets/town_atmosphere.js"),
      "utf8",
    ),
    { globalThis: root, Image },
  );
  const renderer = root.NudgeTownAtmosphere.create();
  const ops = [],
    ctx = {
      save() {},
      restore() {},
      fillRect(...a) {
        ops.push(["rect", ...a]);
      },
      drawImage(im, ...a) {
        ops.push(["image", im.src, ...a]);
      },
    };
  const view = {
    width: 1000,
    height: 900,
    mapW: 1672,
    mapH: 941,
    scale: 1,
    toScreen: (p) => p,
    buildings: [{ id: "plaza", label: { x: 100, y: 100 } }],
    hidden: false,
    reducedMotion: true,
  };
  return { renderer, ctx, view, ops, events };
}
test("reduced motion renders a complete static first frame including all four inhabitants", () => {
  const f = fixture();
  f.renderer.draw(f.ctx, f.view, 0);
  const first = JSON.stringify(f.ops),
    images = f.ops.filter((o) => o[0] === "image");
  assert.equal(images.length, 4);
  assert.ok(
    images
      .slice(0, 3)
      .every((o) => o[2] === 0 && o[3] === 0 && o[4] === 128 && o[5] === 128),
  );
  f.ops.length = 0;
  f.renderer.draw(f.ctx, f.view, 9000);
  assert.equal(JSON.stringify(f.ops), first);
});
test("hidden surface does no drawing; ordinary NPC walking uses supplied 4-frame sheets", () => {
  const f = fixture();
  f.renderer.draw(f.ctx, { ...f.view, hidden: true }, 1000);
  assert.equal(f.ops.length, 0);
  f.renderer.draw(
    f.ctx,
    { ...f.view, reducedMotion: false, speakingActorId: "baker" },
    375,
  );
  const images = f.ops.filter((o) => o[0] === "image");
  assert.equal(images[0][2], 384);
  assert.equal(images[0][3], 128);
  assert.match(images[0][1], /characters\/chestnut\/sheet.webp$/);
});
test("new-content markers only appear after confirmed owner notification data and clear on account change", () => {
  const f = fixture();
  f.renderer.draw(f.ctx, f.view, 0);
  const baseline = f.ops.length;
  f.ops.length = 0;
  f.events["nudge-town-building-content"]({
    detail: { building: "plaza", confirmed: true, hasContent: true },
  });
  f.renderer.draw(f.ctx, f.view, 0);
  assert.equal(f.ops.length, baseline + 3);
  f.ops.length = 0;
  f.events["nudge-town-building-content"]({ detail: { clear: true } });
  f.renderer.draw(f.ctx, f.view, 0);
  assert.equal(f.ops.length, baseline);
});
