// Study Room scene presenter. Pure functions only: the shared Firestore
// listeners stay in app.js, and this module decides what the scene may show.
//
// Privacy boundary: a seat exposes only the approved member's display name,
// role, and one bounded posture derived from their own presence projection.
// It never reads metricValue, sessionSeconds, activeSessionId, or any Ledger
// field of another member.
(function (root, factory) {
  const api = factory();
  if (typeof module === "object" && module.exports) module.exports = api;
  if (root) root.NudgeRoomScene = api;
})(typeof window !== "undefined" ? window : null, function () {
  "use strict";

  const postures = Object.freeze({
    studying: Object.freeze({ key: "focusing", label: "專注中", glyph: "✎" }),
    resting: Object.freeze({ key: "seated", label: "在座位上", glyph: "☕" }),
    offline: Object.freeze({ key: "away", label: "暫時離座", glyph: "·" }),
  });

  function postureFor(presenceStatus) {
    return postures[presenceStatus] || postures.offline;
  }

  // Only fields listed here can ever reach the DOM for another member.
  function seatFor(member, viewerId) {
    const posture = postureFor(member.presenceStatus);
    return Object.freeze({
      memberId: String(member.memberId || ""),
      displayName: String(member.displayName || "自律夥伴").slice(0, 40),
      isOwner: member.role === "owner",
      isViewer: member.memberId === viewerId,
      postureKey: posture.key,
      postureLabel: posture.label,
      glyph: posture.glyph,
    });
  }

  // Returns the scene model for the selected room. A viewer who is not an
  // approved member gets no seats at all, even if Firestore delivered member
  // documents, so a pending or removed member cannot inspect the room.
  function buildScene({ members = [], viewerId = null, memberLimit = 0 } = {}) {
    const viewer = members.find(member => member.memberId === viewerId) || null;
    const viewerApproved = viewer?.approvalStatus === "approved";
    if (!viewerId || !viewerApproved) {
      return Object.freeze({
        viewerApproved: false,
        viewerSeated: false,
        seats: Object.freeze([]),
        approvedCount: 0,
        focusingCount: 0,
        emptySeats: 0,
      });
    }
    const approved = members.filter(member => member.approvalStatus === "approved");
    const seats = approved
      .map(member => seatFor(member, viewerId))
      .sort((a, b) =>
        Number(b.isViewer) - Number(a.isViewer) ||
        Number(b.isOwner) - Number(a.isOwner) ||
        a.displayName.localeCompare(b.displayName, "zh-Hant"));
    const limit = Number.isInteger(memberLimit) && memberLimit > 0 ? memberLimit : seats.length;
    return Object.freeze({
      viewerApproved: true,
      viewerSeated: viewer.presenceStatus !== "offline",
      seats: Object.freeze(seats),
      approvedCount: seats.length,
      focusingCount: seats.filter(seat => seat.postureKey === "focusing").length,
      emptySeats: Math.max(0, Math.min(limit, 12) - seats.length),
    });
  }

  // Presence the viewer should publish after their own Cloud-accepted
  // activity transition. Presence is a coarse posture, never a metric.
  function presenceAfterTransition(nextStatus) {
    if (nextStatus === "active") return "studying";
    if (["paused", "completed", "cancelled"].includes(nextStatus)) return "resting";
    return null;
  }

  // Decides whether the viewer may leave and how. Returns a plain decision so
  // the UI can explain the reason instead of attempting a rejected write.
  function leaveDecision({ room = {}, viewerId = null, sessionStatus = null } = {}) {
    if (!viewerId || !room.id) return { allowed: false, reason: "not_member" };
    if (["active", "paused"].includes(sessionStatus)) {
      return { allowed: false, reason: "session_running" };
    }
    if (room.ownerId !== viewerId) return { allowed: true, mode: "leave" };
    const others = (room.memberIds || []).filter(id => id !== viewerId);
    if (others.length > 0) return { allowed: false, reason: "owner_must_transfer" };
    return { allowed: true, mode: "close" };
  }

  return Object.freeze({
    postureFor,
    buildScene,
    presenceAfterTransition,
    leaveDecision,
  });
});
