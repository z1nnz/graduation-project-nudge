(function (root) {
  'use strict';
  const doc = root.document;
  const core = root.NudgeSeasonalEventCore;
  const story = root.NudgeStoryChaptersCore;
  if (!doc || !core || !story || doc.body?.dataset.page !== 'seasonal-event') return;
  const byId = id => doc.getElementById(id);
  const status = byId('eventStatus');
  const map = byId('eventMap');
  const dialogue = byId('eventDialogue').querySelector('p');
  const ICONS = { gate: '⌂', garden: '✿', observatory: '✦' };
  const LINES = {
    winter: { gate: '冬夜的入口有一盞燈。歐莉邀你慢慢走，今天能來就很好。', garden: '三個不同日子的腳印，讓花園的燈一盞盞亮起。', observatory: '七天的行動把你帶到高處。看看一路走來的自己。' },
    spring: { gate: '春風吹過小鎮，第一顆種子已在這裡等你。', garden: '你在不同日子回來，花園就有了新芽。', observatory: '站上觀景台，看見自己種下的星光。' },
    summer: { gate: '星泉的水聲像一段新的冒險，先沿著小路散步吧。', garden: '每次回來都像為花園添一滴水。', observatory: '夏夜很長，你的腳印已連成一片星座。' },
    autumn: { gate: '秋風把樹葉帶到入口，歐莉邀你拾起一片故事。', garden: '三個日子的行動，像三片收藏的葉子。', observatory: '小鎮從高處看起來很溫暖。這些路是你自己走出來的。' },
  };
  let user = null;
  let connected = false;
  let generation = 0;
  function setStatus(message, kind = '') { status.textContent = message; status.dataset.kind = kind; }
  function render(result) {
    const season = result.season;
    doc.body.style.setProperty('--season-color', season.color);
    byId('eventTitle').textContent = season.title;
    byId('eventSubtitle').textContent = season.subtitle;
    map.replaceChildren();
    for (const place of result.stations) {
      const button = doc.createElement('button');
      button.className = 'event-place'; button.type = 'button'; button.disabled = !place.unlocked;
      const icon = doc.createElement('span'); icon.className = 'event-icon'; icon.textContent = ICONS[place.id]; icon.setAttribute('aria-hidden', 'true');
      const title = doc.createElement('strong'); title.textContent = place.name;
      const hint = doc.createElement('small'); hint.textContent = place.unlocked ? '點擊探索這個地點' : `需要 ${place.requiredDays} 個已確認的行動日 · 目前 ${result.days} 日`;
      button.append(icon, title, hint);
      button.addEventListener('click', () => { dialogue.textContent = LINES[season.id][place.id]; });
      map.append(button);
    }
    setStatus(`最近 28 個自律日已確認 ${result.days} 個行動日。探索地點只是故事，不會增加獎勵。`, 'ready');
  }
  async function readReceipts(uid, request) {
    const db = root.firebase.firestore();
    const base = db.collection('activity_receipts')
      .where('actorUserId', '==', uid)
      .where('verifiedAt', '>=', story.windowStart(new Date()))
      .orderBy('verifiedAt', 'desc');
    const receipts = [];
    let cursor = null;
    for (let page = 0; page < 20; page += 1) {
      let query = base.limit(100);
      if (cursor) query = query.startAfter(cursor);
      const snap = await query.get({ source: 'server' });
      if (request !== generation) return null;
      for (const item of snap.docs) {
        const receipt = { ...item.data(), receiptId: item.id };
        if (root.NudgeConfirmedActivityFeedback?.parse(item.id, receipt, uid)) receipts.push(receipt);
      }
      if (snap.size < 100) return receipts;
      cursor = snap.docs[snap.docs.length - 1];
    }
    throw new Error('紀錄太多，無法完整計算季節探索。請稍後重試。');
  }
  async function refresh() {
    const request = ++generation;
    if (!user || user.isAnonymous) {
      render(core.progress([], 'guest', new Date()));
      setStatus('展示季節故事入口。登入後才會讀取你的 Cloud 確認進度。', 'guest');
      return;
    }
    setStatus('正在讀取雲端確認行動…', 'loading');
    try {
      const receipts = await readReceipts(user.uid, request);
      if (request !== generation) return;
      render(core.progress(receipts, user.uid, new Date()));
    } catch (error) { if (request === generation) { map.replaceChildren(); setStatus(error.message || '讀取失敗，請稍後重試。', 'error'); } }
  }
  function connect() {
    if (connected || !root.firebase?.apps?.length) return;
    connected = true;
    root.firebase.auth().onAuthStateChanged(next => { user = next; dialogue.textContent = '點一個地點開始探索。'; refresh(); });
  }
  byId('eventRefresh').addEventListener('click', refresh);
  doc.addEventListener('firebase-ready', connect); connect();
})(typeof globalThis !== 'undefined' ? globalThis : this);
