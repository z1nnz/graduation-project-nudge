(function (root) {
  'use strict';
  // The park map: each ride opens its arcade game (arcade.js keeps tickets,
  // timers and scores); Bounce runs the ticket booth.
  const doc = root.document;
  const hall = doc.getElementById('arcadeHall');
  if (!hall || !root.NudgeSceneRoom) return;
  const cabinet = id => doc.querySelector(`.arcade-cabinet[data-game="${id}"]`);
  const play = id => () => cabinet(id)?.click();
  const ticketText = () => doc.getElementById('arcadeTicket')?.textContent?.trim() || '';
  let hops = 0;

  const room = root.NudgeSceneRoom.mount({
    host: hall,
    art: 'assets/scenes/park/park.webp',
    title: '遊樂園',
    npc: 'bounce',
    npcAt: [0.24, 0.98],
    npcSize: 112,
    greeting: () => [`我是跳跳！${ticketText() ? '你現在：' + ticketText() + '。' : ''}`],
    tips: [
      '專注 25 分鐘以上換 1 張休息券，50 分鐘以上換 2 張。',
      '摩天輪上可以接星星，連續接五顆有加分喔！',
      '撈魚攤的魚分五種稀有度，傳說的魚只閃一下下。',
      '舞台上有三首 8-bit 曲子，打到 Perfect 很過癮！',
      '旋轉木馬轉著轉著，就把夥伴的臉記住了。',
      '跳房子是免費的，跳幾下活動一下筋骨吧～',
    ],
    objects: [
      { id: 'wheel', label: '摩天輪', hint: '接星星', x: 0.05, y: 0.03, w: 0.4, h: 0.29, onSelect: play('stars') },
      { id: 'stall', label: '撈魚攤', hint: '星光釣魚', x: 0.02, y: 0.4, w: 0.43, h: 0.2, onSelect: play('fishing') },
      { id: 'stage', label: '舞台', hint: '鐘塔節奏', x: 0.66, y: 0.4, w: 0.3, h: 0.16, onSelect: play('rhythm') },
      { id: 'carousel', label: '旋轉木馬', hint: '夥伴記憶配對', x: 0.65, y: 0.1, w: 0.32, h: 0.25, onSelect: play('memory') },
      { id: 'booth', label: '售票亭', hint: '看休息券', x: 0.38, y: 0.75, w: 0.22, h: 0.18,
        onSelect: (e, r) => r.say([ticketText() || '雲端還在確認你的休息券…', doc.querySelector('#arcadeHall .w-subtitle')?.textContent || ''].filter(Boolean)) },
      { id: 'hopscotch', label: '跳房子', hint: '跳一跳', x: 0.66, y: 0.57, w: 0.26, h: 0.15,
        onSelect: (e, r) => {
          hops += 1;
          r.burst({ kind: 'star', count: 3 + (hops % 5), from: 'hopscotch', text: `跳了 ${hops} 格！` });
          if (hops === 9) r.say(['九格全部跳完！你今天的腿也很努力喔～']);
        } },
    ],
    effects: [
      { type: 'sparkle', points: [[0.24, 0.05], [0.09, 0.15], [0.39, 0.15], [0.24, 0.27], [0.13, 0.24], [0.36, 0.24], [0.8, 0.13], [0.7, 0.2], [0.9, 0.2]] },
      { type: 'glow', points: [[0.27, 0.8], [0.73, 0.8], [0.42, 0.36], [0.6, 0.66], [0.94, 0.68]], radius: 0.06 },
      { type: 'balloons', points: [[0.42, 0.04], [0.45, 0.06], [0.17, 0.79], [0.2, 0.78], [0.8, 0.78], [0.83, 0.79]] },
      { type: 'stars', count: 14, height: 0.06 },
    ],
  });
  root.addEventListener('nudge-arcade-result', () => room.burst({ kind: 'star', count: 10, from: 'booth' }));
})(typeof globalThis !== 'undefined' ? globalThis : this);
