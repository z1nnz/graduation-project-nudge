'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

function load(store = new Map()) {
  const played = [];
  class FakeAudio {
    constructor(src) { this.src = src; }
    cloneNode() { const a = new FakeAudio(this.src); a.play = () => { played.push(this.src); return Promise.resolve(); }; return a; }
  }
  const root = { Audio: FakeAudio, localStorage: { getItem: k => store.get(k) ?? null, setItem: (k, v) => store.set(k, v) } };
  const src = fs.readFileSync(path.join(__dirname, '../web_dashboard/assets/game_sfx.js'), 'utf8');
  new Function('globalThis', 'module', src)(root, undefined);
  return { sfx: root.NudgeSfx, played, store };
}

test('sounds play quietly by name and stay silent when muted', () => {
  const { sfx, played } = load();
  assert.equal(sfx.play('coin'), true);
  assert.deepEqual(played, ['assets/sfx/coin.wav']);
  assert.equal(sfx.play('not-a-sound'), false);
  sfx.setMuted(true);
  assert.equal(sfx.muted(), true);
  assert.equal(sfx.play('tap'), false);
  assert.equal(played.length, 1);
});

test('every named sound ships as a small wav for Web and App', () => {
  const { sfx } = load();
  for (const name of sfx.NAMES) {
    for (const dir of ['web_dashboard/assets/sfx', 'assets/audio/sfx']) {
      const file = path.join(__dirname, '..', dir, `${name}.wav`);
      assert.ok(fs.existsSync(file), file);
      assert.ok(fs.statSync(file).size < 40_000, file);
    }
  }
});
