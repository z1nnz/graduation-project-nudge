import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Small 8-bit sound effects for the game rooms. Quiet, mixed with other
/// apps, remembered mute switch. Silently does nothing where audio is
/// unavailable (tests, missing plugin).
abstract final class GameSfx {
  static const names = {'tap', 'coin', 'sparkle', 'page', 'open', 'heart'};
  static const _prefKey = 'game_sfx_muted';
  static const _volume = 0.35;

  /// Turned on by main(); stays off in widget tests.
  static bool enabled = false;
  static bool _muted = false;
  static bool _loaded = false;
  static final Map<String, AudioPlayer> _players = {};

  static bool get muted => _muted;

  static Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _muted = prefs.getBool(_prefKey) ?? false;
    } catch (_) {}
  }

  static Future<void> setMuted(bool value) async {
    _muted = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, value);
    } catch (_) {}
  }

  static void play(String name) {
    if (!enabled || _muted || !names.contains(name)) return;
    try {
      final player = _players.putIfAbsent(name, () {
        final p = AudioPlayer(playerId: 'sfx-$name');
        p.setReleaseMode(ReleaseMode.stop);
        p
            .setAudioContext(
              AudioContextConfig(
                focus: AudioContextConfigFocus.mixWithOthers,
              ).build(),
            )
            .catchError((_) {});
        return p;
      });
      player
          .play(
            AssetSource('audio/sfx/$name.wav'),
            volume: _volume,
            mode: PlayerMode.lowLatency,
          )
          .catchError((_) {});
    } catch (_) {
      // No audio here: the game stays silent.
    }
  }
}
