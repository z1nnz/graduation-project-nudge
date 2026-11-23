(function(root) {
  'use strict';
  // Pure rules for the Web companion town: movement, doors, unlocks and
  // break tickets. No DOM access, so Node tests can load it directly.

  const TICKET_WINDOW_MS = 2 * 60 * 60 * 1000;
  const MAX_TICKETS = 2;
  const FOCUS_TYPES = new Set(['focus', 'study']);

  /** Break tickets from Cloud-confirmed focus receipts (newest first). */
  function breakTickets(receipts, nowMs, usedIds) {
    const used = new Set(usedIds || []);
    return (receipts || [])
      .filter(r => r && FOCUS_TYPES.has(r.activityType) && Number(r.acceptedMetric) >= 25)
      .map(r => ({
        receiptId: r.receiptId,
        minutes: Number(r.acceptedMetric) >= 50 ? 10 : 5,
        verifiedAtMs: Date.parse(r.verifiedAt),
      }))
      .filter(t => Number.isFinite(t.verifiedAtMs) && !used.has(t.receiptId))
      .map(t => ({ ...t, expiresAt: t.verifiedAtMs + TICKET_WINDOW_MS }))
      .filter(t => t.verifiedAtMs <= nowMs && t.expiresAt > nowMs)
      .sort((a, b) => b.verifiedAtMs - a.verifiedAtMs)
      .slice(0, MAX_TICKETS)
      .map(({ receiptId, minutes, expiresAt }) => ({ receiptId, minutes, expiresAt }));
  }

  function hits(p, r, radius) {
    return p.x + radius > r.x && p.x - radius < r.x + r.w &&
      p.y + radius > r.y && p.y - radius < r.y + r.h;
  }

  /** Move by dir*speed*dt, axis by axis so the player slides along walls. */
  function step(pos, dir, dt, speed, blockers, bounds, radius) {
    const clamp = (v, lo, hi) => Math.min(Math.max(v, lo), hi);
    let { x, y } = pos;
    const nx = clamp(x + dir.x * speed * dt, bounds.x + radius, bounds.x + bounds.w - radius);
    if (!blockers.some(b => hits({ x: nx, y }, b, radius))) x = nx;
    else if (dir.x > 0) x = Math.min(x, Math.min(...blockers.filter(b => hits({ x: nx, y }, b, radius)).map(b => b.x)) - radius);
    else if (dir.x < 0) x = Math.max(x, Math.max(...blockers.filter(b => hits({ x: nx, y }, b, radius)).map(b => b.x + b.w)) + radius);
    const ny = clamp(y + dir.y * speed * dt, bounds.y + radius, bounds.y + bounds.h - radius);
    if (!blockers.some(b => hits({ x, y: ny }, b, radius))) y = ny;
    return { x, y };
  }

  function nearestDoor(pos, buildings, reach) {
    let best = null;
    let bestDistance = reach;
    for (const b of buildings || []) {
      const d = Math.hypot(b.door.x - pos.x, b.door.y - pos.y);
      if (d <= bestDistance) { best = b; bestDistance = d; }
    }
    return best;
  }

  function isUnlocked(building, level) {
    return !building.minLevel || Number(level) >= building.minLevel;
  }

  /** Unit direction toward a click target, or null once within stopDistance. */
  function directionTo(from, to, stopDistance) {
    const dx = to.x - from.x;
    const dy = to.y - from.y;
    const d = Math.hypot(dx, dy);
    if (d <= stopDistance) return null;
    return { x: Math.round(dx / d * 1000) / 1000, y: Math.round(dy / d * 1000) / 1000 };
  }

  const api = { breakTickets, step, nearestDoor, isUnlocked, directionTo };
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.NudgeTownCore = api;
})(typeof globalThis !== 'undefined' ? globalThis : this);
