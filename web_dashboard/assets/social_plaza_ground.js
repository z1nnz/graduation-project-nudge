(() => {
  "use strict";
  const stage = document.querySelector(".plaza-scene");
  const motion = matchMedia("(prefers-reduced-motion: reduce)");
  let frame;
  let visible = false;
  let rendered = -1;
  function animate(now) {
    frame = undefined;
    if (motion.matches || document.hidden || !visible) return;
    const tick = Math.floor(now / 100);
    if (tick !== rendered) {
      rendered = tick;
      stage.style.setProperty("--w-water", [.7, 1, .88, .73][tick % 4]);
      stage.style.setProperty("--w-bird", (tick % 40) + "px");
    }
    frame = requestAnimationFrame(animate);
  }
  function sync() {
    if (frame != null) cancelAnimationFrame(frame);
    frame = undefined;
    if (motion.matches) stage.removeAttribute("style");
    else if (!document.hidden && visible) frame = requestAnimationFrame(animate);
  }
  new IntersectionObserver(entries => {
    visible = entries[0].isIntersecting;
    sync();
  }).observe(stage);
  motion.addEventListener("change", sync);
  document.addEventListener("visibilitychange", sync);
  for (const button of stage.querySelectorAll("[data-plaza-panel]")) {
    const panel = document.getElementById("plaza-" + button.dataset.plazaPanel);
    button.addEventListener("click", () => panel.showModal());
    panel.addEventListener("close", () => button.focus());
  }
})();
