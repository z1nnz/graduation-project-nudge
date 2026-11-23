(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.NudgeTownAvatarCore = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';

  const walkFaces = new Set([0, 3, 6, 9, 12, 15]);
  const cycle = ['a', 'p', 'b', 'p'];

  function facing(dx, dy, previous = 'south') {
    if (!Number.isFinite(dx) || !Number.isFinite(dy) || (!dx && !dy)) return previous;
    return Math.abs(dx) >= Math.abs(dy)
      ? (dx < 0 ? 'west' : 'east')
      : (dy < 0 ? 'north' : 'south');
  }

  function pose(faceShapeIndex, direction, moving, elapsedSeconds = 0) {
    if (!walkFaces.has(faceShapeIndex) || !['east', 'west'].includes(direction)) {
      return { kind: 'front', flip: direction === 'west', frame: null };
    }
    const tick = Number.isFinite(elapsedSeconds) ? Math.max(0, elapsedSeconds) : 0;
    const frame = moving ? cycle[Math.floor(tick * 8) % cycle.length] : 'p';
    return { kind: 'side', flip: direction === 'west', frame };
  }

  function sidePath(faceShapeIndex, frame) {
    if (!walkFaces.has(faceShapeIndex) || !['a', 'p', 'b'].includes(frame)) return null;
    return `assets/avatar/poses/walk_${faceShapeIndex}_${frame}.png`;
  }

  return { facing, pose, sidePath };
});
