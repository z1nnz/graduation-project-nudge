(function (root) {
  'use strict';
  // Turns the town's building panel into the building's interior: the room
  // art fills the panel and each destination entry (the same links and
  // buttons town.js already built, with their login and gate rules) sits on
  // its object. Entries without a spot hang on the signpost below the art.
  const doc = root.document;
  const halls = root.NudgeTownHalls;
  if (!doc || !halls) return;

  let stage = null, art = null, npc = null, player = null, home = null;

  function ensureStage(list) {
    if (stage) return;
    stage = doc.createElement('div');
    stage.className = 'town-hall-stage';
    art = doc.createElement('img');
    art.className = 'town-hall-art';
    art.alt = '';
    art.setAttribute('aria-hidden', 'true');
    art.decoding = 'async';
    npc = doc.createElement('button');
    npc.type = 'button';
    npc.className = 'town-hall-npc';
    const body = doc.createElement('span');
    body.className = 'town-hall-npc-body';
    body.setAttribute('aria-hidden', 'true');
    const name = doc.createElement('span');
    name.className = 'town-hall-sign';
    npc.append(body, name);
    stage.append(art, npc);
    home = { parent: list.parentNode, next: list.nextSibling };
  }

  function characterName(id) {
    try { return root.NudgeSpritePlayer.character(id).name; } catch { return ''; }
  }

  function decorate(building, panel, list, locked) {
    const hall = halls.hallFor(building.id);
    const asRoom = Boolean(hall) && !locked;
    panel.classList.toggle('is-room', asRoom);
    if (!asRoom) {
      if (stage && list.parentNode === stage && home) home.parent.insertBefore(list, home.next);
      stage?.remove();
      player?.stop?.();
      for (const li of list.children) { li.removeAttribute('style'); li.classList.remove('is-spot', 'is-signpost'); }
      return;
    }
    ensureStage(list);
    panel.insertBefore(stage, home.next && home.next.parentNode === panel ? home.next : null);
    stage.append(list);
    stage.style.aspectRatio = String(hall.aspect);
    stage.style.setProperty('--hall-art', `url("${new URL(hall.art, doc.baseURI).href}")`);
    if (art.getAttribute('src') !== hall.art) art.src = hall.art;

    for (const li of list.children) {
      const spot = halls.spotFor(building.id, li.dataset.dest);
      li.classList.toggle('is-spot', Boolean(spot));
      li.classList.toggle('is-signpost', !spot);
      const control = li.firstElementChild, title = control?.querySelector('strong');
      if (title) {
        title.dataset.full ||= title.textContent;
        // Signs show the short name; screen readers get the full entry.
        title.textContent = spot ? title.dataset.full.split(/[：（]/)[0] : title.dataset.full;
        control.setAttribute('aria-label', `${title.dataset.full}${control.querySelector('small')?.textContent ? '，' + control.querySelector('small').textContent : ''}`);
      }
      if (spot) {
        li.style.left = spot.left + '%';
        li.style.top = spot.top + '%';
        li.style.width = spot.width + '%';
        li.style.height = spot.height + '%';
      } else li.removeAttribute('style');
    }

    const label = characterName(hall.npc);
    npc.hidden = !label || !root.NudgeSpritePlayer;
    if (!npc.hidden) {
      npc.setAttribute('aria-label', `和${label}說話`);
      npc.querySelector('.town-hall-sign').textContent = label;
      player?.destroy?.();
      player = root.NudgeSpritePlayer.characterPlayer(npc.querySelector('.town-hall-npc-body'), hall.npc, { animation: 'idle', size: 96 });
      npc.onclick = () => {
        player?.play('talk');
        try {
          root.NudgeNpcDialog.open({ speaker: hall.npc, lines: [hall.line], onClose: () => player?.play('idle') });
        } catch { /* dialog script missing: the sign still names the NPC */ }
      };
    }
  }

  root.NudgeTownHallView = Object.freeze({ decorate });
})(typeof globalThis !== 'undefined' ? globalThis : this);
