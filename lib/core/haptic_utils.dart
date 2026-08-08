import 'package:flutter/services.dart';
import '../../models/game_settings.dart';

class HapticUtils {
  static void trigger(HapticType type, GameSettings settings) {
    if (!settings.hapticEnabled) return;
    switch (type) {
      case HapticType.tap:
        HapticFeedback.selectionClick();
        break;
      case HapticType.place:
        HapticFeedback.lightImpact();
        break;
      case HapticType.success:
        HapticFeedback.mediumImpact();
        break;
      case HapticType.error:
        HapticFeedback.vibrate();
        break;
    }
  }
}

enum HapticType {
  tap,
  place,
  success,
  error,
}
