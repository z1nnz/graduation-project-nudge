(function(root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  root.NudgeTownAudioCore = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function() {
  'use strict';
  const track = phase => phase === 'night' || phase === 'dusk' ? 'town_night.wav' : 'town_day.wav';
  const volume = value => Math.max(0, Math.min(1, Number(value) / 100 || 0));
  const allowed = ({ enabled, interacted, hidden, reducedMotion }) =>
    enabled === true && interacted === true && hidden !== true && reducedMotion !== true;
  return { track, volume, allowed };
});
