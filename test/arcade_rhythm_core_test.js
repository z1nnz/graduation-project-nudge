const test = require('node:test');
const assert = require('node:assert/strict');
const rhythm = require('../web_dashboard/assets/arcade_rhythm_core.js');

test('judgement windows: Perfect ±60 ms, Good ±120 ms', () => {
  assert.equal(rhythm.judge(0), 'perfect');
  assert.equal(rhythm.judge(60), 'perfect');
  assert.equal(rhythm.judge(-60), 'perfect');
  assert.equal(rhythm.judge(61), 'good');
  assert.equal(rhythm.judge(-120), 'good');
  assert.equal(rhythm.judge(121), null);
  assert.equal(rhythm.judge(NaN), null);
});

test('three songs, each 60–90 seconds, all lanes used, notes in order', () => {
  assert.equal(rhythm.SONGS.length, 3);
  for (const song of rhythm.SONGS) {
    const chart = rhythm.buildChart(song);
    assert.ok(chart.duration >= 60 && chart.duration <= 90, `${song.id}: ${chart.duration.toFixed(1)} s`);
    assert.ok(chart.notes.length >= 60, song.id);
    assert.deepEqual([...new Set(chart.notes.map(n => n.lane))].sort(), [0, 1, 2]);
    for (let i = 1; i < chart.notes.length; i += 1) assert.ok(chart.notes[i].t > chart.notes[i - 1].t);
    assert.ok(chart.notes[0].t >= rhythm.LEAD_IN_S);
    assert.equal(chart.melody.length, chart.notes.length);
    assert.ok(chart.bass.length > 0);
  }
});

test('lanes follow pitch: low, middle, high', () => {
  assert.deepEqual([1, 3, 4, 6, 7, 9].map(rhythm.laneOfStep), [0, 0, 1, 1, 2, 2]);
  assert.equal(Math.round(rhythm.midiToHz(69)), 440);
});

const chart = [
  { id: 0, t: 2.0, lane: 0 },
  { id: 1, t: 2.5, lane: 1 },
  { id: 2, t: 3.0, lane: 2 },
  { id: 3, t: 3.5, lane: 0 },
];

test('a press judges the closest note in its lane and builds combo', () => {
  const run = rhythm.newRun(chart);
  assert.equal(rhythm.press(run, chart, 0, 2.03).result, 'perfect');
  assert.equal(rhythm.press(run, chart, 1, 2.6).result, 'good');
  assert.equal(run.combo, 2);
  assert.equal(run.maxCombo, 2);
  assert.equal(rhythm.press(run, chart, 0, 2.6), null, 'wrong lane or no note: ignored');
  assert.equal(rhythm.press(run, chart, 2, 2.7), null, 'too early: ignored');
  assert.equal(run.counts.miss, 0);
});

test('a note can only be judged once', () => {
  const run = rhythm.newRun(chart);
  assert.equal(rhythm.press(run, chart, 0, 2.0).result, 'perfect');
  assert.equal(rhythm.press(run, chart, 0, 2.05), null);
});

test('passed notes become misses and break the combo', () => {
  const run = rhythm.newRun(chart);
  rhythm.press(run, chart, 0, 2.0);
  assert.deepEqual(rhythm.sweep(run, chart, 2.62).map(n => n.id), [], 'still inside Good window');
  assert.deepEqual(rhythm.sweep(run, chart, 2.63).map(n => n.id), [1]);
  assert.equal(run.combo, 0);
  assert.equal(run.counts.miss, 1);
  rhythm.sweep(run, chart, 10);
  assert.equal(run.counts.miss, 3);
  assert.equal(run.next, chart.length);
});

test('grades S/A/B/C from accuracy', () => {
  assert.equal(rhythm.grade({ perfect: 100, good: 0, miss: 0 }, 100), 'S');
  assert.equal(rhythm.grade({ perfect: 90, good: 10, miss: 0 }, 100), 'S');
  assert.equal(rhythm.grade({ perfect: 80, good: 10, miss: 10 }, 100), 'A');
  assert.equal(rhythm.grade({ perfect: 60, good: 20, miss: 20 }, 100), 'B');
  assert.equal(rhythm.grade({ perfect: 30, good: 20, miss: 50 }, 100), 'C');
  assert.equal(rhythm.grade({ perfect: 0, good: 0, miss: 0 }, 0), 'C');
});
