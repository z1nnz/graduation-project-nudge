(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.NudgeRewardShopCore = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';
  // Pure rules for the Web shop (operations.html, #82 slice 3). No DOM access.
  //
  // Every purchase goes through the existing purchaseRewardItem callable,
  // which prices the item, checks the balance and writes the reward ledger in
  // one Cloud transaction. The Web only builds the command, keeps a button
  // from sending twice, and explains the outcome honestly. It never applies
  // discounts, changes balances or unlocks items by itself.

  /** Published, in-window character listings whose first stage is for sale. */
  function characterListings(items, nowEpochSeconds, unlockedAvatarItems) {
    const unlocked = new Set(Array.isArray(unlockedAvatarItems) ? unlockedAvatarItems : []);
    return (Array.isArray(items) ? items : [])
      .filter(item => item && item.status === 'published' && Array.isArray(item.character_stages) &&
        (item.start_time == null || Number(item.start_time) <= nowEpochSeconds) &&
        (item.end_time == null || Number(item.end_time) > nowEpochSeconds))
      .map(item => {
        const stage = item.character_stages.find(s => Number(s?.stage) === 1 && s?.shop_eligible === true);
        const index = Number(stage?.catalog_index);
        const price = Number(stage?.coin_price);
        if (!stage || !Number.isSafeInteger(index) || !Number.isSafeInteger(price) || price <= 0) return null;
        return {
          kind: 'character',
          id: String(item.id),
          tab: ['permanent', 'avatar_series'].includes(item.type) ? 'permanent' : String(item.type || ''),
          name: String(item.name || stage.name || '角色'),
          description: String(item.description || '由營運後台發布的完整角色進化鏈。'),
          image: String(stage.character_asset || item.image_path || ''),
          endTime: item.end_time == null ? null : Number(item.end_time),
          index,
          price,
          itemKey: `faceShape:${index}`,
          owned: unlocked.has(`faceShape:${index}`),
        };
      })
      .filter(Boolean);
  }

  /** Priced home decor variants from the shared catalog (free defaults are not sold). */
  function decorListings(catalog, unlockedAvatarItems) {
    const unlocked = new Set(Array.isArray(unlockedAvatarItems) ? unlockedAvatarItems : []);
    const out = [];
    (Array.isArray(catalog?.slots) ? catalog.slots : []).forEach((slot, order) => {
      for (const v of slot.variants || []) {
        if (!(Number(v.price) > 0)) continue;
        const index = order * 100 + v.index;
        out.push({
          kind: 'decor',
          id: `homeDecor:${index}`,
          tab: 'decor',
          slot: slot.slot,
          slotLabel: slot.label,
          variant: v.index,
          name: v.name,
          description: `${slot.label}・放進你的小屋`,
          image: `assets/home/${slot.slot}_${v.index}.png`,
          endTime: null,
          index,
          price: Number(v.price),
          itemKey: `homeDecor:${index}`,
          owned: unlocked.has(`homeDecor:${index}`),
        });
      }
    });
    return out;
  }

  /**
   * purchaseRewardItem payload. The request id is fixed per item, so pressing
   * again after a lost connection replays the same Cloud entry instead of
   * charging twice (the existing Web id format for characters is kept).
   */
  function purchaseCommand(listing) {
    if (listing.kind === 'character') {
      return {
        category: 'faceShape', index: listing.index, catalogItemId: listing.id,
        clientRequestId: `web-purchase-faceShape-${listing.index}`, sourceSurface: 'web',
      };
    }
    return {
      category: 'homeDecor', index: listing.index, catalogItemId: null,
      clientRequestId: `web-purchase-homeDecor-${listing.index}`, sourceSurface: 'web',
    };
  }

  function validPurchaseResult(result, listing) {
    return Boolean(result && result.itemKey === listing.itemKey &&
      Number.isSafeInteger(result.disciplineCoins) && result.disciplineCoins >= 0 &&
      Array.isArray(result.unlockedAvatarItems) && result.unlockedAvatarItems.includes(listing.itemKey));
  }

  /** What the button can do before asking Cloud (Cloud still decides). */
  function buttonState(listing, { signedIn, balance, busy }) {
    if (busy) return { disabled: true, label: '兌換中…' };
    if (listing.owned) return { disabled: true, label: '已擁有' };
    if (!signedIn) return { disabled: false, label: `登入後兌換（${listing.price} 幣）`, login: true };
    if (Number.isSafeInteger(balance) && balance < listing.price) {
      return { disabled: true, label: `還差 ${listing.price - balance} 幣`, reason: 'balance' };
    }
    return { disabled: false, label: `兌換（${listing.price} 幣）` };
  }

  function code(error) {
    return String(error?.code || '').replace(/^functions\//, '');
  }

  /**
   * Honest outcome of a failed purchase. charged: 'no' when Cloud rejected the
   * command (its transaction did not run), 'unknown' when the answer was lost.
   */
  function purchaseError(error) {
    const c = code(error);
    const message = String(error?.message || '');
    if (c === 'unauthenticated') return { kind: 'login', charged: 'no', message: '請先登入自己的帳號再兌換。' };
    if (c === 'failed-precondition' && /insufficient/i.test(message)) {
      return { kind: 'balance', charged: 'no', message: '自律幣不足，沒有扣款。完成雲端確認的行動可以累積自律幣。' };
    }
    if (c === 'not-found') return { kind: 'gone', charged: 'no', message: '這個商品已下架或售完，沒有扣款。' };
    if (c === 'unavailable' && /paused/i.test(message)) {
      return { kind: 'paused', charged: 'no', message: '雲端帳本正在維護，商城暫停兌換，沒有扣款。' };
    }
    if (c === 'already-exists') return { kind: 'conflict', charged: 'no', message: '這筆兌換和先前的要求不一致，沒有扣款。請重新整理後再試。' };
    if (c === 'failed-precondition' || c === 'invalid-argument' || c === 'permission-denied') {
      return { kind: 'rejected', charged: 'no', message: '雲端拒絕了這次兌換，沒有扣款。請重新整理後再試。' };
    }
    return {
      kind: 'network', charged: 'unknown',
      message: '連線中斷，無法確認是否兌換成功。請稍後再按一次：同一個商品不會重複扣款。',
    };
  }

  /** One in-flight purchase per item key; a second press is ignored. */
  function createInFlight() {
    const busy = new Set();
    return {
      start(key) { if (busy.has(key)) return false; busy.add(key); return true; },
      finish(key) { busy.delete(key); },
      has(key) { return busy.has(key); },
    };
  }

  return Object.freeze({
    characterListings, decorListings, purchaseCommand, validPurchaseResult,
    buttonState, purchaseError, createInFlight,
  });
});
