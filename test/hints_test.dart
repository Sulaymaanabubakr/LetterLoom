import 'package:flutter_test/flutter_test.dart';
import 'package:letterloom/features/hints/hint_service.dart';
import 'package:letterloom/core/app_config.dart';

void main() {
  group('HintState & Allowance Reset Tests', () {
    test('HintState initializes with default daily allowances', () {
      final state = HintState.initial();
      expect(state.dailyMoveRemaining, equals(AppConfig.defaultDailyMoveHints));
      expect(state.dailyLetterRemaining, equals(AppConfig.defaultDailyLetterHints));
      expect(state.dailyStrongRemaining, equals(AppConfig.defaultDailyStrongHints));
      expect(state.purchasedMove, equals(0));
    });

    test('Daily reset preserves purchased hint balances', () {
      final json = {
        'dailyMoveRemaining': 0,
        'dailyLetterRemaining': 0,
        'dailyStrongRemaining': 0,
        'purchasedMove': 5,
        'purchasedLetter': 3,
        'purchasedStrong': 2,
        'adsWatchedToday': 3,
        'lastResetDate': '2026-01-01', // Previous day
      };

      final restored = HintState.fromJson(json);
      // Daily free allowance should reset to full
      expect(restored.dailyMoveRemaining, equals(AppConfig.defaultDailyMoveHints));
      expect(restored.dailyLetterRemaining, equals(AppConfig.defaultDailyLetterHints));
      expect(restored.dailyStrongRemaining, equals(AppConfig.defaultDailyStrongHints));

      // Purchased hints MUST be preserved intact!
      expect(restored.purchasedMove, equals(5));
      expect(restored.purchasedLetter, equals(3));
      expect(restored.purchasedStrong, equals(2));

      // Ads watched resets on new day
      expect(restored.adsWatchedToday, equals(0));
    });
  });
}
