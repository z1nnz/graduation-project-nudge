(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  root.NudgeArcadeMemoryCore = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';
  // Companion memory match. Faces are the App's six starter companions and
  // its badge/icon art (thumbnails in assets/arcade/cards/).

  const DIFFICULTIES = Object.freeze([
    Object.freeze({ id: 'easy', name: '4×4', cols: 4, rows: 4 }),
    Object.freeze({ id: 'normal', name: '5×4', cols: 5, rows: 4 }),
    Object.freeze({ id: 'hard', name: '6×5', cols: 6, rows: 5 }),
  ]);

  const FACES = Object.freeze([
    { id: 'c0', label: '星辰學徒', src: 'assets/arcade/cards/c0.png' },
    { id: 'c3', label: '星詠見習生', src: 'assets/arcade/cards/c3.png' },
    { id: 'c6', label: '焰心新星', src: 'assets/arcade/cards/c6.png' },
    { id: 'c9', label: '玫瑰書生', src: 'assets/arcade/cards/c9.png' },
    { id: 'c12', label: '月影見習忍', src: 'assets/arcade/cards/c12.png' },
    { id: 'c15', label: '森芽靈童', src: 'assets/arcade/cards/c15.png' },
    { id: 'badge', label: '小屋徽章', src: 'assets/arcade/cards/badge.png' },
    { id: 'focus', label: '專注徽章', src: 'assets/arcade/cards/focus.png' },
    { id: 'quest', label: '委託徽章', src: 'assets/arcade/cards/quest.png' },
    { id: 'health', label: '健康徽章', src: 'assets/arcade/cards/health.png' },
    { id: 'stats', label: '紀錄徽章', src: 'assets/arcade/cards/stats.png' },
    { id: 'room', label: '自律房徽章', src: 'assets/arcade/cards/room.png' },
    { id: 'letter', label: '信件徽章', src: 'assets/arcade/cards/letter.png' },
    { id: 'calendar', label: '行事曆徽章', src: 'assets/arcade/cards/calendar.png' },
    { id: 'social', label: '好友徽章', src: 'assets/arcade/cards/social.png' },
  ].map(f => Object.freeze(f)));

  const difficultyById = id => DIFFICULTIES.find(d => d.id === id) || null;
  const pairsFor = difficulty => (difficulty.cols * difficulty.rows) / 2;

  /** Shuffle (Fisher–Yates) with an injectable rng() -> [0,1). */
  function shuffle(list, rng = Math.random) {
    const out = list.slice();
    for (let i = out.length - 1; i > 0; i -= 1) {
      const j = Math.min(i, Math.floor(Math.max(0, Number(rng()) || 0) * (i + 1)));
      [out[i], out[j]] = [out[j], out[i]];
    }
    return out;
  }

  /** New board: companions first, then badges, two cards per face. */
  function deal(difficultyId, rng = Math.random) {
    const difficulty = difficultyById(difficultyId);
    if (!difficulty) throw new Error('unknown difficulty');
    const faces = FACES.slice(0, pairsFor(difficulty));
    const cards = shuffle(faces.flatMap(f => [f.id, f.id]), rng).map((face, index) => ({ index, face }));
    return { difficulty: difficulty.id, cards, open: [], matched: [], moves: 0, done: false };
  }

  /**
   * Flip card `index`. Two open cards that differ must be hidden with
   * `settle` first; flipping a third card settles them automatically.
   * Returns { board, event } where event is one of
   * 'ignored' | 'open' | 'match' | 'miss' | 'done'.
   */
  function flip(board, index) {
    const card = board.cards[index];
    if (!card || board.done || board.matched.includes(index) || board.open.includes(index)) {
      return { board, event: 'ignored' };
    }
    let open = board.open;
    if (open.length === 2) open = [];
    open = [...open, index];
    if (open.length === 1) return { board: { ...board, open }, event: 'open' };
    const moves = board.moves + 1;
    const [a, b] = open;
    if (board.cards[a].face === board.cards[b].face) {
      const matched = [...board.matched, a, b];
      const done = matched.length === board.cards.length;
      return { board: { ...board, open: [], matched, moves, done }, event: done ? 'done' : 'match' };
    }
    return { board: { ...board, open, moves }, event: 'miss' };
  }

  /** Hide a mismatched pair. */
  function settle(board) {
    return board.open.length === 2 ? { ...board, open: [] } : board;
  }

  const faceById = id => FACES.find(f => f.id === id) || null;

  return Object.freeze({ DIFFICULTIES, FACES, difficultyById, pairsFor, shuffle, deal, flip, settle, faceById });
});
