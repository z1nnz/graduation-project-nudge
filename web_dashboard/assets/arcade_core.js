(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  root.NudgeArcadeCore = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';
  // Break tickets, play sessions and local best records for the arcade hall.
  //
  // Rules (work package J1):
  //  - one Cloud-confirmed focus receipt of 25+ minutes gives 1 ticket,
  //    50+ minutes gives 2 tickets;
  //  - at most 2 tickets are held at once, each valid 2 hours after the
  //    receipt was verified;
  //  - one ticket buys 5 minutes of play, counted only while a game runs.
  // Scores never turn into coins or XP: nothing here writes to the Cloud.

  const FOCUS_TYPES = Object.freeze(['focus', 'study']);
  const ONE_TICKET_MINUTES = 25;
  const TWO_TICKET_MINUTES = 50;
  const MAX_TICKETS = 2;
  const TICKET_WINDOW_MS = 2 * 60 * 60 * 1000;
  const PLAY_MS_PER_TICKET = 5 * 60 * 1000;
  const USED_LIMIT = 40;
  const NO_TICKET_TEXT = '今天的免費次數用完了';
  // Everyone gets a few free plays a day (a day starts at 05:00, like the
  // rest of Nudge). Cloud-confirmed focus still earns bonus tickets.
  const FREE_PLAYS_PER_DAY = 3;
  const DAY_START_HOUR = 5;

  function ticketCount(minutes) {
    const m = Number(minutes);
    if (!Number.isFinite(m)) return 0;
    if (m >= TWO_TICKET_MINUTES) return 2;
    if (m >= ONE_TICKET_MINUTES) return 1;
    return 0;
  }

  /**
   * Tickets the player holds right now, soonest-expiring first.
   * usedIds holds spent ticket ids ("<receiptId>#<slot>"). A bare receipt id
   * (written by the older in-town game) spends every ticket of that receipt.
   */
  function availableTickets(receipts, nowMs, usedIds) {
    const used = new Set(Array.isArray(usedIds) ? usedIds : []);
    const out = [];
    for (const r of Array.isArray(receipts) ? receipts : []) {
      if (!r || typeof r.receiptId !== 'string' || !r.receiptId) continue;
      if (!FOCUS_TYPES.includes(r.activityType)) continue;
      const count = ticketCount(r.acceptedMetric);
      const verifiedAtMs = Date.parse(r.verifiedAt);
      if (!count || !Number.isFinite(verifiedAtMs)) continue;
      const expiresAt = verifiedAtMs + TICKET_WINDOW_MS;
      if (verifiedAtMs > nowMs || expiresAt <= nowMs) continue;
      if (used.has(r.receiptId)) continue;
      for (let slot = 1; slot <= count; slot += 1) {
        const id = `${r.receiptId}#${slot}`;
        if (!used.has(id)) out.push({ id, receiptId: r.receiptId, slot, expiresAt, playMs: PLAY_MS_PER_TICKET });
      }
    }
    out.sort((a, b) => a.expiresAt - b.expiresAt || a.id.localeCompare(b.id));
    return out.slice(0, MAX_TICKETS);
  }

  /**
   * Spend the soonest-expiring ticket. Returns null when there is none,
   * otherwise the spent ticket, the new used list and a fresh session.
   */
  function spendTicket(receipts, nowMs, usedIds, options = {}) {
    const list = options.free ? allTickets(receipts, nowMs, usedIds) : availableTickets(receipts, nowMs, usedIds);
    if (!list.length) return null;
    const ticket = list[0];
    const prior = Array.isArray(usedIds) ? usedIds.filter(x => typeof x === 'string') : [];
    const used = [...prior.filter(x => x !== ticket.id), ticket.id].slice(-USED_LIMIT);
    return { ticket, used, session: { ticketId: ticket.id, remainingMs: ticket.playMs } };
  }

  function playDay(nowMs) {
    const d = new Date(Number(nowMs) - DAY_START_HOUR * 3600 * 1000);
    const pad = n => String(n).padStart(2, '0');
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
  }

  /** Today's unused free plays. */
  function freeTickets(nowMs, usedIds) {
    const used = new Set(Array.isArray(usedIds) ? usedIds : []);
    const day = playDay(nowMs);
    const start = new Date(Number(nowMs) - DAY_START_HOUR * 3600 * 1000);
    start.setHours(0, 0, 0, 0);
    const expiresAt = start.getTime() + (24 + DAY_START_HOUR) * 3600 * 1000;
    const out = [];
    for (let slot = 1; slot <= FREE_PLAYS_PER_DAY; slot += 1) {
      const id = `free:${day}#${slot}`;
      if (!used.has(id)) out.push({ id, receiptId: null, slot, expiresAt, playMs: PLAY_MS_PER_TICKET, free: true });
    }
    return out;
  }

  /** Focus tickets first (they expire sooner), then today's free plays. */
  function allTickets(receipts, nowMs, usedIds) {
    return [...availableTickets(receipts, nowMs, usedIds), ...freeTickets(nowMs, usedIds)];
  }

  /** Play time left after `elapsedMs` of running (paused time is never passed in). */
  function drainSession(session, elapsedMs) {
    if (!validSession(session)) return null;
    const used = Math.max(0, Number(elapsedMs) || 0);
    return { ticketId: session.ticketId, remainingMs: Math.max(0, session.remainingMs - used) };
  }

  function validSession(session) {
    return Boolean(session && typeof session.ticketId === 'string' && session.ticketId &&
      Number.isFinite(session.remainingMs) && session.remainingMs > 0 &&
      session.remainingMs <= PLAY_MS_PER_TICKET);
  }

  /** Parse a stored session; anything odd counts as no session. */
  function readSession(raw) {
    let value = raw;
    if (typeof raw === 'string') { try { value = JSON.parse(raw); } catch { return null; } }
    if (!validSession(value)) return null;
    return { ticketId: value.ticketId, remainingMs: Math.round(value.remainingMs) };
  }

  function readList(raw) {
    try {
      const value = JSON.parse(raw || '[]');
      return Array.isArray(value) ? value.filter(x => typeof x === 'string') : [];
    } catch { return []; }
  }

  function formatClock(ms) {
    const total = Math.max(0, Math.ceil((Number(ms) || 0) / 1000));
    return `${Math.floor(total / 60)}:${String(total % 60).padStart(2, '0')}`;
  }

  // ---------- local best records, one key per account ----------
  function recordKey(uid, game) {
    if (typeof uid !== 'string' || !uid || !/^[a-z]+$/.test(String(game))) return null;
    return `nudge_arcade_best_${game}_${uid}`;
  }

  /**
   * kind 'high': bigger score wins (zero never counts). kind 'low': fewer moves, then less time.
   */
  function isBetter(kind, candidate, best) {
    if (!candidate) return false;
    if (kind === 'high') {
      // A zero score is not a record worth keeping.
      if (!(Number(candidate.score) > 0)) return false;
      return !best || Number(candidate.score) > Number(best.score);
    }
    if (kind !== 'low') throw new Error('unknown record kind');
    if (!best) return true;
    if (candidate.moves !== best.moves) return candidate.moves < best.moves;
    return candidate.ms < best.ms;
  }

  return Object.freeze({
    FOCUS_TYPES,
    MAX_TICKETS,
    TICKET_WINDOW_MS,
    PLAY_MS_PER_TICKET,
    NO_TICKET_TEXT,
    FREE_PLAYS_PER_DAY,
    ticketCount,
    playDay,
    freeTickets,
    allTickets,
    availableTickets,
    spendTicket,
    drainSession,
    validSession,
    readSession,
    readList,
    formatClock,
    recordKey,
    isBetter,
  });
});
