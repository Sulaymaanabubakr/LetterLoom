import 'package:flutter/services.dart';
import '../../models/game_settings.dart';

class SoundManager {
  static void play(SoundType type, GameSettings settings) {
    if (!settings.soundEnabled) return;
    
    try {
      switch (type) {
        case SoundType.click:
        case SoundType.place:
        case SoundType.pickup:
          SystemSound.play(SystemSoundType.click);
          break;
        case SoundType.invalid:
          // Try playing system sounds or fallback
          SystemSound.play(SystemSoundType.click);
          break;
        case SoundType.submit:
        case SoundType.success:
          SystemSound.play(SystemSoundType.click);
          break;
        case SoundType.victory:
        case SoundType.defeat:
        case SoundType.tie:
          // System click fallback
          SystemSound.play(SystemSoundType.click);
          break;
      }
    } catch (e) {
      print("Error playing system sound: $e");
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
