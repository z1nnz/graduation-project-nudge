(function (root) {
  "use strict";
  const doc = root.document;
  function el(tag, text, attrs = {}) {
    const n = doc.createElement(tag);
    if (text != null) n.textContent = text;
    for (const [k, v] of Object.entries(attrs)) n.setAttribute(k, v);
    return n;
  }
  function mount({
    title,
    background,
    npc = "inky",
    line = "點開場景裡的物件，慢慢看看自己的紀錄。",
    objects = [],
    content = doc.querySelector("main"),
  }) {
    const stage = el("section", null, {
      class: "facility-stage",
      "aria-label": title + "場景",
    });
    stage.style.backgroundImage = 'url("' + background + '")';
    const canvas = el("canvas", null, {
      "aria-hidden": "true",
      class: "facility-life",
    });
    stage.append(canvas);
    const dialog = el("dialog", null, {
        class: "facility-panel",
        role: "dialog",
        "aria-label": title + "功能",
      }),
      heading = el("h2", title),
      close = el("button", "闔上，回到場景", {
        type: "button",
        class: "w-btn",
      }),
      inside = el("div", null, { class: "facility-content" }),
      bar = el("div", null, { class: "facility-panel-bar" });
    bar.append(heading, close);
    dialog.append(bar, inside);
    if (content) content.before(stage);
    else doc.body.append(stage);
    doc.body.append(dialog);
    if (content) inside.append(content);
    let speech = null,
      returnFocus = null,
      guideLine = line;
    function hide() {
      if (!dialog.open) return;
      dialog.close();
      returnFocus?.focus({ preventScroll: true });
    }
    function open({ title: label = title, content: next = content } = {}) {
      returnFocus = doc.activeElement;
      heading.textContent = label;
      if (next) inside.replaceChildren(next);
      if (!dialog.open) dialog.showModal();
      close.focus({ preventScroll: true });
    }
    close.addEventListener("click", hide);
    dialog.addEventListener("cancel", (e) => {
      e.preventDefault();
      e.stopPropagation();
      hide();
    });
    dialog.addEventListener("keydown", (e) => {
      if (e.key === "Escape") {
        e.preventDefault();
        e.stopPropagation();
        hide();
      }
    });
    const npcButton = el("button", null, {
        type: "button",
        class: "facility-npc",
        "aria-label":
          "與" +
          (root.NudgeSpritePlayer.CATALOG.characters.find((c) => c.id === npc)
            ?.name || "夥伴") +
          "交談",
      }),
      sprite = el("span", null, { "aria-hidden": "true" });
    npcButton.append(
      sprite,
      el(
        "span",
        root.NudgeSpritePlayer.CATALOG.characters.find((c) => c.id === npc)
          ?.name || "夥伴",
        { class: "facility-name" },
      ),
    );
    stage.append(npcButton);
    const player = root.NudgeSpritePlayer.characterPlayer(sprite, npc, {
      animation: "idle",
      size: 128,
    });
    npcButton.addEventListener("click", () => {
      speech = root.NudgeNpcDialog.open({ speaker: npc, lines: [guideLine] });
      const box = doc.querySelector(".w-npc-dialog");
      box?.setAttribute("aria-modal", "true");
      box?.addEventListener("keydown", (e) => {
        if (e.key === "Escape") e.stopPropagation();
        if (e.key === "Tab") {
          const choices = [
            box,
            ...box.querySelectorAll('button:not([hidden]),[tabindex=\"0\"]'),
          ].filter((n) => !n.closest("[hidden]"));
          const i = choices.indexOf(doc.activeElement);
          e.preventDefault();
          choices[
            (i + (e.shiftKey ? -1 : 1) + choices.length) % choices.length
          ]?.focus();
        }
      });
    });
    const hotspots = objects.map((o) => {
      const b = el("button", null, {
        type: "button",
        class: "facility-object",
        "aria-label": o.label,
        title: o.label,
      });
      b.style.left = o.x + "%";
      b.style.top = o.y + "%";
      b.append(
        el("span", o.symbol || "✦", {
          "aria-hidden": "true",
          class: "facility-symbol",
        }),
        el("span", o.label, { class: "facility-name" }),
      );
      b.addEventListener("click", () => (o.onSelect ? o.onSelect() : open()));
      stage.append(b);
      return b;
    });
    const media = root.matchMedia("(prefers-reduced-motion: reduce)");
    let raf = null,
      visible = true,
      last = null,
      elapsed = 0,
      lastFrame = -1;
    const g = canvas.getContext("2d");
    function paint(frame) {
      const rect = stage.getBoundingClientRect(),
        dpr = Math.min(root.devicePixelRatio || 1, 2);
      if (
        canvas.width !== Math.round(rect.width * dpr) ||
        canvas.height !== Math.round(rect.height * dpr)
      ) {
        canvas.width = Math.round(rect.width * dpr);
        canvas.height = Math.round(rect.height * dpr);
      }
      g.setTransform(dpr, 0, 0, dpr, 0, 0);
      g.clearRect(0, 0, rect.width, rect.height);
      const palette = root.getComputedStyle(doc.documentElement),
        gold = palette.getPropertyValue("--w-gold"),
        wood = palette.getPropertyValue("--w-wood-deep");
      g.fillStyle = gold;
      g.globalAlpha = 0.4;
      for (let i = 0; i < 16; i++) {
        const x = ((i * 0.173 + frame * 0.0009) % 1) * rect.width,
          y = ((i * 0.137 - frame * 0.0011) % 1) * rect.height;
        g.fillRect(Math.floor(x), Math.floor(y), 2, 2);
      }
      for (const x of [0.17, 0.83])
        g.fillRect(
          Math.floor(rect.width * x),
          Math.floor(rect.height * 0.18),
          4 + (frame % 2) * 2,
          8 + (frame % 3) * 2,
        );
      g.globalAlpha = 0.7;
      g.fillStyle = wood;
      const x = Math.floor(rect.width * 0.37 + (frame % 60)),
        y = Math.floor(rect.height * 0.23);
      g.fillRect(x, y, 6, 2);
      g.fillRect(x + 6, y + 2, 6, 2);
      g.globalAlpha = 1;
      for (const b of hotspots)
        b.style.transform = media.matches
          ? "none"
          : "translateY(" + Math.round(Math.sin(frame / 8) * 2) + "px)";
    }
    function tick(now) {
      raf = null;
      if (doc.hidden || !visible) return;
      if (last !== null) elapsed += Math.min(now - last, 100);
      last = now;
      const frame = media.matches ? 0 : Math.floor(elapsed / 100);
      if (frame !== lastFrame) {
        paint(frame);
        lastFrame = frame;
      }
      const intro = media.matches ? 1 : Math.min(1, elapsed / 400);
      stage.style.transform = "scale(" + (1.04 - 0.04 * intro) + ")";
      stage.style.opacity = String(0.6 + 0.4 * intro);
      if (!media.matches) raf = root.requestAnimationFrame(tick);
    }
    function pause() {
      if (raf !== null) root.cancelAnimationFrame(raf);
      raf = null;
      last = null;
      player.stop();
    }
    function resume() {
      pause();
      lastFrame = -1;
      if (!doc.hidden && visible) {
        player.play("idle");
        raf = root.requestAnimationFrame(tick);
      } else {
        speech?.close();
        speech = null;
      }
    }
    const observer = new IntersectionObserver((entries) => {
      visible = entries[0].isIntersecting;
      resume();
    });
    observer.observe(stage);
    doc.addEventListener("visibilitychange", resume);
    media.addEventListener("change", resume);
    root.addEventListener("resize", resume);
    root.addEventListener("pagehide", pause);
    root.addEventListener("pageshow", resume);
    resume();
    return Object.freeze({
      stage,
      dialog,
      open,
      close: hide,
      content,
      setGuideLine: (s) => (guideLine = s),
      destroy() {
        pause();
        observer.disconnect();
        player.destroy();
        media.removeEventListener("change", resume);
        doc.removeEventListener("visibilitychange", resume);
        root.removeEventListener("resize", resume);
        root.removeEventListener("pagehide", pause);
        root.removeEventListener("pageshow", resume);
        dialog.remove();
        stage.remove();
      },
    });
  }
  root.NudgeFacilityScene = Object.freeze({ mount, el });
})(typeof globalThis !== "undefined" ? globalThis : this);
