(function (root, factory) {
  const api = factory();
  if (typeof module === "object" && module.exports) module.exports = api;
  if (root) root.NudgeTown = api;
})(typeof window !== "undefined" ? window : null, function () {
  "use strict";

  const places = Object.freeze({
    daily: Object.freeze({ title: "今日廣場", description: "從自己的下一步開始。已確認的活動會在總覽呈現。", href: "dashboard.html", x: 275, y: 205 }),
    rooms: Object.freeze({ title: "同伴會館", description: "看看已加入的活動房，按自己的節奏開始或繼續。", href: "rooms.html", x: 695, y: 220 }),
    profile: Object.freeze({ title: "角色小屋", description: "看看自己的角色、名片與成長紀錄。", href: "profile.html", x: 735, y: 450 }),
  });
  const bounds = Object.freeze({ minX: 90, maxX: 870, minY: 100, maxY: 525 });
  const directions = Object.freeze({ left: [-1, 0], right: [1, 0], up: [0, -1], down: [0, 1] });

  function move(position, direction, distance = 32) {
    const vector = directions[direction];
    if (!vector) return position;
    return {
      x: Math.min(bounds.maxX, Math.max(bounds.minX, position.x + vector[0] * distance)),
      y: Math.min(bounds.maxY, Math.max(bounds.minY, position.y + vector[1] * distance)),
    };
  }

  function nearestPlace(position) {
    return Object.entries(places).reduce((nearest, [key, place]) => {
      const distance = Math.hypot(place.x - position.x, place.y - position.y);
      return distance < nearest.distance ? { key, distance } : nearest;
    }, { key: "daily", distance: Infinity }).key;
  }

  function initialize(doc) {
    const viewport = doc.querySelector("[data-town-viewport]");
    const companion = doc.querySelector("[data-town-companion]");
    if (!viewport || !companion) return;
    let position = { x: 510, y: 385 };
    let selected = null;

    function paint(smooth = false) {
      companion.style.left = `${position.x}px`;
      companion.style.top = `${position.y}px`;
      const targetLeft = position.x - viewport.clientWidth / 2;
      const targetTop = position.y - viewport.clientHeight / 2;
      const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
      viewport.scrollTo({ left: targetLeft, top: targetTop, behavior: smooth && !reducedMotion ? "smooth" : "auto" });
    }

    function select(key) {
      const place = places[key];
      if (!place) return;
      selected = key;
      doc.querySelector("[data-town-title]").textContent = place.title;
      doc.querySelector("[data-town-description]").textContent = place.description;
      const enter = doc.querySelector("[data-town-enter]");
      enter.href = place.href;
      enter.innerHTML = `前往${place.title} <span aria-hidden="true">↗</span>`;
      doc.querySelectorAll("[data-town-place]").forEach(button => {
        button.setAttribute("aria-pressed", String(button.dataset.townPlace === key));
      });
      if (window.matchMedia("(max-width: 900px)").matches) {
        enter.focus({ preventScroll: true });
        enter.scrollIntoView({ block: "nearest", behavior: window.matchMedia("(prefers-reduced-motion: reduce)").matches ? "auto" : "smooth" });
      }
    }

    function step(direction) {
      position = move(position, direction);
      paint(true);
    }

    viewport.addEventListener("keydown", event => {
      if (event.target !== viewport) return;
      const direction = { ArrowLeft: "left", ArrowRight: "right", ArrowUp: "up", ArrowDown: "down" }[event.key];
      if (direction) {
        event.preventDefault();
        step(direction);
      } else if (event.key === "Enter") {
        event.preventDefault();
        select(nearestPlace(position));
      }
    });
    doc.querySelectorAll("[data-town-move]").forEach(button => {
      button.addEventListener("click", () => step(button.dataset.townMove));
    });
    doc.querySelectorAll("[data-town-place]").forEach(button => {
      button.addEventListener("click", () => select(button.dataset.townPlace));
    });
    doc.querySelector("[data-town-nearby]")?.addEventListener("click", () => select(nearestPlace(position)));
    paint();
  }

  if (typeof document !== "undefined") {
    if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", () => initialize(document));
    else initialize(document);
  }
  return { places, bounds, move, nearestPlace, initialize };
});
