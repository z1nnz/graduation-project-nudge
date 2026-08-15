(function attachRoomResonanceContract(root) {
  const cueKeys = [
    "gentle_restart",
    "open_to_company",
    "starting_small",
    "completed_step",
  ];
  const responseKeys = ["with_you", "cheer", "take_your_time"];

  function requireText(value, label) {
    const text = String(value || "").trim();
    if (!text) throw new Error(`${label} is required`);
    return text;
  }

  function requireDate(value, label) {
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) throw new Error(`${label} is invalid`);
    return date.toISOString();
  }

  function parsePreference(expectedRoomId, expectedUserId, raw) {
    const roomId = requireText(raw?.roomId, "roomId");
    const userId = requireText(raw?.userId, "userId");
    if (
      raw?.schemaVersion !== 1 ||
      roomId !== expectedRoomId ||
      userId !== expectedUserId ||
      raw.preferenceId !== `${roomId}--${userId}` ||
      typeof raw.enabled !== "boolean" ||
      raw.audience !== "room_members_only" ||
      raw.shareMode !== "cue_only"
    ) {
      throw new Error("Invalid room resonance preference");
    }
    return {
      schemaVersion: 1,
      preferenceId: raw.preferenceId,
      roomId,
      userId,
      enabled: raw.enabled,
      audience: raw.audience,
      shareMode: raw.shareMode,
      updatedAt: requireDate(raw.updatedAt, "updatedAt"),
    };
  }

  function parseSignal(expectedRoomId, raw) {
    const roomId = requireText(raw?.roomId, "roomId");
    const ownerUserId = requireText(raw?.ownerUserId, "ownerUserId");
    const createdAt = requireDate(raw?.createdAt, "createdAt");
    const updatedAt = requireDate(raw?.updatedAt, "updatedAt");
    const expiresAt = requireDate(raw?.expiresAt, "expiresAt");
    const withdrawnAt = raw?.withdrawnAt == null
      ? null
      : requireDate(raw.withdrawnAt, "withdrawnAt");
    if (
      raw?.schemaVersion !== 1 ||
      roomId !== expectedRoomId ||
      raw.signalId !== `${roomId}--${ownerUserId}` ||
      !/^[A-Za-z0-9_-]{8,128}$/.test(String(raw.generationId || "")) ||
      !cueKeys.includes(raw.cueKey) ||
      !["active", "withdrawn"].includes(raw.status) ||
      raw.visibility !== "room_members_only" ||
      !Number.isInteger(raw.acknowledgementCount) ||
      raw.acknowledgementCount < 0 ||
      Date.parse(updatedAt) < Date.parse(createdAt) ||
      Date.parse(expiresAt) <= Date.parse(createdAt) ||
      (raw.status === "active" && withdrawnAt !== null) ||
      (raw.status === "withdrawn" && withdrawnAt === null)
    ) {
      throw new Error("Invalid room resonance signal");
    }
    return {
      schemaVersion: 1,
      signalId: raw.signalId,
      roomId,
      ownerUserId,
      generationId: raw.generationId,
      cueKey: raw.cueKey,
      status: raw.status,
      visibility: raw.visibility,
      acknowledgementCount: raw.acknowledgementCount,
      createdAt,
      updatedAt,
      expiresAt,
      withdrawnAt,
    };
  }

  function isVisible(signal, now = new Date()) {
    return signal.status === "active" &&
      Date.parse(signal.expiresAt) > now.getTime();
  }

  const contract = {
    cueKeys,
    responseKeys,
    parsePreference,
    parseSignal,
    isVisible,
  };
  root.NudgeRoomResonanceContract = contract;
  if (typeof module !== "undefined" && module.exports) {
    module.exports = contract;
  }
})(typeof window !== "undefined" ? window : globalThis);
