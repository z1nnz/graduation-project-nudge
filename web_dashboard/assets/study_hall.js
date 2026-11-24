(() => {
  "use strict";

  const art = "assets/study_hall/";
  const seats = [
    [22, 78], [41, 78], [61, 78], [80, 78],
    [25, 57], [41.5, 57], [58, 57], [74.5, 57],
  ];
  const date = new Intl.DateTimeFormat("en-CA", { timeZone: "Asia/Taipei", dateStyle: "short" });
  let state;

  function stop() {
    state?.unsubscribe();
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
    stage.replaceChildren(image(art + "chandelier-" + chandelier + ".png", 128, 96, "study-hall-chandelier"));

    const count = Math.min(8, scene.approvedCount + scene.emptySeats);
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
          const face = state.faces.get(seat.memberId) ?? 0;
          const family = Math.floor(face / 3) * 3;
          const sprite = seat.postureKey === "away"
            ? "assets/avatar/characters/character_" + face + ".png"
            : "assets/avatar/poses/pose_" + family + "_" + pose + ".png";
          data.append(image(sprite, 32, 50, "study-hall-avatar"));
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
    for (const seat of options.scene.seats.slice(0, 8)) {
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
