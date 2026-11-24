(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.NudgeTownWindowCore = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';
  // Rules for the town window: facility pages open in a wooden window on top
  // of the town instead of replacing it, so the player never leaves the
  // world. Pure functions only; town_window.js does the DOM work.

  // Pages that must stay full pages: the town itself, the landing page and
  // sign-in (which may redirect the whole site).
  const FULL_PAGES = new Set(['town.html', 'index.html', 'login.html']);
  const PAGE = /^[a-z0-9_-]+\.html$/i;

  /** Same-site player page for `href` (relative to `base`), or null. */
  function windowPath(href, base) {
    if (typeof href !== 'string' || !href || href.startsWith('#')) return null;
    let url;
    let from;
    try {
      from = new URL(base);
      url = new URL(href, from);
    } catch (_) {
      return null;
    }
    if (url.origin !== from.origin) return null;
    const dir = from.pathname.slice(0, from.pathname.lastIndexOf('/') + 1);
    if (!url.pathname.startsWith(dir)) return null;
    const name = url.pathname.slice(dir.length);
    if (!PAGE.test(name) || FULL_PAGES.has(name.toLowerCase())) return null;
    return name + url.search;
  }

  function hashFor(path) {
    return `#open=${encodeURIComponent(path)}`;
  }

  /** The page named in the town URL hash, if it is a valid window page. */
  function pathFromHash(hash) {
    const match = /^#open=(.+)$/.exec(hash || '');
    if (!match) return null;
    let path;
    try {
      path = decodeURIComponent(match[1]);
    } catch (_) {
      return null;
    }
    const [name] = path.split('?');
    if (!PAGE.test(name) || FULL_PAGES.has(name.toLowerCase())) return null;
    return path;
  }

  function embedUrl(path) {
    return `${path}${path.includes('?') ? '&' : '?'}embed=1`;
  }

  /** True when `win` is a page shown inside the town window. */
  function isTownEmbed(win) {
    try {
      const parent = win && win.parent;
      if (!parent || parent === win) return false;
      return parent.document?.body?.dataset?.page === 'town';
    } catch (_) {
      return false; // a different site framed us: not the town
    }
  }

  function transitionForBuilding(building) {
    if (building === 'tower' || building === 'observatory') return 'portal';
    if (building === 'store' || building === 'park') return 'curtain';
    return 'door';
  }

  function swipeShouldClose(distance, height) {
    return Number.isFinite(distance) && Number.isFinite(height) && height > 0 &&
      distance > 0 && distance >= height * 0.25;
  }

  function loadingTimedOut(startedAt, now) {
    return Number.isFinite(startedAt) && Number.isFinite(now) && now - startedAt >= 8000;
  }

  function prefetchPath(destinations, building) {
    if (!Array.isArray(destinations)) return null;
    const preferred = destinations.find(d => d.building === building && d.audience === 'player' &&
      d.status === 'available' && d.href && !d.href.startsWith('town.html'));
    return preferred ? preferred.href.split('#')[0] : null;
  }

  return Object.freeze({ windowPath, hashFor, pathFromHash, embedUrl, isTownEmbed,
    transitionForBuilding, swipeShouldClose, loadingTimedOut, prefetchPath });
});
