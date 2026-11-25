(() => {
  "use strict";
  const ground = document.querySelector("[data-community-ground]");
  const motion = matchMedia("(prefers-reduced-motion: reduce)");
  const isFamily = ground.classList.contains("community-ground--courtyard");
  const speaker = isFamily ? "sprout" : "scroll";
  const message = isFamily
    ? "你可以看看共同花圃、在桌上寫每週回顧，或到信箱安排鼓勵信。"
    : "翻開日曆就能看團體活動。壁畫和辦公室在另一側。";
  const actor = NudgeSpritePlayer.characterPlayer(ground.querySelector(".community-actor"), speaker, { size: 64 });
  addEventListener("pagehide", event => {
    if (!event.persisted) actor.destroy();
  });
  const calendar = document.querySelector("[data-guild-calendar]");
  const manager = document.querySelector("[data-guild-manager]");
  const office = ground.querySelector("[data-community-open=office]");
  let opener, frame, rendered;
  let visible = false;

  function animate(now) {
    frame = undefined;
    if (motion.matches || document.hidden || !visible) return;
    const tick = Math.floor(now / 100);
    if (tick !== rendered) {
      rendered = tick;
      ground.style.setProperty("--w-ember", (tick % 16) + "px");
      ground.style.setProperty("--w-halo", [.35, .55, .65, .5][tick % 4]);
    }
    frame = requestAnimationFrame(animate);
  }
  function sync() {
    if (frame != null) cancelAnimationFrame(frame);
    frame = undefined;
    if (motion.matches) {
      ground.removeAttribute("style");
    } else if (visible && !document.hidden) frame = requestAnimationFrame(animate);
  }
  new IntersectionObserver(entries => {
    visible = entries[0].isIntersecting;
    sync();
  }).observe(ground);
  motion.addEventListener("change", sync);
  document.addEventListener("visibilitychange", sync);
  if (manager && calendar) {
    const syncOffice = () => { office.disabled = manager.hidden || calendar.hidden; };
    const permissions = new MutationObserver(syncOffice);
    permissions.observe(manager, { attributes: true, attributeFilter: ["hidden"] });
    permissions.observe(calendar, { attributes: true, attributeFilter: ["hidden"] });
    syncOffice();
  }
  ground.addEventListener("click", event => {
    const stop = event.target.closest("[data-community-open]");
    if (!stop) return;
    opener = stop;
    const destination = stop.dataset.communityOpen;
    if (destination === "guide") {
      NudgeNpcDialog.open({
        speaker,
        lines: [message],
        portraitSize: 64,
        actions: [{ label: "關閉" }],
      });
      return;
    }
    const panel = document.querySelector('[data-community-panel="' + destination + '"]');
    if (panel.parentElement.closest("[hidden]")) return;
    for (const other of document.querySelectorAll("[data-community-panel][data-opened]")) {
      other.hidden = true;
      delete other.dataset.opened;
    }
    panel.dataset.opened = "";
    panel.hidden = false;
    panel.focus();
  });
  for (const action of document.querySelectorAll("[data-community-return]")) action.addEventListener("click", () => {
    const panel = action.closest("[data-community-panel]");
    panel.hidden = true;
    delete panel.dataset.opened;
    opener?.focus();
  });
})();
