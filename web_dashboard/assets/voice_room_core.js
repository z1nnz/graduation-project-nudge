(function (root) {
  "use strict";

  const maxParticipants = 8;
  const heartbeatTimeoutMs = 120_000;

  function shouldOffer(selfUid, peerUid) {
    return typeof selfUid === "string" && typeof peerUid === "string" && selfUid < peerUid;
  }

  function heartbeatExpired(updatedAt, now = Date.now()) {
    const ms = updatedAt?.toMillis?.();
    return !Number.isFinite(ms) || now - ms >= heartbeatTimeoutMs;
  }

  const api = Object.freeze({ maxParticipants, heartbeatTimeoutMs, shouldOffer, heartbeatExpired });
  if (typeof module === "object" && module.exports) module.exports = api;
  else root.NudgeVoiceRoomCore = api;
})(globalThis);
