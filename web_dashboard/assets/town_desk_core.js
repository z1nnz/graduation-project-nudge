(function (root) {
  'use strict';
  // Pure rules for the town quest board and focus desk (#82 slice 2).
  // Timing is derived from timestamps, not from counting interval ticks, so a
  // session survives a refresh. Nothing here grants rewards: the desk only
  // queues the existing standalone focus evidence, and celebration waits for
  // the Cloud-written activity receipt of the same session.

  const STORAGE_PREFIX = 'nudge_town_desk_session_v1_';
  const OUTBOX_KEY = 'nudge_web_activity_ledger_outbox_v1';
  const DEAD_LETTER_KEY = 'nudge_web_activity_ledger_dead_letters_v1';
  const DURATIONS = Object.freeze([15, 25, 50]);
  const STATUSES = new Set(['active', 'paused', 'awaiting']);
  const AUTO_SOURCES = new Set(['sleepHours', 'steps', 'exerciseMinutes', 'focusMinutes', 'studyRoom']);

  function storageKey(uid) { return `${STORAGE_PREFIX}${uid}`; }

  function createSession(nowMs, minutes, random = Math.random) {
    const target = DURATIONS.includes(Number(minutes)) ? Number(minutes) : 25;
    return {
      sessionId: `web_focus_${nowMs}_${random().toString(36).slice(2, 10)}`,
      status: 'active',
      targetSeconds: target * 60,
      accumulatedSeconds: 0,
      resumedAtMs: nowMs,
      completedSeconds: null,
    };
  }

  function elapsedSeconds(session, nowMs) {
    if (!session) return 0;
    if (session.status === 'awaiting') return session.completedSeconds;
    const running = session.status === 'active' ? Math.max(0, (nowMs - session.resumedAtMs) / 1000) : 0;
    return Math.min(session.targetSeconds, Math.floor(session.accumulatedSeconds + running));
  }

  function remainingSeconds(session, nowMs) {
    return session ? Math.max(0, session.targetSeconds - elapsedSeconds(session, nowMs)) : 0;
  }

  function pause(session, nowMs) {
    if (session?.status !== 'active') return session;
    return { ...session, status: 'paused', accumulatedSeconds: elapsedSeconds(session, nowMs), resumedAtMs: null };
  }

  function resume(session, nowMs) {
    if (session?.status !== 'paused') return session;
    return { ...session, status: 'active', resumedAtMs: nowMs };
  }

  /** After the completed event is queued: keep the id to match the Cloud receipt. */
  function awaitConfirmation(session, nowMs) {
    return { ...session, status: 'awaiting', completedSeconds: elapsedSeconds(session, nowMs), resumedAtMs: null };
  }

  /** Validate what came back from localStorage; anything odd is dropped. */
  function parseStored(raw) {
    let value;
    try { value = JSON.parse(raw); } catch { return null; }
    if (!value || typeof value !== 'object') return null;
    const ok = typeof value.sessionId === 'string' && /^web_focus_\d+_[a-z0-9]+$/.test(value.sessionId) &&
      STATUSES.has(value.status) &&
      Number.isFinite(value.targetSeconds) && value.targetSeconds > 0 && value.targetSeconds <= 50 * 60 &&
      Number.isFinite(value.accumulatedSeconds) && value.accumulatedSeconds >= 0 &&
      (value.status !== 'active' || Number.isFinite(value.resumedAtMs)) &&
      (value.status !== 'awaiting' || Number.isFinite(value.completedSeconds));
    if (!ok) return null;
    return {
      sessionId: value.sessionId,
      status: value.status,
      targetSeconds: value.targetSeconds,
      accumulatedSeconds: value.accumulatedSeconds,
      resumedAtMs: value.status === 'active' ? value.resumedAtMs : null,
      completedSeconds: value.status === 'awaiting' ? value.completedSeconds : null,
    };
  }

  function listFrom(storage, key) {
    try {
      const value = JSON.parse(storage.getItem(key) || '[]');
      return Array.isArray(value) ? value : [];
    } catch { return []; }
  }

  /**
   * Honest status of one session's completed event:
   * confirmed (Cloud receipt seen) / rejected (dead letter) / sending (queued,
   * first attempt not finished) / pending (still in the outbox after a failed
   * attempt: offline or retrying) / sent (left the outbox, receipt not seen yet).
   */
  function confirmation({ uid, sessionId, receipt, storage }) {
    if (receipt) return { state: 'confirmed' };
    const matches = entry => entry?.actorUserId === uid && entry?.evidence?.sessionId === sessionId &&
      entry?.evidence?.eventType === 'completed';
    const rejected = listFrom(storage, DEAD_LETTER_KEY).find(matches);
    if (rejected) return { state: 'rejected', error: String(rejected.lastError || '') };
    // The outbox sends one account's events in order and stops at the first
    // failure, so an untried event behind a failed one is just as stuck.
    const mine = listFrom(storage, OUTBOX_KEY).filter(entry => entry?.actorUserId === uid);
    const pending = mine.find(matches);
    const failed = mine.filter(entry => Number(entry.attempts) > 0 || entry.lastError);
    if (pending && !failed.length) return { state: 'sending' };
    if (pending) {
      const worst = failed.reduce((a, b) => (Number(b.attempts) > Number(a.attempts) ? b : a));
      return { state: 'pending', attempts: Number(worst.attempts) || 0, error: worst.lastError ? String(worst.lastError) : '' };
    }
    return { state: 'sent' };
  }

  /** Board rows: what can be completed here, and why not otherwise. */
  function boardTasks(tasks, isDeadlineReady) {
    return (Array.isArray(tasks) ? tasks : [])
      .filter(t => t && typeof t === 'object' && typeof t.title === 'string' && t.title.trim() && t.id != null)
      .map(t => {
        const done = t.done === true || t.isDone === true;
        const auto = t.isAutoTracked === true || AUTO_SOURCES.has(t.sourceType);
        const deadlineReady = typeof isDeadlineReady === 'function' ? Boolean(isDeadlineReady(t)) : t.taskType !== 'deadline';
        let reason = '';
        if (done) reason = '已完成';
        else if (auto) reason = '自動追蹤，由健康資料或自律房同步';
        else if (!deadlineReady) reason = '截止日任務尚未到驗收日';
        return { id: String(t.id), title: t.title.trim(), done, canComplete: !done && !auto && deadlineReady, reason };
      })
      .sort((a, b) => Number(a.done) - Number(b.done));
  }

  function clock(seconds) {
    const s = Math.max(0, Math.round(seconds));
    return `${String(Math.floor(s / 60)).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`;
  }

  const api = {
    DURATIONS, STORAGE_PREFIX, storageKey, createSession, elapsedSeconds, remainingSeconds,
    pause, resume, awaitConfirmation, parseStored, confirmation, boardTasks, clock,
  };
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.NudgeTownDeskCore = api;
})(typeof globalThis !== 'undefined' ? globalThis : this);
