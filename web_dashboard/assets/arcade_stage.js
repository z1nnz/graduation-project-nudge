(function (root) {
  'use strict';
  // Arcade stage dressing (J6) for every game, old and new: your companion
  // stands beside the game and cheers on hits (the new games send
  // nudge-arcade-hit / -miss; older ones are read from the score line),
  // hits throw pixel sparks, and the result card plays out line by line with
  // a grade stamp and stars. Park rides open with a short ride-in scene.
  const doc = root.document;
  const A = root.NudgeAvatarLayers;
  const game = doc?.getElementById('arcadeGame');
  if (!doc || !game) return;
  const reduced = () => root.matchMedia('(prefers-reduced-motion: reduce)').matches;
  const make = (tag, cls) => { const n = doc.createElement(tag); n.className = cls; return n; };

  // ---- the buddy beside the game ----
  const buddy = make('span', 'as-buddy');
  buddy.setAttribute('aria-hidden', 'true');
  game.querySelector('.arcade-game-bar')?.append(buddy);
  // The earlier companion (world_life.js's actor); the layered character is
  // only for the dressing room.
  const player = root.NudgeWorldLife?.companionActor(buddy, { size: 96 }) || (A ? A.create(buddy, { look: A.loadLook(), scale: 2, animation: 'idle' }) : null);
  let cheerT = 0;
  function cheer(kind) {
    if (!player) return;
    root.clearTimeout(cheerT);
    player.play(kind === 'miss' ? 'think' : 'happy');
    cheerT = root.setTimeout(() => player.play('idle'), 900);
  }
  function burst(n = 6) {
    if (reduced()) return;
    const stage = doc.getElementById('gameStage');
    const r = stage.getBoundingClientRect();
    for (let i = 0; i < n; i++) {
      const s = make('i', 'as-spark');
      s.style.left = `${r.width * (0.3 + Math.random() * 0.4)}px`;
      s.style.top = `${r.height * (0.25 + Math.random() * 0.4)}px`;
      s.style.setProperty('--as-dx', `${(Math.random() - 0.5) * 80}px`);
      s.style.setProperty('--as-dy', `${-20 - Math.random() * 50}px`);
      stage.append(s);
      s.addEventListener('animationend', () => s.remove(), { once: true });
    }
  }
  root.addEventListener('nudge-arcade-hit', () => { cheer('hit'); burst(); });
  root.addEventListener('nudge-arcade-miss', () => cheer('miss'));
  // Older games: a rising number in the score line is a hit.
  const score = doc.getElementById('gameScore');
  let lastNum = null, lastGame = '';
  if (score) {
    new root.MutationObserver(() => {
      const title = doc.getElementById('gameTitle')?.textContent || '';
      const n = Number((score.textContent.match(/\d+/) || [])[0]);
      if (title !== lastGame) { lastGame = title; lastNum = n; return; }
      if (['螢火蟲燈籠', '星座連線'].includes(title)) return;
      if (Number.isFinite(n) && lastNum != null && n > lastNum && !/步數/.test(score.textContent)) { cheer('hit'); burst(4); }
      lastNum = n;
    }).observe(score, { childList: true, characterData: true, subtree: true });
  }

  // ---- results that play out ----
  const result = doc.getElementById('arcadeResult');
  if (result) {
    new root.MutationObserver(() => {
      if (result.hidden) return;
      const lines = [...result.querySelectorAll('#resultLines li')];
      result.classList.remove('as-reveal');
      void result.offsetWidth;
      if (!reduced()) {
        result.classList.add('as-reveal');
        lines.forEach((li, i) => li.style.setProperty('--as-i', String(i)));
      }
      const grade = doc.getElementById('resultGrade');
      const g = (grade?.textContent || '').trim().slice(-1);
      player?.play(g === 'C' ? 'think' : 'happy');
      const stars = { S: 3, A: 2, B: 1 }[g] ?? (lines.length ? 1 : 0);
      let row = result.querySelector('.as-stars');
      if (!row) { row = make('p', 'as-stars'); grade?.after(row); }
      row.textContent = '★'.repeat(stars) + '☆'.repeat(3 - stars);
      row.setAttribute('aria-label', `${stars} 顆星`);
      root.NudgeSfx?.play('sparkle');
    }).observe(result, { attributes: true, attributeFilter: ['hidden'] });
  }

  // ---- ride-in scenes from the park map ----
  const RIDE = { wheel: 'wheel', stall: 'tent', stage: 'tent', carousel: 'carousel', lantern: 'lantern', telescope: 'wheel' };
  doc.addEventListener('click', e => {
    const b = e.target.closest?.('.room-object');
    const kind = b && RIDE[b.dataset.object];
    if (!kind || b.dataset.wlPass !== '1' || reduced()) return;
    const cut = make('div', `as-ride as-ride--${kind}`);
    cut.setAttribute('aria-hidden', 'true');
    cut.innerHTML = '<i class="as-ride-a"></i><i class="as-ride-b"></i><i class="as-ride-c"></i>';
    doc.body.append(cut);
    root.NudgeSfx?.play('open');
    root.setTimeout(() => cut.remove(), 600);
  }, true);

  root.NudgeArcadeStage = Object.freeze({ cheer, burst });
})(typeof globalThis !== 'undefined' ? globalThis : this);
