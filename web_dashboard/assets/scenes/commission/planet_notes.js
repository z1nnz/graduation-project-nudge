(function (root) {
  'use strict';
  // Planet mission log (J9): today's orbit missions are commission notes
  // pinned on a board; ticking one stamps it 完成 and it flies into the
  // envelope at the corner. app.js still owns the list and every check.
  const doc = root.document;
  const panel = doc?.getElementById('missionLogPanel');
  const list = doc?.getElementById('dynamicMissionList');
  if (!panel || !list) return;
  const reduced = () => root.matchMedia('(prefers-reduced-motion: reduce)').matches;
  panel.classList.add('pn-board');
  const envelope = doc.createElement('span');
  envelope.className = 'pn-envelope';
  envelope.setAttribute('aria-hidden', 'true');
  panel.append(envelope);
  function dress() {
    [...list.querySelectorAll('.mission-item')].forEach((li, i) => {
      li.style.setProperty('--pn-tilt', `${((i * 37) % 5) - 2}deg`);
      li.classList.toggle('is-stamped', Boolean(li.querySelector('.mission-check')?.checked));
    });
  }
  list.addEventListener('change', e => {
    const li = e.target.closest?.('.mission-item');
    if (!li || !e.target.classList?.contains('mission-check')) return;
    li.classList.toggle('is-stamped', e.target.checked);
    if (!e.target.checked || reduced()) return;
    root.NudgeSfx?.play?.('coin');
    const r = li.getBoundingClientRect(), t = envelope.getBoundingClientRect();
    const fly = li.cloneNode(true);
    fly.classList.add('pn-fly');
    fly.removeAttribute('data-id');
    fly.querySelectorAll('input,button').forEach(n => n.remove());
    Object.assign(fly.style, { position: 'fixed', left: `${r.left}px`, top: `${r.top}px`, width: `${r.width}px` });
    fly.style.setProperty('--pn-dx', `${t.left - r.left}px`);
    fly.style.setProperty('--pn-dy', `${t.top - r.top}px`);
    doc.body.append(fly);
    fly.addEventListener('animationend', () => fly.remove(), { once: true });
  });
  new root.MutationObserver(dress).observe(list, { childList: true });
  dress();
})(typeof globalThis !== 'undefined' ? globalThis : this);
