import 'package:flutter_test/flutter_test.dart';
import 'package:letterloom/features/daily/daily_challenge_service.dart';

void main() {
  group('Daily Word Mosaic', () {
    test('generates the same puzzle for the same date and streak', () {
      final first = DailyChallengeService.generatePuzzle(
        '2026-08-11',
        streakDays: 0,
      );
      final second = DailyChallengeService.generatePuzzle(
        '2026-08-11',
        streakDays: 0,
      );

      expect(second.puzzleId, first.puzzleId);
      expect(
        second.words.map((word) => word.answer).toList(),
        first.words.map((word) => word.answer).toList(),
      );
      expect(
        second.words.map((word) => word.letters),
        first.words.map((word) => word.letters),
      );
    });

    test('difficulty increases with the streak tier', () {
      final starter = DailyChallengeService.generatePuzzle(
        '2026-08-11',
        streakDays: 0,
      );
      final advanced = DailyChallengeService.generatePuzzle(
        '2026-08-11',
        streakDays: 10,
      );

      expect(starter.difficultyTier, 0);
      expect(advanced.difficultyTier, 3);
      expect(advanced.words.any((word) => word.answer.length >= 9), isTrue);
    });

    test('excludes previously used puzzle ids when alternatives exist', () {
      final first = DailyChallengeService.generatePuzzle(
        '2026-08-11',
        streakDays: 0,
      );
      final next = DailyChallengeService.generatePuzzle(
        '2026-08-12',
        streakDays: 0,
        excludedPuzzleIds: [first.puzzleId],
      );

      expect(next.puzzleId, isNot(first.puzzleId));
    });
  });
}
