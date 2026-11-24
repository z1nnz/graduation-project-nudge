(function(root) {
  'use strict';
  const doc = root.document, core = root.NudgeTownAudioCore;
  if (!core || doc.body?.dataset.page !== 'town') return;
  const host = doc.getElementById('townAudioSettings');
  const storageKey = 'nudge_town_audio_v1';
  let saved = {};
  try { saved = JSON.parse(root.localStorage.getItem(storageKey) || '{}') || {}; } catch { saved = {}; }
  const prefs = { soundEffects: saved.soundEffects === true, ambience: saved.ambience === true,
    volume: Number.isFinite(Number(saved.volume)) ? Math.max(0, Math.min(100, Number(saved.volume))) : 50 };
  let interacted = false, currentTrack = null;
  const tracks = new Map();
  const save = () => { try { root.localStorage.setItem(storageKey, JSON.stringify(prefs)); } catch { /* private mode */ } };
  const reduced = () => Boolean(root.NudgeTownHud?.reducedMotion);
  const can = enabled => core.allowed({ enabled, interacted, hidden: doc.hidden, reducedMotion: reduced() });

  function audio(name, loop = false) {
    if (!tracks.has(name)) {
      const player = new Audio(`assets/audio/${name}`);
      player.preload = 'none';
      player.loop = loop;
      tracks.set(name, player);
    }
    return tracks.get(name);
  }

  function phaseTrack() {
    return core.track(root.NudgeTownAtmosphereCore?.phaseAt(new Date()).name);
  }

  function syncAmbient() {
    const wanted = can(prefs.ambience) ? phaseTrack() : null;
    if (currentTrack && currentTrack !== wanted) tracks.get(currentTrack)?.pause();
    currentTrack = wanted;
    if (!wanted) return;
    const player = audio(wanted, true);
    player.volume = core.volume(prefs.volume) * .55;
    if (player.paused) player.play().catch(() => { /* browser or OS declined playback */ });
  }

  function effect(name) {
    if (!can(prefs.soundEffects)) return;
    const original = audio(name);
    const player = original.paused ? original : original.cloneNode();
    player.volume = core.volume(prefs.volume) * .7;
    player.play().catch(() => { /* browser or OS declined playback */ });
  }

  function activate() { interacted = true; syncAmbient(); }
  doc.addEventListener('pointerdown', activate, { once: true });
  doc.addEventListener('keydown', activate, { once: true });
  doc.addEventListener('click', event => {
    if (event.target?.closest?.('button, a')) effect('ui_click.wav');
  });
  doc.addEventListener('nudge-town-scene', event => effect(event.detail?.open ? 'door_open.wav' : 'door_close.wav'));
  doc.addEventListener('nudge-town-celebrate', () => effect('stamp.wav'));
  doc.addEventListener('nudge-town-level-up', () => effect('level_up.wav'));
  doc.addEventListener('nudge-town-preference', syncAmbient);
  doc.addEventListener('visibilitychange', syncAmbient);
  root.addEventListener('pagehide', () => { for (const track of tracks.values()) track.pause(); });
  root.setInterval(syncAmbient, 60000);

  function option(id, title, checked) {
    const label = doc.createElement('label'), input = doc.createElement('input');
    input.type = 'checkbox'; input.id = id; input.checked = checked;
    label.append(input, doc.createTextNode(` ${title}`));
    host.appendChild(label);
    return input;
  }
  const effectsToggle = option('townSoundEffects', '介面音效', prefs.soundEffects);
  const ambientToggle = option('townAmbientAudio', '小鎮環境音', prefs.ambience);
  const volumeLabel = doc.createElement('label'), volumeInput = doc.createElement('input');
  volumeInput.type = 'range'; volumeInput.id = 'townAudioVolume';
  volumeInput.min = '0'; volumeInput.max = '100'; volumeInput.step = '5';
  volumeInput.value = String(prefs.volume);
  volumeInput.setAttribute('aria-label', '小鎮音量');
  volumeLabel.append(doc.createTextNode('音量'), volumeInput);
  host.appendChild(volumeLabel);
  effectsToggle.addEventListener('change', () => { prefs.soundEffects = effectsToggle.checked; save(); });
  ambientToggle.addEventListener('change', () => { prefs.ambience = ambientToggle.checked; save(); syncAmbient(); });
  volumeInput.addEventListener('input', () => { prefs.volume = Number(volumeInput.value); save(); syncAmbient(); });
  root.NudgeTownAudio = { effect, syncAmbient };
})(typeof globalThis !== 'undefined' ? globalThis : this);
