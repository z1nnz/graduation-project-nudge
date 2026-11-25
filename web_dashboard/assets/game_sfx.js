(function (root, factory) {
  const api = factory(root);
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.NudgeSfx = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function (root) {
  'use strict';
  // Small 8-bit sound effects for the game rooms. Quiet by default, one
  // mute switch remembered on this device, never played before a tap.
  const KEY = 'nudge_sfx_muted';
  const NAMES = ['tap', 'coin', 'sparkle', 'page', 'open', 'heart'];
  const VOLUME = 0.35;
  const cache = new Map();

  function muted() {
    try { return root.localStorage?.getItem(KEY) === '1'; } catch { return false; }
  }
  function setMuted(value) {
    try { root.localStorage?.setItem(KEY, value ? '1' : '0'); } catch { /* private mode */ }
    root.document?.querySelectorAll?.('[data-sfx-toggle]').forEach(paintToggle);
  }
  function play(name) {
    if (!NAMES.includes(name) || muted() || typeof root.Audio !== 'function') return false;
    let base = cache.get(name);
    if (!base) {
      base = new root.Audio(`assets/sfx/${name}.wav`);
      base.preload = 'auto';
      cache.set(name, base);
    }
    try {
      const sound = base.cloneNode();
      sound.volume = VOLUME;
      sound.play()?.catch?.(() => {});
    } catch { return false; }
    return true;
  }
  function paintToggle(button) {
    const off = muted();
    button.textContent = off ? '♪ 關' : '♪ 開';
    button.setAttribute('aria-pressed', String(!off));
    button.setAttribute('aria-label', off ? '音效已關閉，點一下開啟' : '音效已開啟，點一下關閉');
  }
  /** Adds a small sound switch to the page HUD (once). */
  function mountToggle(doc = root.document) {
    const hud = doc?.querySelector?.('.w-hud, .scene-topbar, .gate-top');
    if (!hud || hud.querySelector('[data-sfx-toggle]')) return null;
    const button = doc.createElement('button');
    button.type = 'button';
    button.className = 'w-btn sfx-toggle';
    button.dataset.sfxToggle = '';
    paintToggle(button);
    button.addEventListener('click', () => { setMuted(!muted()); if (!muted()) play('tap'); });
    hud.append(button);
    return button;
  }
  return Object.freeze({ NAMES, play, muted, setMuted, mountToggle });
});
