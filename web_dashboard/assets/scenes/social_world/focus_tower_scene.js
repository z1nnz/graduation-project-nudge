(function (root, factory) {
  const api = factory(root);
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.NudgeFocusTowerScene = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function (root) {
  'use strict';
  // #200 H7: the study hall as a living scene.
  //  - The synchronised focus round is the big wall clock: its hands follow
  //    the round timer (real Taipei time when no round runs).
  //  - The procrastination monster stands in the hall: while members focus,
  //    stars fly from the desks and hit it; it shakes, and falls with stars
  //    when the shared focus minutes defeat it.
  // Data is only read from what study_hall.js / focus_round.js already render
  // (the round <time> and the monster's <meter>); nothing is written.

  /** Clock hand angles (degrees) for "mm:ss" left in a round, or a wall time. */
  function handAngles({ remaining = null, durationMin = 25, hour = 0, minute = 0, second = 0 } = {}) {
    if (remaining) {
      const [m, s] = remaining.split(':').map(Number);
      const left = (m || 0) * 60 + (s || 0);
      const total = Math.max(1, durationMin * 60);
      return { minute: (1 - left / total) * 360, second: (60 - (s || 0)) % 60 * 6, round: true };
    }
    return { minute: minute * 6 + second * 0.1, hour: (hour % 12) * 30 + minute * 0.5, second: second * 6, round: false };
  }

  /** Monster state from its HP meter: idle, hit (HP dropped) or down. */
  function monsterState(previous, value, max) {
    if (!(max > 0)) return 'idle';
    if (value <= 0) return 'down';
    if (previous != null && value < previous) return 'hit';
    return 'idle';
  }

  const pure = { handAngles, monsterState };
  const doc = root.document;
  if (!doc || doc.body?.dataset.livingRoom !== 'rooms') return Object.freeze(pure);

  const reduced = () => root.matchMedia?.('(prefers-reduced-motion: reduce)').matches;
  const taipei = () => {
    const d = new Date(Date.now() + 8 * 3600000);
    return { hour: d.getUTCHours(), minute: d.getUTCMinutes(), second: d.getUTCSeconds() };
  };

  function start() {
    const room = root.NudgeLivingPage;
    if (!room) return;
    const clockButton = room.object('clock');
    const roundTime = doc.querySelector('[data-focus-round] time');

    // ---- wall clock ----
    const face = doc.createElement('canvas');
    face.className = 'living-clock-hands';
    face.setAttribute('aria-hidden', 'true');
    clockButton?.append(face);
    function drawClock() {
      if (!clockButton) return;
      const size = Math.max(24, Math.round(Math.min(clockButton.clientWidth, clockButton.clientHeight)));
      if (face.width !== size) { face.width = size; face.height = size; }
      const g = face.getContext('2d');
      g.clearRect(0, 0, size, size);
      const running = roundTime && !roundTime.hidden && /\d+:\d{2}/.test(roundTime.textContent);
      const a = handAngles(running ? { remaining: roundTime.textContent.trim() } : taipei());
      const c = size / 2;
      const hand = (deg, len, width, color) => {
        const rad = (deg - 90) * Math.PI / 180;
        g.strokeStyle = color; g.lineWidth = width; g.lineCap = 'square';
        g.beginPath(); g.moveTo(c, c); g.lineTo(c + Math.cos(rad) * len, c + Math.sin(rad) * len); g.stroke();
      };
      if (!a.round) hand(a.hour, size * 0.22, Math.max(2, size / 22), '#3a1d0c');
      hand(a.minute, size * 0.32, Math.max(2, size / 28), a.round ? '#c94f4f' : '#3a1d0c');
      if (!reduced()) hand(a.second, size * 0.36, 1, '#c4710b');
      clockButton.dataset.roundRunning = running ? 'true' : 'false';
    }

    // ---- monster in the hall ----
    const monster = doc.createElement('span');
    monster.className = 'living-monster';
    monster.setAttribute('aria-hidden', 'true');
    const sprite = doc.createElement('img');
    sprite.alt = '';
    const hp = doc.createElement('span');
    hp.className = 'living-monster-hp';
    monster.append(hp, sprite);
    room.frame.append(monster);
    let previous = null, kind = null, attackTimer = null;
    function syncMonster() {
      const source = doc.querySelector('.study-room-corner-monster');
      const meter = source?.querySelector('meter');
      const img = source?.querySelector('img');
      monster.hidden = !meter;
      if (!meter) return;
      kind = (img?.getAttribute('src') || '').match(/study_hall\/(\w+?)_/)?.[1] || 'slime';
      const value = Number(meter.value), max = Number(meter.max);
      const state = monsterState(previous, value, max);
      previous = value;
      sprite.src = `assets/scenes/study_hall/${kind}_${state === 'hit' ? 'hit' : state}.webp`;
      hp.style.setProperty('--hp', `${Math.round((value / Math.max(1, max)) * 100)}%`);
      monster.classList.toggle('is-down', state === 'down');
      if (state === 'hit' && !reduced()) {
        monster.classList.remove('is-hit'); void monster.offsetWidth; monster.classList.add('is-hit');
        room.burst({ kind: 'star', count: 6, from: 'table', to: monster });
      }
      if (state === 'down') room.announce('拖延怪被大家的專注打倒了！');
    }
    // While anyone in the hall is focusing, the desks keep "attacking".
    function attack() {
      const focusing = doc.querySelector('[data-focus-round] time:not([hidden])') ||
        doc.querySelector('.study-hall-avatar[data-animation^="walk"], .study-hall-avatar[data-animation="think"]');
      if (!focusing || monster.hidden || monster.classList.contains('is-down') || reduced() || doc.hidden) return;
      room.burst({ kind: 'star', count: 3, from: 'table', to: monster });
      monster.classList.remove('is-hit'); void monster.offsetWidth; monster.classList.add('is-hit');
    }

    const stage = doc.querySelector('main > section.room-stage-panel') || doc.body;
    new root.MutationObserver(syncMonster).observe(stage, { subtree: true, childList: true, attributes: true, attributeFilter: ['value', 'src'] });
    if (roundTime) new root.MutationObserver(drawClock).observe(roundTime, { childList: true, characterData: true, subtree: true, attributes: true });
    root.setInterval(() => { if (!doc.hidden) drawClock(); }, 1000);
    attackTimer = root.setInterval(attack, 6000);
    root.addEventListener('pagehide', () => root.clearInterval(attackTimer), { once: true });
    syncMonster();
    drawClock();
  }
  // living_page.js mounts on DOMContentLoaded; this listener is added later so it runs after.
  if (doc.readyState === 'loading') doc.addEventListener('DOMContentLoaded', () => root.setTimeout(start, 0), { once: true });
  else root.setTimeout(start, 0);
  return Object.freeze(pure);
});
