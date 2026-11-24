(function(root) {
  'use strict';
  const doc = root.document, core = root.NudgeTownHudCore;
  if (!core || doc.body?.dataset.page !== 'town') return;
  const el = id => doc.getElementById(id);
  const store = {
    get(key) { try { return root.localStorage.getItem(key); } catch { return null; } },
    set(key, value) { try { root.localStorage.setItem(key, value); } catch { /* private mode */ } },
  };
  const prefKey = 'nudge_town_preferences_v1';
  let preferences = {};
  try { preferences = JSON.parse(store.get(prefKey) || '{}') || {}; } catch { preferences = {}; }
  const mediaReduced = root.matchMedia?.('(prefers-reduced-motion: reduce)').matches || false;
  const reduced = () => mediaReduced || preferences.reducedMotion === true;
  const save = () => store.set(prefKey, JSON.stringify(preferences));
  const state = { uid: null, buildings: [], previous: new Map(), previousLevel: null, unreadUnsub: null,
    authUnsub: null, lastPositionUpdate: 0, settingsReturn: null, emoteReturn: null };

  function count(id, value) {
    const target = el(id), next = String(value);
    if (target.textContent === next) return;
    target.textContent = next;
    if (state.previous.has(id) && !reduced()) {
      target.classList.remove('is-changing');
      void target.offsetWidth;
      target.classList.add('is-changing');
    }
    state.previous.set(id, next);
  }

  function renderQuests(tasks) {
    const preview = core.quests(tasks, root.NudgeDailyNextAction?.resolve);
    el('townQuestNext').textContent = preview.next;
    const list = el('townQuestList');
    list.replaceChildren();
    for (const title of preview.pending) {
      const li = doc.createElement('li'), button = doc.createElement('button');
      button.type = 'button'; button.textContent = title;
      button.addEventListener('click', () => openScene('board'));
      li.appendChild(button); list.appendChild(li);
    }
  }

  function updateUser(user, data, confirmed) {
    const uid = user?.uid || null;
    if (state.uid !== uid) {
      state.uid = uid;
      state.previous.clear();
      state.previousLevel = null;
      count('townCoins', '—'); count('townStreak', '—');
      el('townXpRing').style.setProperty('--xp-progress', '0%');
      renderQuests([]);
    }
    if (!uid) { el('townQuestStatus').textContent = '登入後讀取雲端清單'; return; }
    if (!confirmed || !data) {
      el('townQuestStatus').textContent = '等待雲端確認';
      return;
    }
    const level = Number(data.avatarLevel), exp = Number(data.avatarExperience);
    const xp = core.progress(level, exp);
    if (xp && state.previousLevel != null && level > state.previousLevel)
      doc.dispatchEvent(new CustomEvent('nudge-town-level-up', { detail: { level } }));
    if (xp) state.previousLevel = level;
    el('townXpRing').style.setProperty('--xp-progress', `${Math.round((xp?.fraction || 0) * 100)}%`);
    el('townXpRing').title = xp ? `Lv ${level}・${exp} EXP，距下一級 ${xp.remaining}` : '經驗值尚未同步';
    const coins = data.disciplineCoins;
    count('townCoins', Number.isSafeInteger(coins) && coins >= 0 ? coins : '—');
    el('townQuestStatus').textContent = '雲端已確認的個人委託';
    renderQuests(data.tasks);
  }

  function updateReceipts(receipts, confirmed, capped) {
    if (!state.uid || !confirmed) return;
    const result = core.streak(receipts, new Date(), capped);
    count('townStreak', `${result.count}${result.lowerBound ? '+' : ''}`);
    el('townStreak').title = result.lowerBound
      ? '依最近 90 筆雲端活動確認計算，實際連續日可能更多'
      : '依雲端活動確認計算的連續日';
  }

  function setBuildings(buildings) {
    state.buildings = buildings;
    const map = el('townMiniMapArt');
    for (const building of buildings) {
      const button = doc.createElement('button');
      button.type = 'button'; button.textContent = '•';
      button.title = `走向${building.name}`;
      button.setAttribute('aria-label', `走向${building.name}`);
      button.style.left = `${building.door.x / 1672 * 100}%`;
      button.style.top = `${building.door.y / 941 * 100}%`;
      button.addEventListener('click', () => {
        doc.dispatchEvent(new CustomEvent('nudge-town-travel', { detail: { buildingId: building.id } }));
        toggleMap(false);
      });
      map.appendChild(button);
    }
  }

  function setPlayer(position, now) {
    if (now - state.lastPositionUpdate < 80) return;
    state.lastPositionUpdate = now;
    const dot = el('townMiniPlayer');
    dot.style.left = `${position.x / 1672 * 100}%`;
    dot.style.top = `${position.y / 941 * 100}%`;
  }

  function toggleMap(open = el('townMinimap').hidden) {
    el('townMinimap').hidden = !open;
    el('townMapToggle').setAttribute('aria-expanded', String(open));
    if (open) el('townMiniMapArt').querySelector('button')?.focus({ preventScroll: true });
    else el('townMapToggle').focus({ preventScroll: true });
  }

  function openScene(kind) {
    doc.dispatchEvent(new CustomEvent('nudge-town-open-scene', { detail: { kind } }));
  }

  function openPage(path) {
    if (!root.NudgeTownWindow?.open(path)) root.location.href = path;
  }

  function applyPrefs() {
    el('townReduceMotion').checked = preferences.reducedMotion === true;
    const size = ['1', '1.15', '1.3'].includes(preferences.textSize) ? preferences.textSize : '1';
    el('townTextSize').value = size;
    doc.body.style.setProperty('--town-text-scale', size);
    doc.body.classList.toggle('town-reduced-motion', reduced());
    doc.dispatchEvent(new CustomEvent('nudge-town-preference', { detail: { reducedMotion: reduced() } }));
  }

  function toggleSettings(open = el('townSettings').hidden) {
    if (open) state.settingsReturn = doc.activeElement;
    el('townSettings').hidden = !open;
    el('townSettingsToggle').setAttribute('aria-expanded', String(open));
    if (open) el('townSettingsClose').focus({ preventScroll: true });
    else (state.settingsReturn || el('townSettingsToggle')).focus({ preventScroll: true });
  }

  function toggleEmote(open = el('townEmoteWheel').hidden) {
    if (open) state.emoteReturn = doc.activeElement;
    el('townEmoteWheel').hidden = !open;
    if (open) el('townEmoteWheel').querySelector('button')?.focus({ preventScroll: true });
    else state.emoteReturn?.focus?.({ preventScroll: true });
  }

  function listenUnread() {
    const firebase = root.firebase;
    if (!firebase?.apps?.length || state.authUnsub) return;
    state.authUnsub = firebase.auth().onAuthStateChanged(user => {
      state.unreadUnsub?.(); state.unreadUnsub = null;
      el('townUnread').hidden = true;
      if (!user) return;
      state.unreadUnsub = firebase.firestore().collection('user_notifications')
        .where('recipientUserId', '==', user.uid).orderBy('createdAt', 'desc').limit(100)
        .onSnapshot({ includeMetadataChanges: true }, snap => {
          if (snap.metadata.fromCache || snap.metadata.hasPendingWrites) return;
          const amount = core.unread(snap.docs.map(d => d.data()));
          el('townUnread').textContent = amount >= 100 ? '99+' : String(amount);
          el('townUnread').hidden = amount === 0;
          el('townMail').setAttribute('aria-label', amount ? `小鎮郵箱，${amount} 封未讀` : '小鎮郵箱');
        }, () => { el('townUnread').hidden = true; });
    });
  }

  el('townQuestToggle').addEventListener('click', () => {
    const expanded = el('townQuestToggle').getAttribute('aria-expanded') !== 'true';
    el('townQuestToggle').setAttribute('aria-expanded', String(expanded));
    el('townQuestBody').hidden = !expanded;
  });
  el('townQuestNext').addEventListener('click', () => openScene('board'));
  el('townMail').addEventListener('click', () => openPage('mailbox.html'));
  el('townMapToggle').addEventListener('click', () => toggleMap());
  el('townSettingsToggle').addEventListener('click', () => toggleSettings());
  el('townSettingsClose').addEventListener('click', () => toggleSettings(false));
  el('townReduceMotion').addEventListener('change', event => {
    preferences.reducedMotion = event.target.checked; save(); applyPrefs();
  });
  el('townTextSize').addEventListener('change', event => {
    preferences.textSize = event.target.value; save(); applyPrefs();
  });
  for (const button of doc.querySelectorAll('[data-town-scene]'))
    button.addEventListener('click', () => openScene(button.dataset.townScene));
  for (const button of doc.querySelectorAll('[data-town-page]'))
    button.addEventListener('click', () => openPage(button.dataset.townPage));
  for (const button of doc.querySelectorAll('[data-emote]')) button.addEventListener('click', () => {
    doc.dispatchEvent(new CustomEvent('nudge-town-emote', { detail: { type: button.dataset.emote } }));
    toggleEmote(false);
  });
  doc.addEventListener('keydown', event => {
    if (event.key === 'Escape') {
      if (!el('townEmoteWheel').hidden) { event.preventDefault(); toggleEmote(false); }
      else if (!el('townSettings').hidden) { event.preventDefault(); toggleSettings(false); }
      else if (!el('townMinimap').hidden) { event.preventDefault(); toggleMap(false); }
    }
  }, true);
  root.addEventListener('pagehide', () => { state.unreadUnsub?.(); state.authUnsub?.(); });
  doc.addEventListener('firebase-ready', listenUnread);
  applyPrefs(); listenUnread();
  root.NudgeTownHud = { updateUser, updateReceipts, setBuildings, setPlayer, toggleEmote,
    get reducedMotion() { return reduced(); } };
})(typeof globalThis !== 'undefined' ? globalThis : this);
