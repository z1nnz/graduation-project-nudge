(function (root, factory) {
  const api = factory();
  if (typeof module === "object" && module.exports) {
    module.exports = api;
  } else {
    root.NudgeFamilyLinkContract = api;
  }
})(typeof globalThis !== "undefined" ? globalThis : this, function () {
  function parseRole(value) {
    const role = String(value || "").trim().toLowerCase();
    if (role !== "guardian" && role !== "child") {
      throw new Error("A family link requires one guardian and one child.");
    }
    return role;
  }

  function buildFamilyLinkPayload({
    linkId,
    senderId,
    senderRole,
    receiverId,
    receiverRole,
    now = new Date().toISOString(),
  }) {
    const sender = parseRole(senderRole);
    const receiver = parseRole(receiverRole);
    if (sender === receiver) {
      throw new Error("A family link requires one guardian and one child.");
    }

    const guardianId = sender === "guardian" ? senderId : receiverId;
    const childId = sender === "child" ? senderId : receiverId;
    return {
      schemaVersion: 1,
      guardianId,
      childId,
      participantIds: [guardianId, childId],
      status: "active",
      consentScopes: {
        summary: true,
        weeklyReport: false,
        taskCategories: false,
        healthTrends: false,
      },
      createdAt: now,
      updatedAt: now,
    };
  }

  function buildEncouragementPayload({
    guardianId,
    childId,
    title,
    message,
    now = new Date().toISOString(),
  }) {
    return {
      schemaVersion: 1,
      senderId: guardianId,
      recipientId: childId,
      title: String(title || "").trim(),
      message: String(message || "").trim(),
      status: "sent",
      createdAt: now,
    };
  }

  function buildSharedGoalPayload({
    guardianId,
    childId,
    title,
    message,
    now = new Date().toISOString(),
  }) {
    return {
      schemaVersion: 1,
      title: String(title || "").trim(),
      message: String(message || "").trim(),
      status: "proposed",
      proposedBy: guardianId,
      decisionBy: childId,
      createdAt: now,
      updatedAt: now,
    };
  }

  const FamilyBondPolicy = Object.freeze({
    pointsFor(eventType) {
      if (eventType === "acknowledgement") return 3;
      if (eventType === "goalCompleted") return 10;
      return 0;
    },
    levelForXp(xp) {
      if (xp >= 30) return 3;
      if (xp >= 10) return 2;
      return 1;
    },
  });

  return {
    FamilyBondPolicy,
    buildEncouragementPayload,
    buildFamilyLinkPayload,
    buildSharedGoalPayload,
  };
});
