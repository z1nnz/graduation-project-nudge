const test = require("node:test"),
  assert = require("node:assert/strict"),
  weather = require("../web_dashboard/assets/town_weather.js");
const storage = (rows = {}) => ({
  getItem: (k) => rows[k] ?? null,
  setItem: (k, v) => (rows[k] = v),
  removeItem: (k) => delete rows[k],
});
test("town weather mirrors App opt-in city coordinates and WMO mapping", () => {
  assert.equal(weather.CITIES.length, 11);
  assert.match(
    weather.forecastUri(weather.CITIES[0]),
    /^https:\/\/api.open-meteo.com\/v1\/forecast\?latitude=25.04&longitude=121.56&current=weather_code$/,
  );
  for (const c of [51, 61, 67, 80, 82, 95, 99])
    assert.equal(weather.weatherOf(c), "rain");
  for (const c of [2, 3, 45, 71, 85])
    assert.equal(weather.weatherOf(c), "cloudy");
  for (const c of [null, NaN, -1, 100, "61"])
    assert.equal(weather.weatherOf(c), "unknown");
});
test("no city means no location access and no weather request", async () => {
  let calls = 0;
  const c = weather.create({
    storage: storage(),
    fetch: async () => {
      calls++;
    },
  });
  await c.refresh();
  assert.equal(calls, 0);
  assert.equal(c.state().city, null);
});
test("city changes reject stale replies and never cache previous city data", async () => {
  const pending = [];
  const s = storage(),
    c = weather.create({
      storage: s,
      clock: () => 100000,
      fetch: () => new Promise((resolve) => pending.push(resolve)),
    });
  const a = c.choose("台北"),
    b = c.choose("高雄");
  pending[1]({
    ok: true,
    json: async () => ({ current: { weather_code: 61 } }),
  });
  await b;
  pending[0]({
    ok: true,
    json: async () => ({ current: { weather_code: 0 } }),
  });
  await a;
  assert.equal(c.state().city, "高雄");
  assert.equal(c.state().kind, "rain");
  assert.equal(JSON.parse(s.getItem("town_weather_cache")).city, "高雄");
});
test("cache is city-scoped, bounded in time, retains honest stale offline data, and can be disabled", async () => {
  let now = 200000,
    calls = 0;
  const c = weather.create({
    storage: storage({
      cabin_weather_city: "台北",
      town_weather_cache: JSON.stringify({ city: "台北", code: 3, at: 100000 }),
    }),
    clock: () => now,
    fetch: async () => {
      calls++;
      throw Error("offline");
    },
  });
  await c.refresh();
  assert.equal(calls, 0);
  now += weather.MAX_AGE;
  await c.refresh();
  assert.equal(c.state().kind, "cloudy");
  assert.equal(c.state().stale, true);
  assert.equal(c.state().error, true);
  await c.choose("");
  assert.equal(c.state().city, null);
  assert.equal(c.state().code, null);
});
test("malformed responses do not manufacture current weather", async () => {
  const c = weather.create({
    storage: storage(),
    fetch: async () => ({
      ok: true,
      json: async () => ({ current: { weather_code: "61" } }),
    }),
  });
  await c.choose("花蓮");
  assert.equal(c.state().kind, "unknown");
  assert.equal(c.state().error, true);
});
