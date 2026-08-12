import 'package:flutter_test/flutter_test.dart';
import 'package:letterloom/features/daily/daily_challenge_service.dart';

void main() {
  test('daily puzzle answer is normalized for authoritative submission', () {
    final puzzle = DailyChallengeService.generatePuzzle('2026-08-12');
    final word = puzzle.words.first;

    expect(word.clue, 'A bright object in the sky');
    expect(word.answer, 'SUN');
    expect(word.answerLength, word.answer.length);
  });
}
