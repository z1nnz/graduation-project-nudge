(function (root) {
  "use strict";
  const room = root.NudgePageRoom;
  if (!room) return;
  const doc = root.document,
    kind = doc.body.dataset.page || doc.body.dataset.townGate,
    isGate = kind === "login";
  if (!isGate && kind !== "privacy") return;
  const el =
    root.NudgeSceneRoom.el ||
    ((tag, text, attrs = {}) => {
      const n = doc.createElement(tag);
      if (text) n.textContent = text;
      for (const [k, v] of Object.entries(attrs)) n.setAttribute(k, v);
      return n;
    });
  let currentSeal = null;
  function firstSeal() {
    return new Promise((resolve) => {
      const dialog = el("dialog", null, {
          class: "studio-seal-dialog",
          role: "dialog",
          "aria-label": "第一道封印・閱讀刪除說明",
        }),
        canvas = el("canvas", null, {
          width: 144,
          height: 88,
          "aria-hidden": "true",
        }),
        cancel = el("button", "返回，保留帳號", {
          type: "button",
          class: "w-btn",
        }),
        next = el("button", "閱讀完成，前往第二步", {
          type: "button",
          class: "w-btn",
        });
      dialog.append(
        el("h2", "第一道封印・閱讀刪除說明"),
        canvas,
        el(
          "p",
          "這一步尚未送出申請。接著仍須在原來的第二道確認送出正式申請；送出後有 7 天冷靜期，可以取消。",
        ),
        cancel,
        next,
      );
      document.body.append(dialog);
      const focus = document.activeElement,
        media = root.matchMedia("(prefers-reduced-motion: reduce)");
      let raf = null,
        last = null,
        elapsed = 0,
        painted = -1,
        closed = false;
      function draw(frame) {
        const g = canvas.getContext("2d"),
          css = getComputedStyle(document.documentElement),
          color = (k) => css.getPropertyValue("--w-" + k);
        g.clearRect(0, 0, 144, 88);
        g.fillStyle = color("wood-deep");
        g.fillRect(16, 20 + 8 - frame, 44, 44);
        g.fillRect(86, 20, 44, 44);
        g.fillStyle = color("red");
        g.fillRect(20, 24 + 8 - frame, 36, 36);
        g.fillStyle = color("gold");
        g.fillRect(31, 38 + 8 - frame, 14, 5);
        g.fillRect(105, 34, 5, 19);
      }
      function pause() {
        if (raf !== null) cancelAnimationFrame(raf);
        raf = null;
        last = null;
      }
      function tick(now) {
        raf = null;
        if (closed || document.hidden) return;
        if (last !== null) elapsed += Math.min(now - last, 100);
        last = now;
        const frame = media.matches
          ? 0
          : Math.min(8, Math.floor(elapsed / 100));
        if (frame !== painted) {
          draw(frame);
          painted = frame;
        }
        if (!media.matches && frame < 8) raf = requestAnimationFrame(tick);
      }
      function resume() {
        pause();
        painted = -1;
        if (!closed && !document.hidden) raf = requestAnimationFrame(tick);
      }
      function close(ok) {
        if (closed) return;
        closed = true;
        pause();
        media.removeEventListener("change", resume);
        document.removeEventListener("visibilitychange", resume);
        root.removeEventListener("pagehide", abort);
        dialog.close();
        dialog.remove();
        if (focus?.isConnected) focus.focus({ preventScroll: true });
        currentSeal = null;
        resolve(ok);
      }
      const abort = () => close(false);
      cancel.addEventListener("click", abort);
      next.addEventListener("click", () => close(true));
      dialog.addEventListener("cancel", (e) => {
        e.preventDefault();
        e.stopPropagation();
        abort();
      });
      dialog.addEventListener("keydown", (e) => {
        if (e.key === "Escape") {
          e.preventDefault();
          e.stopPropagation();
          abort();
        }
      });
      media.addEventListener("change", resume);
      document.addEventListener("visibilitychange", resume);
      root.addEventListener("pagehide", abort);
      dialog.showModal();
      cancel.focus();
      currentSeal = { close: abort };
      resume();
    });
  }

  if (!isGate) {
    const button = doc.querySelector("[data-privacy-request-deletion]"),
      approved = new WeakSet();
    let confirming = false;
    button?.addEventListener(
      "click",
      async (e) => {
        if (approved.has(button)) {
          approved.delete(button);
          return;
        }
        e.preventDefault();
        e.stopImmediatePropagation();
        if (confirming || button.disabled) return;
        confirming = true;
        try {
          if (await firstSeal()) {
            approved.add(button);
            button.click();
          }
        } finally {
          confirming = false;
        }
      },
      true,
    );
  }
  let buddy = null,
    visible = true,
    authOff = null,
    authStarted = false,
    previous;
  const media = root.matchMedia("(prefers-reduced-motion: reduce)");
  if (isGate) {
    const node = el("span", null, {
      class: "studio-companion",
      "aria-hidden": "true",
    });
    room.frame.append(node);
    buddy = root.NudgeSpritePlayer.characterPlayer(node, "companion", {
      animation: "wave",
      size: 128,
    });
  }
  function sync() {
    if (doc.hidden || !visible || media.matches) buddy?.stop();
    else buddy?.play("wave");
  }
  const observer = new IntersectionObserver((entries) => {
    visible = entries[0].isIntersecting;
    sync();
  });
  observer.observe(room.stage);
  doc.addEventListener("visibilitychange", sync);
  media.addEventListener("change", sync);
  root.addEventListener("pagehide", () => {
    buddy?.stop();
    currentSeal?.close();
    authOff?.();
    authOff = null;
    authStarted = false;
    previous = undefined;
  });
  root.addEventListener("pageshow", () => {
    sync();
    auth();
  });
  function auth() {
    if (authStarted || !root.firebase?.apps?.length) return;
    authStarted = true;
    authOff = root.firebase.auth().onAuthStateChanged((user) => {
      const uid = user && !user.isAnonymous ? user.uid : null;
      if (!isGate && previous !== undefined && previous !== uid) {
        currentSeal?.close();
        room.closePanel();
      }
      previous = uid;
    });
  }
  doc.addEventListener("firebase-ready", auth);
  auth();
  sync();
})(typeof globalThis !== "undefined" ? globalThis : this);
