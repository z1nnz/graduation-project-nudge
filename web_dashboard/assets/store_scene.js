(function (root) {
  'use strict';
  // The general store: shelves open the real shop (reward_shop.js), the cash
  // box shows the Cloud ledger balance, Chestnut talks, the cat purrs.
  const doc = root.document;
  const shop = () => root.NudgeRewardShop;
  const shelf = doc.getElementById('storeShelf');
  const ledger = doc.getElementById('storeLedger');
  if (!shelf || !root.NudgeSceneRoom) return;

  const TAB_TITLE = {
    permanent: '衣服架：常駐角色',
    limited: '玻璃櫃：限時角色',
    event_character: '玻璃櫃：活動角色',
    decor: '家具架：小屋家具',
  };
  function showTabs(tabs) {
    shelf.querySelectorAll('.shop-tab-btn').forEach(b => { b.hidden = !tabs.includes(b.dataset.tab); });
  }
  function openShelf(tabs, from) {
    showTabs(tabs);
    if (!tabs.includes(shop()?.tab())) shop()?.selectTab(tabs[0]);
    room.openPanel({ title: TAB_TITLE[shop()?.tab()] || '貨架', content: shelf, variant: 'shelf', from });
  }
  shelf.addEventListener('click', e => {
    const tab = e.target.closest?.('.shop-tab-btn')?.dataset.tab;
    if (tab) room.dialog.querySelector('.room-panel-title').textContent = TAB_TITLE[tab];
  });

  const coins = () => shop()?.balance?.();
  let catPets = 0;
  const room = root.NudgeSceneRoom.mount({
    host: doc.getElementById('storeMain'),
    art: 'assets/scenes/store/store.webp',
    title: '小鎮雜貨店',
    npc: 'chestnut',
    npcAt: [0.3, 0.88],
    greeting: () => {
      const c = coins();
      return [c == null ? '歡迎光臨！登入之後，我就能幫你查錢箱裡有多少自律幣喔。' : `歡迎光臨！你的錢箱裡有 ${c} 枚自律幣。`];
    },
    tips: [
      '左邊的衣服架是常駐角色，隨時都買得到。',
      '中間的木架擺的是小屋家具，買了就能回家布置。',
      '右邊發亮的玻璃櫃裡，是限時和活動才有的特別角色。',
      '想換衣服？站到鏡子前面就能進更衣室。',
      '金幣只能靠真實的任務和專注賺到，我這裡不打折，但絕對不會多扣。',
      '那隻橘貓叫「麻糬」，牠只在你摸牠的時候才會醒來。',
    ],
    objects: [
      { id: 'clothes', label: '衣服架', hint: '常駐角色', x: 0.03, y: 0.235, w: 0.3, h: 0.225,
        onSelect: (e, r) => openShelf(['permanent'], r.object('clothes')) },
      { id: 'furniture', label: '家具架', hint: '小屋家具', x: 0.35, y: 0.235, w: 0.265, h: 0.23,
        onSelect: (e, r) => openShelf(['decor'], r.object('furniture')) },
      { id: 'cabinet', label: '玻璃櫃', hint: '限時與活動角色', x: 0.65, y: 0.19, w: 0.215, h: 0.27,
        onSelect: (e, r) => openShelf(['limited', 'event_character'], r.object('cabinet')) },
      { id: 'cashbox', label: '錢箱', hint: '看看自律幣', x: 0.06, y: 0.49, w: 0.15, h: 0.085,
        onSelect: (e, r) => {
          r.burst({ kind: 'coin', count: 5, from: 'cashbox' });
          r.openPanel({ title: '錢箱與帳本', content: ledger, variant: 'parchment', from: r.object('cashbox') });
        } },
      { id: 'cat', label: '麻糬', hint: '摸摸貓', x: 0.29, y: 0.51, w: 0.25, h: 0.065,
        onSelect: (e, r) => {
          catPets += 1;
          r.burst({ kind: 'heart', count: 4 + Math.min(catPets, 4), from: 'cat', text: catPets > 3 ? '麻糬翻了個身，呼嚕呼嚕。' : '麻糬呼嚕了一聲。' });
          if (catPets === 5) r.say(['麻糬很少讓客人摸這麼久，牠很喜歡你喔！']);
        } },
      { id: 'mirror', label: '鏡子', hint: '進更衣室換裝', x: 0.75, y: 0.48, w: 0.24, h: 0.3,
        onSelect: () => { root.location.href = 'profile.html'; } },
    ],
    effects: [
      { type: 'glow', points: [[0.42, 0.125], [0.67, 0.125], [0.58, 0.5], [0.02, 0.83]], radius: 0.09 },
      { type: 'sparkle', points: [[0.72, 0.28], [0.8, 0.25], [0.7, 0.38], [0.82, 0.36], [0.74, 0.43], [0.83, 0.44]] },
      { type: 'dust', count: 16 },
    ],
  });

  root.addEventListener('nudge-shop-purchase', e => {
    const { item, from, alreadyUnlocked } = e.detail;
    if (alreadyUnlocked) { room.say([`「${item.name}」你已經有了，我沒有再收你的錢喔。`]); return; }
    room.burst({ kind: 'coin', count: Math.min(12, 4 + Math.round(item.price / 50)), from, to: 'cashbox' });
    root.setTimeout(() => room.burst({ kind: 'star', count: 8, from, text: `買到了「${item.name}」！` }), 450);
    root.setTimeout(() => room.say([
      `謝謝惠顧！「${item.name}」幫你包好了。`,
      item.kind === 'decor' ? '回小屋打開布置模式就能擺放。' : '到鏡子前面就能換上它。',
    ]), 700);
  });
  root.addEventListener('nudge-shop-short', e => {
    const { item, missing } = e.detail;
    room.closePanel();
    room.say([`「${item.name}」還差 ${missing} 枚金幣。`, '去委託所接幾張委託單，很快就存到了！'], [
      { label: '去委託所', onSelect: () => { root.location.href = 'quests.html'; } },
      { label: '再逛逛' },
    ]);
  });
  root.addEventListener('nudge-shop-lift', e => {
    room.announce(`拿起了「${e.detail.item.name}」`);
  });
})(typeof globalThis !== 'undefined' ? globalThis : this);
