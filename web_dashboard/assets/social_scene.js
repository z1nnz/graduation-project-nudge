// Social facility scenes (#105): study tower, family courtyard, group hall
// and plaza. Each page declares <body data-social-facility="family|guild|tower|plaza">
// and gets the in-scene navigation between the rooms of that facility.
// Presentation only: every page keeps its own login, role and Cloud checks.
(function (root, factory) {
  const api = factory();
  if (typeof module === "object" && module.exports) module.exports = api;
  if (root) root.NudgeSocialScene = api;
})(typeof globalThis !== "undefined" ? globalThis : this, function () {
  "use strict";

  const SCENES = Object.freeze({
    tower: Object.freeze({
      place: "專注塔 · 自律房",
      rooms: Object.freeze([
        ["rooms.html", "自習室"],
        ["room-chat.html", "夥伴聊天室"],
      ]),
    }),
    family: Object.freeze({
      place: "家庭庭院",
      rooms: Object.freeze([
        ["family-courtyard.html", "庭院"],
        ["guardian.html", "陪伴小屋"],
        ["guardian-encouragement.html", "鼓勵卡信箱"],
        ["guardian-goals.html", "共同目標樹"],
        ["guardian-report.html", "週報書桌"],
        ["guardian-permissions.html", "分享同意"],
        ["guardian-link.html", "連結家人"],
      ]),
    }),
    guild: Object.freeze({
      place: "團體會館",
      rooms: Object.freeze([
        ["group-hall.html", "會館大廳"],
        ["groups.html", "共同進度"],
        ["groups-challenge.html", "挑戰布告欄"],
        ["groups-study-schedule.html", "共讀時段"],
        ["groups-templates.html", "倒數模板"],
        ["groups-ranking.html", "成果牆"],
        ["groups-link.html", "加入或建立"],
      ]),
    }),
    plaza: Object.freeze({
      place: "小鎮廣場",
      rooms: Object.freeze([
        ["mailbox.html", "郵箱"],
        ["notifications.html", "通知與邀請"],
        ["friend.html", "好友"],
        ["friend-visits.html", "好友拜訪"],
      ]),
    }),
  });

  function fileOf(path) {
    return String(path || "").split("#")[0].split("?")[0].split("/").pop() || "";
  }

  function navFor(sceneId, currentPath) {
    const scene = SCENES[sceneId];
    if (!scene) return null;
    const current = fileOf(currentPath);
    return {
      place: scene.place,
      links: scene.rooms.map(([href, label]) => ({ href, label, current: href === current })),
    };
  }

  // Walking into the courtyard or hall is the player's choice of relationship
  // context, which the retired sidebar switch used to record. It is only a UI
  // preference: role gates in app.js and Firestore Rules still decide access.
  const CONTEXT_BY_SCENE = Object.freeze({ family: "family", guild: "group" });

  function applyRelationshipContext(storage, sceneId, userId) {
    const context = CONTEXT_BY_SCENE[sceneId];
    if (!storage || !context || !userId) return null;
    storage.setItem(`nudgeRelationshipContext:${userId}`, context);
    return context;
  }

  return Object.freeze({ SCENES, CONTEXT_BY_SCENE, navFor, fileOf, applyRelationshipContext });
});

(function (root) {
  "use strict";
  const doc = root.document;
  const api = root.NudgeSocialScene;
  if (!doc || !api) return;
  const sceneId = doc.body?.dataset.socialFacility;
  try {
    // Synchronous, before app.js runs its role gate for this page.
    api.applyRelationshipContext(root.localStorage, sceneId, root.localStorage?.getItem("nudgeActiveDemoUserId"));
  } catch (_) { /* storage blocked: the page falls back to its own gate */ }
  doc.addEventListener("firebase-ready", () => {
    try {
      api.applyRelationshipContext(root.localStorage, sceneId, root.firebase?.auth?.().currentUser?.uid);
    } catch (_) { /* storage blocked */ }
  });
  function render() {
    const sceneId = doc.body?.dataset.socialFacility;
    const model = api.navFor(sceneId, root.location?.pathname);
    if (!model) return;
    const place = doc.querySelector("[data-scene-place]");
    if (place && !place.textContent.trim()) place.textContent = model.place;
    const nav = doc.querySelector("[data-scene-nav]");
    if (!nav) return;
    nav.setAttribute("aria-label", `${model.place}裡的地點`);
    nav.replaceChildren(...model.links.map(link => {
      const a = doc.createElement("a");
      a.href = link.href;
      a.textContent = link.label;
      if (link.current) a.setAttribute("aria-current", "page");
      return a;
    }));
  }
  if (doc.readyState === "loading") doc.addEventListener("DOMContentLoaded", render);
  else render();
})(typeof globalThis !== "undefined" ? globalThis : this);
