(function(root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  root.NudgeTownAtmosphereCore = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function() {
  'use strict';

  const PHASES = [
    { name: 'dawn', start: 5 * 60 },
    { name: 'day', start: 7 * 60 },
    { name: 'dusk', start: 17 * 60 },
    { name: 'night', start: 19 * 60 },
  ];
  const SEASONS = ['winter', 'spring', 'summer', 'autumn'];
  const NPCS = [
    { id: 'baker', name: '雜貨店老闆・栗子', character: 'chestnut', colors: ['#8a472e', '#f3c67a', '#fff0ce'],
      route: [[.20, .80], [.29, .70], [.35, .61], [.29, .70]],
      lines: {
        dawn: ['麵團還在醒，早安也慢慢來。', '第一爐麵包快好了，香味會先到。'],
        day: ['走了一小段也算出門，歡迎來店裡。', '歇一下再繼續，熱麵包不會催你。'],
        dusk: ['收工前把桌子擦乾淨，明天會輕鬆些。', '今天完成的一件小事，我替你記得。'],
        night: ['店門關了，明天再買也可以。', '夜深了，讓麵團和你都休息吧。'],
      } },
    { id: 'gardener', name: '園丁・苗苗', character: 'sprout', colors: ['#566e43', '#e6bf95', '#f5d1a4'],
      route: [[.67, .82], [.60, .77], [.55, .67], [.60, .77]],
      lines: {
        dawn: ['清晨的花還掛著露水，輕輕走。', '每天澆一點點水，花會自己長。'],
        day: ['累了就看看樹，呼吸一口氣。', '有些花今天不開，也很正常。'],
        dusk: ['夕陽替花園染了顏色，來坐坐。', '把今天的努力留在土裡吧。'],
        night: ['花兒睡了，我們也放慢腳步。', '月光下的花園很安靜，晚安。'],
      } },
    { id: 'postman', name: '郵差・小信', character: 'letty', colors: ['#496b9b', '#f2cba0', '#ebd6a1'],
      route: [[.50, .62], [.56, .54], [.66, .46], [.56, .54]],
      lines: {
        dawn: ['今天第一封信，要送給剛起床的你。', '郵袋準備好了，我們慢慢出發。'],
        day: ['信送到了！記得看看告示板。', '每走一步，路就多認識你一點。'],
        dusk: ['今天的信快送完了，謝謝你陪我。', '黃昏的路燈，是回家的記號。'],
        night: ['夜班只送晚安，不送催促。', '剩下的信，交給明天的我。'],
      } },
  ];

  function taipeiParts(date) {
    const parts = new Intl.DateTimeFormat('en-CA', {
      timeZone: 'Asia/Taipei', year: 'numeric', month: '2-digit', day: '2-digit',
      hour: '2-digit', minute: '2-digit', hourCycle: 'h23',
    }).formatToParts(date);
    const value = type => Number(parts.find(p => p.type === type)?.value);
    return { year: value('year'), month: value('month'), day: value('day'),
      hour: value('hour'), minute: value('minute') };
  }

  function phaseAt(date) {
    const { hour, minute } = taipeiParts(date);
    const now = hour * 60 + minute;
    let current = PHASES[PHASES.length - 1];
    let previous = PHASES[PHASES.length - 2];
    for (let i = 0; i < PHASES.length; i++) {
      if (now >= PHASES[i].start) {
        current = PHASES[i];
        previous = PHASES[(i + PHASES.length - 1) % PHASES.length];
      }
    }
    return { name: current.name, from: previous.name,
      blend: now < PHASES[0].start ? 1 :
        Math.min(1, Math.max(0, (now - current.start) / 20)) };
  }

  function hash(value) {
    let h = 2166136261;
    for (let i = 0; i < value.length; i++) {
      h ^= value.charCodeAt(i);
      h = Math.imul(h, 16777619);
    }
    return h >>> 0;
  }

  function season(month) { return SEASONS[Math.floor((month % 12) / 3)]; }
  function weatherAt(date) {
    const { year, month, day } = taipeiParts(date);
    const key = `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
    const s = season(month);
    const roll = hash(`nudge-town:${key}`) % 10;
    return { key, season: s, kind: roll < 2 ? 'rain' :
      { spring: 'petal', summer: 'firefly', autumn: 'leaf', winter: 'snow' }[s] };
  }

  function particleLimit(width, height) {
    if (!(width > 0) || !(height > 0)) return 0;
    return Math.min(width < 600 ? 60 : 120, Math.max(10, Math.floor(width * height / 11000)));
  }

  function npcPosition(npc, seconds) {
    const route = npc.route;
    const cycle = ((seconds / 6) % route.length + route.length) % route.length;
    const index = Math.floor(cycle);
    const t = cycle - index;
    const a = route[index], b = route[(index + 1) % route.length];
    return { x: a[0] + (b[0] - a[0]) * t, y: a[1] + (b[1] - a[1]) * t,
      facing: Math.abs(b[0]-a[0])>Math.abs(b[1]-a[1])?(b[0]<a[0]?'west':'east'):(b[1]<a[1]?'north':'south') };
  }

  function npcLine(npc, phase, dayKey) {
    const choices = npc.lines[phase] || npc.lines.day;
    return choices[hash(`${npc.id}:${dayKey}:${phase}`) % choices.length];
  }

  return { NPCS, taipeiParts, phaseAt, weatherAt, particleLimit, npcPosition, npcLine, hash };
});
