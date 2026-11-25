(() => {
  "use strict";

  const art = "assets/study_hall/";
  const seats = [
    [22, 78], [41, 78], [61, 78], [80, 78],
    [25, 57], [41.5, 57], [58, 57], [74.5, 57],
  ];
  const date = new Intl.DateTimeFormat("en-CA", { timeZone: "Asia/Taipei", dateStyle: "short" });
  let state;
  const motion = matchMedia("(prefers-reduced-motion: reduce)");
  const focusPanel = document.querySelector("[data-focus-round]");
  const roundTime = focusPanel.querySelector("time");
  const roster = ["slime", "ghost", "goblin", "snail"];
  let previousDamage;
  let clockButton;
  let guideButton;
  let guideActor;
  const seatActors = new Map();

  function clearActors() {
    guideActor?.destroy();
    guideButton?.remove();
    guideActor = guideButton = undefined;
    for (const actor of seatActors.values()) actor.destroy();
    seatActors.clear();
  }

  function roomGuide() {
    if (guideButton) return guideButton;
    guideButton = document.createElement("button");
    guideButton.type = "button";
    guideButton.className = "study-hall-guide";
    guideButton.setAttribute("aria-label", "問問墨墨");
    guideButton.setAttribute("aria-haspopup", "dialog");
    const costume = document.createElement("span");
    costume.className = "study-hall-guide-sprite";
    guideButton.append(costume);
    guideActor = NudgeSpritePlayer.characterPlayer(costume, "inky", { size: 48 });
    guideButton.addEventListener("click", () => NudgeNpcDialog.open({
      speaker: "inky",
      lines: ["看看座位就知道誰在專注，想一起讀書就點牆上的番茄鐘。"],
      portraitSize: 64,
    }));
    return guideButton;
  }

  function seatActor(memberId, animation) {
    let actor = seatActors.get(memberId);
    if (!actor) {
      const element = document.createElement("span");
      element.className = "study-hall-avatar";
      actor = NudgeSpritePlayer.characterPlayer(element, "companion", { animation, size: 32 });
      seatActors.set(memberId, actor);
    } else if (actor.el.dataset.animation !== animation) {
      actor.play(animation);
    }
    return actor.el;
  }

  addEventListener("pagehide", event => {
    if (!event.persisted) clearActors();
  });
  const syncClock = () => {
    if (!clockButton) return;
    const digits = roundTime.hidden ? "" : roundTime.textContent;
    clockButton.textContent = digits || "◷";
    const seconds = digits ? Number(digits.split(":").at(-1)) : 0;
    clockButton.style.setProperty("--w-clock-angle", (motion.matches ? 0 : 360 - seconds * 6) + "deg");
  };
  new MutationObserver(syncClock).observe(roundTime, { childList: true, attributes: true, attributeFilter: ["hidden"] });
  motion.addEventListener("change", syncClock);

  function roomClock() {
    if (clockButton) return clockButton;
    clockButton = document.createElement("button");
    clockButton.type = "button";
    clockButton.className = "study-room-wall-clock";
    clockButton.setAttribute("aria-label", "牆上的同步番茄鐘");
    clockButton.addEventListener("click", () => {
      if (!focusPanel.hidden) focusPanel.querySelector("h2").focus();
    });
    syncClock();
    return clockButton;
  }

  function roomBoss(target, damage) {
    const defeated = damage >= target;
    const struck = previousDamage != null && damage > previousDamage;
    previousDamage = damage;
    const taipeiDay = Date.now() + 8 * 3_600_000;
    const week = Math.floor((taipeiDay - Date.UTC(2024, 0, 1)) / 604800000);
    const name = roster[week % roster.length];
    const monster = document.createElement("div");
    monster.className = "study-room-corner-monster";
    const meter = document.createElement("meter");
    meter.max = target;
    meter.value = Math.max(0, target - damage);
    meter.setAttribute("aria-label", "拖延怪剩餘血量：" + Math.ceil(meter.value) + " 分鐘");
    const prefix = "assets/scenes/study_hall/" + name + "_";
    const hit = !defeated && struck && !motion.matches && !document.hidden;
    const visual = image(prefix + (defeated ? "down" : hit ? "hit" : "idle") + ".webp", 64, 64, "");
    monster.append(meter, visual);
    if (hit) {
      monster.classList.add("is-hit");
      monster.addEventListener("animationend", () => { visual.src = prefix + "idle.webp"; }, { once: true });
    }
    if (defeated) {
      const stars = document.createElement("strong");
      stars.textContent = "✦ 已打倒";
      monster.append(stars);
    }
    return monster;
  }


  function stop() {
    state?.unsubscribe();
    clearActors();
    clockButton?.remove();
    clockButton = undefined;
    previousDamage = undefined;
    state = null;
  }

  function sessionMinutes(records) {
    const today = date.format(new Date());
    const superseded = new Set(records.map(item => item.correctionOfReceiptId).filter(Boolean));
    const totals = new Map();
    for (const row of records) {
      if (superseded.has(row.receiptId) || typeof row.occurredAt !== "string" ||
          !Number.isFinite(Date.parse(row.occurredAt)) || date.format(new Date(row.occurredAt)) !== today ||
          !["minutes", "hours"].includes(row.metricUnit) || !Number.isFinite(row.metricValue)) continue;
      const minutes = row.metricValue * (row.metricUnit === "hours" ? 60 : 1);
      totals.set(row.actorUserId, (totals.get(row.actorUserId) || 0) + minutes);
    }
    return totals;
  }

  function image(path, width, height, className) {
    const node = new Image(width, height);
    node.src = path;
    node.alt = "";
    node.className = className;
    return node;
  }

  function redraw() {
    if (!state) return;
    const { stage, detail, scene, room, records, selectedId } = state;
    const previousFocus = document.activeElement?.dataset.roomStageMember;
    const focusedClock = clockButton != null && document.activeElement === clockButton;
    const minutes = sessionMinutes(records);
    const online = scene.seats.filter(seat => seat.postureKey !== "away").length;
    const goal = room.dailyGoalValue *
      (String(room.goalUnitLabel).includes("小時") || room.goalSourceType === "sleepHours" ? 60 : 1);
    const timeGoal = !["steps", "custom"].includes(room.roomType);
    const progress = timeGoal && goal > 0 && scene.approvedCount
      ? scene.seats.reduce((sum, seat) => sum + Math.min(goal, minutes.get(seat.memberId) || 0), 0) /
        (goal * scene.approvedCount)
      : 0;
    const chandelier = progress >= 1 ? 2 : progress >= .5 ? 1 : 0;
    stage.classList.add("is-study-hall");
    stage.style.setProperty("--hall-light", String(.68 + Math.min(online, 8) * .065));
    const guide = roomGuide();
    const clock = roomClock();
    for (const child of [...stage.children]) {
      if (child !== guide && child !== clock) child.remove();
    }
    stage.prepend(image(art + "chandelier-" + chandelier + ".png", 128, 96, "study-hall-chandelier"));
    if (guide.parentElement !== stage) stage.append(guide);
    if (clock.parentElement !== stage) stage.append(clock);
    if (focusedClock) clockButton.focus({ preventScroll: true });
    if (state.available && room.roomType === "study" && Math.min(goal, scene.approvedCount) > 0) {
      stage.append(roomBoss(goal * scene.approvedCount, [...minutes.values()].reduce((sum, value) => sum + value, 0)));
    }
    const count = Math.min(8, scene.approvedCount + scene.emptySeats);
    const occupiedActors = new Set();
    seats.slice(0, count).forEach(([left, top], index) => {
      const seat = scene.seats[index];
      const data = document.createElement(seat ? "button" : "span");
      data.className = "study-hall-seat";
      data.style.setProperty("--seat-x", left + "%");
      data.style.setProperty("--seat-y", top + "%");
      const occupied = seat?.postureKey !== "away" && Boolean(seat);
      const lamp = image(art + "desk-" + (occupied ? 1 : 0) + ".png", 32, 32, "study-hall-desk-lamp");
      data.append(lamp);
      if (seat) {
        const name = seat.isViewer ? "你" : seat.displayName;
        data.type = "button";
        data.dataset.roomStageMember = seat.memberId;
        data.setAttribute("aria-label", name + "，" + seat.postureLabel);
        data.setAttribute("aria-pressed", String(seat.memberId === selectedId));
        data.classList.toggle("study-hall-viewer", seat.isViewer);
        const pose = seat.postureKey === "focusing" ? (room.roomType === "exercise" ? "exercise" : "read") : "sleep";
        if (occupied || seat.isViewer) {
          if (pose !== "exercise" || !occupied) {
            const animation = !occupied ? "walk_up" : pose === "sleep" ? "sleep" : "think";
            occupiedActors.add(seat.memberId);
            data.append(seatActor(seat.memberId, animation));
            if (occupied && pose === "read") {
              const book = document.createElement("span");
              book.className = "study-hall-book";
              book.setAttribute("aria-hidden", "true");
              data.append(book);
            }
          } else {
            const face = state.faces.get(seat.memberId) ?? 0;
            const family = Math.floor(face / 3) * 3;
            const sprite = "assets/avatar/poses/pose_" + family + "_exercise.png";
            data.append(image(sprite, 32, 50, "study-hall-avatar"));
          }
        }
        const label = document.createElement("strong");
        label.textContent = name;
        data.append(label);
        data.addEventListener("click", () => {
          state.selectedId = seat.memberId;
          showDetails();
          for (const button of stage.querySelectorAll("[data-room-stage-member]")) {
            button.setAttribute("aria-pressed", String(button === data));
          }
        });
      } else {
        data.setAttribute("aria-hidden", "true");
      }
      stage.append(data);
      if (previousFocus && seat?.memberId === previousFocus) data.focus({ preventScroll: true });
    });

    for (const [memberId, actor] of seatActors) {
      if (occupiedActors.has(memberId)) continue;
      actor.destroy();
      seatActors.delete(memberId);
    }

    function showDetails() {
      const seat = scene.seats.find(item => item.memberId === state.selectedId);
      const time = seat ? minutes.get(seat.memberId) : null;
      detail.textContent = [
        seat && (seat.displayName + " · " + seat.postureLabel),
        seat && (time == null ? "今日無已確認時間" : "今日已確認 " + Math.floor(time) + " 分鐘"),
        timeGoal && state.available && "共同目標燈光 " + (chandelier + 1) + "／3",
      ].filter(Boolean).join(" · ");
    }
    showDetails();
  }

  function render(options) {
    if (state?.room.id !== options.room.id) {
      stop();
      const next = state = {
        ...options, records: [], available: false, selectedId: null,
        faces: new Map(), unsubscribe() {},
      };
      next.unsubscribe = options.db.collection("room_contributions")
        .where("roomId", "==", options.room.id).onSnapshot(snapshot => {
          if (state !== next) return;
          next.records = snapshot.docs.map(doc => doc.data());
          next.available = !snapshot.metadata.fromCache;
          redraw();
        }, () => {
          if (state !== next) return;
          next.available = false;
          next.records = [];
          redraw();
        });
    }
    Object.assign(state, options);
    const active = state;
    const exerciseSeats = options.room.roomType === "exercise" ? options.scene.seats.slice(0, 8) : [];
    for (const seat of exerciseSeats) {
      if (active.faces.has(seat.memberId)) continue;
      active.faces.set(seat.memberId, 0);
      options.db.collection("public_profiles").doc(seat.memberId).get().then(snapshot => {
        if (state !== active) return;
        const face = snapshot.data()?.avatarProfile?.faceShapeIndex;
        if (Number.isInteger(face) && face >= 0 && face < 18 && face !== 0) {
          active.faces.set(seat.memberId, face);
          redraw();
        }
      }).catch(() => {});
    }
    redraw();
  }

  window.NudgeStudyHall = Object.freeze({ render, stop });
})();
