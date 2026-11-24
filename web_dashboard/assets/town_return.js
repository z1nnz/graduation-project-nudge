(function (root) {
  'use strict';
  // "Back to town" links for any Web page. Usage on a page:
  //   <a data-town-return href="town.html">← 返回小鎮</a>
  //   <script src="assets/town_routes.js?v=4"></script>
  //   <script src="assets/town_return.js?v=2"></script>
  // data-town-return="tower" forces a building; empty means "the building
  // that owns this page" from town_routes.js, falling back to the square.
  //
  // Inside the town window (town_window.js) the page is already in the
  // town: back links and links to town.html close the window instead.
  const routes = root.NudgeTownRoutes;
  const doc = root.document;
  if (!doc) return;

  function inTownWindow() {
    try {
      const parent = root.parent;
      return Boolean(parent && parent !== root && parent.document?.body?.dataset?.page === 'town');
    } catch (_) {
      return false;
    }
  }
  const embedded = inTownWindow();

  function apply() {
    if (embedded) {
      doc.documentElement.classList.add('is-town-window');
      // The window's own "✕ 回小鎮" bar replaces the page's back link.
      const style = doc.createElement('style');
      // Pages still on the old dashboard shell drop its sidebar: the town is
      // the navigation now.
      style.textContent = '.is-town-window [data-town-return]{display:none !important}'
        + '.is-town-window .shell{grid-template-columns:1fr !important}'
        + '.is-town-window .sidebar{display:none !important}';
      doc.head.appendChild(style);
    }
    if (!routes) return;
    const page = root.location ? root.location.pathname : '';
    for (const link of doc.querySelectorAll('[data-town-return]')) {
      const wanted = link.getAttribute('data-town-return');
      link.setAttribute('href', routes.isBuilding(wanted) ? routes.townHref(wanted) : routes.returnHrefForPage(page));
    }
  }

  if (embedded) {
    doc.addEventListener('click', event => {
      if (event.defaultPrevented || event.button !== 0) return;
      const link = event.target?.closest?.('a[href]');
      if (!link) return;
      const href = link.getAttribute('href') || '';
      const toTown = link.hasAttribute('data-town-return') || /(^|\/)town\.html([?#].*)?$/.test(href);
      if (!toTown) return;
      event.preventDefault();
      root.parent.postMessage({ type: 'nudge-town-window-close' }, root.location.origin);
    });
  }

  if (doc.readyState === 'loading') doc.addEventListener('DOMContentLoaded', apply);
  else apply();
})(typeof globalThis !== 'undefined' ? globalThis : this);
