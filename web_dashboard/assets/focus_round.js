(() => {
  "use strict";

  const core = window.NudgeFocusRoundCore;
  const panel = document.querySelector("[data-focus-round]");
  const status = panel.querySelector("[data-focus-round-status]");
  const timer = panel.querySelector("time");
  const celebration = panel.querySelector("[data-focus-round-celebration]");
  const start = panel.querySelector("[data-focus-round-start]");
  const join = panel.querySelector("[data-focus-round-join]");
  let current = null;
  let clock = null;

  async function calibrate(getServerTime) {
    const start = performance.now();
    const server = await getServerTime();
    clock = { millis: server, measuredAt: (start + performance.now()) / 2 };
  }

  const now = () => clock.millis + performance.now() - clock.measuredAt;

  function render() {
    if (!current) return;
    const { round, pending, canJoin, joinedAt, failure, ready } = current;
    if (!clock || !ready) {
      status.textContent = failure || "正在同步伺服器時間…";
      start.disabled = true;
      join.hidden = true;
      return;
    }
    const { phase, remaining } = core.snapshot(round, now());
    if (current.phase === "focus" && phase === "break") {
      celebration.hidden = false;
      celebration.classList.remove("focus-round-fireworks");
      requestAnimationFrame(() => celebration.classList.add("focus-round-fireworks"));
    } else if (phase !== "break") {
      celebration.hidden = true;
    }
    current.phase = phase;
    const label = { idle: "可以發起新一輪", focus: "一起專注中", break: "完成這一輪，休息 5 分鐘" }[phase];
    const nextStatus = failure || label;
    if (status.textContent !== nextStatus) status.textContent = nextStatus;
    timer.textContent = String(Math.floor(remaining / 60)).padStart(2, "0") + ":" +
      String(remaining % 60).padStart(2, "0");
    timer.hidden = phase === "idle";
    start.hidden = phase !== "idle";
    start.disabled = pending;
    join.hidden = phase !== "focus";
    const joined = joinedAt === round?.startAt?.toMillis();
    join.disabled = pending || joined || !canJoin();
    join.textContent = joined ? "已加入這一輪" : "加入這一輪";
  }

  async function run(action) {
    const state = current;
    if (!state || state.pending) return;
    state.pending = true;
    state.failure = "";
    render();
    try {
      await action(state);
    } catch (error) {
      if (state === current) {
        state.failure = error.message || "操作失敗，請重新整理。";
      }
    } finally {
      state.pending = false;
      if (state === current) render();
    }
  }

  start.addEventListener("click", () => run(async state => {
    await state.db.runTransaction(async transaction => {
      const currentRound = (await transaction.get(state.ref)).data();
      if (core.snapshot(currentRound, now()).phase !== "idle") {
        throw new Error("已有一輪專注或休息正在進行。");
      }
      transaction.set(state.ref,
        core.newRound(state.userId, firebase.firestore.FieldValue.serverTimestamp()));
    });
  }));

  join.addEventListener("click", () => run(async state => {
    if (core.snapshot(state.round, now()).phase !== "focus" || !state.canJoin()) return;
    const startAt = state.round.startAt.toMillis();
    await state.startOwnActivity();
    state.joinedAt = startAt;
  }));

  function stop() {
    if (!current) return;
    current.unsubscribe();
    clearInterval(current.interval);
    current = null;
    panel.hidden = true;
  }

  function sync(options) {
    if (!options) return stop();
    if (current?.roomId === options.roomId) return render();
    stop();
    const state = current = {
      ...options, ready: false, phase: "idle",
      ref: options.db.collection("rooms").doc(options.roomId).collection("focus_rounds").doc("current"),
    };
    panel.hidden = false;
    timer.hidden = true;
    celebration.hidden = true;
    start.hidden = false;
    render();
    const syncClock = () => calibrate(options.getServerTime).then(() => {
      if (state === current) render();
    }).catch(() => {
      if (state === current) {
        state.failure = "無法取得伺服器時間，請重新整理後再試。";
        render();
      }
    });
    state.unsubscribe = state.ref.onSnapshot({ includeMetadataChanges: true }, snapshot => {
      if (snapshot.metadata.hasPendingWrites) return;
      state.ready = !snapshot.metadata.fromCache;
      state.round = snapshot.data();
      state.failure = "";
      render();
    }, () => {
      state.ready = false;
      state.failure = "無法同步專注計時器。";
      render();
    });
    let lastSync = performance.now();
    state.interval = setInterval(() => {
      if (performance.now() - lastSync > 60_000) {
        lastSync = performance.now();
        syncClock();
      }
      render();
    }, 250);
    syncClock();
  }

  window.NudgeFocusRound = Object.freeze({ sync, stop });
})();
