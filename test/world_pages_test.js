const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const routes = require('../web_dashboard/assets/town_routes.js');
const windowCore = require('../web_dashboard/assets/town_window_core.js');

const root = path.join(__dirname, '..', 'web_dashboard');
const migrated = new Set([
  'dashboard.html', 'personal-focus.html', 'planet.html', 'planet-builder.html', 'operations.html',
  'profile.html', 'privacy.html', 'safety-center.html',
]);
// TODO: remove entries as the page owners migrate them. town.html has its own
// full-screen game shell.
const awaitingMigration = new Set([
  'cabin.html', 'family-courtyard.html', 'friend-visits.html', 'friend.html',
  'garden.html', 'group-hall.html', 'groups-challenge.html', 'groups-link.html',
  'groups-ranking.html', 'groups-study-schedule.html', 'groups-templates.html',
  'groups.html', 'guardian-encouragement.html', 'guardian-goals.html',
  'guardian-link.html', 'guardian-permissions.html', 'guardian-report.html',
  'guardian.html', 'login.html', 'mailbox.html', 'notifications.html',
  'personal-identity.html', 'personal-letter.html', 'personal-pressure.html',
  'personal-skill-tree.html', 'personal-template.html', 'personal-time-capsule.html',
  'personal-trends.html', 'personal-weather.html', 'personal.html',
  'room-chat.html', 'rooms.html', 'seasonal-event.html', 'story-chapters.html',
  'weekly-planner.html',
]);

test('every player page has an explicit migration state', () => {
  const pages = new Set(routes.DESTINATIONS.filter(route => route.audience === 'player')
    .map(route => route.href.split('#')[0].split('?')[0]));
  pages.delete('town.html');
  assert.deepEqual([...pages].sort(), [...migrated, ...awaitingMigration].sort());
});

test('migrated player pages use town chrome without old dashboard or star layers', () => {
  for (const page of migrated) {
    const html = fs.readFileSync(path.join(root, page), 'utf8');
    assert.match(html, /<body class="w-page world-page"/, page);
    assert.match(html, /assets\/world_ui\.css\?v=2/, page);
    assert.match(html, /data-town-return/, page);
    assert.match(html, /assets\/town_routes\.js/, page);
    assert.match(html, /assets\/town_return\.js/, page);
    assert.doesNotMatch(html, /class="(?:shell|sidebar)(?:\s|\")/, page);
    assert.doesNotMatch(html, /class="stars(?:\s|\")/, page);
  }
  const builder = fs.readFileSync(path.join(root, 'planet-builder.html'), 'utf8');
  assert.match(builder, /assets\/world_ui\.css\?v=2/);
  assert.match(builder, /data-town-return/);
  assert.equal(windowCore.windowPath('planet-builder.html', 'https://nudge.example/web/town.html'), 'planet-builder.html');
});

test('existing Cloud-bound player controls remain in their migrated pages', () => {
  const hooks = {
    'dashboard.html': ['dailyActionTitle', 'dailyActionStatus', 'dailyActivityFeedback'],
    'personal-focus.html': ['focusTimerDisplay', 'btnStartFocus', 'btnPauseFocus', 'btnStopFocus'],
    'planet.html': ['planetCount', 'planetNote'],
    'operations.html': ['shop-items-container', 'shopStatus'],
    'profile.html': ['profileMainAvatar'],
    'privacy.html': ['data-privacy-accept', 'data-privacy-request-deletion'],
  };
  for (const [page, markers] of Object.entries(hooks)) {
    const html = fs.readFileSync(path.join(root, page), 'utf8');
    for (const marker of markers) assert.ok(html.includes(marker), `${page}: ${marker}`);
  }
});

test('focus desk controls parse and keep the Cloud pending state explicit', () => {
  const html = fs.readFileSync(path.join(root, 'personal-focus.html'), 'utf8');
  const script = html.match(/<script>\s*([\s\S]*?)\s*<\/script>/)?.[1];
  assert.ok(script);
  assert.doesNotThrow(() => new vm.Script(script));
  assert.match(html, /data-focus-mins="25"/);
  assert.match(html, /data-focus-mins="50"/);
  assert.match(html, /獎勵由雲端確認中/);
  assert.match(html, /activitySessionId.*completedSessionId/);
  assert.match(html, /NudgeConfirmedActivityFeedback\?\.parse/);
  assert.match(html, /獎勵仍以雲端獎勵帳本為準/);
});
