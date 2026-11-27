(function (root) {
  'use strict';
  // Commission hall 2.0 (J9). On quests.html: every running commission is a
  // note pinned to the board (stamps fill it like a water line); tapping one
  // tears it off and opens it; a finished one gets a red stamp and flies into
  // the envelope on the desk. The adventure map is a little path: one flag
  // per stamp, and your character stands on the next step. On the home page
  // (dashboard.html) the notice clerk Scroll hands you today's step as a
  // slip of paper. Everything is read from the page's own Cloud-backed DOM.
  const doc = root.document;
  const room = root.NudgePageRoom;
  if (!doc || !room || !root.NudgeWorldLife) return;
  const key = doc.body.dataset.roomKey || doc.body.dataset.page;
  const reduced = () => root.matchMedia('(prefers-reduced-motion: reduce)').matches;
  const make = (tag, cls, text) => { const n = doc.createElement(tag); if (cls) n.className = cls; if (text != null) n.textContent = text; return n; };
  const place = (n, r) => Object.assign(n.style, { left: r[0] * 100 + '%', top: r[1] * 100 + '%', width: r[2] * 100 + '%', height: r[3] * 100 + '%' });

  if (key === 'quests') quests();
  if (key === 'home') today();

  function quests() {
    const R = {
      wide: { board: [0.21, 0.18, 0.47, 0.4], map: [0.73, 0.25, 0.18, 0.3], desk: [0.63, 0.6, 0.3, 0.24], clock: [0.08, 0.02, 0.1, 0.16], request: [0.01, 0.25, 0.17, 0.46] },
      tall: { board: [0.12, 0.17, 0.63, 0.36], map: [0.76, 0.29, 0.22, 0.22], desk: [0.52, 0.63, 0.44, 0.2], clock: [0.0, 0.0, 0.16, 0.12], request: [0.0, 0.2, 0.11, 0.4] },
    };
    const L = () => R[room.layout()] || R.tall;
    const life = root.NudgeWorldLife.attach(room, {
      layouts: {
        wide: { rects: R.wide, floor: [0.72, 0.95], start: [0.45, 0.9], skyRect: [0.25, 0.03, 0.14, 0.09], near: { fall: 'dust', count: 16, plants: [{ x: 0.99, size: 0.16, kind: 'fern' }] } },
        tall: { rects: R.tall, floor: [0.7, 0.95], start: [0.45, 0.9], skyRect: [0.27, 0.035, 0.17, 0.065], near: { fall: 'dust', count: 12 } },
      },
      acts: {
        board: { face: 'up', anim: 'think', fx: 'shake', sfx: 'page', wait: 520, onArrive: () => tear() },
        map: { face: 'up', anim: 'look', fx: 'pop', sfx: 'page' },
        desk: { face: 'up', anim: 'read', fx: 'pull', sfx: 'open', onArrive: () => mail() },
        clock: { face: 'up', anim: 'look', fx: 'pop', sfx: 'tap' },
        request: { face: 'left', anim: 'wave', fx: 'pop', sfx: 'tap' },
      },
    });

    const notes = make('div', 'qbl-notes');
    notes.setAttribute('aria-hidden', 'true');
    const path = make('div', 'qbl-path');
    path.setAttribute('aria-hidden', 'true');
    const envelope = make('span', 'qbl-envelope');
    envelope.setAttribute('aria-hidden', 'true');
    room.frame.append(notes, path, envelope);
    let walker = null;

    function chains() {
      return [...doc.querySelectorAll('#qbChains .qb-chain')].map(c => {
        const slots = c.querySelectorAll('.qb-slot');
        return {
          title: c.querySelector('h3')?.textContent || '委託',
          status: c.dataset.status,
          stamps: c.querySelectorAll('.qb-slot.is-stamped').length,
          target: slots.length,
          fresh: c.querySelectorAll('.qb-slot.is-new').length,
        };
      });
    }
    function render() {
      const list = chains();
      const b = L().board;
      place(notes, [b[0] + b[2] * 0.06, b[1] + b[3] * 0.12, b[2] * 0.88, b[3] * 0.78]);
      notes.textContent = '';
      list.slice(0, 6).forEach((c, i) => {
        const n = make('span', `qbl-note${c.status === 'completed' ? ' is-done' : ''}${c.fresh ? ' is-fresh' : ''}`);
        n.style.setProperty('--qbl-tilt', `${((i * 37) % 7) - 3}deg`);
        n.style.setProperty('--qbl-fill', String(c.target ? c.stamps / c.target : 0));
        n.append(make('i', 'qbl-pin'), make('b', 'qbl-title', c.title), make('small', 'qbl-count', `${c.stamps}/${c.target}`), make('i', 'qbl-water'));
        if (c.status === 'completed') n.append(make('i', 'qbl-stamp', '完成'));
        notes.append(n);
      });
      if (!list.length) notes.append(make('span', 'qbl-note is-empty', '空位：去地圖接一條委託'));
      // the adventure path: first running chain
      const run = list.find(c => c.status !== 'completed') || list[0];
      const m = L().map;
      place(path, [m[0] + m[2] * 0.08, m[1] + m[3] * 0.18, m[2] * 0.84, m[3] * 0.66]);
      path.textContent = '';
      const n = Math.max(3, Math.min(10, run?.target || 5));
      for (let i = 0; i < n; i++) {
        const x = 6 + (88 * i) / (n - 1), y = 50 + Math.sin(i * 1.3) * 28;
        const node = make('i', `qbl-step${run && i < run.stamps ? ' is-flag' : ''}`);
        Object.assign(node.style, { left: `${x}%`, top: `${y}%` });
        path.append(node);
      }
      const at = Math.min(n - 1, run?.stamps || 0);
      const holder = make('span', 'qbl-hiker');
      Object.assign(holder.style, { left: `${6 + (88 * at) / (n - 1)}%`, top: `${50 + Math.sin(at * 1.3) * 28}%` });
      path.append(holder);
      walker?.destroy?.();
      walker = root.NudgeWorldLife?.companionActor(holder, { size: 56, animation: run && run.stamps ? 'happy' : 'idle' }) || null;
      place(envelope, [L().desk[0] + L().desk[2] * 0.62, L().desk[1] + L().desk[3] * 0.05, L().desk[2] * 0.18, L().desk[3] * 0.3]);
    }
    // Tearing a note off before the board opens.
    function tear() {
      const first = notes.querySelector('.qbl-note:not(.is-empty)');
      if (!first || reduced()) return;
      first.classList.add('is-torn');
      root.setTimeout(() => first.classList.remove('is-torn'), 900);
    }
    // Finished commissions get stamped and fly into the envelope.
    function mail() {
      const done = [...notes.querySelectorAll('.qbl-note.is-done')];
      if (!done.length || reduced()) return;
      const e = envelope.getBoundingClientRect();
      for (const n of done) {
        const r = n.getBoundingClientRect();
        const fly = n.cloneNode(true);
        fly.classList.add('qbl-fly');
        Object.assign(fly.style, { position: 'fixed', left: `${r.left}px`, top: `${r.top}px`, width: `${r.width}px`, height: `${r.height}px` });
        fly.style.setProperty('--qbl-dx', `${e.left + e.width / 2 - r.left - r.width / 2}px`);
        fly.style.setProperty('--qbl-dy', `${e.top + e.height / 2 - r.top - r.height / 2}px`);
        doc.body.append(fly);
        fly.addEventListener('animationend', () => fly.remove(), { once: true });
      }
      envelope.classList.remove('is-full');
      void envelope.offsetWidth;
      envelope.classList.add('is-full');
    }
    new root.MutationObserver(() => root.setTimeout(render, 30)).observe(doc.getElementById('qbChains'), { childList: true, subtree: true, attributes: true, attributeFilter: ['class', 'data-status'] });
    root.addEventListener('resize', () => root.setTimeout(render, 150));
    render();
    root.NudgeQuestBoardLife = Object.freeze({ render, tear, mail, life });
  }

  function today() {
    const life = root.NudgeWorldLife.attach(room, {
      layouts: {
        wide: { rects: { chalkboard: [0.4, 0.1, 0.28, 0.24], book: [0.32, 0.5, 0.26, 0.16] }, floor: [0.7, 0.95], start: [0.5, 0.9], skyRect: [0.1, 0.08, 0.16, 0.44], near: { fall: 'dust', count: 14, plants: [{ x: 0.99, size: 0.18, kind: 'fern' }] } },
        tall: { rects: { chalkboard: [0.5, 0.1, 0.35, 0.22], book: [0.27, 0.38, 0.41, 0.2] }, floor: [0.64, 0.94], start: [0.55, 0.88], skyRect: [0.08, 0.05, 0.34, 0.29], near: { fall: 'dust', count: 10 } },
      },
      acts: { chalkboard: { face: 'up', anim: 'think', fx: 'pop', sfx: 'tap' }, book: { face: 'up', anim: 'read', fx: 'lift', sfx: 'page' } },
    });
    // Scroll walks the slip over: today's step written on paper.
    const slip = make('button', 'qbl-slip w-parchment');
    slip.type = 'button';
    const title = make('b', 'qbl-slip-title');
    const detail = make('small', 'qbl-slip-detail');
    slip.append(make('i', 'qbl-pin'), title, detail);
    room.stage.append(slip);
    function fill() {
      title.textContent = doc.getElementById('dailyActionTitle')?.textContent?.trim() || '今天從一件小事開始吧。';
      detail.textContent = doc.getElementById('dailyActionDetail')?.textContent?.trim() || '';
      slip.setAttribute('aria-label', `阿紙遞給你的紙條：${title.textContent}`);
    }
    fill();
    new root.MutationObserver(fill).observe(doc.getElementById('dailyActionTitle') || doc.body, { childList: true, characterData: true, subtree: true });
    root.setTimeout(() => { slip.classList.add('is-given'); life.npcAct('wave'); life.emote(room.npcButton, 'note'); }, reduced() ? 0 : 700);
    slip.addEventListener('click', () => {
      life.player()?.play('happy');
      const link = doc.getElementById('dailyActionLink');
      if (link?.href) root.setTimeout(() => { root.location.href = link.href; }, reduced() ? 0 : 400);
    });
    root.NudgeTodaySlip = slip;
  }
})(typeof globalThis !== 'undefined' ? globalThis : this);
