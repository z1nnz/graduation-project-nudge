(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  root.NudgeQuestCore = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';
  // #200 H4: villager quest lines. Progress is computed only from the
  // player's Cloud-confirmed activity receipts (activityType, verifiedAt);
  // nothing is stored and no reward is granted.

  function taipeiDay(iso) {
    const t = Date.parse(iso);
    return Number.isFinite(t) ? new Date(t + 8 * 3600000).toISOString().slice(0, 10) : null;
  }
  const days = (receipts, types) => new Set(receipts
    .filter(r => !types || types.includes(r.activityType)).map(r => taipeiDay(r.verifiedAt)).filter(Boolean));
  const count = (receipts, types) => receipts.filter(r => !types || types.includes(r.activityType)).length;

  /** Longest run of consecutive days in a set of YYYY-MM-DD keys. */
  function longestRun(keys) {
    const sorted = [...keys].sort();
    let best = 0, run = 0, prev = null;
    for (const key of sorted) {
      const ok = prev && (Date.parse(`${key}T00:00:00Z`) - Date.parse(`${prev}T00:00:00Z`)) === 86400000;
      run = ok ? run + 1 : 1;
      best = Math.max(best, run);
      prev = key;
    }
    return best;
  }

  const QUESTS = Object.freeze([
    Object.freeze({ id: 'garden-water', npc: 'gardener', name: '園丁・苗苗', title: '連續三天的澆水',
      intro: '花圃想要每天一點點水。你的專注紀錄，就是給花的水。',
      done: '三天的水都澆到了！花圃開出了一朵新花，謝謝你。',
      steps: [
        { text: '完成一次專注，替花圃澆第一次水。', test: r => days(r, ['focus', 'study']).size >= 1 },
        { text: '換一天再專注一次，花芽冒出來了。', test: r => days(r, ['focus', 'study']).size >= 2 },
        { text: '連續兩天都有專注紀錄。', test: r => longestRun(days(r, ['focus', 'study'])) >= 2 },
        { text: '連續三天都有專注紀錄，花就會開。', test: r => longestRun(days(r, ['focus', 'study'])) >= 3 },
      ] }),
    Object.freeze({ id: 'bakery-helper', npc: 'baker', name: '雜貨店老闆・栗子', title: '麵包店的小幫手',
      intro: '店裡今天特別忙，完成幾件小事，就像幫我揉麵團。',
      done: '麵包都出爐了！多虧你這幾天一件一件完成。',
      steps: [
        { text: '完成一件任務或活動。', test: r => count(r) >= 1 },
        { text: '累積完成三件任務或活動。', test: r => count(r) >= 3 },
        { text: '在兩個不同的日子都有完成紀錄。', test: r => days(r).size >= 2 },
      ] }),
    Object.freeze({ id: 'postman-route', npc: 'postman', name: '郵差・小信', title: '走一圈送信路線',
      intro: '送信要走很多路。動一動身體、走走路，都算陪我送信。',
      done: '整條路線都送完了！每一步都有你。',
      steps: [
        { text: '留下一筆運動或步數紀錄。', test: r => count(r, ['exercise', 'steps']) >= 1 },
        { text: '累積三筆運動或步數紀錄。', test: r => count(r, ['exercise', 'steps']) >= 3 },
        { text: '在三個不同的日子都有任何活動紀錄。', test: r => days(r).size >= 3 },
        { text: '好好睡一覺，留下一筆睡眠紀錄。', test: r => count(r, ['sleep']) >= 1 },
        { text: '總共累積八筆活動紀錄，路線送完。', test: r => count(r) >= 8 },
      ] }),
  ]);

  /** Quest state from receipts: steps are sequential, so a later step only counts once earlier ones are done. */
  function progress(quest, receipts) {
    const list = Array.isArray(receipts) ? receipts : [];
    let open = true;
    const steps = quest.steps.map(step => {
      const done = open && step.test(list);
      if (!done) open = false;
      return { text: step.text, done };
    });
    const doneCount = steps.filter(s => s.done).length;
    return { id: quest.id, title: quest.title, steps, doneCount, total: steps.length, complete: doneCount === steps.length,
      current: steps.find(s => !s.done)?.text || null };
  }

  /** What the NPC says now. */
  function lineFor(npcId, receipts) {
    const quest = QUESTS.find(q => q.npc === npcId);
    if (!quest) return null;
    const p = progress(quest, receipts);
    if (p.complete) return `${quest.done}（${quest.title} ${p.total}/${p.total}）`;
    return `${p.doneCount === 0 ? quest.intro + ' ' : ''}下一步：${p.current}（${p.doneCount}/${p.total}）`;
  }

  /** Steps newly completed since the counts the player last saw. */
  function newlyDone(receipts, seen) {
    const out = [];
    for (const quest of QUESTS) {
      const p = progress(quest, receipts);
      const before = Number(seen?.[quest.id] || 0);
      if (p.doneCount > before) out.push({ quest, from: before, to: p.doneCount, complete: p.complete });
    }
    return out;
  }

  return Object.freeze({ QUESTS, progress, lineFor, newlyDone, longestRun, taipeiDay });
});
