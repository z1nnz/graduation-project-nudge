(function (root) {
  'use strict';
  // Puts an existing page behind a room: each object opens one of the page's
  // own sections (same nodes, same listeners, same Cloud calls) in a panel.
  // Config lives in page_rooms.js, keyed by <body data-page>.
  const doc = root.document;
  const page = doc.body?.dataset.page || doc.body?.dataset.townGate;
  const config = root.NudgePageRooms?.[page];
  if (!config || !root.NudgeSceneRoom) return;

  const sections = new Map();
  for (const o of config.objects) {
    if (!o.section) continue;
    const node = doc.querySelector(o.section);
    if (!node) continue;
    sections.set(o.id, node);
    node.dataset.roomHidden = '1';
    node.hidden = true;
  }
  for (const sel of config.hide || []) doc.querySelectorAll(sel).forEach(n => { n.hidden = true; });

  const room = root.NudgeSceneRoom.mount({
    host: doc.querySelector(config.host || 'main'),
    art: config.art,
    title: config.title,
    aspect: config.aspect,
    npc: config.npc,
    npcAt: config.npcAt,
    greeting: config.greeting ? () => config.greeting(doc) : [],
    tips: config.tips || [],
    effects: config.effects || [],
    objects: config.objects.map(o => ({
      ...o,
      onSelect: (event, r) => {
        if (o.burst) r.burst({ kind: o.burst, count: 6, from: o.id });
        if (o.href) { root.location.href = o.href; return; }
        if (o.say) { r.say(o.say(doc)); return; }
        const node = sections.get(o.id);
        if (node) r.openPanel({ title: o.panelTitle || o.label, content: node, variant: o.variant, from: r.object(o.id) });
      },
    })),
  });
  root.NudgePageRoom = room;
  if (config.openOnArrive) {
    const target = config.objects.find(o => o.id === config.openOnArrive);
    if (target && sections.get(target.id)) {
      room.openPanel({ title: target.panelTitle || target.label, content: sections.get(target.id), variant: target.variant, from: room.object(target.id) });
    }
  }
})(typeof globalThis !== 'undefined' ? globalThis : this);
