(function (root) {
  'use strict';
  // Weekly planner (J9): the seven days are stops on a little adventure
  // trail above the planner. Each stop's flag rises with the tasks planned
  // for that day (the number is the small label), past days you planned
  // show a raised flag, and your character stands on today's stop. Reads the
  // planner's own day columns; saves nothing.
  const doc = root.document;
  const days = doc?.getElementById('plannerDays');
  if (!days || doc.body.dataset.page !== 'weekly-planner') return;
  const reduced = () => root.matchMedia('(prefers-reduced-motion: reduce)').matches;
  const trail = doc.createElement('div');
  trail.className = 'wpt-trail';
  trail.setAttribute('role', 'img');
  days.before(trail);
  let hiker = null;

  function today() {
    const d = new Date(Date.now() - 5 * 3600 * 1000);
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
  }
  function render() {
    const cols = [...days.querySelectorAll('.planner-day')];
    trail.textContent = '';
    if (!cols.length) return;
    const now = today();
    const labels = [];
    cols.forEach((c, i) => {
      const n = c.querySelectorAll('.planner-task').length;
      const stop = doc.createElement('span');
      stop.className = 'wpt-stop';
      stop.style.left = `${6 + (88 * i) / (cols.length - 1)}%`;
      stop.style.top = `${52 + Math.sin(i * 1.1) * 18}%`;
      stop.style.setProperty('--wpt-h', String(Math.min(5, n)));
      if (n) stop.classList.add('has-flag');
      if (c.dataset.day < now && n) stop.classList.add('is-past');
      if (c.dataset.day === now) stop.classList.add('is-today');
      const day = (c.querySelector('h3')?.textContent || '').split('·')[0].trim();
      stop.append(Object.assign(doc.createElement('small'), { textContent: `${day} ${n}` }));
      trail.append(stop);
      labels.push(`${day} ${n} 件`);
      if (c.dataset.day === now) {
        const h = doc.createElement('span');
        h.className = 'wpt-hiker';
        stop.append(h);
        hiker?.destroy?.();
        // The earlier companion walks the trail.
        try { hiker = root.NudgeSpritePlayer?.characterPlayer(h, 'companion', { animation: reduced() ? 'idle' : 'walk_right', size: 56 }) || null; } catch { hiker = null; }
      }
    });
    trail.setAttribute('aria-label', `本週冒險小路：${labels.join('、')}`);
  }
  new root.MutationObserver(() => root.setTimeout(render, 20)).observe(days, { childList: true, subtree: true });
  render();
  root.NudgePlannerTrail = Object.freeze({ render });
})(typeof globalThis !== 'undefined' ? globalThis : this);
