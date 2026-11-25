(function (root, factory) {
  const api = factory(root);
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.NudgeTownCrowd = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function (root) {
  'use strict';
  // Friends walking the town in real time. Sharing is the player's own
  // choice (presence_settings), only mutual friends can read a position
  // (Firestore rules), and only fixed emotes and phrases are ever sent.
  const PHRASES = Object.freeze({
    hi: '嗨！', study: '一起讀書嗎？', great: '你好棒！', rest: '休息一下～', bye: '掰掰！', go: '衝呀！',
  });
  const EMOTES = Object.freeze({ wave: '👋', cheer: '✨', sit: '🪑', sleep: '💤', heart: '💗', study: '📖' });
  const FRESH_MS = 5 * 60 * 1000;
  const SEND_EVERY_MS = 1000;
  const HEARTBEAT_MS = 20_000;
  const BUBBLE_MS = 4000;

  /** Pure: is a presence record a visible friend in town right now? */
  function townPerson(record, now) {
    const t = record?.town;
    const updated = record?.updatedAt?.toMillis?.();
    if (record?.building !== 'town' || !t || !Number.isFinite(updated) || now - updated > FRESH_MS) return null;
    if (![t.x, t.y].every(v => typeof v === 'number' && v >= 0 && v <= 1)) return null;
    return {
      x: t.x, y: t.y,
      facing: ['south', 'north', 'east', 'west'].includes(t.facing) ? t.facing : 'south',
      emote: Object.hasOwn(EMOTES, t.emote) ? t.emote : null,
      say: Object.hasOwn(PHRASES, t.say) ? t.say : null,
      face: Number.isSafeInteger(t.face) && t.face >= 0 && t.face < 100 ? t.face : 0,
      updated,
    };
  }

  /** Pure: should this frame send an update? */
  function shouldSend(last, next, now) {
    if (!last) return true;
    if (now - last.at < SEND_EVERY_MS) return false;
    if (next.emote !== last.emote || next.say !== last.say || next.facing !== last.facing) return true;
    if (Math.hypot(next.x - last.x, next.y - last.y) > 0.003) return true;
    return now - last.at > HEARTBEAT_MS;
  }

  const state = {
    uid: null, enabled: null, call: null, unsubs: [], friends: new Map(), people: new Map(), listeners: new Map(),
    last: null, sending: false, say: null, sayAt: 0, images: new Map(), panel: null,
  };

  function image(face) {
    if (!state.images.has(face)) {
      const img = new root.Image();
      img.src = `assets/avatar/characters/character_${face}.png`;
      state.images.set(face, img);
    }
    return state.images.get(face);
  }

  function stopAll() {
    for (const u of state.unsubs) { try { u(); } catch { /* gone */ } }
    for (const u of state.listeners.values()) { try { u(); } catch { /* gone */ } }
    state.unsubs = []; state.listeners.clear(); state.people.clear(); state.friends.clear();
    state.uid = null; state.enabled = null; state.last = null;
    renderPanel();
  }

  function watchFriend(db, fid) {
    if (state.listeners.has(fid)) return;
    const off = db.collection('presence').doc(fid).onSnapshot(snap => {
      const person = snap.exists ? townPerson(snap.data(), Date.now()) : null;
      if (!person) { state.people.delete(fid); return; }
      const prev = state.people.get(fid);
      state.people.set(fid, {
        ...person, name: state.friends.get(fid) || '好友',
        drawX: prev ? prev.drawX : person.x, drawY: prev ? prev.drawY : person.y,
        bubbleAt: person.say !== prev?.say || person.emote !== prev?.emote ? Date.now() : prev?.bubbleAt || 0,
      });
    }, () => state.people.delete(fid));
    state.listeners.set(fid, off);
  }

  function start(fb) {
    const auth = fb?.auth?.(), db = fb?.firestore?.();
    if (!auth || !db) return;
    auth.onAuthStateChanged(user => {
      stopAll();
      if (!user || user.isAnonymous) return;
      state.uid = user.uid;
      // Resolve the callable on each send, after the page has finished wiring Firebase.
      state.call = data => fb.app().functions('asia-east1').httpsCallable('manageFriendPresence')(data);
      state.unsubs.push(db.collection('presence_settings').doc(user.uid).onSnapshot(s => {
        state.enabled = s.data()?.enabled === true;
        renderPanel();
      }, () => { state.enabled = null; renderPanel(); }));
      state.unsubs.push(db.collection('users').doc(user.uid).collection('friends').onSnapshot(snapshot => {
        state.friends = new Map(snapshot.docs.slice(0, 30).map(d => [d.id, String(d.data().nickname || d.data().displayName || '好友').slice(0, 16)]));
        for (const [fid, off] of state.listeners) if (!state.friends.has(fid)) { off(); state.listeners.delete(fid); state.people.delete(fid); }
        for (const fid of state.friends.keys()) watchFriend(db, fid);
        renderPanel();
      }, () => {}));
    });
  }

  async function send(payload) {
    if (!state.call || state.sending) return;
    state.sending = true;
    try { await state.call({ action: 'town', ...payload }); } catch { /* offline: try again next tick */ } finally { state.sending = false; }
  }

  /** Called every frame by town.js with the player's map position. */
  function report({ x, y, facing, emote }) {
    if (state.enabled !== true) return;
    const now = Date.now();
    const next = {
      x: Math.min(1, Math.max(0, x)), y: Math.min(1, Math.max(0, y)),
      facing: ['south', 'north', 'east', 'west'].includes(facing) ? facing : 'south',
      emote: Object.hasOwn(EMOTES, emote) ? emote : null,
      say: now - state.sayAt < BUBBLE_MS ? state.say : null,
    };
    if (!shouldSend(state.last, next, now)) return;
    state.last = { ...next, at: now };
    void send(next);
  }

  function say(key) {
    if (!Object.hasOwn(PHRASES, key)) return;
    state.say = key;
    state.sayAt = Date.now();
    // The next allowed send (at most a second away) carries the phrase;
    // sending sooner would only be dropped by the server's throttle.
    root.NudgeSfx?.play('page');
  }

  async function setSharing(on) {
    if (!state.call) return;
    try {
      await state.call({ action: 'consent', enabled: on });
    } catch { /* the toggle repaints from the server setting */ }
  }

  function bubble(ctx, x, y, text, s) {
    ctx.font = `${Math.max(12, Math.round(13 * s))}px "Cubic11", sans-serif`;
    const w = ctx.measureText(text).width + 14 * s, h = 20 * s;
    ctx.fillStyle = 'rgba(255,250,240,0.95)';
    ctx.strokeStyle = '#3a2216';
    ctx.lineWidth = 2;
    ctx.fillRect(Math.round(x - w / 2), Math.round(y - h), Math.round(w), Math.round(h));
    ctx.strokeRect(Math.round(x - w / 2), Math.round(y - h), Math.round(w), Math.round(h));
    ctx.fillStyle = '#3a1d0c';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(text, x, y - h / 2);
  }

  /** Called by town.js after the map and before the player is drawn. */
  function draw(ctx, { toScreen, scale: s, mapW, mapH, reducedMotion, self }) {
    const now = Date.now();
    for (const [fid, p] of state.people) {
      if (now - p.updated > FRESH_MS) { state.people.delete(fid); continue; }
      const k = reducedMotion ? 1 : 0.12;
      p.drawX += (p.x - p.drawX) * k;
      p.drawY += (p.y - p.drawY) * k;
      const at = toScreen({ x: p.drawX * mapW, y: p.drawY * mapH });
      const img = image(p.face);
      const ph = 40 * s;
      const pw = img.naturalWidth ? ph * img.naturalWidth / img.naturalHeight : ph * 0.6;
      ctx.fillStyle = 'rgba(0,0,0,0.22)';
      ctx.beginPath();
      ctx.ellipse(at.x, at.y, pw * 0.35, ph * 0.07, 0, 0, Math.PI * 2);
      ctx.fill();
      if (img.complete && img.naturalWidth) {
        ctx.save();
        ctx.translate(at.x, at.y);
        if (p.facing === 'west') ctx.scale(-1, 1);
        ctx.drawImage(img, -pw / 2, -ph, pw, ph);
        ctx.restore();
      }
      ctx.font = `${Math.max(11, Math.round(12 * s))}px "Cubic11", sans-serif`;
      const label = p.name;
      const lw = ctx.measureText(label).width + 10;
      ctx.fillStyle = 'rgba(58,34,22,0.85)';
      ctx.fillRect(Math.round(at.x - lw / 2), Math.round(at.y + 2), Math.round(lw), Math.round(15 * s));
      ctx.fillStyle = '#ffe6a3';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'top';
      ctx.fillText(label, at.x, at.y + 3);
      const recent = now - p.bubbleAt < BUBBLE_MS * 1.5;
      if (p.say && recent) bubble(ctx, at.x, at.y - ph - 6 * s, PHRASES[p.say], s);
      else if (p.emote) {
        ctx.font = `${Math.max(16, Math.round(18 * s))}px sans-serif`;
        ctx.textBaseline = 'alphabetic';
        ctx.fillText(EMOTES[p.emote], at.x, at.y - ph - 6 * s);
      }
    }
    if (self && state.say && now - state.sayAt < BUBBLE_MS) {
      const at = toScreen(self);
      bubble(ctx, at.x, at.y - 50 * s, PHRASES[state.say], s);
    }
  }

  // ---------- the small "say hello" panel in the town ----------
  function renderPanel() {
    const doc = root.document;
    if (!doc?.body || doc.body.dataset.page !== 'town') return;
    let panel = state.panel;
    if (!panel) {
      panel = doc.createElement('section');
      panel.className = 'town-crowd';
      panel.setAttribute('aria-label', '小鎮好友');
      const toggle = doc.createElement('label');
      toggle.className = 'town-crowd-share';
      const box = doc.createElement('input');
      box.type = 'checkbox';
      box.dataset.crowdShare = '';
      box.addEventListener('change', () => setSharing(box.checked));
      toggle.append(box, doc.createTextNode(' 在小鎮顯示我（只有好友看得到）'));
      const count = doc.createElement('p');
      count.className = 'town-crowd-count';
      count.dataset.crowdCount = '';
      const phrases = doc.createElement('div');
      phrases.className = 'town-crowd-phrases';
      for (const [key, text] of Object.entries(PHRASES)) {
        const b = doc.createElement('button');
        b.type = 'button';
        b.className = 'w-btn';
        b.textContent = text;
        b.addEventListener('click', () => say(key));
        phrases.append(b);
      }
      panel.append(toggle, count, phrases);
      (doc.getElementById('townMain') || doc.querySelector('.town') || doc.body).append(panel);
      state.panel = panel;
    }
    panel.hidden = !state.uid;
    const box = panel.querySelector('[data-crowd-share]');
    box.checked = state.enabled === true;
    box.disabled = state.enabled === null;
    panel.querySelector('.town-crowd-phrases').hidden = state.enabled !== true;
    const online = [...state.people.values()].length;
    panel.querySelector('[data-crowd-count]').textContent = state.enabled === true
      ? `小鎮裡的好友：${online} 位`
      : '開啟後，好友會在地圖上看到你走動。';
  }
  // Only a real page runs timers; requiring the module (tests) stays inert.
  if (root.document?.body) root.setInterval(() => { if (state.uid) renderPanel(); }, 3000);
  let begun = false;
  function begin() {
    if (begun || !root.firebase?.apps?.length) return;
    begun = true;
    start(root.firebase);
  }
  if (root.document?.body) {
    root.document.addEventListener('firebase-ready', begin);
    root.setTimeout(begin, 0);
  }

  return Object.freeze({ PHRASES, EMOTES, townPerson, shouldSend, start, report, say, draw });
});
