(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.NudgeCabinCore = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';
  // Pure rules for the Web companion cabin (#82 slice 3). No DOM access.
  //
  // Contract shared with the App and Cloud (PR #75):
  // - catalog: assets/home/home_decor_catalog.json (same file as the App and
  //   functions/src/home-decor-catalog.json); variant 0 of every slot is free.
  // - ownership: users/{uid}.unlockedAvatarItems contains
  //   `homeDecor:<slot order * 100 + variant index>`.
  // - arrangement: users/{uid}.homeDecor, written only by the arrangeHomeDecor
  //   callable, which re-checks ownership. The Web never writes it directly.

  const REQUEST_ID = /^[A-Za-z0-9][A-Za-z0-9._:-]{7,127}$/;

  function slots(catalog) {
    return Array.isArray(catalog?.slots) ? catalog.slots : [];
  }

  /** Cloud item index for a slot variant. */
  function cloudIndex(order, index) { return order * 100 + index; }
  function itemKey(order, index) { return `homeDecor:${cloudIndex(order, index)}`; }

  /** slot -> Set of variant indexes this account may place (free defaults included). */
  function ownedVariants(catalog, unlockedAvatarItems) {
    const unlocked = new Set(Array.isArray(unlockedAvatarItems)
      ? unlockedAvatarItems.filter(x => typeof x === 'string') : []);
    const owned = new Map();
    slots(catalog).forEach((slot, order) => {
      const set = new Set();
      for (const v of slot.variants || []) {
        if (v.index === 0 || unlocked.has(itemKey(order, v.index))) set.add(v.index);
      }
      owned.set(slot.slot, set);
    });
    return owned;
  }

  /** Every slot present with a known variant; anything else falls back to the free default. */
  function normalizeArrangement(raw, catalog) {
    const out = {};
    for (const slot of slots(catalog)) {
      const value = raw && typeof raw === 'object' ? raw[slot.slot] : undefined;
      const known = (slot.variants || []).some(v => v.index === value);
      out[slot.slot] = Number.isSafeInteger(value) && known ? value : 0;
    }
    return out;
  }

  /** What the cabin may show: a saved variant that is no longer owned shows the default. */
  function visibleArrangement(saved, catalog, owned) {
    const out = normalizeArrangement(saved, catalog);
    for (const slot of Object.keys(out)) {
      if (!owned.get(slot)?.has(out[slot])) out[slot] = 0;
    }
    return out;
  }

  function canPlace(owned, slot, index) {
    return Boolean(owned.get(slot)?.has(index));
  }

  /** New draft with one slot changed, or the same draft when the variant is not owned. */
  function choose(draft, owned, slot, index) {
    if (!canPlace(owned, slot, index)) return draft;
    return { ...draft, [slot]: index };
  }

  function isDirty(draft, saved) {
    return Object.keys(draft).some(slot => draft[slot] !== saved[slot]);
  }

  function newRequestId(nowMs, random = Math.random) {
    const id = `web-decor-${Math.floor(nowMs).toString(36)}-${random().toString(36).slice(2, 10)}`;
    return REQUEST_ID.test(id) ? id : `web-decor-${Math.floor(nowMs)}`;
  }

  /** Payload for the arrangeHomeDecor callable. */
  function arrangeCommand(draft, catalog, clientRequestId) {
    return {
      arrangement: normalizeArrangement(draft, catalog),
      clientRequestId,
      sourceSurface: 'web',
    };
  }

  /** The callable answers with the arrangement it stored; anything else is not trusted. */
  function validArrangeResult(result, sent) {
    const stored = result?.homeDecor;
    return Boolean(stored && typeof stored === 'object' &&
      Object.keys(sent).every(slot => stored[slot] === sent[slot]));
  }

  function code(error) {
    return String(error?.code || '').replace(/^functions\//, '');
  }

  /**
   * Honest message for a failed save. `saved` says whether we know the Cloud
   * kept the previous arrangement ('no') or cannot tell ('unknown').
   */
  function arrangeError(error) {
    const c = code(error);
    const message = String(error?.message || '');
    if (c === 'unauthenticated') return { kind: 'login', saved: 'no', message: '登入已過期，請重新登入後再保存擺設。' };
    if (c === 'failed-precondition' && /owned/i.test(message)) {
      return { kind: 'not-owned', saved: 'no', message: '有家具還不屬於你，雲端沒有保存。請到雜貨店購買後再擺放。' };
    }
    if (c === 'unavailable' && /paused/i.test(message)) {
      return { kind: 'paused', saved: 'no', message: '雲端帳本正在維護，暫時不能改擺設，稍後再試。' };
    }
    if (['unavailable', 'deadline-exceeded', 'internal', 'cancelled', 'unknown'].includes(c) || !c) {
      return {
        kind: 'network', saved: 'unknown',
        message: '連線中斷，無法確認是否已保存。重新整理後會顯示雲端目前的擺設。',
      };
    }
    return { kind: 'rejected', saved: 'no', message: '雲端拒絕了這次擺設，沒有保存。請重新整理後再試。' };
  }

  /** Decor image layers for the cabin stage, from assets/home/cabin_layout.json. */
  function decorLayers(layout, arrangement) {
    const out = [];
    for (const [slot, index] of Object.entries(arrangement || {})) {
      const layer = layout?.layers?.[slot];
      const src = layer?.images?.[index];
      if (!layer || typeof src !== 'string' || !Array.isArray(layer.rect)) continue;
      out.push({ slot, src, rect: layer.rect, z: Number(layer.z) || 0 });
    }
    return out.sort((a, b) => a.z - b.z);
  }

  /** Character sprite from the account's own avatar profile (same rule as the town). */
  function characterSprite(data) {
    const face = Number(data?.avatarProfile?.faceShapeIndex);
    return `assets/avatar/characters/character_${Number.isInteger(face) && face >= 0 ? face : 0}.png`;
  }

  return Object.freeze({
    slots, cloudIndex, itemKey, ownedVariants, normalizeArrangement, visibleArrangement,
    canPlace, choose, isDirty, newRequestId, arrangeCommand, validArrangeResult,
    arrangeError, decorLayers, characterSprite, REQUEST_ID,
  });
});
