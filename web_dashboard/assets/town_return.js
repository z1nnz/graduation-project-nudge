(function (root) {
  'use strict';
  // "Back to town" links for any Web page. Usage on a page:
  //   <a data-town-return href="town.html">← 返回小鎮</a>
  //   <script src="assets/town_routes.js?v=1"></script>
  //   <script src="assets/town_return.js?v=1"></script>
  // data-town-return="tower" forces a building; empty means "the building
  // that owns this page" from town_routes.js, falling back to the square.
  const routes = root.NudgeTownRoutes;
  const doc = root.document;
  if (!routes || !doc) return;
  function apply() {
    const page = root.location ? root.location.pathname : '';
    for (const link of doc.querySelectorAll('[data-town-return]')) {
      const wanted = link.getAttribute('data-town-return');
      link.setAttribute('href', routes.isBuilding(wanted) ? routes.townHref(wanted) : routes.returnHrefForPage(page));
    }
  }
  if (doc.readyState === 'loading') doc.addEventListener('DOMContentLoaded', apply);
  else apply();
})(typeof globalThis !== 'undefined' ? globalThis : this);
