(function (root) {
  "use strict";
  const core = root.NudgeTownAtmosphereCore,
    loader = root.NudgeTownImage;
  if (!core) return;
  const doc = root.document,
    images = new Map(),
    phaseAlpha = { dawn: 0.17, day: 0.07, dusk: 0.13, night: 0.55 };
  const lamps = [
    [0.096, 0.205],
    [0.153, 0.302],
    [0.236, 0.202],
    [0.417, 0.295],
    [0.481, 0.296],
    [0.413, 0.452],
    [0.563, 0.448],
    [0.597, 0.663],
    [0.758, 0.694],
    [0.757, 0.454],
    [0.839, 0.192],
  ];
  const windows = [
    [0.156, 0.424],
    [0.195, 0.517],
    [0.442, 0.199],
    [0.59, 0.216],
    [0.727, 0.226],
    [0.865, 0.452],
    [0.926, 0.455],
    [0.237, 0.754],
    [0.181, 0.754],
  ];
  const owl = { id: "owl", name: "貓頭鷹館長・歐莉", x: 0.505, y: 0.615 };
  const hashUnit = (s) => core.hash(s) / 4294967295;
  function palette() {
    const css = root.getComputedStyle(doc.documentElement);
    return Object.fromEntries(
      [
        "night",
        "gold",
        "gold-deep",
        "parchment",
        "ink",
        "violet",
        "wood",
        "wood-deep",
        "green",
      ].map((k) => [k, css.getPropertyValue("--w-" + k).trim()]),
    );
  }
  function imageFor(actor) {
    const key = actor.character || actor.id;
    if (images.has(key)) return images.get(key);
    const image = new Image();
    loader.load(
      image,
      actor.character
        ? "assets/characters/" + actor.character + "/sheet.webp"
        : "assets/town/guide.png",
    );
    images.set(key, image);
    return image;
  }
  function paint(ctx, color, alpha, fn) {
    ctx.save();
    ctx.fillStyle = color;
    ctx.strokeStyle = color;
    ctx.globalAlpha = alpha;
    fn();
    ctx.restore();
  }
  function glow(ctx, x, y, r, p, strength) {
    paint(ctx, p.gold, strength * 0.18, () =>
      ctx.fillRect(Math.round(x - r / 2), Math.round(y - r / 2), r, r),
    );
    paint(ctx, p.gold, strength * 0.06, () =>
      ctx.fillRect(Math.round(x - r), Math.round(y - r), r * 2, r * 2),
    );
  }
  function actors(now, reducedMotion) {
    return [
      ...core.NPCS.map((npc) => ({
        ...npc,
        ...core.npcPosition(npc, reducedMotion ? 0 : Math.floor(now / 125) / 8),
      })),
      owl,
    ];
  }
  function drawActors(ctx, view, now, p) {
    for (const actor of actors(now, view.reducedMotion)) {
      const q = view.toScreen({
          x: actor.x * view.mapW,
          y: actor.y * view.mapH,
        }),
        image = imageFor(actor),
        size = Math.round(
          (actor.character ? 64 : 40) * Math.max(0.8, view.scale),
        );
      if (!image.complete || !image.naturalWidth) continue;
      if (actor.character) {
        const row = view.reducedMotion
            ? 0
            : view.speakingActorId === actor.id
              ? 1
              : { south: 2, west: 3, east: 4, north: 5 }[actor.facing] || 0,
          frame = view.reducedMotion ? 0 : Math.floor(now / 125) % 4;
        ctx.drawImage(
          image,
          frame * 128,
          row * 128,
          128,
          128,
          Math.round(q.x - size / 2),
          Math.round(q.y - size),
          size,
          size,
        );
      } else
        ctx.drawImage(
          image,
          Math.round(q.x - size / 2),
          Math.round(q.y - size),
          size,
          size,
        );
    }
  }
  function create() {
    let phase = core.phaseAt(new Date()),
      cachedMinute = -1,
      p = palette(),
      weather = { city: null, kind: "clear" },
      lastWeatherAttempt = -Infinity;
    const content = new Set();
    const citySelect = doc.getElementById("townWeatherCity"),
      status = doc.getElementById("townWeatherStatus");
    const safeStorage = {
      getItem(k) {
        try {
          return root.localStorage.getItem(k);
        } catch (_) {
          return null;
        }
      },
      setItem(k, v) {
        try {
          root.localStorage.setItem(k, v);
        } catch (_) {}
      },
      removeItem(k) {
        try {
          root.localStorage.removeItem(k);
        } catch (_) {}
      },
    };
    const weatherController = root.NudgeTownWeather?.create({
      storage: safeStorage,
      fetch: (...args) => root.fetch(...args),
      onChange: updateWeather,
    });
    function updateWeather(next) {
      weather = next;
      if (citySelect) citySelect.value = next.city || "";
      if (status) {
        const names = {
          rain: "雨天",
          cloudy: "陰天",
          clear: "晴朗",
          unknown: "天氣尚未確認",
        };
        status.textContent = !next.city
          ? "未選城市，使用晴朗場景，不讀取位置。"
          : next.pending
            ? next.city + "：天氣確認中。"
            : next.city +
              "：" +
              names[next.kind] +
              (next.at
                ? "，" +
                  new Date(next.at).toLocaleTimeString("zh-TW", {
                    hour: "2-digit",
                    minute: "2-digit",
                  }) +
                  "更新"
                : "") +
              (next.stale || next.error
                ? "（離線或未更新，保留上次可確認資料）"
                : "") +
              "。";
      }
    }
    if (citySelect && weatherController) {
      for (const city of root.NudgeTownWeather.CITIES) {
        const o = doc.createElement("option");
        o.value = city.name;
        o.textContent = city.name;
        citySelect.append(o);
      }
      citySelect.addEventListener("change", () => {
        lastWeatherAttempt = Date.now();
        weatherController.choose(citySelect.value);
      });
      updateWeather(weatherController.state());
      weatherController.refresh();
    }
    doc.addEventListener("visibilitychange", () => {
      if (doc.hidden) weatherController?.cancel();
      else weatherController?.refresh();
    });
    root.addEventListener("pagehide", () => weatherController?.cancel());
    root.addEventListener("pageshow", () => weatherController?.refresh());
    doc.addEventListener("nudge-town-building-content", (e) => {
      if (e.detail?.clear) {
        content.clear();
        return;
      }
      if (!["plaza", "library", "board"].includes(e.detail?.building)) return;
      if (e.detail.confirmed && e.detail.hasContent)
        content.add(e.detail.building);
      else content.delete(e.detail.building);
    });
    return {
      actors,
      weather: () => ({ ...weather }),
      draw(ctx, view, rawNow) {
        if (view.hidden) return;
        const minute = Math.floor(Date.now() / 60000);
        if (minute !== cachedMinute) {
          phase = core.phaseAt(new Date());
          cachedMinute = minute;
          p = palette();
          if (Date.now() - lastWeatherAttempt >= 30 * 60000) {
            lastWeatherAttempt = Date.now();
            weatherController?.refresh();
          }
        }
        const now = view.reducedMotion ? 0 : Math.floor(rawNow / 100) * 100,
          point = (x, y) =>
            view.toScreen({ x: x * view.mapW, y: y * view.mapH });
        const tintColors = {
          night: p.night,
          day: p.gold,
          dusk: p.violet,
          dawn: p.parchment,
        };
        paint(
          ctx,
          tintColors[phase.from],
          phaseAlpha[phase.from] * (1 - phase.blend),
          () => ctx.fillRect(0, 0, view.width, view.height),
        );
        paint(
          ctx,
          tintColors[phase.name],
          phaseAlpha[phase.name] * phase.blend,
          () => ctx.fillRect(0, 0, view.width, view.height),
        );
        if (weather.kind === "cloudy" || weather.kind === "rain")
          paint(ctx, p.night, 0.18, () =>
            ctx.fillRect(0, 0, view.width, view.height),
          );
        if (["night", "dusk"].includes(phase.name)) {
          const amount = phase.name === "night" ? 0.6 : 0.3;
          for (const [x, y] of lamps) {
            const q = point(x, y);
            glow(ctx, q.x, q.y, 12, p, amount);
          }
          for (const [x, y] of windows) {
            const q = point(x, y);
            glow(ctx, q.x, q.y, 8, p, amount);
          }
          paint(ctx, p.gold, 0.7, () => {
            for (let i = 0; i < 25; i++) {
              const x = Math.round(hashUnit("star-x" + i) * view.width),
                y = Math.round(hashUnit("star-y" + i) * view.height * 0.16);
              if (view.reducedMotion || (Math.floor(now / 700) + i) % 4 !== 0)
                ctx.fillRect(x, y, 2, 2);
            }
          });
        }
        // Clouds, leaves, water and smoke advance in ten discrete frames/second.
        const drift = view.reducedMotion
          ? view.width * 0.3
          : ((now / 90) % (view.width + 180)) - 90;
        paint(ctx, p.parchment, weather.kind === "cloudy" ? 0.2 : 0.1, () => {
          ctx.fillRect(Math.round(drift), 36, 110, 12);
          ctx.fillRect(Math.round(drift + 20), 24, 65, 12);
        });
        for (const [x, y] of [
          [0.09, 0.367],
          [0.035, 0.351],
        ]) {
          const q = point(x, y);
          for (let i = 0; i < 3; i++) {
            const rise = (now / 100 + i * 13) % 43;
            paint(ctx, p.parchment, 0.2 * (1 - rise / 43), () =>
              ctx.fillRect(
                Math.round(q.x + Math.sin(now / 1200 + i) * 4),
                Math.round(q.y - rise),
                8 + Math.floor(rise / 8) * 2,
                6,
              ),
            );
          }
        }
        for (const [x, y] of [
          [0.31, 0.18],
          [0.15, 0.09],
          [0.67, 0.45],
          [0.56, 0.69],
        ]) {
          const q = point(x, y);
          paint(ctx, p.green, 0.35, () =>
            ctx.fillRect(
              Math.round(
                q.x + (view.reducedMotion ? 0 : Math.sin(now / 800 + x) * 3),
              ),
              Math.round(q.y),
              12,
              4,
            ),
          );
        }
        for (const [x, y] of [
          [0.05, 0.9],
          [0.15, 0.92],
          [0.28, 0.96],
          [0.48, 0.52],
        ]) {
          const q = point(x, y),
            s = view.reducedMotion ? 0 : Math.floor(now / 150) % 6;
          paint(ctx, p.gold, 0.35, () => {
            ctx.fillRect(Math.round(q.x - 12 + s * 2), Math.round(q.y), 18, 2);
            ctx.fillRect(Math.round(q.x - 7 - s), Math.round(q.y + 5), 12, 2);
          });
        }
        if (view.reducedMotion || Math.floor(now / 20000) % 3 === 0) {
          const flight = view.reducedMotion
            ? view.width * 0.65
            : ((now / 40) % (view.width + 140)) - 70;
          paint(ctx, p["wood-deep"], 0.7, () => {
            for (let i = 0; i < 5; i++) {
              const x = Math.round(flight - i * 15),
                y = Math.round(view.height * 0.18 + (i % 2) * 7);
              ctx.fillRect(x - 3, y - 2, 3, 2);
              ctx.fillRect(x, y, 3, 2);
            }
          });
        }
        if (weather.kind === "rain") {
          paint(ctx, p.parchment, 0.5, () => {
            for (
              let i = 0;
              i < core.particleLimit(view.width, view.height);
              i++
            ) {
              const x = Math.round(
                  ((((hashUnit("rainx" + i) - now / 6000) % 1) + 1) % 1) *
                    view.width,
                ),
                y = Math.round(
                  ((hashUnit("rainy" + i) + now / 8000) % 1) * view.height,
                );
              ctx.fillRect(x, y, 2, 8);
            }
          });
          for (const [x, y] of [
            [0.48, 0.62],
            [0.35, 0.72],
            [0.72, 0.82],
          ]) {
            const q = point(x, y);
            paint(ctx, p.ink, 0.2, () => {
              ctx.fillRect(Math.round(q.x - 18), Math.round(q.y), 36, 4);
              ctx.fillRect(
                Math.round(q.x - 10 + ((now / 300) % 8)),
                Math.round(q.y + 1),
                12,
                1,
              );
            });
          }
        }
        for (const id of content) {
          const spot = view.buildings?.find((b) => b.id === id)?.label;
          if (!spot) continue;
          const q = view.toScreen(spot);
          paint(ctx, p.gold, 0.95, () =>
            ctx.fillRect(Math.round(q.x - 10), Math.round(q.y - 40), 20, 16),
          );
          paint(ctx, p["wood-deep"], 1, () => {
            ctx.fillRect(Math.round(q.x - 1), Math.round(q.y - 37), 2, 7);
            ctx.fillRect(Math.round(q.x - 1), Math.round(q.y - 28), 2, 2);
          });
        }
        drawActors(ctx, view, view.reducedMotion ? 0 : rawNow, p);
      },
      line(actor) {
        return core.npcLine(
          actor,
          core.phaseAt(new Date()).name,
          core.weatherAt(new Date()).key,
        );
      },
    };
  }
  root.NudgeTownAtmosphere = { create };
})(typeof globalThis !== "undefined" ? globalThis : this);
