(function (root, factory) {
  const api = factory(root);
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.NudgePets = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function (root) {
  'use strict';
  // Pets (J3): three species, three growth stages, sheets in
  // assets/characters/pets/. Growth only reads Cloud-confirmed focus minutes
  // that already exist; the chosen pet is kept on this device. Treats and
  // pats are just animation: no number changes anywhere.
  //
  //   NudgePets.player(el, { species: 'fox', stage: 'teen', scale: 3 })
  //   NudgePets.follow(container, () => playerAt, { reduced })   // tags along
  const BASE = 'assets/characters/pets/';
  const CHOICE_KEY = 'nudge.pet.v1';
  const STAGE_KEY = 'nudge.pet.stage.v1';

  // Mirrors assets/characters/pets/pets.json (test/pets_test.js keeps them equal).
  const MANIFEST = Object.freeze({
    frameWidth: 32, frameHeight: 32, columns: 8, pivot: [16, 29],
    animations: [
      { name: 'idle', frames: 8, fps: 8, loop: true },
      { name: 'walk_down', frames: 6, fps: 10, loop: true },
      { name: 'walk_left', frames: 6, fps: 10, loop: true },
      { name: 'walk_right', frames: 6, fps: 10, loop: true },
      { name: 'walk_up', frames: 6, fps: 10, loop: true },
      { name: 'happy', frames: 6, fps: 10, loop: false },
      { name: 'sleep', frames: 8, fps: 8, loop: true },
      { name: 'cuddle', frames: 8, fps: 8, loop: true },
    ],
    species: [
      { id: 'owl', name: '小貓頭鷹', stages: ['毛球雛鳥', '見習夜梟', '星夜貓頭鷹'] },
      { id: 'fox', name: '小狐狸', stages: ['小奶狐', '蓬尾狐', '晚霞狐'] },
      { id: 'slime', name: '小史萊姆', stages: ['小水滴', '發芽史萊姆', '王冠史萊姆'] },
    ],
    stageNames: ['baby', 'teen', 'adult'],
    growth: { unit: 'focusMinutes', teen: 300, adult: 1500 },
  });
  const ROWS = Object.fromEntries(MANIFEST.animations.map((a, row) => [a.name, { ...a, row }]));

  /** Growth stage for a total of Cloud-confirmed focus minutes. */
  function stageFor(minutes) {
    const m = Number(minutes);
    if (!(m >= MANIFEST.growth.teen)) return 'baby';
    return m >= MANIFEST.growth.adult ? 'adult' : 'teen';
  }

  /** Minutes still needed for the next stage, or 0 when fully grown. */
  function toNext(minutes) {
    const m = Math.max(0, Number(minutes) || 0);
    if (m < MANIFEST.growth.teen) return MANIFEST.growth.teen - m;
    if (m < MANIFEST.growth.adult) return MANIFEST.growth.adult - m;
    return 0;
  }

  function speciesInfo(id) {
    return MANIFEST.species.find(s => s.id === id) || null;
  }

  function stageName(species, stage) {
    const s = speciesInfo(species);
    return s ? s.stages[Math.max(0, MANIFEST.stageNames.indexOf(stage))] : '';
  }

  function sheet(species, stage, basePath = '') {
    return `${basePath}${BASE}${species}_${MANIFEST.stageNames.includes(stage) ? stage : 'baby'}.webp`;
  }

  function loadChoice(storage = root.localStorage) {
    try {
      const v = JSON.parse(storage?.getItem(CHOICE_KEY) || 'null');
      return v && speciesInfo(v.species) ? { species: v.species } : null;
    } catch { return null; }
  }
  function saveChoice(species, storage = root.localStorage) {
    if (!speciesInfo(species)) return null;
    try { storage?.setItem(CHOICE_KEY, JSON.stringify({ species })); } catch { /* private mode */ }
    return { species };
  }
  /** Last stage worked out from the Cloud, so the pet shows before the read finishes. */
  function cachedStage(storage = root.localStorage) {
    try { const s = storage?.getItem(STAGE_KEY); return MANIFEST.stageNames.includes(s) ? s : 'baby'; } catch { return 'baby'; }
  }
  function cacheStage(stage, storage = root.localStorage) {
    try { storage?.setItem(STAGE_KEY, stage); } catch { /* private mode */ }
  }

  /** Focus minutes from activity session documents that the Cloud completed. */
  function focusMinutes(docs, uid) {
    let total = 0;
    for (const d of docs || []) {
      if (!d || d.actorUserId !== uid || d.status !== 'completed') continue;
      if (d.activityType !== 'focus' && d.activityType !== 'study') continue;
      if (d.metricUnit !== 'minutes') continue;
      const v = d.metricValue;
      if (typeof v !== 'number' || !Number.isFinite(v) || v < 0 || v > 1440) continue;
      total += v;
    }
    return Math.round(total);
  }

  /** Read-only: the same completed-session query the garden uses. */
  async function loadFocusMinutes(firestore, uid) {
    const result = await firestore.collection('activity_sessions')
      .where('actorUserId', '==', uid)
      .where('status', '==', 'completed')
      .orderBy('endedAt', 'desc')
      .limit(500)
      .get({ source: 'server' });
    if (result.metadata?.fromCache) throw new Error('cache');
    return focusMinutes(result.docs.map(d => d.data()), uid);
  }

  /** A pet sprite; play(name) switches animation, unknown names idle. */
  function player(el, options = {}) {
    const P = root.NudgeSpritePlayer;
    const scale = Math.max(1, Math.round(options.scale || 2));
    const first = ROWS[options.animation] || ROWS.idle;
    const p = P.create(el, {
      src: sheet(options.species || 'owl', options.stage, options.basePath), frameWidth: 32, frameHeight: 32,
      columns: MANIFEST.columns, rows: MANIFEST.animations.length, row: first.row, frames: first.frames,
      fps: first.fps, loop: first.loop, size: 32 * scale, env: options.env, onEnd: options.onEnd,
    });
    el.dataset && Object.assign(el.dataset, { pet: options.species || 'owl', stage: options.stage || 'baby', animation: first.name });
    return Object.assign(Object.create(p), {
      play(name, more = {}) {
        const a = ROWS[name] || ROWS.idle;
        if (el.dataset) el.dataset.animation = a.name;
        p.play({ row: a.row, frames: a.frames, fps: a.fps, loop: a.loop, onEnd: more.onEnd });
      },
      stop: p.stop, destroy: p.destroy,
    });
  }

  /**
   * The chosen pet trails the player inside [container] (art-fraction
   * positions) and wanders off to sniff now and then. Returns null when no
   * pet is chosen.
   */
  function follow(container, playerAt, opts = {}) {
    const choice = opts.choice || loadChoice();
    if (!choice) return null;
    const doc = container.ownerDocument;
    const node = doc.createElement('span');
    node.className = 'pet-follower';
    container.append(node);
    const stage = opts.stage || cachedStage();
    const pet = player(node, { species: choice.species, stage, scale: opts.scale || 2 });
    let at = playerAt().slice();
    at[0] += 0.06;
    let anim = 'idle', wander = null, lastT = 0;
    const place = () => {
      node.style.left = at[0] * 100 + '%';
      node.style.top = at[1] * 100 + '%';
      node.style.zIndex = String(Math.round(at[1] * 100));
    };
    place();
    function setAnim(a) { if (a !== anim) { anim = a; pet.play(a); } }
    function update(target = playerAt(), now = 0) {
      const dt = lastT ? Math.min(100, now - lastT) : 16;
      lastT = now;
      if (opts.reduced?.()) { at = [target[0] + 0.06, target[1]]; place(); return; }
      if (!wander && Math.random() < 0.002) {
        wander = { to: [Math.min(0.94, Math.max(0.06, target[0] + (Math.random() - 0.5) * 0.4)), Math.min(0.95, target[1] + 0.03)], until: now + 2600 };
      }
      const goal = wander ? wander.to : [target[0] + (target[0] > at[0] ? -0.07 : 0.07), target[1] + 0.01];
      const dx = goal[0] - at[0], dy = goal[1] - at[1];
      const d = Math.hypot(dx, dy);
      if (d > 0.012) {
        const step = Math.min(d, (dt / 1000) * (wander ? 0.18 : 0.3));
        at = [at[0] + (dx / d) * step, at[1] + (dy / d) * step];
        setAnim(Math.abs(dx) > Math.abs(dy) ? (dx > 0 ? 'walk_right' : 'walk_left') : (dy > 0 ? 'walk_down' : 'walk_up'));
      } else if (wander) {
        setAnim('happy');
        if (now > wander.until) wander = null;
      } else setAnim('idle');
      place();
    }
    return { node, pet, update, destroy() { pet.destroy(); node.remove(); } };
  }

  return { BASE, CHOICE_KEY, STAGE_KEY, MANIFEST, ROWS, stageFor, toNext, speciesInfo, stageName, sheet, loadChoice, saveChoice, cachedStage, cacheStage, focusMinutes, loadFocusMinutes, player, follow };
});
