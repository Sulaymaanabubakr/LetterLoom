import 'dart:math';

class RankedRatingResult {
  final int newPlayerRating;
  final int newOpponentRating;
  final int playerDelta;
  final int opponentDelta;

  const RankedRatingResult({
    required this.newPlayerRating,
    required this.newOpponentRating,
    required this.playerDelta,
    required this.opponentDelta,
  });
}

class RankedRatingCalculator {
  static const int kFactor = 32;

  /// Calculates Elo rating updates after a ranked match.
  /// [scoreA]: 1.0 for win, 0.5 for draw, 0.0 for loss.
  static RankedRatingResult calculateRatingChange({
    required int ratingA,
    required int ratingB,
    required double scoreA,
  }) {
    final double expectedA = 1.0 / (1.0 + pow(10, (ratingB - ratingA) / 400.0));
    final double expectedB = 1.0 - expectedA;
    final double scoreB = 1.0 - scoreA;

    final int deltaA = (kFactor * (scoreA - expectedA)).round();
    final int deltaB = (kFactor * (scoreB - expectedB)).round();

    final int newA = max(100, ratingA + deltaA);
    final int newB = max(100, ratingB + deltaB);

    return RankedRatingResult(
      newPlayerRating: newA,
      newOpponentRating: newB,
      playerDelta: deltaA,
      opponentDelta: deltaB,
    );
  }
}
