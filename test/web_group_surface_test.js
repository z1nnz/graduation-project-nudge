const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");

function read(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), "utf8");
}

test("group overview exposes canonical publications to members", () => {
  const html = read("web_dashboard/groups.html");
  const app = read("web_dashboard/assets/app.js");

  assert.match(html, /data-group-challenge-list/);
  assert.match(html, /data-group-schedule-list/);
  assert.match(html, /data-group-template-list/);
  assert.match(app, /function renderCanonicalGroupOverview/);
  assert.match(app, /template\.strategy/);
  assert.match(app, /const canReadPublications = isPreviewMode\(\) \|\| Boolean\(activeWebGroup\)/);
  assert.match(app, /function clearCanonicalGroupPublications/);
  assert.match(read("web_dashboard/assets/styles.css"), /\.center-hub \.hub-card\[hidden\]/);
});

test("app consumes the same canonical publication fields and full template list", () => {
  const state = read("lib/state/app_state.dart");
  const screen = read("lib/screens/group_management_page.dart");

  assert.match(state, /List<Map<String, dynamic>> get groupTemplates/);
  assert.match(state, /\.collection\('templates'\)[\s\S]*?\.limit\(50\)/);
  assert.match(state, /challenge\['groupName'\]/);
  assert.match(screen, /challenge\['groupName'\]/);
  assert.match(screen, /template\['strategy'\]/);
  assert.doesNotMatch(screen, /template\['pressure'\]/);
});

test("group surfaces do not ship fabricated outcomes", () => {
  const overview = read("web_dashboard/groups.html");
  const ranking = read("web_dashboard/groups-ranking.html");
  const schedule = read("web_dashboard/groups-study-schedule.html");

  assert.doesNotMatch(overview, /4 個企業挑戰|8 個讀書會房間/);
  assert.doesNotMatch(ranking, /842|798|751|匯出週報 Demo/);
  assert.doesNotMatch(schedule, /42 位學生/);
  assert.match(ranking, /尚未產生/);
});
