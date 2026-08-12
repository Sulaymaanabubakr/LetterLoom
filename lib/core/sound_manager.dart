import 'package:audioplayers/audioplayers.dart';
import '../../models/game_settings.dart';

/// Short, bundled feedback sounds. They are independent from music and always
/// respect the player's Sound Effects setting.
class SoundManager {
  SoundManager._();

  static final AudioPlayer _tapPlayer = AudioPlayer()
    ..setReleaseMode(ReleaseMode.stop);
  static DateTime? _lastPlayback;
  static bool _configured = false;

  static Future<void> play(SoundType type, GameSettings settings) async {
    if (!settings.soundEnabled) return;
    final now = DateTime.now();
    if (_lastPlayback != null &&
        now.difference(_lastPlayback!) < const Duration(milliseconds: 65)) {
      return;
    }
    _lastPlayback = now;
    try {
      if (!_configured) {
        await _tapPlayer.setAudioContext(
          AudioContextConfig(
            focus: AudioContextConfigFocus.mixWithOthers,
          ).build(),
        );
        _configured = true;
      }
      switch (type) {
        case SoundType.click:
        case SoundType.pickup:
        case SoundType.place:
        case SoundType.submit:
        case SoundType.success:
        case SoundType.victory:
        case SoundType.defeat:
        case SoundType.tie:
        case SoundType.invalid:
          await _tapPlayer.play(AssetSource('audio/tap.wav'), volume: 0.45);
      }
    } catch (_) {
      // Sound effects are optional and must never interrupt a game action.
    }
  }
}

enum SoundType {
  click,
  pickup,
  place,
  invalid,
  submit,
  success,
  victory,
  defeat,
  tie,
}
