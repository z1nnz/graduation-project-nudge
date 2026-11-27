const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const webRoot = path.join(root, "web_dashboard");
const scene = require("../web_dashboard/assets/social_scene.js");
const routes = require("../web_dashboard/assets/town_routes.js");

const scenePages = () => fs.readdirSync(webRoot)
  .filter(name => name.endsWith(".html"))
  .map(name => ({ name, html: fs.readFileSync(path.join(webRoot, name), "utf8") }))
  .filter(page => /data-social-facility="/.test(page.html));

test("every facility room is a real page owned by the same town building", () => {
  const buildingOf = { tower: "tower", family: "family", guild: "guild", plaza: "plaza" };
  for (const [sceneId, facility] of Object.entries(scene.SCENES)) {
    for (const [href] of facility.rooms) {
      assert.ok(fs.existsSync(path.join(webRoot, href)), `${href} exists`);
      const dest = routes.destinationForPage(href);
      assert.ok(dest, `${href} is in the town route table`);
      assert.equal(dest.building, buildingOf[sceneId], `${href} belongs to ${sceneId}`);
    }
  }
});

test("scene navigation marks only the current room", () => {
  const nav = scene.navFor("family", "/web/guardian-goals.html?x=1");
  assert.equal(nav.place, "家庭庭院");
  assert.deepEqual(nav.links.filter(link => link.current).map(link => link.href), ["guardian-goals.html"]);
  assert.equal(scene.navFor("unknown", "/x.html"), null);
});

test("entering the courtyard or hall selects only that relationship context", () => {
  const store = new Map();
  const storage = { setItem: (key, value) => store.set(key, value) };
  assert.equal(scene.applyRelationshipContext(storage, "family", "u1"), "family");
  assert.equal(scene.applyRelationshipContext(storage, "guild", "u1"), "group");
  assert.equal(store.get("nudgeRelationshipContext:u1"), "group");
  assert.equal(scene.applyRelationshipContext(storage, "plaza", "u1"), null);
  assert.equal(scene.applyRelationshipContext(storage, "family", null), null);
  assert.equal(store.size, 1);
});

test("scene pages drop the dashboard shell and return to the town", () => {
  const appVersions = new Set();
  for (const { name, html } of scenePages()) {
    assert.match(html, /<a data-town-return href="town\.html">← 回小鎮<\/a>/, `${name} town return`);
    assert.match(html, /assets\/town_routes\.js/, `${name} loads town routes`);
    assert.match(html, /assets\/town_return\.js/, `${name} loads town return`);
    if (/data-living-room="/.test(html)) {
      // #200 living rooms: in-world objects lead between rooms instead of a nav bar.
      assert.match(html, /assets\/scenes\/social_world\/living_page\.js/, `${name} mounts its living room`);
      assert.match(html, /<header class="w-hud">[\s\S]{0,400}data-town-return/, `${name} keeps the town return in the HUD`);
    } else {
      assert.match(html, /assets\/social_scene\.css/, `${name} loads scene css`);
      assert.match(html, /data-scene-nav/, `${name} has scene nav`);
    }
    assert.doesNotMatch(html, /class="[^"]*\b(sidebar|shell|app-shell|page-section)\b/, `${name} legacy shell`);
    assert.doesNotMatch(html, /class="hero split"/, `${name} legacy hero`);
    assert.doesNotMatch(html, /class="(?:[^"]*\s)?panel(?:\s[^"]*)?"/, `${name} legacy panel`);
    for (const match of html.matchAll(/assets\/app\.js\?v=(\d+)/g)) appVersions.add(match[1]);
  }
  assert.ok(appVersions.size <= 1, "scene pages share the main app.js version");
});
