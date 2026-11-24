(() => {
  "use strict";
  const root = document.querySelector("[data-guild-calendar]");
  const get = selector => root.querySelector(selector);
  const api = NudgeGuildCalendarCore;
  const details = get("[data-guild-event-details]");
  const eventList = get("[data-guild-calendar-list]");
  const grid = get("[data-guild-grid]");
  const status = get("[data-guild-status]");
  const kindName = { study: "共同自習", book: "讀書會", exam: "考前衝刺夜" };
  const date = new Intl.DateTimeFormat("zh-Hant-TW", { month: "numeric", day: "numeric", weekday: "short" });
  const time = new Intl.DateTimeFormat("zh-Hant-TW", { hour: "2-digit", minute: "2-digit", hourCycle: "h23" });
  let groupId;
  let generation = 0;
  let model;
  let selectedId;
  let running = false;
  let anchor = new Date();
  let view = "month";

  async function call(action, data) {
    return (await functions.httpsCallable("manageGuildCalendar")({ action, groupId, ...data })).data;
  }

  function button(label, callback, pressed) {
    const element = document.createElement("button");
    element.type = "button";
    element.className = "w-btn";
    element.textContent = label;
    if (typeof pressed === "boolean") element.setAttribute("aria-pressed", String(pressed));
    element.addEventListener("click", callback);
    return element;
  }

  function eventCard(event) {
    const card = document.createElement("article");
    card.className = "guild-calendar-card";
    const title = document.createElement("h3");
    title.textContent = event.title;
    const schedule = document.createElement("p");
    schedule.textContent = kindName[event.kind] + " · " + date.format(new Date(event.startsAt)) +
      " " + time.format(new Date(event.startsAt)) + "–" + time.format(new Date(event.endsAt));
    const tools = document.createElement("div");
    tools.className = "guild-calendar-tools";
    if (event.endsAt > model.now) {
      tools.append(
        button("參加", () => perform("rsvp", { eventId: event.id, status: "going" }, "已確認參加。"), event.status === "going"),
        button("不參加", () => perform("rsvp", { eventId: event.id, status: "declined" }, "已記錄不參加。"), event.status === "declined"),
      );
    }
    if (event.joinable) {
      const door = button("進入自習", () => perform("join", { eventId: event.id }));
      door.classList.add("guild-calendar-room");
      const image = new Image(120, 160);
      image.src = "assets/guild_calendar/door.png";
      image.alt = "";
      door.prepend(image);
      tools.append(door);
    }
    card.append(title, schedule, tools);
    return card;
  }

  function render() {
    if (!model) return;
    root.hidden = false;
    const days = api.days(anchor, view);
    const keys = new Set(days.map(api.key));
    const visible = model.events.filter(event => keys.has(api.key(new Date(event.startsAt))));
    const selected = visible.find(event => event.id === selectedId);
    get("[data-guild-range]").textContent = view === "week" ?
      date.format(days[0]) + " 至 " + date.format(days[6]) :
      anchor.getFullYear() + " 年 " + (anchor.getMonth() + 1) + " 月";
    grid.replaceChildren();
    for (const day of days) {
      const cell = document.createElement("div");
      cell.className = "guild-calendar-day";
      if (day === days[0]) cell.style.gridColumnStart = String(day.getDay() + 1);
      const stamp = document.createElement("time");
      stamp.dateTime = api.key(day);
      stamp.textContent = String(day.getDate());
      cell.append(stamp);
      for (const event of visible.filter(item => api.key(new Date(item.startsAt)) === stamp.dateTime)) {
        cell.append(button(event.title, () => {
          selectedId = event.id;
          render();
          details.focus();
        }, selectedId === event.id));
      }
      grid.append(cell);
    }
    const cards = visible.map(eventCard);
    if (!cards.length) {
      const empty = document.createElement("p");
      empty.textContent = "這段期間沒有活動。";
      cards.push(empty);
    }
    eventList.replaceChildren(...cards);
    details.replaceChildren(...(selected ? [eventCard(selected)] : []));
    const notices = get("[data-guild-notices]");
    notices.replaceChildren();
    for (const notice of model.notices) {
      const entry = document.createElement("li");
      entry.className = "guild-calendar-card";
      const content = document.createElement("p");
      content.textContent = notice.body;
      entry.append(content);
      const tools = document.createElement("div");
      tools.className = "guild-calendar-tools";
      const read = button(notice.acknowledged ? "已讀" : "標為已讀",
        () => perform("ack", { noticeId: notice.id }, "已標為已讀。"));
      read.disabled = notice.acknowledged;
      tools.append(read);
      if (model.manager) {
        const count = document.createElement("span");
        count.textContent = "已讀 " + notice.count + " 人";
        tools.append(count, button("取消釘選", () => perform("unpin", { noticeId: notice.id }, "已取消釘選。")));
      }
      entry.append(tools);
      notices.append(entry);
    }
    get("[data-guild-manager]").hidden = !model.manager;
    get("[data-guild-view-month]").setAttribute("aria-pressed", String(view === "month"));
    get("[data-guild-view-week]").setAttribute("aria-pressed", String(view === "week"));
  }

  async function refresh() {
    if (!groupId) return;
    const request = ++generation;
    try {
      const result = await call("list");
      if (request !== generation) return;
      model = result;
      render();
    } catch {
      if (request !== generation) return;
      root.hidden = true;
      model = null;
    }
  }

  function select(id) {
    if (id === groupId) return;
    groupId = id;
    generation++;
    selectedId = null;
    model = null;
    root.hidden = true;
    status.textContent = "";
    root.querySelectorAll("form").forEach(form => form.reset());
    if (id) void refresh();
  }

  async function perform(action, data, success) {
    if (!groupId || !model || running) return false;
    const active = groupId;
    running = true;
    try {
      const result = await call(action, data);
      if (groupId !== active) return false;
      if (action === "join") {
        const url = new URL("rooms.html", location.href);
        url.searchParams.set("room", result.roomId);
        location.assign(url.href);
        return true;
      }
      await refresh();
      if (groupId === active) {
        status.textContent = success;
        status.focus();
      }
      return true;
    } catch {
      if (groupId === active) status.textContent = "操作未確認，請檢查時間、團體資格或公告數量。";
      return false;
    } finally {
      running = false;
    }
  }

  get("[data-guild-prev]").addEventListener("click", () => { anchor = api.navigate(anchor, view, -1); render(); });
  get("[data-guild-next]").addEventListener("click", () => { anchor = api.navigate(anchor, view, 1); render(); });
  get("[data-guild-view-month]").addEventListener("click", () => { view = "month"; render(); });
  get("[data-guild-view-week]").addEventListener("click", () => { view = "week"; render(); });
  get("[data-guild-event-form]").addEventListener("submit", async event => {
    event.preventDefault();
    const form = event.currentTarget;
    const fields = form.elements;
    if (await perform("create", {
      title: fields.title.value, kind: fields.kind.value, startsAt: new Date(fields.starts.value).toISOString(),
      endsAt: new Date(fields.ends.value).toISOString(), voiceEnabled: fields.voice.checked,
    }, "活動已公布。")) form.reset();
  });
  get("[data-guild-notice-form]").addEventListener("submit", async event => {
    event.preventDefault();
    const form = event.currentTarget;
    if (await perform("pin", { body: form.elements.body.value }, "公告已釘選。")) form.reset();
  });
  setInterval(() => { if (groupId && !running && !document.activeElement?.closest("form")) void refresh(); }, 30_000);
  window.NudgeGuildCalendar = Object.freeze({ select });
})();
