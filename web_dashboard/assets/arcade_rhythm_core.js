(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  root.NudgeArcadeRhythmCore = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';
  // Clock-tower rhythm: three lanes (J K L), notes fall onto a judgement
  // line. The three songs are written here as 8-bit scores; the page plays
  // them with a Web Audio synth, so there are no audio files.

  const PERFECT_MS = 60;
  const GOOD_MS = 120;
  const LEAD_IN_S = 2;
  const TAIL_S = 1;
  const LANES = 3;
  const KEYS = Object.freeze(['j', 'k', 'l']);

  // Scale steps 1-9 of a major pentatonic, as semitones above the song key.
  const SCALE = Object.freeze([0, 2, 4, 7, 9, 12, 14, 16, 19]);

  // Each phrase is 16 eighth notes: '1'-'9' a scale step, '.' a rest.
  // bass lists the scale step held under each of its two bars.
  const SONGS = Object.freeze([
    song('dusk-bells', '黃昏鐘聲', '慢步的鐘聲，適合第一次挑戰。', 108, 60, 'square', {
      A: ['1.3.5.3.6.5.3...', [1, 4]],
      B: ['5.6.8.6.5.3.2...', [4, 1]],
      C: ['3.5.6.9.8.6.5.3.', [5, 4]],
      D: ['1.2.3.5.3.2.1...', [2, 1]],
    }, 'ABACBCAD ABACBCAD'),
    song('firefly-lake', '湖面螢火', '輕輕搖晃的切分節奏。', 96, 57, 'triangle', {
      A: ['4..5..6.5...3...', [1, 4]],
      B: ['6..8..9.8...6...', [4, 5]],
      C: ['3.4.5...6.5.4...', [2, 5]],
      D: ['1...3...5...4...', [4, 1]],
    }, 'ABCD ABCD ACBC AD'),
    song('starlight-run', '星光跑跑', '輕快的跑跳曲，音符比較密。', 132, 62, 'square', {
      A: ['1.3.5.8.5.3.5.8.', [1, 1]],
      B: ['9.8.6.5.6.8.9...', [4, 5]],
      C: ['2.4.6.4.7.6.4.2.', [2, 5]],
      D: ['5.5.8.8.9.8.6...', [4, 1]],
      E: ['1.5.9.5.1.5.9...', [1, 4]],
    }, 'AABC AABD CCBD ABCE ABDC BE'),
  ]);

  function song(id, title, blurb, bpm, keyMidi, wave, phrases, arrangement) {
    return Object.freeze({
      id, title, blurb, bpm, keyMidi, wave,
      phrases: Object.freeze(phrases),
      arrangement: Object.freeze(arrangement.replace(/\s+/g, '').split('')),
    });
  }

  function laneOfStep(step) {
    if (step <= 3) return 0;
    if (step <= 6) return 1;
    return 2;
  }

  // Milliseconds between two song times, rounded to 1 µs so float noise
  // (2.62 - 2.5 = 0.12000000000000011) never flips a judgement.
  const msBetween = (a, b) => Math.round((a - b) * 1e6) / 1e3;

  const midiToHz = midi => 440 * Math.pow(2, (midi - 69) / 12);

  /**
   * Turn a score into timed events. Times are seconds from the start of
   * playback (the lead-in is included). Returns notes (playable, one per
   * lane hit), melody and bass (for the synth) and the song length.
   */
  function buildChart(songDef) {
    const eighth = 60 / songDef.bpm / 2;
    const notes = [];
    const melody = [];
    const bass = [];
    let t = LEAD_IN_S;
    for (const name of songDef.arrangement) {
      const [line, chords] = songDef.phrases[name];
      if (typeof line !== 'string' || line.length !== 16) throw new Error(`phrase ${name} must be 16 steps`);
      for (let i = 0; i < 16; i += 1) {
        const ch = line[i];
        const at = t + i * eighth;
        if (i % 8 === 0) {
          const root = chords[i / 8];
          bass.push({ t: at, dur: eighth * 8 * 0.95, hz: midiToHz(songDef.keyMidi - 12 + SCALE[root - 1]) });
        }
        if (ch === '.') continue;
        const step = Number(ch);
        if (!Number.isInteger(step) || step < 1 || step > 9) throw new Error(`bad step ${ch}`);
        let len = 1;
        while (i + len < 16 && line[i + len] === '.' && len < 2) len += 1;
        melody.push({ t: at, dur: eighth * len * 0.9, hz: midiToHz(songDef.keyMidi + SCALE[step - 1]) });
        notes.push({ id: notes.length, t: at, lane: laneOfStep(step) });
      }
      t += eighth * 16;
    }
    return { notes, melody, bass, duration: t + TAIL_S };
  }

  /** 'perfect' | 'good' | null for a press `deltaMs` away from a note. */
  function judge(deltaMs) {
    const d = Math.abs(Number(deltaMs));
    if (!Number.isFinite(d)) return null;
    if (d <= PERFECT_MS) return 'perfect';
    if (d <= GOOD_MS) return 'good';
    return null;
  }

  function newRun(notes) {
    return {
      next: 0,
      judged: new Map(),
      counts: { perfect: 0, good: 0, miss: 0 },
      combo: 0,
      maxCombo: 0,
      score: 0,
      total: notes.length,
    };
  }

  const POINTS = { perfect: 100, good: 50, miss: 0 };

  function record(run, note, result) {
    run.judged.set(note.id, result);
    run.counts[result] += 1;
    if (result === 'miss') run.combo = 0;
    else {
      run.combo += 1;
      run.maxCombo = Math.max(run.maxCombo, run.combo);
      run.score += POINTS[result] + Math.min(50, run.combo);
    }
  }

  /**
   * A press in `lane` at song time `timeS`. Judges the closest open note in
   * that lane inside the Good window; a press with no note nearby is ignored
   * (no penalty). Returns { result, note } or null.
   */
  function press(run, notes, lane, timeS) {
    let best = null;
    for (let i = run.next; i < notes.length; i += 1) {
      const note = notes[i];
      if (msBetween(note.t, timeS) > GOOD_MS) break;
      if (note.lane !== lane || run.judged.has(note.id)) continue;
      const delta = msBetween(timeS, note.t);
      if (Math.abs(delta) <= GOOD_MS && (!best || Math.abs(delta) < Math.abs(best.delta))) best = { note, delta };
    }
    if (!best) return null;
    const result = judge(best.delta);
    record(run, best.note, result);
    advance(run, notes);
    return { result, note: best.note, deltaMs: Math.round(best.delta) };
  }

  /** Mark notes whose Good window has passed as misses. Returns them. */
  function sweep(run, notes, timeS) {
    const missed = [];
    for (let i = run.next; i < notes.length; i += 1) {
      const note = notes[i];
      if (msBetween(timeS, note.t) <= GOOD_MS) break;
      if (!run.judged.has(note.id)) { record(run, note, 'miss'); missed.push(note); }
    }
    advance(run, notes);
    return missed;
  }

  function advance(run, notes) {
    while (run.next < notes.length && run.judged.has(notes[run.next].id)) run.next += 1;
  }

  function accuracy(counts, total) {
    if (!total) return 0;
    return (counts.perfect + counts.good * 0.5) / total;
  }

  /** S ≥ 95 %, A ≥ 85 %, B ≥ 70 %, otherwise C. */
  function grade(counts, total) {
    const acc = accuracy(counts, total);
    if (acc >= 0.95) return 'S';
    if (acc >= 0.85) return 'A';
    if (acc >= 0.7) return 'B';
    return 'C';
  }

  const songById = id => SONGS.find(s => s.id === id) || null;

  return Object.freeze({
    PERFECT_MS, GOOD_MS, LEAD_IN_S, LANES, KEYS, SONGS, songById,
    buildChart, judge, newRun, press, sweep, accuracy, grade, laneOfStep, midiToHz,
  });
});
