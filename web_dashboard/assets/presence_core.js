(function (root, factory) {
  const api = factory();
  if (typeof module === "object" && module.exports) module.exports = api;
  else root.NudgePresenceCore = api;
})(globalThis, function () {
  "use strict";

  function buildingForPath(routes, path) {
    const destination = routes.destinationForPage(path);
    return destination?.audience === "player" && !destination.scene &&
      routes.isBuilding(destination.building) && destination.id !== "login"
      ? destination.building
      : null;
  }

  function visiblePresence(record, buildings, now) {
    const expiry = record?.expiresAt?.toMillis?.();
    return typeof record?.uid === "string" &&
      Object.hasOwn(buildings, record.building) &&
      record.page === record.building &&
      Number.isFinite(expiry) && expiry > now
      ? { uid: record.uid, building: record.building, expiresAt: expiry }
      : null;
  }

  return Object.freeze({ buildingForPath, visiblePresence });
});
