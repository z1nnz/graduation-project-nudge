(function (root) {
  "use strict";
  const { el, mount } = root.NudgeFacilityScene,
    world = root.NudgeGrowthWorld,
    core = root.NudgeLibrarySceneCore;
  const tools = document.getElementById("museumMain");
  const scene = mount({
    title: "紀錄館・每週藏書",
    background: "assets/scenes/library/library_room.webp",
    npc: "inky",
    content: tools,
    objects: [{ label: "閱讀工具與其他篇章", symbol: "▤", x: 52, y: 82 }],
  });
  const shelf = el("div", null, {
      class: "library-shelf",
      "aria-label": "每週冒險書架",
    }),
    status = document.getElementById("growthStatus");
  status.className = "facility-status";
  scene.stage.append(status, shelf);
  let ctx = null,
    model = null,
    version = 0;
  function clear() {
    ++version;
    model = null;
    shelf.replaceChildren();
    scene.close();
    scene.setGuideLine("雲端還沒確認，我們先等真實紀錄，不用範例補滿。");
  }
  document.addEventListener("growth-clear", clear);
  function bookPage(book) {
    const spread = el("div", null, { class: "library-spread" }),
      left = el("section", null, { class: "library-leaf" }),
      right = el("section", null, { class: "library-leaf" });
    left.append(
      el("h3", "七天冒險日誌"),
      el("p", book.start + " 至 " + book.end),
    );
    const max = Math.max(1, ...book.days.map((d) => d.focus)),
      days = el("div", null, { class: "library-days" });
    for (const d of book.days) {
      const day = el("div", null, { class: "library-day" }),
        stack = el("span", null, {
          class: "library-stack" + (d.focus ? "" : " is-empty"),
          "aria-hidden": "true",
        });
      for (
        let i = 0;
        i < (d.focus ? Math.min(8, Math.floor(1 + (7 * d.focus) / max)) : 0);
        i++
      )
        stack.append(el("i"));
      day.append(
        stack,
        el("time", d.date.slice(5), { datetime: d.date }),
        el("span", d.recorded ? d.focus + " 分" : "留白"),
        el("span", d.tasks ? "★ " + d.tasks + " 件委託" : ""),
      );
      days.append(day);
    }
    left.append(days);
    if (book.empty)
      left.append(el("p", "這一週留白也沒關係，下一本隨時可以開始。"));
    right.append(el("h3", "這本書記下的真實數字"));
    for (const [k, label, unit] of [
      ["focus", "專注／學習", "分鐘"],
      ["sleep", "已記錄睡眠", "小時"],
      ["steps", "步數", "步"],
    ]) {
      const figure = el("figure", null, { class: "library-metric" }),
        drawing = el("canvas", null, {
          "aria-hidden": "true",
          class: "library-metric-icon",
          width: 96,
          height: 96,
        }),
        g = drawing.getContext("2d"),
        ratio = book[k] / model.maxima[k],
        css = getComputedStyle(document.documentElement),
        ink = css.getPropertyValue("--w-wood-deep"),
        gold = css.getPropertyValue("--w-gold"),
        paper = css.getPropertyValue("--w-parchment-hi");
      g.imageSmoothingEnabled = false;
      g.fillStyle = ink;
      if (k === "focus") {
        g.fillRect(18, 10, 60, 6);
        g.fillRect(18, 80, 60, 6);
        g.lineWidth = 4;
        g.strokeStyle = ink;
        g.beginPath();
        g.moveTo(24, 16);
        g.lineTo(72, 16);
        g.lineTo(24, 80);
        g.lineTo(72, 80);
        g.closePath();
        g.stroke();
        g.save();
        g.clip();
        g.fillStyle = gold;
        g.fillRect(20, 80 - Math.round(ratio * 60), 56, Math.round(ratio * 60));
        g.restore();
      } else if (k === "sleep") {
        g.fillStyle = gold;
        g.beginPath();
        g.arc(48, 48, 32, 0, Math.PI * 2);
        g.fill();
        g.fillStyle = paper;
        g.beginPath();
        g.arc(48 + Math.round(ratio * 65), 48, 32, 0, Math.PI * 2);
        g.fill();
        g.strokeStyle = ink;
        g.lineWidth = 2;
        g.beginPath();
        g.arc(48, 48, 32, 0, Math.PI * 2);
        g.stroke();
      } else {
        for (let i = 0; i < 8; i++) {
          g.globalAlpha = i < Math.ceil(ratio * 8) ? 1 : 0.15;
          const x = 18 + (i % 2) * 38,
            y = 10 + Math.floor(i / 2) * 20;
          g.fillRect(x, y + 5, 10, 12);
          g.fillRect(x + 2, y, 4, 4);
          g.fillRect(x + 8, y + 1, 4, 4);
        }
      }
      g.globalAlpha = 1;
      figure.append(
        drawing,
        el(
          "figcaption",
          label + " " + Math.round(book[k] * 100) / 100 + " " + unit,
        ),
      );
      right.append(figure);
    }
    right.append(
      el("p", "運動 " + book.exercise + " 分鐘・委託 " + book.tasks + " 件"),
      el(
        "p",
        "圖像以本書架最高週為滿格；數字只計已確認的紀錄，不等於完整健康資料。",
      ),
    );
    spread.append(left, right);
    return spread;
  }
  async function load() {
    clear();
    const own = version,
      scope = ctx;
    if (!scope?.user) {
      status.textContent = "登入後才載入自己的書；沒有範例數字。";
      shelf.append(
        el("a", "登入，翻開自己的書架", { href: "login.html", class: "w-btn" }),
      );
      return;
    }
    status.textContent = "雲端確認中，書架尚未顯示數字。";
    try {
      const now = new Date(),
        range = core.range(now),
        rows = await world.sessions(scope, range.start, range.end);
      if (!scope.alive() || own !== version) return;
      model = core.shelf(rows, now);
      for (const book of model.books) {
        const b = el("button", null, {
          type: "button",
          class: "library-book",
          "aria-label": "翻開 " + book.start + " 至 " + book.end + " 的冒險書",
          title: book.start + " 至 " + book.end,
        });
        b.style.setProperty("--book-thickness", book.thickness + "px");
        b.append(el("span", book.start.slice(5) + "—" + book.end.slice(5)));
        b.addEventListener("click", () =>
          scene.open({
            title: book.start + " 的冒險書",
            content: bookPage(book),
          }),
        );
        shelf.append(b);
      }
      const comparison = root.NudgeGrowthReview.summarize(
        rows,
        root.NudgeGrowthReview.period("week", now),
      );
      scene.setGuideLine(
        "本週已確認專注／學習 " +
          comparison.current.focusMinutes +
          " 分鐘；上期同期 " +
          comparison.previous.focusMinutes +
          " 分鐘。每一筆真實的行動，都留在自己的書裡。",
      );
      status.textContent =
        "最近12週的本人紀錄已確認。書的厚度依專注、運動與完成委託增加，不授予獎勵。";
    } catch (_) {
      if (!scope.alive() || own !== version) return;
      clear();
      status.textContent =
        "書架尚未確認：可能離線或超過500筆。未顯示部分資料，請重試或使用隱私匯出。";
      const retry = el("button", "重新讀取", {
        type: "button",
        class: "w-btn",
      });
      retry.addEventListener("click", load);
      shelf.append(retry);
    }
  }
  world.connect((c) => {
    ctx = c;
    load();
    return clear;
  });
})(typeof globalThis !== "undefined" ? globalThis : this);
