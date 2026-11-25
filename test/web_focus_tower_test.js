const { test } = require("node:test");
const assert = require("node:assert/strict");
const { readFileSync, statSync } = require("node:fs");

const page = readFileSync("web_dashboard/rooms.html", "utf8");
const script = readFileSync("web_dashboard/assets/room_lobby.js", "utf8");
const style = readFileSync("web_dashboard/assets/room_lobby.css", "utf8");

test("the focus tower includes the gate, floors and roof workshop", () => {
  for (const selector of ["data-lobby-porter", "data-lobby-doors", "data-lobby-new", "data-tower-climb"]) {
    assert.ok(page.includes(selector), selector);
  }
  for (const name of ["roof", "floor", "gate"]) {
    assert.ok(statSync("web_dashboard/assets/scenes/focus_tower/" + name + ".webp").size < 300_000);
  }
  assert.equal([...page.matchAll(/data-tower-theme=/g)].length, 4);
  assert.match(script, /porter\.addEventListener\("click"/);
  assert.match(script, /call\("preview", \{ token: code \}\)/);
  assert.match(script, /showRoom\(room, button\)/);
  assert.match(script, /call\("create"/);
});

test("the scene respects reduced motion and room presence permissions", () => {
  assert.match(style, /@media \(prefers-reduced-motion: no-preference\)/);
  assert.match(script, /motion\.matches \|\| document\.hidden \|\| !towerVisible/);
  assert.match(script, /if \(room\.joined\) activeFloors\.observe\(button\)/);
  assert.match(script, /returnFocus\?\.isConnected/);
});
