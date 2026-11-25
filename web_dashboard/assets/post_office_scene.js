(() => {
  "use strict";
  const scene = document.querySelector(".post-office-scene");
  const motion = matchMedia("(prefers-reduced-motion: reduce)");
  const guide = scene.querySelector("[data-post-office-guide]");
  const letty = NudgeSpritePlayer.characterPlayer(guide.querySelector(".post-office-actor"), "letty", { size: 64 });
  addEventListener("pagehide", event => {
    if (!event.persisted) letty.destroy();
  });
  let frame;
  let visible = false;
  let tick = -1;
  function animate(now) {
    frame = undefined;
    if (motion.matches || document.hidden || !visible) return;
    const next = Math.floor(now / 100);
    if (next !== tick) {
      tick = next;
      scene.style.setProperty("--w-post-light", [.5, .68, .8, .66][tick % 4]);
      scene.style.setProperty("--w-post-dust", (tick % 18) + "px");
    }
    frame = requestAnimationFrame(animate);
  }
  function sync() {
    if (frame != null) cancelAnimationFrame(frame);
    frame = undefined;
    if (motion.matches) scene.removeAttribute("style");
    else if (!document.hidden && visible) frame = requestAnimationFrame(animate);
  }
  new IntersectionObserver(entries => {
    visible = entries[0].isIntersecting;
    sync();
  }).observe(scene);
  motion.addEventListener("change", sync);
  document.addEventListener("visibilitychange", sync);
  guide.addEventListener("click", () => NudgeNpcDialog.open({
    speaker: "letty",
    lines: ["來信放在信箱，拆過的信會收進抽屜。想設定提醒時，看看鬧鐘架。"],
    portraitSize: 64,
    actions: [{ label: "關閉" }],
  }));
  for (const link of scene.querySelectorAll('a[href^="#"]')) link.addEventListener("click", () => {
    const destination = document.querySelector(link.hash);
    if (destination instanceof HTMLDetailsElement) destination.open = true;
    destination?.focus();
  });
})();
