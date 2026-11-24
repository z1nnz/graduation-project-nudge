(function (root, factory) {
  const api = factory();
  if (typeof module === "object" && module.exports) module.exports = api;
  else root.NudgeTownWeather = api;
})(typeof globalThis !== "undefined" ? globalThis : this, function () {
  "use strict";
  const CITIES = Object.freeze(
    [
      ["台北", 25.04, 121.56],
      ["新北", 25.01, 121.46],
      ["桃園", 24.99, 121.3],
      ["新竹", 24.8, 120.97],
      ["台中", 24.15, 120.67],
      ["嘉義", 23.48, 120.45],
      ["台南", 22.99, 120.21],
      ["高雄", 22.63, 120.3],
      ["宜蘭", 24.75, 121.75],
      ["花蓮", 23.99, 121.6],
      ["台東", 22.76, 121.14],
    ].map(([name, latitude, longitude]) =>
      Object.freeze({ name, latitude, longitude }),
    ),
  );
  const MAX_AGE = 30 * 60 * 1000;
  function weatherOf(code) {
    if (!Number.isInteger(code) || code < 0 || code > 99) return "unknown";
    if (code <= 1) return "clear";
    return (code >= 51 && code <= 67) ||
      (code >= 80 && code <= 82) ||
      code >= 95
      ? "rain"
      : "cloudy";
  }
  function forecastUri(city) {
    if (!CITIES.includes(city)) throw Error("Choose a listed city");
    return (
      "https://api.open-meteo.com/v1/forecast?" +
      new URLSearchParams({
        latitude: city.latitude,
        longitude: city.longitude,
        current: "weather_code",
      })
    );
  }
  function create({
    storage,
    fetch: fetcher,
    clock = Date.now,
    onChange = () => {},
  }) {
    let city = null,
      code = null,
      at = 0,
      version = 0,
      pending = false,
      request = null,
      error = false;
    try {
      city =
        CITIES.find((c) => c.name === storage.getItem("cabin_weather_city")) ||
        null;
      const cache = JSON.parse(storage.getItem("town_weather_cache") || "null");
      if (
        city &&
        cache?.city === city.name &&
        weatherOf(cache.code) !== "unknown" &&
        Number.isFinite(cache.at) &&
        cache.at <= clock()
      ) {
        code = cache.code;
        at = cache.at;
      }
    } catch (_) {}
    const state = () => ({
      city: city?.name || null,
      kind: city ? weatherOf(code) : "clear",
      code: city ? code : null,
      at: city && at ? at : null,
      pending,
      stale: Boolean(city && at && clock() - at >= MAX_AGE),
      error,
    });
    function publish() {
      onChange(state());
    }
    async function refresh(force = false) {
      if (!city || pending || (!force && at && clock() - at < MAX_AGE))
        return state();
      const own = ++version,
        chosen = city;
      pending = true;
      error = false;
      request = new AbortController();
      const controller = request;
      publish();
      const timeout = setTimeout(() => controller.abort(), 8000);
      try {
        const response = await fetcher(forecastUri(chosen), {
          signal: controller.signal,
        });
        if (!response.ok) throw Error("Weather unavailable");
        const data = await response.json(),
          value = data?.current?.weather_code;
        if (weatherOf(value) === "unknown") throw Error("Unconfirmed weather");
        if (own !== version) return state();
        code = value;
        at = clock();
        try {
          storage.setItem(
            "town_weather_cache",
            JSON.stringify({ city: chosen.name, code, at }),
          );
        } catch (_) {}
      } catch (_) {
        if (own === version) error = true;
      } finally {
        clearTimeout(timeout);
        if (own === version) {
          pending = false;
          request = null;
          publish();
        }
      }
      return state();
    }
    function cancel() {
      ++version;
      request?.abort();
      request = null;
      pending = false;
    }
    async function choose(name) {
      cancel();
      city = CITIES.find((c) => c.name === name) || null;
      code = null;
      at = 0;
      error = false;
      try {
        storage.removeItem("town_weather_cache");
        if (city) storage.setItem("cabin_weather_city", city.name);
        else storage.removeItem("cabin_weather_city");
      } catch (_) {}
      publish();
      return refresh(true);
    }
    return Object.freeze({ state, refresh, choose, cancel });
  }
  return Object.freeze({ CITIES, MAX_AGE, weatherOf, forecastUri, create });
});
