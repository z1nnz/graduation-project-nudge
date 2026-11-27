(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.NudgeWorldLifeCore = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';
  // Pure parts of the living-scene layer (world_life.js): time of day, sky
  // palette, where the player stands for an object, which way to face, the
  // pixel emotes, and the companion's day. No DOM here, so Node tests run it.
  // Suggested for the shared components (scene_room) once it settles.

  const PHASES = [
    // [from hour, name]
    [0, 'night'], [5, 'dawn'], [7, 'day'], [17, 'dusk'], [19.5, 'night'],
  ];

  /** Phase of the day at [hour] (0–24, fractions allowed). */
  function phaseAt(hour) {
    const h = ((hour % 24) + 24) % 24;
    let name = 'night';
    for (const [from, n] of PHASES) if (h >= from) name = n;
    return name;
  }

  /** 0 at midnight, 1 at noon: how much daylight comes through the windows. */
  function daylight(hour) {
    const h = ((hour % 24) + 24) % 24;
    if (h < 5 || h >= 20) return 0;
    if (h < 7) return (h - 5) / 2;
    if (h < 17) return 1;
    return Math.max(0, 1 - (h - 17) / 3);
  }

  const SKY = {
    // top, middle, horizon; night keeps the town's soft purple
    night: ['#160f2e', '#2a1d52', '#4a2f6e'],
    dawn: ['#3b2f6b', '#b2729e', '#f4b98a'],
    day: ['#5f9ee0', '#8fc3ee', '#d8ecf4'],
    dusk: ['#2f2460', '#8a4c8c', '#f08a6a'],
  };

  /** Sky bands for [hour]; blends into the next phase during the last hour. */
  function skyColors(hour) {
    const p = phaseAt(hour);
    return SKY[p].slice();
  }

  /** Sun or moon position: x 0–1 across the sky, y 0 (high) – 1 (horizon). */
  function bodyAt(hour) {
    const h = ((hour % 24) + 24) % 24;
    const sun = h >= 6 && h < 19;
    const t = sun ? (h - 6) / 13 : ((h >= 19 ? h - 19 : h + 5) / 11);
    return { kind: sun ? 'sun' : 'moon', x: 0.1 + 0.8 * t, y: 1 - Math.sin(Math.PI * t) };
  }

  /** Where the player stands to use an object: [layout.spots[id]] or below its rect. */
  function spotFor(layout, id) {
    const s = layout?.spots?.[id];
    if (s) return s.slice(0, 2);
    const r = layout?.rects?.[id];
    if (!r) return null;
    const [fy0, fy1] = layout.floor || [0.62, 0.95];
    return [clamp(r[0] + r[2] / 2, 0.06, 0.94), clamp(r[1] + r[3] + 0.05, fy0, fy1)];
  }

  function clamp(v, a, b) { return Math.max(a, Math.min(b, v)); }

  /** Walk direction from [a] to [b]: 'left' | 'right' | 'up' | 'down'. */
  function direction(a, b, aspect = 1) {
    const dx = (b[0] - a[0]) * aspect, dy = b[1] - a[1];
    if (Math.abs(dx) >= Math.abs(dy)) return dx >= 0 ? 'right' : 'left';
    return dy >= 0 ? 'down' : 'up';
  }

  /** Milliseconds to walk from a to b at [speed] frame widths per second. */
  function walkTime(a, b, speed = 0.3, aspect = 1) {
    const d = Math.hypot((b[0] - a[0]) * aspect, b[1] - a[1]);
    return Math.round((d / speed) * 1000);
  }

  // Pixel emotes, 9x9: '#' outline, 'o' fill, 'x' mark, '.' empty.
  const EMOTES = {
    '!': ['..#####..', '.#ooxoo#.', '.#ooxoo#.', '.#ooxoo#.', '.#ooooo#.', '.#ooxoo#.', '..#ooo#..', '...#o#...', '....#....'],
    '?': ['..#####..', '.#oxxxo#.', '.#ooooxo#', '.#oooxo#.', '.#ooxoo#.', '.#ooooo#.', '..#oxo#..', '...#o#...', '....#....'],
    heart: ['.........', '.##...##.', '#xx#.#xx#', '#xxx#xxx#', '#xxxxxxx#', '.#xxxxx#.', '..#xxx#..', '...#x#...', '....#....'],
    note: ['....###..', '....#x##.', '....#..#.', '....#....', '....#....', '.###.....', '#xxx#....', '#xxx#....', '.###.....'],
    zz: ['.........', '.######..', '....##...', '...##....', '..##.....', '.######..', '......###', '.......#.', '......###'],
    sweat: ['....#....', '...#x#...', '...#x#...', '..#xxx#..', '..#xxx#..', '.#xxxxx#.', '.#xxxxx#.', '..#xxx#..', '...###...'],
    star: ['....#....', '...#x#...', '...#x#...', '###xxx###', '#xxxxxxx#', '.#xxxxx#.', '.#xx#xx#.', '#xx#.#xx#', '##.....##'],
    dots: ['.........', '.........', '.........', '.........', '##.##.##.', '#x##x##x#', '##.##.##.', '.........', '.........'],
    wave: ['.#.#.#...', '.#x#x#x#.', '.#x#x#x#.', '.#xxxxx#.', '##xxxxx#.', '#xxxxxx#.', '.#xxxxx#.', '..#xxx#..', '...###...'],
  };
  const EMOTE_COLORS = {
    '!': '#d8452e', '?': '#4b2fa8', heart: '#e05a86', note: '#4b2fa8', zz: '#8b6cf0', sweat: '#4e8cdc',
    star: '#ffc54d', dots: '#5a3a26', wave: '#fad6b2',
  };

  /** Which emote a line of dialogue earns. */
  function moodOf(line = '') {
    if (/[？?]/.test(line)) return '?';
    if (/[！!]/.test(line)) return '!';
    if (/(謝謝|喜歡|開心|太好|棒)/.test(line)) return 'heart';
    if (/(睡|晚安|Zz)/.test(line)) return 'zz';
    return 'dots';
  }

  // The companion's day in the cabin (J4), by local hour.
  const DAY = [
    { from: 0, act: 'sleep', at: 'bed', say: '呼…Zz' },
    { from: 6.5, act: 'stretch', at: 'bed', say: '早安！伸個懶腰～' },
    { from: 8, act: 'read', at: 'desk', say: '今天也來讀一點書。' },
    { from: 12, act: 'snack', at: 'table', say: '午餐時間，吃點心！' },
    { from: 13.5, act: 'read', at: 'desk', say: '下午繼續加油。' },
    { from: 18, act: 'look', at: 'window', say: '晚霞好漂亮。' },
    { from: 21, act: 'sit', at: 'window', say: '星星出來了。' },
    { from: 23, act: 'sleep', at: 'bed', say: '該睡了，晚安。' },
  ];

  /** What the companion is doing at [hour]. */
  function routineAt(hour) {
    const h = ((hour % 24) + 24) % 24;
    let cur = DAY[0];
    for (const d of DAY) if (h >= d.from) cur = d;
    return { ...cur };
  }

  return { PHASES, SKY, DAY, EMOTES, EMOTE_COLORS, phaseAt, daylight, skyColors, bodyAt, spotFor, direction, walkTime, moodOf, routineAt, clamp };
});
