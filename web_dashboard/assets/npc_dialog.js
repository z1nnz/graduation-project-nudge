(function (root, factory) {
  const api = factory(root);
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.NudgeNpcDialog = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function (root) {
  'use strict';
  // Pixel speech box with a portrait, a typewriter and click-to-continue.
  //
  //   NudgeNpcDialog.open({
  //     speaker: 'chestnut',                 // catalog id, or { name, portrait }
  //     lines: ['歡迎光臨！', '貨架上的東西都可以拿起來看看。'],
  //     actions: [{ label: '去委託所', onSelect: () => go('board') }],  // after the last line
  //     onClose: () => {},
  //   });
  //
  // Click, Enter or Space: finish the line, then the next line, then close.
  // Esc closes. Reduced motion shows each line at once. Needs sprite_player.js
  // for catalog portraits and world_ui.css for the look.

  const CHARS_PER_SECOND = 40;
  let current = null;

  /** Characters shown after [elapsedMs] of typing [text]. */
  function typedLength(text, elapsedMs, cps = CHARS_PER_SECOND) {
    const total = Array.from(text).length;
    if (!(elapsedMs > 0)) return 0;
    return Math.min(total, Math.floor((elapsedMs * cps) / 1000));
  }

  function open(options) {
    const env = options.env || root;
    const doc = env.document;
    const lines = (options.lines || []).map(String).filter(Boolean);
    if (!lines.length) throw new Error('npc dialog needs at least one line');
    current?.close();

    const players = env.NudgeSpritePlayer;
    const speakerInfo = typeof options.speaker === 'string'
      ? players.character(options.speaker)
      : { name: '', ...(options.speaker || {}) };
    const raf = env.requestAnimationFrame ? env.requestAnimationFrame.bind(env) : (cb => env.setTimeout(cb, 16));
    const caf = env.cancelAnimationFrame ? env.cancelAnimationFrame.bind(env) : (id => env.clearTimeout(id));
    const now = () => (env.performance?.now ? env.performance.now() : Date.now());
    const reduced = () => {
      try { return Boolean(env.matchMedia?.('(prefers-reduced-motion: reduce)').matches); } catch { return false; }
    };
    const make = (tag, cls, text) => {
      const n = doc.createElement(tag);
      if (cls) n.className = cls;
      if (text != null) n.textContent = text;
      return n;
    };

    const nameId = `w-npc-name-${Math.random().toString(36).slice(2, 8)}`;
    const box = make('div', 'w-npc-dialog');
    box.setAttribute('role', 'dialog');
    box.setAttribute('aria-labelledby', nameId);
    box.tabIndex = 0;
    const portrait = make('div', 'w-npc-dialog__portrait');
    const body = make('div', 'w-npc-dialog__body');
    const name = make('p', 'w-npc-dialog__name', speakerInfo.name);
    name.id = nameId;
    const typed = make('p', 'w-npc-dialog__text');
    typed.setAttribute('aria-hidden', 'true');
    // Screen readers get each whole line once instead of every typed letter.
    const spoken = make('p', 'w-npc-dialog__sr');
    spoken.setAttribute('aria-live', 'polite');
    const more = make('span', 'w-npc-dialog__more', '▼');
    more.setAttribute('aria-hidden', 'true');
    const actions = make('div', 'w-npc-dialog__actions');
    actions.hidden = true;
    const close = make('button', 'w-npc-dialog__close', '×');
    close.type = 'button';
    close.setAttribute('aria-label', '關閉對話');
    body.append(name, typed, spoken, more, actions);
    box.append(portrait, body, close);

    let sprite = null;
    if (typeof options.speaker === 'string') {
      sprite = players.characterPlayer(portrait, options.speaker, {
        animation: 'talk', size: options.portraitSize || 96, basePath: options.basePath, env,
      });
    } else if (speakerInfo.portrait) {
      const img = make('img');
      img.src = speakerInfo.portrait;
      img.alt = '';
      portrait.appendChild(img);
    }

    const host = options.host || doc.body;
    const returnFocus = doc.activeElement;
    host.appendChild(box);

    const state = { index: 0, shown: 0, start: 0, handle: null, closed: false };
    const chars = () => Array.from(lines[state.index]);
    const typing = () => state.shown < chars().length;

    function render() {
      typed.textContent = chars().slice(0, state.shown).join('');
      const done = !typing();
      const last = state.index === lines.length - 1;
      more.hidden = !done || last;
      actions.hidden = !(done && last) || !actions.children.length;
      box.dataset.line = String(state.index);
      box.dataset.typing = done ? 'false' : 'true';
      if (done && sprite && sprite.character.animations.talk) sprite.play('idle');
    }
    function tick() {
      state.handle = null;
      state.shown = typedLength(lines[state.index], now() - state.start);
      render();
      if (typing()) state.handle = raf(tick);
    }
    function showLine(i) {
      if (state.handle != null) caf(state.handle);
      state.handle = null;
      state.index = i;
      spoken.textContent = lines[i];
      if (sprite && sprite.character.animations.talk) sprite.play('talk');
      if (reduced()) {
        state.shown = chars().length;
        render();
        return;
      }
      state.shown = 0;
      state.start = now();
      render();
      state.handle = raf(tick);
    }

    for (const a of options.actions || []) {
      const b = make('button', 'w-btn is-gold', a.label);
      b.type = 'button';
      b.addEventListener('click', e => {
        e.stopPropagation();
        controller.close();
        a.onSelect?.();
      });
      actions.appendChild(b);
    }

    const controller = {
      el: box,
      get line() { return state.index; },
      get typing() { return typing(); },
      /** Finish the line being typed, else go on to the next one, else close. */
      next() {
        if (state.closed) return;
        if (typing()) {
          if (state.handle != null) caf(state.handle);
          state.handle = null;
          state.shown = chars().length;
          render();
        } else if (state.index < lines.length - 1) {
          showLine(state.index + 1);
        } else if (!actions.children.length) {
          controller.close();
        }
      },
      close() {
        if (state.closed) return;
        state.closed = true;
        if (state.handle != null) caf(state.handle);
        sprite?.destroy();
        box.remove?.();
        if (current === controller) current = null;
        if (returnFocus && returnFocus.focus && returnFocus !== doc.body) returnFocus.focus();
        options.onClose?.();
      },
    };

    box.addEventListener('click', () => controller.next());
    box.addEventListener('keydown', e => {
      if (e.key === 'Escape') { e.preventDefault(); controller.close(); }
      else if ((e.key === 'Enter' || e.key === ' ') && e.target === box) { e.preventDefault(); controller.next(); }
    });
    close.addEventListener('click', e => { e.stopPropagation(); controller.close(); });

    current = controller;
    showLine(0);
    box.focus?.();
    return controller;
  }

  return { CHARS_PER_SECOND, typedLength, open };
});
