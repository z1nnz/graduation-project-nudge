import 'package:audioplayers/audioplayers.dart';

import '../models/focus_sound.dart';

/// Plays ambient loops with `audioplayers`, mixing with other apps so a
/// Spotify or Apple Music playlist keeps playing underneath.
class AudioplayersFocusBackend implements FocusSoundBackend {
  AudioplayersFocusBackend() {
    _player.setReleaseMode(ReleaseMode.loop);
    _player.setAudioContext(
      AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build(),
    );
  }

  final AudioPlayer _player = AudioPlayer(playerId: 'focus-ambient');

  @override
  Future<void> play(String asset, double volume) async {
    await _player.stop();
    await _player.setVolume(volume);
    await _player.play(AssetSource(asset));
  }

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() => _player.dispose();
}
