(function (root) {
  'use strict';
  // #200 H4 journey book: story-chapters.html shows the villager quest lines
  // as a book you turn page by page. Progress is read from the signed-in
  // player's Cloud-confirmed activity receipts (read-only).
  const core = root.NudgeQuestCore;
  const doc = root.document;
  const host = doc?.querySelector('[data-quest-book]');
  if (!core || !host) return;
  let page = 0, receipts = [], signedIn = false;
  const reduced = () => root.matchMedia?.('(prefers-reduced-motion: reduce)').matches;

  function el(tag, cls, text) { const n = doc.createElement(tag); if (cls) n.className = cls; if (text != null) n.textContent = text; return n; }

  function render(turn = 0) {
    const pages = core.QUESTS.map(q => ({ quest: q, p: core.progress(q, receipts) }));
    page = (page + turn + pages.length) % pages.length;
    const { quest, p } = pages[page];
    const sheet = el('article', 'quest-page');
    sheet.append(el('p', 'quest-npc', quest.name), el('h3', null, quest.title),
      el('p', 'quest-intro', p.complete ? quest.done : quest.intro));
    const list = el('ol', 'quest-steps');
    for (const step of p.steps) {
      const li = el('li', step.done ? 'is-done' : '', `${step.done ? '✦ ' : '○ '}${step.text}`);
      list.append(li);
    }
    sheet.append(list, el('p', 'quest-count', signedIn ? `${p.doneCount} / ${p.total} 步` : '登入後依雲端確認的紀錄翻開這一頁'));
    const nav = el('div', 'quest-nav');
    const prev = el('button', 'w-btn', '← 上一頁'), next = el('button', 'w-btn', '下一頁 →');
    prev.type = next.type = 'button';
    prev.addEventListener('click', () => render(-1));
    next.addEventListener('click', () => render(1));
    nav.append(prev, el('span', 'quest-folio', `${page + 1} / ${pages.length}`), next);
    const body = host.querySelector('.quest-book-body') || host.appendChild(el('div', 'quest-book-body'));
    body.replaceChildren(sheet, nav);
    if (turn && !reduced()) { sheet.classList.add(turn > 0 ? 'is-turning-next' : 'is-turning-prev'); }
  }

  function listen(uid) {
    root.firebase.firestore().collection('activity_receipts')
      .where('actorUserId', '==', uid).orderBy('verifiedAt', 'desc').limit(90)
      .onSnapshot(snap => {
        receipts = snap.docs.map(d => d.data());
        render();
      }, () => render());
  }
  render();
  doc.addEventListener('firebase-ready', () => {
    const user = root.firebase?.auth?.().currentUser;
    if (!user || user.isAnonymous) return;
    signedIn = true;
    listen(user.uid);
  });
})(typeof globalThis !== 'undefined' ? globalThis : this);
