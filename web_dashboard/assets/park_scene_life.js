(function (root) {
  'use strict';
  // Park 2.0 (J6) on park_scene.js: the player walks to a ride before it
  // opens (arcade_stage.js plays the ride-in), a live sky over the hills,
  // petals in front, and the two new rides stand on the map.
  const doc = root.document;
  const room = root.NudgeParkRoom;
  if (!doc || !room || !root.NudgeWorldLife) return;
  const R = {
    wide: { wheel: [0.18, 0.05, 0.19, 0.3], carousel: [0.7, 0.12, 0.2, 0.26], stall: [0.17, 0.37, 0.24, 0.21], stage: [0.7, 0.38, 0.18, 0.18], hopscotch: [0.72, 0.57, 0.18, 0.15], booth: [0.47, 0.68, 0.13, 0.2], lantern: [0.05, 0.6, 0.06, 0.2], telescope: [0.53, 0.1, 0.07, 0.13] },
    tall: { wheel: [0.05, 0.03, 0.4, 0.29], stall: [0.02, 0.4, 0.43, 0.2], stage: [0.66, 0.4, 0.3, 0.16], carousel: [0.65, 0.1, 0.32, 0.25], booth: [0.38, 0.75, 0.22, 0.18], hopscotch: [0.66, 0.57, 0.26, 0.15], lantern: [0.04, 0.62, 0.12, 0.12], telescope: [0.44, 0.08, 0.14, 0.09] },
  };
  const ride = { face: 'up', fx: 'pop', sfx: 'open', anim: 'happy', wait: 520 };
  const life = root.NudgeWorldLife.attach(room, {
    layouts: {
      wide: { rects: R.wide, floor: [0.45, 0.95], start: [0.5, 0.92], skyRect: [0, 0, 1, 0.1], hills: 0.1,
        spots: { wheel: [0.28, 0.4], carousel: [0.78, 0.42], stall: [0.3, 0.62], stage: [0.78, 0.6], hopscotch: [0.8, 0.76], booth: [0.53, 0.9], lantern: [0.12, 0.82], telescope: [0.56, 0.3] },
        near: { fall: 'petals', count: 18, plants: [{ x: 0.01, size: 0.2, kind: 'flowers', bloom: '#f6a7c1' }, { x: 0.99, size: 0.18, kind: 'flowers', bloom: '#f6a7c1' }] } },
      tall: { rects: R.tall, floor: [0.45, 0.96], start: [0.5, 0.93], skyRect: [0, 0, 1, 0.07], hills: 0.07,
        spots: { wheel: [0.26, 0.36], carousel: [0.8, 0.38], stall: [0.24, 0.64], stage: [0.8, 0.6], hopscotch: [0.78, 0.76], booth: [0.5, 0.95], lantern: [0.12, 0.78], telescope: [0.5, 0.2] },
        near: { fall: 'petals', count: 12, plants: [{ x: 0.02, size: 0.12, kind: 'flowers', bloom: '#f6a7c1' }] } },
    },
    acts: {
      wheel: ride, carousel: ride, stall: ride, stage: ride, lantern: ride, telescope: ride,
      hopscotch: { face: 'down', anim: 'happy', fx: 'pop', sfx: 'tap' },
      booth: { face: 'up', anim: 'talk', fx: 'shake', sfx: 'coin' },
    },
  });
  const props = {};
  for (const [id, file] of [['lantern', 'lantern_post.png'], ['telescope', 'telescope.png']]) {
    const img = doc.createElement('img');
    img.className = 'pk-prop';
    img.alt = '';
    img.src = `assets/scenes/park/${file}`;
    Object.assign(img.style, { position: 'absolute', objectFit: 'contain', objectPosition: '50% 100%', imageRendering: 'pixelated', pointerEvents: 'none', zIndex: '60' });
    room.frame.append(img);
    props[id] = img;
  }
  function layout() {
    const r = R[room.layout()] || R.tall;
    for (const [id, img] of Object.entries(props)) {
      const q = r[id];
      Object.assign(img.style, { left: q[0] * 100 + '%', top: q[1] * 100 + '%', width: q[2] * 100 + '%', height: q[3] * 100 + '%' });
    }
  }
  layout();
  root.addEventListener('resize', () => root.setTimeout(layout, 140));
  root.NudgeParkLife = life;
})(typeof globalThis !== 'undefined' ? globalThis : this);
