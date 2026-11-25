(() => {
  "use strict";
  const stage = document.querySelector(".plaza-scene");
  const motion = matchMedia("(prefers-reduced-motion: reduce)");
  const post = stage.querySelector('[data-plaza-panel="post"]');
  const letterPanel = document.getElementById("plaza-post");
  const message = letterPanel.querySelector("p");
  const line = message.textContent;
  const spoken = document.createElement("span");
  spoken.className = "w-npc-dialog__sr";
  spoken.textContent = line;
  message.before(spoken);
  message.setAttribute("aria-hidden", "true");
  const letty = NudgeSpritePlayer.characterPlayer(post.querySelector(".plaza-post-sprite"), "letty", { size: 64 });
  let portrait;
  let speakingSince = null;
  const route = [
    { x: 82, y: 36, animation: "walk_down" },
    { x: 82, y: 56, animation: "walk_left" },
    { x: 67, y: 56, animation: "walk_up" },
    { x: 67, y: 36, animation: "walk_right" },
  ];
  const legDuration = 2600;
  const idleDuration = 1400;
  const cycle = idleDuration + route.length * legDuration;
  let distance = 0;
  let updatedAt;
  let walkAnimation = "idle";
  function walk(next) {
    if (walkAnimation === next) return;
    letty.play(next);
    walkAnimation = next;
  }

  function move(now) {
    const inspecting = post.matches(":hover, :focus") || letterPanel.open;
    if (!inspecting && updatedAt != null) distance += now - updatedAt;
    updatedAt = now;
    if (inspecting) {
      walk("idle");
      return;
    }
    const elapsed = distance % cycle - idleDuration;
    if (elapsed < 0) {
      post.style.setProperty("--w-plaza-x", route[0].x + "%");
      post.style.setProperty("--w-plaza-y", route[0].y + "%");
      walk("idle");
      return;
    }
    const leg = Math.floor(elapsed / legDuration);
    const from = route[leg];
    const to = route[(leg + 1) % route.length];
    const step = Math.floor(elapsed % legDuration / 125) * 125 / legDuration;
    post.style.setProperty("--w-plaza-x", (from.x + (to.x - from.x) * step) + "%");
    post.style.setProperty("--w-plaza-y", (from.y + (to.y - from.y) * step) + "%");
    walk(from.animation);
  }
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
      move(now);
      if (speakingSince != null) {
        const shown = NudgeNpcDialog.typedLength(line, now - speakingSince);
        message.textContent = Array.from(line).slice(0, shown).join("");
        if (message.textContent === line) {
          speakingSince = null;
          portrait?.play("idle");
        }
      }
    }
    frame = requestAnimationFrame(animate);
  }
  function sync() {
    if (frame != null) cancelAnimationFrame(frame);
    frame = undefined;
    updatedAt = undefined;
    if (motion.matches) {
      stage.style.removeProperty("--w-water");
      stage.style.removeProperty("--w-bird");
      post.style.setProperty("--w-plaza-x", route[0].x + "%");
      post.style.setProperty("--w-plaza-y", route[0].y + "%");
      walk("idle");
      if (speakingSince != null) {
        speakingSince = null;
        message.textContent = line;
        portrait?.play("idle");
      }
    } else if (!document.hidden && visible) frame = requestAnimationFrame(animate);
  }
  new IntersectionObserver(entries => {
    visible = entries[0].isIntersecting;
    sync();
  }).observe(stage);
  motion.addEventListener("change", sync);
  document.addEventListener("visibilitychange", sync);
  addEventListener("pagehide", event => {
    if (event.persisted) return;
    letty.destroy();
    portrait?.destroy();
  });
  const openers = new WeakMap();
  const friendPanel = document.getElementById("plaza-friends");
  friendPanel.querySelector("[data-plaza-bench]").addEventListener("plaza-friend-open", event => {
    openers.set(friendPanel, event.detail);
    if (!friendPanel.open) friendPanel.showModal();
  });
  for (const button of stage.querySelectorAll("[data-plaza-panel]")) {
    const panel = document.getElementById("plaza-" + button.dataset.plazaPanel);
    button.addEventListener("click", () => {
      openers.set(panel, button);
      panel.showModal();
      if (panel === letterPanel) {
        message.textContent = motion.matches ? line : "";
        speakingSince = motion.matches ? null : performance.now();
        portrait = NudgeSpritePlayer.characterPlayer(
          panel.querySelector(".plaza-post-portrait"), "letty",
          { animation: motion.matches ? "idle" : "talk", size: 64 }
        );
      }
    });
    panel.addEventListener("close", () => {
      if (panel === letterPanel) {
        portrait?.destroy();
        portrait = undefined;
        speakingSince = null;
      }
      const opener = openers.get(panel);
      (opener?.isConnected ? opener : button).focus();
    });
  }
})();
