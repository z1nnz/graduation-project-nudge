const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const core = require('../web_dashboard/assets/town_audio_core.js');

test('audio stays off until both opt-in and a user gesture, and stops when hidden or reduced', () => {
  const ready = { enabled: true, interacted: true, hidden: false, reducedMotion: false };
  assert.equal(core.allowed(ready), true);
  for (const key of ['enabled', 'interacted']) assert.equal(core.allowed({ ...ready, [key]: false }), false);
  for (const key of ['hidden', 'reducedMotion']) assert.equal(core.allowed({ ...ready, [key]: true }), false);
  assert.equal(core.track('night'), 'town_night.wav');
  assert.equal(core.track('dusk'), 'town_night.wav');
  assert.equal(core.track('day'), 'town_day.wav');
  assert.equal(core.volume(200), 1);
  assert.equal(core.volume(-10), 0);
});

test('all seven original sounds exist and have a WAV header and license entry', () => {
  const folder = path.join(__dirname, '../web_dashboard/assets/audio');
  const license = fs.readFileSync(path.join(folder, 'LICENSES.txt'), 'utf8');
  for (const name of ['town_day.wav', 'town_night.wav', 'ui_click.wav', 'door_open.wav',
    'door_close.wav', 'stamp.wav', 'level_up.wav']) {
    const data = fs.readFileSync(path.join(folder, name));
    assert.equal(data.toString('ascii', 0, 4), 'RIFF', name);
    assert.equal(data.toString('ascii', 8, 12), 'WAVE', name);
    assert.ok(data.length > 3000, name);
    assert.ok(license.includes(name), name);
  }
});

test('town loads audio controls after HUD and before main input', () => {
  const html = fs.readFileSync(path.join(__dirname, '../web_dashboard/town.html'), 'utf8');
  assert.ok(html.indexOf('town_hud.js') < html.indexOf('town_audio.js'));
  assert.ok(html.indexOf('town_audio.js') < html.indexOf('town.js'));
});
