(function (root) {
  'use strict';
  // The town window: facility pages open in a wooden window on top of the
  // town, so the player never leaves the world. Rules live in
  // town_window_core.js; pages inside the window close it through
  // town_return.js.
  const core = root.NudgeTownWindowCore;
  const routes = root.NudgeTownRoutes;
  const doc = root.document;
  if (!core || !doc || doc.body?.dataset.page !== 'town') return;

  const el = id => doc.getElementById(id);
  const box = el('townWindow');
  const frame = el('townWindowFrame');
  const title = el('townWindowTitle');
  if (!box || !frame || !title) return;

  let openPath = null;
  let pushed = false;
  let returnFocus = null;

  function labelFor(path) {
    const name = path.split('?')[0];
    const dest = routes?.DESTINATIONS?.find(d => d.href.split('#')[0].split('?')[0] === name);
    return dest ? dest.title : '';
  }

  function announce(open) {
    doc.dispatchEvent(new CustomEvent('nudge-town-scene', { detail: { open } }));
  }

  function open(path, { label = '', push = true } = {}) {
    if (!path) return false;
    if (!openPath) returnFocus = doc.activeElement;
    openPath = path;
    title.textContent = label || labelFor(path) || '';
    frame.src = core.embedUrl(path);
    box.hidden = false;
    doc.body.classList.add('town-window-open');
    if (push && root.history && root.location.hash !== core.hashFor(path)) {
      root.history.pushState({ townWindow: path }, '', core.hashFor(path));
      pushed = true;
    }
    announce(true);
    el('townWindowClose').focus({ preventScroll: true });
    return true;
  }

  function close({ fromHistory = false } = {}) {
    if (!openPath) return;
    openPath = null;
    box.hidden = true;
    doc.body.classList.remove('town-window-open');
    frame.src = 'about:blank';
    if (fromHistory) {
      pushed = false;
    } else if (pushed) {
      pushed = false;
      root.history.back();
    } else if (root.history) {
      root.history.replaceState(null, '', root.location.pathname + root.location.search);
    }
    announce(false);
    const back = returnFocus;
    returnFocus = null;
    if (back && doc.contains(back) && typeof back.focus === 'function') back.focus({ preventScroll: true });
  }

  // Page title once loaded, when the route table had no name for it.
  frame.addEventListener('load', () => {
    if (title.textContent) return;
    try {
      title.textContent = (frame.contentDocument?.title || '').replace(/^Nudge\s*/, '');
    } catch (_) { /* not readable: keep it empty */ }
  });

  el('townWindowClose').addEventListener('click', () => close());

  // Links to player pages open in the window; tools and new tabs stay normal.
  doc.addEventListener('click', event => {
    if (event.defaultPrevented || event.button !== 0) return;
    if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
    const link = event.target?.closest?.('a[href]');
    if (!link || link.target === '_blank' || link.hasAttribute('download')) return;
    if (link.closest('#townToolList')) return;
    const path = core.windowPath(link.getAttribute('href'), root.location.href);
    if (!path) return;
    event.preventDefault();
    const panel = el('townPanel');
    if (panel && !panel.hidden) el('townPanelClose')?.click();
    const label = link.querySelector('strong')?.textContent || '';
    open(path, { label });
  });

  // Esc closes the window before the town sees the key.
  doc.addEventListener('keydown', event => {
    if (openPath && event.key === 'Escape') {
      event.preventDefault();
      event.stopPropagation();
      close();
    }
  }, true);

  // Pages inside the window ask to close it ("回小鎮").
  root.addEventListener('message', event => {
    if (event.origin !== root.location.origin) return;
    if (event.source !== frame.contentWindow) return;
    if (event.data?.type === 'nudge-town-window-close') close();
  });

  root.addEventListener('popstate', () => {
    const path = core.pathFromHash(root.location.hash);
    if (path) open(path, { push: false });
    else close({ fromHistory: true });
  });

  root.NudgeTownWindow = Object.freeze({ open: path => open(path), close: () => close() });

  // A shared or refreshed link (town.html#open=rooms.html) opens straight away.
  const initial = core.pathFromHash(root.location.hash);
  if (initial) open(initial, { push: false });
})(typeof globalThis !== 'undefined' ? globalThis : this);
