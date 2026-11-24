(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.NudgeCabinLayoutCore = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';
  // Pure rules for decorating the Web cabin: grid snapping, where a piece of
  // furniture may go, and the undo / redo stack. No DOM access.
  //
  // Coordinates are fractions (0-1) of the cabin stage, the same space as
  // assets/home/cabin_layout.json, so the App and the Web agree on where each
  // slot sits. The Cloud only stores which variant each slot shows
  // (users/{uid}.homeDecor via arrangeHomeDecor), so a drag can only drop a
  // piece onto its own slot's spot. Free positions are not part of the shared
  // contract and are never invented here.

  const COLS = 24;
  const HISTORY_LIMIT = 20;
  const MIN_OVERLAP = 0.35;

  /** Square cells over the stage: `cols` across, as many rows as fit. */
  function grid(aspect, cols = COLS) {
    const a = Number(aspect) > 0 ? Number(aspect) : 0.5629;
    const cellW = 1 / cols;
    const cellH = cellW * a; // a cell is as tall as it is wide on screen
    return Object.freeze({ cols, rows: Math.floor(1 / cellH), cellW, cellH });
  }

  function clamp(v, lo, hi) { return Math.min(hi, Math.max(lo, v)); }

  /** Rect [x, y, w, h] moved so its top-left sits on a grid corner and it stays on the stage. */
  function snapRect(rect, g) {
    const [x, y, w, h] = rect;
    const sx = Math.round(x / g.cellW) * g.cellW;
    const sy = Math.round(y / g.cellH) * g.cellH;
    return [clamp(sx, 0, Math.max(0, 1 - w)), clamp(sy, 0, Math.max(0, 1 - h)), w, h];
  }

  /** Rect of size w x h centred on a point, then snapped. */
  function rectAt(point, size, g) {
    const [w, h] = size;
    return snapRect([point.x - w / 2, point.y - h / 2, w, h], g);
  }

  /** Grid cell (col, row) under a point. */
  function cellAt(point, g) {
    return {
      col: clamp(Math.floor(point.x / g.cellW), 0, g.cols - 1),
      row: clamp(Math.floor(point.y / g.cellH), 0, g.rows - 1),
    };
  }

  function area(r) { return Math.max(0, r[2]) * Math.max(0, r[3]); }

  function intersection(a, b) {
    const w = Math.min(a[0] + a[2], b[0] + b[2]) - Math.max(a[0], b[0]);
    const h = Math.min(a[1] + a[3], b[1] + b[3]) - Math.max(a[1], b[1]);
    return w > 0 && h > 0 ? w * h : 0;
  }

  /** Share of the smaller rect covered by the other one (0-1). */
  function overlap(a, b) {
    const smaller = Math.min(area(a), area(b));
    return smaller > 0 ? intersection(a, b) / smaller : 0;
  }

  /** The allowed spot of every decor slot in the catalog, from the shared layout. */
  function spots(layout, catalog) {
    const out = [];
    for (const slot of Array.isArray(catalog?.slots) ? catalog.slots : []) {
      const rect = layout?.layers?.[slot.slot]?.rect;
      if (Array.isArray(rect) && rect.length === 4 && rect.every(Number.isFinite)) {
        out.push(Object.freeze({ slot: slot.slot, label: slot.label, rect: Object.freeze([...rect]) }));
      }
    }
    return out;
  }

  /**
   * Where a dragged piece of `slot` would land if dropped at `rect`.
   * ok: it covers its own spot enough. Otherwise a reason the page can explain:
   * 'occupied' (it sits on another slot's spot), 'outside' (no spot there).
   */
  function dropTarget(allSpots, slot, rect, minOverlap = MIN_OVERLAP) {
    const own = allSpots.find(s => s.slot === slot);
    if (!own) return { ok: false, reason: 'unknown' };
    let blocker = null;
    let blockerShare = 0;
    for (const s of allSpots) {
      if (s.slot === slot) continue;
      const share = overlap(rect, s.rect);
      if (share > blockerShare) { blocker = s; blockerShare = share; }
    }
    const ownShare = overlap(rect, own.rect);
    if (ownShare >= minOverlap && ownShare >= blockerShare) return { ok: true, slot, rect: own.rect };
    if (blocker && blockerShare >= minOverlap) return { ok: false, reason: 'occupied', by: blocker.slot, byLabel: blocker.label };
    return { ok: false, reason: 'outside' };
  }

  // ---------- undo / redo ----------
  function same(a, b) {
    const keys = new Set([...Object.keys(a || {}), ...Object.keys(b || {})]);
    for (const k of keys) if ((a || {})[k] !== (b || {})[k]) return false;
    return true;
  }

  function createHistory(present, limit = HISTORY_LIMIT) {
    return Object.freeze({ past: Object.freeze([]), present: Object.freeze({ ...present }), future: Object.freeze([]), limit });
  }

  /** A new step. Equal states are not recorded; the oldest step drops past `limit`. */
  function record(h, next) {
    if (same(h.present, next)) return h;
    const past = [...h.past, h.present].slice(-h.limit);
    return Object.freeze({ past: Object.freeze(past), present: Object.freeze({ ...next }), future: Object.freeze([]), limit: h.limit });
  }

  function undo(h) {
    if (!h.past.length) return h;
    const past = h.past.slice(0, -1);
    return Object.freeze({
      past: Object.freeze(past), present: h.past[h.past.length - 1],
      future: Object.freeze([h.present, ...h.future]), limit: h.limit,
    });
  }

  function redo(h) {
    if (!h.future.length) return h;
    return Object.freeze({
      past: Object.freeze([...h.past, h.present].slice(-h.limit)), present: h.future[0],
      future: Object.freeze(h.future.slice(1)), limit: h.limit,
    });
  }

  function canUndo(h) { return h.past.length > 0; }
  function canRedo(h) { return h.future.length > 0; }

  // ---------- styles ----------
  /** Free default for every slot (variant 0 is free in the shared catalog). */
  function defaultArrangement(catalog) {
    const out = {};
    for (const slot of Array.isArray(catalog?.slots) ? catalog.slots : []) out[slot.slot] = 0;
    return out;
  }

  /** Next (dir 1) or previous (dir -1) owned variant of a slot, wrapping around. */
  function cycleVariant(catalog, owned, slot, current, dir = 1) {
    const def = (catalog?.slots || []).find(s => s.slot === slot);
    const mine = (def?.variants || []).map(v => v.index).filter(i => owned.get(slot)?.has(i)).sort((a, b) => a - b);
    if (!mine.length) return current;
    const at = mine.indexOf(current);
    if (at < 0) return mine[0];
    return mine[(at + (dir < 0 ? mine.length - 1 : 1)) % mine.length];
  }

  /** Changed slots between two arrangements, for an honest "what will be saved" line. */
  function changes(from, to) {
    return Object.keys(to || {}).filter(k => (from || {})[k] !== to[k]);
  }

  return Object.freeze({
    COLS, HISTORY_LIMIT, MIN_OVERLAP,
    grid, snapRect, rectAt, cellAt, overlap, intersection, spots, dropTarget,
    createHistory, record, undo, redo, canUndo, canRedo, same,
    defaultArrangement, cycleVariant, changes,
  });
});
