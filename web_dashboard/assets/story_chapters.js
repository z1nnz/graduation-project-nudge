(function (root) {
  'use strict';
  const doc = root.document;
  const core = root.NudgeStoryChaptersCore;
  if (!doc || !core || doc.body?.dataset.page !== 'story-chapters') return;

  const byId = id => doc.getElementById(id);
  const status = byId('storyStatus');
  const list = byId('chapterList');
  const dialog = byId('chapterDialog');
  const stories = {
    'first-light': '你完成的第一件小事，讓小鎮的夜晚有了第一盞燈。明天不需要完美，只要能再往前一步。',
    'small-path': '三個不同日子的行動連成一條路。歐莉把路標放在這裡，提醒你曾經回來過。',
    'star-road': '七個自律日的腳印帶你走到星光路口。這不是終點，你可以選下一段想走的路。',
  };
  let connected = false;
  let generation = 0;
  let currentUser = null;

  function setStatus(message, kind = '') {
    status.textContent = message;
    status.dataset.kind = kind;
  }

  function render(result) {
    list.replaceChildren();
    for (const [index, chapter] of result.chapters.entries()) {
      const card = doc.createElement('article');
      card.className = `story-chapter ${chapter.completed ? 'is-complete' : chapter.unlocked ? 'is-open' : 'is-locked'}`;
      const marker = doc.createElement('span');
      marker.className = 'story-chapter-marker';
      marker.setAttribute('aria-hidden', 'true');
      marker.textContent = chapter.completed ? '✦' : chapter.unlocked ? String(index + 1) : '🔒';
      const body = doc.createElement('div');
      const tag = doc.createElement('span');
      tag.className = 'story-eyebrow';
      tag.textContent = `第 ${index + 1} 章`;
      const title = doc.createElement('h3');
      title.textContent = chapter.title;
      const detail = doc.createElement('p');
      detail.textContent = chapter.completed
        ? `已走過 ${chapter.requiredDays} 個自律日 · 可閱讀故事`
        : `${chapter.currentDays} / ${chapter.requiredDays} 個已確認的行動日`;
      const button = doc.createElement('button');
      button.type = 'button';
      button.className = 'story-button story-button-secondary';
      button.textContent = chapter.unlocked ? '閱讀這一章' : '尚未開放';
      button.disabled = !chapter.unlocked;
      button.addEventListener('click', () => {
        byId('chapterDialogTitle').textContent = chapter.title;
        byId('chapterDialogText').textContent = stories[chapter.id];
        dialog.showModal();
      });
      body.append(tag, title, detail, button);
      card.append(marker, body);
      list.append(card);
    }
    setStatus(result.days
      ? `最近 28 個自律日有 ${result.days} 天留下已確認行動，共 ${result.actions} 筆紀錄。`
      : '目前沒有這段期間的 Cloud 確認行動；你仍可以閱讀第一章的開場。', 'ready');
  }

  async function readReceipts(user, expectedGeneration) {
    const db = root.firebase.firestore();
    const start = core.windowStart(new Date());
    const base = db.collection('activity_receipts')
      .where('actorUserId', '==', user.uid)
      .where('verifiedAt', '>=', start)
      .orderBy('verifiedAt', 'desc');
    const records = [];
    let cursor = null;
    for (let page = 0; page < 20; page += 1) {
      let query = base.limit(100);
      if (cursor) query = query.startAfter(cursor);
      const snap = await query.get({ source: 'server' });
      if (expectedGeneration !== generation) return;
      for (const item of snap.docs) {
        const record = { ...item.data(), receiptId: item.id };
        if (root.NudgeConfirmedActivityFeedback?.parse(item.id, record, user.uid)) records.push(record);
      }
      if (snap.size < 100) return records;
      cursor = snap.docs[snap.docs.length - 1];
    }
    throw new Error('這段期間的紀錄太多，無法完整計算章節。請稍後重試。');
  }

  async function refresh() {
    const user = currentUser;
    const request = ++generation;
    if (!user) {
      render(core.progress([], 'guest', new Date()));
      setStatus('展示章節開場。登入後才會讀取你的 Cloud 確認進度。', 'guest');
      return;
    }
    setStatus('正在讀取 Cloud 確認紀錄…', 'loading');
    try {
      const receipts = await readReceipts(user, request);
      if (request !== generation) return;
      render(core.progress(receipts, user.uid, new Date()));
    } catch (error) {
      if (request !== generation) return;
      list.replaceChildren();
      setStatus(error.message || '無法讀取章節進度，請稍後重試。', 'error');
    }
  }

  function connect() {
    if (connected || !root.firebase?.apps?.length) return;
    connected = true;
    root.firebase.auth().onAuthStateChanged(user => {
      currentUser = user;
      refresh();
    });
  }
  byId('storyRefresh').addEventListener('click', refresh);
  doc.addEventListener('firebase-ready', connect);
  connect();
})(typeof globalThis !== 'undefined' ? globalThis : this);
