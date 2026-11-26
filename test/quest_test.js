const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const quests = require('../web_dashboard/assets/scenes/social_world/quest_core.js');

const r = (type, iso) => ({ activityType: type, verifiedAt: iso });
const day = n => `2026-11-${String(n).padStart(2, '0')}T02:00:00.000Z`;

test('every villager has a 3 to 5 step quest line', () => {
  assert.ok(quests.QUESTS.length >= 3);
  for (const q of quests.QUESTS) {
    assert.ok(q.steps.length >= 3 && q.steps.length <= 5, q.id);
    assert.ok(q.intro && q.done && q.name);
  }
});

test('the gardener needs focus on three consecutive days, read from receipts', () => {
  const gardener = quests.QUESTS.find(q => q.npc === 'gardener');
  assert.equal(quests.progress(gardener, []).doneCount, 0);
  const twoApart = [r('focus', day(20)), r('focus', day(22))];
  assert.equal(quests.progress(gardener, twoApart).doneCount, 2, 'two days but not in a row');
  const run = [r('focus', day(20)), r('focus', day(21)), r('study', day(22)), r('task', day(23))];
  const p = quests.progress(gardener, run);
  assert.equal(p.complete, true);
  assert.equal(quests.longestRun(new Set(['2026-11-20', '2026-11-21', '2026-11-23'])), 2);
});

test('steps are sequential and lines describe the next step', () => {
  const postman = quests.QUESTS.find(q => q.npc === 'postman');
  const onlySleep = [r('sleep', day(20))];
  assert.equal(quests.progress(postman, onlySleep).doneCount, 0, 'sleep alone cannot skip ahead');
  assert.match(quests.lineFor('postman', []), /下一步：留下一筆運動或步數紀錄。（0\/5）/);
  assert.equal(quests.lineFor('owl', []), null);
});

test('newly completed steps are detected against what the player last saw', () => {
  const baker = quests.QUESTS.find(q => q.npc === 'baker');
  const receipts = [r('task', day(20)), r('task', day(20)), r('focus', day(21))];
  const fresh = quests.newlyDone(receipts, { [baker.id]: 1 });
  const item = fresh.find(x => x.quest.id === baker.id);
  assert.equal(item.from, 1);
  assert.equal(item.to, 3);
  assert.equal(item.complete, true);
  assert.equal(quests.newlyDone(receipts, { [baker.id]: 3 }).some(x => x.quest.id === baker.id), false);
});

test('quests are read-only and wired into the town and the journey book', () => {
  for (const f of ['scenes/social_world/quest_core.js', 'town_quests.js', 'scenes/social_world/quest_book.js']) {
    const src = fs.readFileSync(`web_dashboard/assets/${f}`, 'utf8');
    assert.doesNotMatch(src, /\.set\(|\.update\(|(?<!classList)\.add\(|httpsCallable|addCoins|grantXp/, f);
  }
  const town = fs.readFileSync('web_dashboard/assets/town.js', 'utf8');
  assert.match(town, /NudgeTownQuests\?\.update\(receipts\)/);
  assert.match(town, /NudgeTownQuests\?\.lineFor\(actor\)/);
  const story = fs.readFileSync('web_dashboard/story-chapters.html', 'utf8');
  assert.match(story, /data-quest-book/);
  assert.ok(story.indexOf('quest_core.js') < story.indexOf('quest_book.js'));
});
