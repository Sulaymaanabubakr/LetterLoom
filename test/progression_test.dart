import 'package:flutter_test/flutter_test.dart';
import 'package:letterloom/core/app_config.dart';

void main() {
  group('Progression & Level Curve Tests', () {
    test('level 1 starts at 0 XP', () {
      expect(AppConfig.levelForXP(0), equals(1));
      expect(AppConfig.xpRequiredForLevel(1), equals(0));
    });

    test('level increases predictably with XP', () {
      final lvl2XP = AppConfig.xpRequiredForLevel(2);
      expect(lvl2XP, greaterThan(0));
      expect(AppConfig.levelForXP(lvl2XP), equals(2));

      final lvl5XP = AppConfig.xpRequiredForLevel(5);
      expect(AppConfig.levelForXP(lvl5XP), equals(5));
      expect(AppConfig.levelForXP(lvl5XP - 1), equals(4));
    });

    test('Ranked tier mapping maps rating correctly', () {
      expect(AppConfig.getRankedTier(900), equals('Bronze III'));
      expect(AppConfig.getRankedTier(1200), equals('Silver III'));
      expect(AppConfig.getRankedTier(1700), equals('Gold III'));
      expect(AppConfig.getRankedTier(1800), equals('Gold II'));
      expect(AppConfig.getRankedTier(2600), equals('Master'));
    });
  });
}
