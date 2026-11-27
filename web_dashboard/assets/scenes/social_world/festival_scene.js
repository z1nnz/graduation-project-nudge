(function (root) {
  'use strict';
  // #200 H3 on the festival and town-goal pages: festival decorations in the
  // scene, a festival NPC line, a short self-made chiptune (WebAudio, only
  // when the player has turned town sound on) and fireworks in the scene the
  // first time this week's shared town goal is seen as reached.
  const core = root.NudgeFestivalCore;
  const doc = root.document;
  if (!core || !doc) return;
  const key = doc.body?.dataset.livingRoom;
  if (key !== 'seasonal-event' && key !== 'town-goals') return;
  const preview = new URLSearchParams(root.location.search).get('festival');
  const festival = core.festivalAt(new Date(), preview);
  const reduced = () => root.matchMedia?.('(prefers-reduced-motion: reduce)').matches;

  function soundOn() {
    try { return JSON.parse(root.localStorage.getItem('nudge_town_audio_v1') || '{}').ambience === true; } catch { return false; }
  }
  function playMelody(notes) {
    if (!soundOn() || reduced()) return;
    const Ctx = root.AudioContext || root.webkitAudioContext;
    if (!Ctx) return;
    const ctx = new Ctx();
    notes.forEach((semi, i) => {
      const osc = ctx.createOscillator(), gain = ctx.createGain();
      osc.type = 'square';
      osc.frequency.value = 440 * Math.pow(2, (semi - 9) / 12);
      gain.gain.setValueAtTime(0.0001, ctx.currentTime + i * 0.22);
      gain.gain.exponentialRampToValueAtTime(0.05, ctx.currentTime + i * 0.22 + 0.02);
      gain.gain.exponentialRampToValueAtTime(0.0001, ctx.currentTime + i * 0.22 + 0.2);
      osc.connect(gain).connect(ctx.destination);
      osc.start(ctx.currentTime + i * 0.22);
      osc.stop(ctx.currentTime + i * 0.22 + 0.21);
    });
  }

  function decorate(room) {
    doc.body.dataset.festival = festival ? festival.key : 'none';
    if (!festival) return;
    for (const [i, name] of festival.decor.entries()) {
      for (let k = 0; k < 2; k++) {
        const img = doc.createElement('img');
        img.className = `living-festival living-festival--${name} living-festival--${k}`;
        img.src = `assets/scenes/social_world/festival/${name}.png`;
        img.alt = '';
        img.setAttribute('aria-hidden', 'true');
        room.frame.append(img);
      }
      if (i === 0) room.announce(`${festival.name}期間，小鎮換上了節慶裝飾。`);
    }
    const npcButton = room.npcButton;
    npcButton?.addEventListener('click', () => root.setTimeout(() => room.say(festival.lines), 50), { once: true });
  }

  function watchGoal(room) {
    const progress = doc.getElementById('townProgress');
    if (!progress) return;
    const week = core.weekKey(new Date());
    const check = () => {
      if (!(progress.max > 0) || progress.value < progress.max) return;
      core.markGoalReached(root.localStorage, week);
      // Fireworks here once; the town shows its own once too on the next visit.
      if (doc.body.dataset.fireworksShown) return;
      doc.body.dataset.fireworksShown = '1';
      room.announce('全鎮目標達成！小鎮放起了煙火。');
      if (reduced()) return;
      for (let i = 0; i < 4; i++) root.setTimeout(() => room.burst({ kind: 'star', count: 12, from: 'fountain' }), i * 450);
    };
    new root.MutationObserver(check).observe(progress, { attributes: true });
    check();
  }

  function start() {
    const room = root.NudgeLivingPage;
    if (!room) return;
    decorate(room);
    if (festival) doc.addEventListener('pointerdown', () => playMelody(festival.melody), { once: true });
    watchGoal(room);
  }
  if (doc.readyState === 'loading') doc.addEventListener('DOMContentLoaded', () => root.setTimeout(start, 0), { once: true });
  else root.setTimeout(start, 0);
})(typeof globalThis !== 'undefined' ? globalThis : this);
