(function (root) {
  'use strict';
  const core = root.NudgeTownWindowCore;
  const routes = root.NudgeTownRoutes;
  const doc = root.document;
  if (!core || !doc || doc.body?.dataset.page !== 'town') return;
  const el = id => doc.getElementById(id);
  const box = el('townWindow');
  const frame = el('townWindowFrame');
  const title = el('townWindowTitle');
  const back = el('townWindowBack');
  const closeButton = el('townWindowClose');
  const loading = el('townWindowLoading');
  const loadingText = el('townWindowLoadingText');
  const loadingActions = el('townWindowLoadingActions');
  if (!box || !frame || !title || !back || !loading) return;

  const reducedMotion = root.matchMedia?.('(prefers-reduced-motion: reduce)').matches;
  let openPath = null;
  let pushed = false;
  let returnFocus = null;
  let door = null;
  let loadTimer = null;
  let loadingFrameTimer = null;
  let closeTimer = null;
  let loadingStarted = 0;
  let navigatingBack = false;
  let stack = [];
  let inertSnapshot = [];
  const prefetched = new Set();

  function destination(path) {
    const name = path.split('?')[0];
    return routes?.DESTINATIONS?.find(d => d.href.split('#')[0].split('?')[0] === name);
  }
  function setDoor(building, point) {
    door = { building, point };
  }
  function nearDoor(building) {
    if (prefetched.has(building)) return;
    const path = core.prefetchPath(routes?.DESTINATIONS, building);
    if (!path) return;
    prefetched.add(building);
    const link = doc.createElement('link');
    link.rel = 'prefetch';
    link.href = path;
    doc.head.appendChild(link);
  }
  function blockBackground() {
    if (inertSnapshot.length) return;
    let child = box;
    while (child.parentElement) {
      const parent = child.parentElement;
      for (const sibling of parent.children) {
        if (sibling === child || sibling.tagName === 'SCRIPT') continue;
        inertSnapshot.push([sibling, sibling.inert]);
        sibling.inert = true;
      }
      child = parent;
      if (parent === doc.body) break;
    }
  }
  function restoreBackground() {
    for (const [node, wasInert] of inertSnapshot) node.inert = wasInert;
    inertSnapshot = [];
  }
  function announce(open) {
    doc.dispatchEvent(new CustomEvent('nudge-town-scene', { detail: { open } }));
  }
  function updateBack() { back.hidden = stack.length === 0; }
  function startLoading(path) {
    root.clearTimeout(loadTimer);
    root.clearInterval(loadingFrameTimer);
    loadingStarted = Date.now();
    loading.hidden = false;
    loadingActions.hidden = true;
    const building = destination(path)?.building;
    loadingText.textContent = `正在進入${routes?.BUILDINGS?.[building]?.name || '設施'}…`;
    if (!reducedMotion) {
      const poses = ['a', 'p', 'b', 'p'];
      let frameIndex = 0;
      loadingFrameTimer = root.setInterval(() => {
        loading.querySelector('img').src = `assets/avatar/poses/walk_0_${poses[frameIndex++ % poses.length]}.png`;
      }, 180);
    }
    loadTimer = root.setTimeout(() => {
      if (!openPath || !core.loadingTimedOut(loadingStarted, Date.now())) return;
      loadingText.textContent = '載入時間較久，請重試或回小鎮。';
      loadingActions.hidden = false;
    }, 8000);
  }
  function stopLoading() {
    root.clearTimeout(loadTimer);
    root.clearInterval(loadingFrameTimer);
    loadTimer = null;
    loadingFrameTimer = null;
    loading.hidden = true;
  }
  function showTransition(building) {
    if (door?.point && Number.isFinite(door.point.x) && Number.isFinite(door.point.y)) {
      const rect = box.getBoundingClientRect();
      box.style.setProperty('--town-door-x', `${Math.min(rect.width, Math.max(0, door.point.x - rect.left))}px`);
      box.style.setProperty('--town-door-y', `${Math.min(rect.height, Math.max(0, door.point.y - rect.top))}px`);
    }
    box.dataset.transition = core.transitionForBuilding(building);
    box.classList.remove('is-closing', 'is-opening');
    if (!reducedMotion) {
      void box.offsetWidth;
      box.classList.add('is-opening');
      root.setTimeout(() => box.classList.remove('is-opening'), 450);
    }
  }
  function open(path, { label = '', push = true } = {}) {
    if (!path) return false;
    root.clearTimeout(closeTimer);
    const first = !openPath;
    if (first) returnFocus = doc.activeElement;
    else if (path !== openPath) stack.push(openPath);
    openPath = path;
    title.textContent = label || destination(path)?.title || '';
    updateBack();
    box.hidden = false;
    blockBackground();
    doc.body.classList.add('town-window-open');
    showTransition(destination(path)?.building || door?.building);
    startLoading(path);
    frame.src = core.embedUrl(path);
    if (push && root.history && root.location.hash !== core.hashFor(path)) {
      root.history.pushState({ townWindow: path }, '', core.hashFor(path));
      pushed = true;
    }
    if (first) announce(true);
    closeButton.focus({ preventScroll: true });
    return true;
  }
  function close({ fromHistory = false } = {}) {
    if (!openPath) return;
    openPath = null;
    stack = [];
    updateBack();
    stopLoading();
    doc.body.classList.remove('town-window-open');
    if (fromHistory) pushed = false;
    else if (pushed) { pushed = false; root.history.back(); }
    else root.history?.replaceState(null, '', root.location.pathname + root.location.search);
    announce(false);
    const finish = () => {
      box.hidden = true;
      box.classList.remove('is-closing');
      frame.src = 'about:blank';
      restoreBackground();
      const focus = returnFocus;
      returnFocus = null;
      if (focus && doc.contains(focus) && typeof focus.focus === 'function') focus.focus({ preventScroll: true });
    };
    if (reducedMotion) finish();
    else { box.classList.add('is-closing'); closeTimer = root.setTimeout(finish, 430); }
  }
  function pathInsideFrame() {
    try {
      const url = new URL(frame.contentWindow.location.href);
      url.searchParams.delete('embed');
      return core.windowPath(url.href, root.location.href);
    } catch (_) { return null; }
  }
  frame.addEventListener('load', () => {
    if (!openPath) return;
    stopLoading();
    try {
      const inner = frame.contentDocument;
      inner?.addEventListener('keydown', event => {
        if (event.defaultPrevented) return;
        if (event.key === 'Escape') {
          event.preventDefault();
          close();
        } else if (event.key === 'Tab') {
          const controls = [...inner.querySelectorAll('a[href], button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])')]
            .filter(node => !node.hidden && node.getClientRects().length);
          const edge = event.shiftKey ? controls[0] : controls[controls.length - 1];
          if (!edge || inner.activeElement !== edge) return;
          event.preventDefault();
          (back.hidden ? closeButton : back).focus();
        }
      });
    } catch (_) { /* cross-origin pages cannot be read or controlled */ }
    const path = pathInsideFrame();
    if (path && path !== openPath) {
      if (!navigatingBack) stack.push(openPath);
      openPath = path;
      title.textContent = destination(path)?.title || (frame.contentDocument?.title || '').replace(/^Nudge\s*/, '');
      root.history?.replaceState({ townWindow: path }, '', core.hashFor(path));
      updateBack();
    }
    navigatingBack = false;
  });
  back.addEventListener('click', () => {
    const previous = stack.pop();
    if (!previous) return;
    navigatingBack = true;
    openPath = previous;
    title.textContent = destination(previous)?.title || '';
    updateBack();
    startLoading(previous);
    frame.src = core.embedUrl(previous);
    root.history?.replaceState({ townWindow: previous }, '', core.hashFor(previous));
  });
  closeButton.addEventListener('click', () => close());
  el('townWindowCancel').addEventListener('click', () => close());
  el('townWindowRetry').addEventListener('click', () => {
    if (!openPath) return;
    startLoading(openPath);
    frame.src = core.embedUrl(openPath);
  });
  doc.addEventListener('click', event => {
    if (event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
    const link = event.target?.closest?.('a[href]');
    if (!link || link.target === '_blank' || link.hasAttribute('download') || link.closest('#townToolList')) return;
    const path = core.windowPath(link.getAttribute('href'), root.location.href);
    if (!path) return;
    event.preventDefault();
    const panel = el('townPanel');
    if (panel && !panel.hidden) el('townPanelClose')?.click();
    open(path, { label: link.querySelector('strong')?.textContent || '' });
  });
  doc.addEventListener('keydown', event => {
    if (!openPath) return;
    if (event.key === 'Escape') {
      event.preventDefault(); event.stopPropagation(); close();
    } else if (event.key === 'Tab') {
      const first = back.hidden ? closeButton : back;
      if (event.shiftKey && doc.activeElement === first) { event.preventDefault(); frame.focus(); }
      else if (!event.shiftKey && doc.activeElement === frame) { event.preventDefault(); first.focus(); }
    }
  }, true);
  let swipeStart = null;
  const bar = box.querySelector('.town-window-bar');
  bar.addEventListener('pointerdown', event => {
    if (root.innerWidth > 640 || event.target.closest('button')) return;
    swipeStart = { id: event.pointerId, y: event.clientY };
    bar.setPointerCapture?.(event.pointerId);
  });
  bar.addEventListener('pointerup', event => {
    if (!swipeStart || event.pointerId !== swipeStart.id) return;
    const distance = event.clientY - swipeStart.y;
    swipeStart = null;
    if (core.swipeShouldClose(distance, box.clientHeight)) close();
    else { box.classList.add('is-bouncing'); root.setTimeout(() => box.classList.remove('is-bouncing'), 250); }
  });
  bar.addEventListener('pointercancel', () => { swipeStart = null; });
  root.addEventListener('message', event => {
    if (event.origin !== root.location.origin || event.source !== frame.contentWindow) return;
    if (event.data?.type === 'nudge-town-window-close') close();
  });
  root.addEventListener('popstate', () => {
    const path = core.pathFromHash(root.location.hash);
    if (path) open(path, { push: false });
    else close({ fromHistory: true });
  });
  root.NudgeTownWindow = Object.freeze({ open: path => open(path), close: () => close(), setDoor, nearDoor });
  const initial = core.pathFromHash(root.location.hash);
  if (initial) open(initial, { push: false });
})(typeof globalThis !== 'undefined' ? globalThis : this);
