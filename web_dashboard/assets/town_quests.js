(function(root) {
  'use strict';
  // #200 H4 in the town: quest NPCs talk about the next step of their quest
  // line (camera pushes in while they speak) and a newly completed step plays
  // the town's celebration. Progress comes only from Cloud-confirmed receipts
  // that town.js already reads; nothing is written to the cloud.
  const core = root.NudgeQuestCore;
  const doc = root.document;
  if (!core || !doc || doc.body?.dataset.page !== 'town') return;
  const SEEN = 'nudge_town_quest_seen_v1';
  let receipts = [];
  function readSeen() { try { return JSON.parse(root.localStorage.getItem(SEEN) || '{}'); } catch { return {}; } }
  function writeSeen(value) { try { root.localStorage.setItem(SEEN, JSON.stringify(value)); } catch { /* private mode */ } }
  // Celebrate steps finished since the last visit, but not on a first-ever load.
  let seenLoaded = Object.keys(readSeen()).length > 0;

  function update(list) {
    receipts = Array.isArray(list) ? list : [];
    const seen = readSeen();
    const fresh = core.newlyDone(receipts, seen);
    if (seenLoaded) {
      for (const item of fresh) {
        const message = item.complete
          ? `${item.quest.name}：${item.quest.done}`
          : `${item.quest.name}的任務前進了（${item.to}/${item.quest.steps.length}）`;
        doc.dispatchEvent(new CustomEvent('nudge-town-celebrate', { detail: { message } }));
      }
    }
    for (const quest of core.QUESTS) seen[quest.id] = core.progress(quest, receipts).doneCount;
    writeSeen(seen);
    seenLoaded = true;
  }

  function lineFor(actor) { return actor ? core.lineFor(actor.id, receipts) : null; }

  root.NudgeTownQuests = { update, lineFor };
})(typeof globalThis !== 'undefined' ? globalThis : this);
