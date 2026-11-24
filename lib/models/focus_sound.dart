import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// An original ambient loop bundled with the app (synthesised in-house, so no
/// third-party audio).
class FocusSound {
  const FocusSound(this.id, this.label, this.emoji);

  final String id;
  final String label;
  final String emoji;

  /// Path relative to `assets/`, as audio players expect.
  String get asset => 'audio/ambient/$id.wav';

  static const all = [
    FocusSound('rain', '雨聲', '🌧️'),
    FocusSound('fire', '壁爐', '🔥'),
    FocusSound('stream', '溪流', '🏞️'),
    FocusSound('brown', '低沉白噪音', '🌫️'),
  ];

  static FocusSound? byId(String? id) {
    for (final s in all) {
      if (s.id == id) return s;
    }
    return null;
  }
}

/// A music app the user can jump to. The ambient loop mixes with whatever the
/// music app plays, so both can run during focus.
class MusicApp {
  const MusicApp(this.label, this.url);

  final String label;
  final String url;

  Uri get uri => Uri.parse(url);

  static const all = [
    MusicApp('Spotify', 'https://open.spotify.com/'),
    MusicApp('Apple Music', 'https://music.apple.com/'),
    MusicApp('YouTube Music', 'https://music.youtube.com/'),
    MusicApp('KKBOX', 'https://www.kkbox.com/tw/tc'),
  ];
}

/// The audio engine behind the controller; swapped for a fake in tests.
abstract class FocusSoundBackend {
  Future<void> play(String asset, double volume);
  Future<void> setVolume(double volume);
  Future<void> stop();
  Future<void> dispose();
}

/// Which ambient loop is chosen and how loud, remembered between sessions.
class FocusSoundController extends ChangeNotifier {
  FocusSoundController({required FocusSoundBackend backend})
    : _backend = backend;

  static const _idKey = 'focus_sound_id';
  static const _volumeKey = 'focus_sound_volume';
  static const defaultVolume = 0.6;

  final FocusSoundBackend _backend;
  FocusSound? _current;
  double _volume = defaultVolume;
  bool _playing = false;

  FocusSound? get current => _current;
  double get volume => _volume;
  bool get playing => _playing;

  /// Loads the saved choice without starting playback.
  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    _current = FocusSound.byId(prefs.getString(_idKey));
    _volume = (prefs.getDouble(_volumeKey) ?? defaultVolume).clamp(0.0, 1.0);
    notifyListeners();
  }

  /// Starts the saved sound, if any (for example when a focus round begins).
  Future<void> resume() async {
    final sound = _current;
    if (sound == null || _playing) return;
    _playing = true;
    notifyListeners();
    await _backend.play(sound.asset, _volume);
  }

  Future<void> select(String? id) async {
    final sound = FocusSound.byId(id);
    _current = sound;
    final prefs = await SharedPreferences.getInstance();
    if (sound == null) {
      await prefs.remove(_idKey);
      _playing = false;
      notifyListeners();
      await _backend.stop();
      return;
    }
    await prefs.setString(_idKey, sound.id);
    _playing = true;
    notifyListeners();
    await _backend.play(sound.asset, _volume);
  }

  Future<void> setVolume(double value) async {
    _volume = value.clamp(0.0, 1.0);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_volumeKey, _volume);
    await _backend.setVolume(_volume);
  }

  Future<void> pause() async {
    if (!_playing) return;
    _playing = false;
    notifyListeners();
    await _backend.stop();
  }

  @override
  void dispose() {
    _backend.dispose();
    super.dispose();
  }
}
