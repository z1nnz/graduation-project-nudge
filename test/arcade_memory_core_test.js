const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const memory = require('../web_dashboard/assets/arcade_memory_core.js');

const seq = values => { let i = 0; return () => values[i++ % values.length]; };

test('three sizes deal full pairs', () => {
  for (const [id, cards] of [['easy', 16], ['normal', 20], ['hard', 30]]) {
    const board = memory.deal(id, Math.random);
    assert.equal(board.cards.length, cards);
    const counts = {};
    for (const c of board.cards) counts[c.face] = (counts[c.face] || 0) + 1;
    assert.ok(Object.values(counts).every(n => n === 2), id);
    assert.equal(Object.keys(counts).length, cards / 2);
  }
  assert.throws(() => memory.deal('giant'));
});

test('the six companions always appear; every face has art', () => {
  const faces = new Set(memory.deal('easy').cards.map(c => c.face));
  for (const id of ['c0', 'c3', 'c6', 'c9', 'c12', 'c15']) assert.ok(faces.has(id));
  for (const f of memory.FACES) {
    assert.ok(fs.existsSync(path.join(__dirname, '..', 'web_dashboard', f.src)), f.src);
  }
});

test('shuffle is a permutation', () => {
  const out = memory.shuffle([1, 2, 3, 4, 5], seq([0.1, 0.9, 0.5, 0.3]));
  assert.deepEqual([...out].sort(), [1, 2, 3, 4, 5]);
});

function fixedBoard() {
  const board = memory.deal('easy', () => 0);
  // Put a known pair at 0/1 and a non-pair at 2/3.
  const faces = ['c0', 'c0', 'c3', 'c6', ...board.cards.slice(4).map(c => c.face)];
  return { ...board, cards: board.cards.map((c, i) => ({ ...c, face: faces[i] })) };
}

test('a matching pair stays open and counts one move', () => {
  let { board, event } = memory.flip(fixedBoard(), 0);
  assert.equal(event, 'open');
  ({ board, event } = memory.flip(board, 1));
  assert.equal(event, 'match');
  assert.deepEqual(board.matched, [0, 1]);
  assert.equal(board.moves, 1);
  assert.equal(memory.flip(board, 0).event, 'ignored', 'matched cards cannot be flipped');
});

test('a mismatch stays visible until settled or a third card is flipped', () => {
  let { board, event } = memory.flip(fixedBoard(), 2);
  assert.equal(memory.flip(board, 2).event, 'ignored', 'same card twice');
  ({ board, event } = memory.flip(board, 3));
  assert.equal(event, 'miss');
  assert.deepEqual(board.open, [2, 3]);
  assert.equal(board.moves, 1);
  assert.deepEqual(memory.settle(board).open, []);
  ({ board, event } = memory.flip(board, 0));
  assert.equal(event, 'open');
  assert.deepEqual(board.open, [0]);
});

test('matching every pair finishes the board', () => {
  let board = memory.deal('easy', Math.random);
  const byFace = {};
  board.cards.forEach(c => (byFace[c.face] = byFace[c.face] || []).push(c.index));
  let last;
  for (const [a, b] of Object.values(byFace)) {
    board = memory.flip(board, a).board;
    ({ board, event: last } = memory.flip(board, b));
  }
  assert.equal(last, 'done');
  assert.equal(board.done, true);
  assert.equal(board.moves, 8);
  assert.equal(memory.flip(board, 0).event, 'ignored');
});
