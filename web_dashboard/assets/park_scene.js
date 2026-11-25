(function (root) {
  'use strict';
  // The park map: each ride opens its arcade game (arcade.js keeps plays,
  // timers and scores); Bounce runs the ticket booth. Desktop gets the wide
  // map, phones the tall one, and townsfolk stroll along the paths.
  const doc = root.document;
  const hall = doc.getElementById('arcadeHall');
  if (!hall || !root.NudgeSceneRoom) return;
  const cabinet = id => doc.querySelector(`.arcade-cabinet[data-game="${id}"]`);
  const play = id => () => cabinet(id)?.click();
  const ticketText = () => doc.getElementById('arcadeTicket')?.textContent?.trim() || '';
  let hops = 0;

  const room = root.NudgeSceneRoom.mount({
    host: hall,
    title: '遊樂園',
    npc: 'bounce',
    npcSize: 112,
    greeting: () => [`我是跳跳！${ticketText() ? ticketText() + '。' : ''}`],
    tips: [
      '每天可以免費玩 3 次，早上 5 點補滿；專注 25 分鐘以上還能多拿獎勵券。',
      '摩天輪上可以接星星，連續接五顆有加分喔！',
      '撈魚攤的魚分五種稀有度，傳說的魚只閃一下下。',
      '舞台上有三首 8-bit 曲子，打到 Perfect 很過癮！',
      '旋轉木馬轉著轉著，就把夥伴的臉記住了。',
      '跳房子是免費的，跳幾下活動一下筋骨吧～',
    ],
    objects: [
      { id: 'wheel', label: '摩天輪', hint: '接星星', onSelect: play('stars') },
      { id: 'stall', label: '撈魚攤', hint: '星光釣魚', onSelect: play('fishing') },
      { id: 'stage', label: '舞台', hint: '鐘塔節奏', onSelect: play('rhythm') },
      { id: 'carousel', label: '旋轉木馬', hint: '夥伴記憶配對', onSelect: play('memory') },
      { id: 'booth', label: '售票亭', hint: '今天還能玩幾次',
        onSelect: (e, r) => r.say([ticketText() || '雲端還在確認…', '每天早上 5 點補滿 3 次免費遊玩，專注 25 分鐘以上還能多拿獎勵券。']) },
      { id: 'hopscotch', label: '跳房子', hint: '跳一跳',
        onSelect: (e, r) => {
          hops += 1;
          r.burst({ kind: 'star', count: 3 + (hops % 5), from: 'hopscotch', text: `跳了 ${hops} 格！` });
          if (hops === 9) r.say(['九格全部跳完！你今天的腿也很努力喔～']);
        } },
    ],
    layouts: {
      wide: {
        art: 'assets/scenes/park/park_wide.webp', aspect: 1.5, npcAt: [0.42, 0.9],
        rects: {
          wheel: [0.18, 0.05, 0.19, 0.3], carousel: [0.7, 0.12, 0.2, 0.26], stall: [0.17, 0.37, 0.24, 0.21],
          stage: [0.7, 0.38, 0.18, 0.18], hopscotch: [0.72, 0.57, 0.18, 0.15], booth: [0.47, 0.68, 0.13, 0.2],
        },
        effects: [
          { type: 'clouds', top: 0.0, band: 0.07, count: 5, alpha: 0.3 },
          { type: 'birds', y: 0.06, count: 5, period: 140 },
          { type: 'sparkle', points: [[0.28, 0.06], [0.2, 0.13], [0.35, 0.13], [0.28, 0.27], [0.79, 0.14], [0.73, 0.22], [0.87, 0.22], [0.2, 0.39], [0.38, 0.39]] },
          { type: 'flicker', points: [[0.15, 0.27], [0.45, 0.35], [0.46, 0.45], [0.58, 0.49], [0.64, 0.27], [0.91, 0.35], [0.43, 0.63], [0.64, 0.63], [0.9, 0.65]], radius: 0.012 },
          { type: 'balloons', points: [[0.4, 0.12], [0.42, 0.11], [0.36, 0.73], [0.38, 0.72], [0.71, 0.74], [0.73, 0.75]], radius: 0.01 },
          { type: 'fireflies', count: 10, top: 0.55, band: 0.4 },
        ],
        walkers: [
          { id: 'companion', path: [[0.535, 0.97], [0.535, 0.62], [0.44, 0.48], [0.4, 0.3], [0.44, 0.22], [0.5, 0.4], [0.535, 0.62]], speed: 0.05, pause: 1500 },
          { id: 'sprout', path: [[0.6, 0.45], [0.66, 0.37], [0.6, 0.3], [0.52, 0.42]], speed: 0.03, pause: 2500 },
          { id: 'inky', path: [[0.3, 0.62], [0.44, 0.66], [0.36, 0.7], [0.25, 0.66]], speed: 0.03, pause: 3000 },
        ],
      },
      tall: {
        art: 'assets/scenes/park/park.webp', aspect: 2 / 3, npcAt: [0.24, 0.95],
        rects: {
          wheel: [0.05, 0.03, 0.4, 0.29], stall: [0.02, 0.4, 0.43, 0.2], stage: [0.66, 0.4, 0.3, 0.16],
          carousel: [0.65, 0.1, 0.32, 0.25], booth: [0.38, 0.75, 0.22, 0.18], hopscotch: [0.66, 0.57, 0.26, 0.15],
        },
        effects: [
          { type: 'clouds', top: 0.0, band: 0.05, count: 3, alpha: 0.3 },
          { type: 'birds', y: 0.05, count: 4 },
          { type: 'sparkle', points: [[0.24, 0.05], [0.09, 0.15], [0.39, 0.15], [0.24, 0.27], [0.13, 0.24], [0.36, 0.24], [0.8, 0.13], [0.7, 0.2], [0.9, 0.2]] },
          { type: 'glow', points: [[0.27, 0.8], [0.73, 0.8], [0.42, 0.36], [0.6, 0.66], [0.94, 0.68]], radius: 0.06 },
          { type: 'balloons', points: [[0.42, 0.04], [0.45, 0.06], [0.17, 0.79], [0.2, 0.78], [0.8, 0.78], [0.83, 0.79]] },
        ],
        walkers: [
          { id: 'companion', path: [[0.5, 0.97], [0.5, 0.62], [0.47, 0.42], [0.5, 0.3], [0.55, 0.42]], speed: 0.06, pause: 1500 },
          { id: 'sprout', path: [[0.3, 0.66], [0.45, 0.68], [0.35, 0.72]], speed: 0.03, pause: 2500 },
        ],
      },
    },
  });
  root.addEventListener('nudge-arcade-result', () => room.burst({ kind: 'star', count: 10, from: 'booth' }));
})(typeof globalThis !== 'undefined' ? globalThis : this);
