(function (root) {
  'use strict';
  // Mounts a living social scene for the page named by <body data-living-room>.
  // Each object opens one of the page's own sections (same nodes, listeners
  // and Cloud calls) after the companion walks over, or leads to a sibling
  // room of the same facility with a door transition. Config: social_rooms.js.
  const doc = root.document;
  // Mount after every synchronous page script (sprite player, dialog, app.js
  // listeners) has run, whatever order the page lists them in.
  if (doc.readyState === 'loading') { doc.addEventListener('DOMContentLoaded', start, { once: true }); return; }
  start();
  function start() {
  const key = doc.body?.dataset.livingRoom;
  const config = root.NudgeSocialRooms?.[key];
  if (!config || !root.NudgeLivingRoom?.mount || !root.NudgeSceneRoom) return;

  const main = doc.querySelector('main') || doc.body;
  config.prepare?.(doc);
  const sections = new Map();
  for (const o of config.objects) {
    if (!o.section) continue;
    const node = doc.querySelector(o.section);
    if (!node) continue;
    sections.set(o.id, node);
    node.dataset.roomHidden = '1';
    node.hidden = true;
  }
  for (const sel of config.hide || []) doc.querySelectorAll(sel).forEach(n => { n.hidden = true; n.dataset.livingHidden = '1'; });

  const reduced = () => root.matchMedia?.('(prefers-reduced-motion: reduce)').matches;
  function leave(href) {
    if (reduced()) { root.location.href = href; return; }
    doc.body.classList.add('living-leaving');
    root.setTimeout(() => { root.location.href = href; }, 420);
  }

  const room = root.NudgeLivingRoom.mount({
    host: doc.querySelector(config.host || 'main') || main,
    title: config.title,
    npc: config.npc,
    companion: config.companion || 'companion',
    layouts: config.layouts,
    far: config.far,
    near: config.near,
    greeting: config.greeting ? () => config.greeting(doc) : [],
    tips: config.tips || [],
    objects: config.objects.map(o => ({
      ...o,
      content: o.section ? () => sections.get(o.id) || null : null,
      onUse: o.href ? () => leave(o.href) : o.say ? r => r.say(o.say(doc)) : null,
    })),
  });
  root.NudgeLivingPage = room;
  doc.body.classList.add('living-arrived');
  for (const sel of config.float || []) {
    const node = doc.querySelector(sel);
    if (!node) continue;
    node.classList.add('room-float', 'living-float');
    room.stage.append(node);
  }
  config.afterMount?.(room, doc);
  const arrive = new URLSearchParams(root.location.search).get('open') || config.openOnArrive;
  if (arrive && config.objects.some(o => o.id === arrive && o.section)) room.use(arrive);
  }
})(typeof globalThis !== 'undefined' ? globalThis : this);
