(function (root) {
  'use strict';
  // Entering a building opens its interior full screen. town.js still builds
  // the destination entries (links, login prompts, gates); each one becomes
  // an object on the room art that presses that same entry. Entries without
  // a spot stay visible as wooden signs at the bottom of the room.
  const doc = root.document;
  const halls = root.NudgeTownHalls;
  if (!doc || !halls || !root.NudgeSceneRoom) return;

  let room = null, host = null;

  function teardown(panel, list) {
    room?.destroy();
    room = null;
    host?.remove();
    host = null;
    panel.classList.remove('is-room');
    for (const li of list.children) li.classList.remove('is-spot', 'is-signpost');
  }

  function decorate(building, panel, list, locked) {
    teardown(panel, list);
    const hall = halls.hallFor(building.id);
    const layouts = halls.layoutsFor(building.id);
    if (!hall || !layouts || locked) return;
    panel.classList.add('is-room');

    const entries = [...list.children].map(li => ({ li, id: li.dataset.dest, control: li.firstElementChild }));
    const spotted = new Set(Object.values(layouts).flatMap(l => Object.keys(l.rects || {})));
    for (const e of entries) {
      e.li.classList.toggle('is-spot', spotted.has(e.id));
      e.li.classList.toggle('is-signpost', !spotted.has(e.id));
    }

    host = doc.createElement('div');
    host.className = 'town-hall-host';
    panel.insertBefore(host, list);
    room = root.NudgeSceneRoom.mount({
      host,
      title: building.name,
      npc: hall.npc,
      npcSize: 112,
      greeting: () => [hall.line],
      tips: [building.desc].filter(Boolean),
      layouts,
      objects: entries.filter(e => spotted.has(e.id)).map(e => {
        const title = e.control?.querySelector('strong')?.textContent || e.id;
        const note = e.control?.querySelector('small')?.textContent || '';
        return {
          id: e.id,
          label: title.split(/[：（]/)[0],
          hint: [title.includes('：') ? title.split('：')[1] : '', note].filter(Boolean).join('，') || null,
          className: `is-${[...(e.control?.classList || [])].find(c => c.startsWith('is-'))?.slice(3) || 'open'}`,
          onSelect: (event, api) => {
            // Locked or still-building entries are plain text: the NPC explains.
            if (!e.control || e.control.tagName === 'SPAN') { api.say([`${title}：${note || '還沒開放'}`]); return; }
            e.control.click();
          },
        };
      }),
    });
  }

  root.NudgeTownHallView = Object.freeze({ decorate });
})(typeof globalThis !== 'undefined' ? globalThis : this);
