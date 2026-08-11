import 'package:flutter_test/flutter_test.dart';
import 'package:letterloom/features/ranked/ranked_rating.dart';

void main() {
  group('RankedRatingCalculator Elo Tests', () {
    test('Winner gains rating points, loser loses rating points', () {
      final res = RankedRatingCalculator.calculateRatingChange(
        ratingA: 1200,
        ratingB: 1200,
        scoreA: 1.0, // A wins
      );

      expect(res.playerDelta, greaterThan(0));
      expect(res.opponentDelta, lessThan(0));
      expect(res.newPlayerRating, equals(1200 + res.playerDelta));
      expect(res.newOpponentRating, equals(1200 + res.opponentDelta));
    });

    test('Higher rated player beating lower rated player gains fewer points', () {
      final resEqual = RankedRatingCalculator.calculateRatingChange(
        ratingA: 1200,
        ratingB: 1200,
        scoreA: 1.0,
      );

      final resFavored = RankedRatingCalculator.calculateRatingChange(
        ratingA: 1600,
        ratingB: 1200,
        scoreA: 1.0,
      );

      expect(resFavored.playerDelta, lessThan(resEqual.playerDelta));
    });

    test('Underdog win yields larger rating gain', () {
      final resUnderdog = RankedRatingCalculator.calculateRatingChange(
        ratingA: 1200,
        ratingB: 1600,
        scoreA: 1.0, // Underdog A wins against higher-rated B
      );

      expect(resUnderdog.playerDelta, greaterThan(16));
    });
  });
}
